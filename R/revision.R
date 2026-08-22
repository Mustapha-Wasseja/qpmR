# Forecast revision decomposition across rounds.
#
# compare_rounds() rebuilds the path from the old round to the new one by
# swapping one ingredient at a time and re-running the full pipeline
# (solve -> filter -> forecast -> conditions/judgment):
#
#   f0  old round as archived (recomputed, and checked against the archive)
#   f1  + new calibration                    -> "parameters"
#   f2a + new data values on the old window  -> "data revisions"
#   f2b + the new quarters (new window)      -> "new data"
#   f3  + the new round's conditions         -> "conditions"
#   f4  + the new round's judgment           -> "judgment"  ( = new round)
#
# The contributions telescope, so they sum to the total revision exactly;
# f4 is verified against the new round's archived forecast. The order is
# fixed and documented; a Shapley average over orderings is on the roadmap.

# Re-run one full pipeline. Conditions/judgment are re-resolved by period
# label; entries that fall inside the data window (now outturns) or beyond
# the horizon are dropped and reported.
run_pipeline <- function(model, data, observables, horizon, bands,
                         measurement_error, kappa,
                         conditions = NULL, anticipated = FALSE,
                         instruments = NULL) {
  sol <- qpm_solve(model)
  fit <- qpm_filter(sol, data, observables = observables,
                    measurement_error = measurement_error, kappa = kappa)
  fc <- qpm_forecast(sol, from = fit, horizon = horizon, bands = bands)

  dropped <- NULL
  if (!is.null(conditions) && nrow(conditions)) {
    h_new <- match(conditions$period, fc$periods)
    in_data <- conditions$period %in% as.character(fit$period)
    keep <- !is.na(h_new)
    if (any(!keep)) {
      dropped <- data.frame(variable = conditions$variable[!keep],
                            period = conditions$period[!keep],
                            source = conditions$source[!keep],
                            reason = ifelse(in_data[!keep], "now an outturn",
                                            "beyond the horizon"),
                            stringsAsFactors = FALSE)
      conditions <- conditions[keep, , drop = FALSE]
      h_new <- h_new[keep]
    }
    if (nrow(conditions)) {
      conditions$h <- h_new
      fc$baseline_dev <- fc$dev
      fc$conditions <- conditions
      fc <- recondition(fc, anticipated = anticipated, instruments = instruments)
    }
  }
  attr(fc, "dropped") <- dropped
  fc
}

round_conditions <- function(round, sources = c("condition", "judgment")) {
  cn <- round$forecast$conditions
  if (is.null(cn)) return(NULL)
  cn[cn$source %in% sources, , drop = FALSE]
}

fc_values <- function(fc, variables, periods) {
  h <- match(periods, fc$periods)
  out <- vapply(variables, function(v) {
    d <- fc$paths[fc$paths$variable == v, , drop = FALSE]
    d$mean[match(h, d$h)]
  }, numeric(length(periods)))
  matrix(out, nrow = length(periods),
         dimnames = list(periods, variables))
}

#' Compare two forecast rounds: the revision decomposition
#'
#' Decomposes the forecast revision between two rounds -- "inflation for
#' 2027-Q1 is 0.4pp higher than we said in June: why?" -- into the
#' contributions of new data (outturns), data revisions, calibration
#' changes, changed conditions, and judgment, by re-running the full
#' pipeline swapping one ingredient at a time. The contributions
#' telescope, so they sum to the total revision exactly; the final step
#' is verified against the new round's archived forecast.
#'
#' Requirements: both rounds must use the same model structure and the
#' same observables, and their data must carry `"YYYY-Qq"` period labels
#' so the calendars align. Comparison covers the calendar quarters both
#' rounds forecast.
#'
#' @param old,new `qpm_round` objects (or names to [load_round()] from
#'   `store`).
#' @param variables Variables to decompose (default: all).
#' @param store Round store used when `old`/`new` are names.
#' @return An object of class `qpm_revision`: a data frame with one row
#'   per variable and overlap period, columns `old`, `new`, `total`, and
#'   the five contributions. Print shows waterfall tables; `plot()`
#'   draws stacked contribution bars across the overlap.
#' @examples
#' m <- qpm_template("bkl")
#' obs <- simulate(qpm_solve(m), nsim = 44, seed = 1, burn = 20)
#' obs$period <- next_quarters("2015-Q4", 44)
#' rA <- qpm_round("June", m, obs[1:40, c("period", "pi", "i", "q")], horizon = 8)
#' rB <- qpm_round("September", m, obs[, c("period", "pi", "i", "q")], horizon = 8)
#' rB <- add_judgment(rB, pi = stats::setNames(0.3, rB$forecast$periods[2]),
#'                    author = "desk", rationale = "tariff")
#' rev <- compare_rounds(rA, rB)
#' rev
#' @export
compare_rounds <- function(old, new, variables = NULL, store = "rounds") {
  if (is.character(old)) old <- load_round(old, store)
  if (is.character(new)) new <- load_round(new, store)
  stopifnot(inherits(old, "qpm_round"), inherits(new, "qpm_round"))

  same_structure <-
    identical(vapply(old$model$equations, deparse1, character(1)),
              vapply(new$model$equations, deparse1, character(1))) &&
    identical(old$model$vars$name, new$model$vars$name) &&
    identical(old$model$shocks, new$model$shocks)
  if (!same_structure)
    stop("the rounds use different model structures; the revision decomposition needs the same equations",
         call. = FALSE)
  if (!identical(sort(old$observables), sort(new$observables)))
    stop("the rounds observe different variables; changing observables between rounds is not yet decomposed",
         call. = FALSE)
  for (fld in c("measurement_error", "kappa"))
    if (!identical(old[[fld]], new[[fld]]))
      stop(sprintf("the rounds differ in %s; align them before comparing", fld),
           call. = FALSE)

  overlap <- intersect(old$forecast$periods, new$forecast$periods)
  if (length(overlap) == 0L)
    stop("the rounds' forecast horizons do not overlap in calendar time",
         call. = FALSE)
  variables <- variables %||% new$solution$vars
  bad <- setdiff(variables, new$solution$vars)
  if (length(bad))
    stop(sprintf("unknown variable(s): %s", paste(bad, collapse = ", ")), call. = FALSE)

  old_cn <- round_conditions(old)
  new_cn <- round_conditions(new, "condition")
  new_jd <- round_conditions(new, "judgment")
  a_old <- isTRUE(old$forecast$anticipated)
  a_new <- isTRUE(new$forecast$anticipated)
  i_old <- old$forecast$instruments
  i_new <- new$forecast$instruments

  pipe <- function(model, data, horizon, conditions, anticipated, instruments)
    run_pipeline(model, data, old$observables, horizon, new$bands,
                 new$measurement_error, new$kappa,
                 conditions = conditions, anticipated = anticipated,
                 instruments = instruments)

  # ingredient swaps
  m1 <- old$model
  m1$params <- new$model$params
  m1$sigma <- new$model$sigma

  old_window <- as.character(old$data$period)
  d_rev <- new$data[match(old_window, as.character(new$data$period)), , drop = FALSE]
  if (anyNA(match(old_window, as.character(new$data$period))))
    stop("the new round's data does not cover the old round's window; cannot align vintages",
         call. = FALSE)

  f0  <- pipe(old$model, old$data, old$horizon, old_cn, a_old, i_old)
  f1  <- pipe(m1, old$data, old$horizon, old_cn, a_old, i_old)
  f2a <- pipe(m1, d_rev, old$horizon, old_cn, a_old, i_old)
  f2b <- pipe(m1, new$data, new$horizon, old_cn, a_old, i_old)
  f3  <- pipe(m1, new$data, new$horizon, new_cn, a_new, i_new)
  f4  <- pipe(m1, new$data, new$horizon, rbind(new_cn, new_jd), a_new, i_new)

  # integrity: the endpoints must reproduce the archived rounds
  chk0 <- max(abs(fc_values(f0, variables, overlap) -
                    fc_values(old$forecast, variables, overlap)))
  chk4 <- max(abs(fc_values(f4, variables, overlap) -
                    fc_values(new$forecast, variables, overlap)))
  if (chk0 > 1e-6)
    warning(sprintf(paste0("re-running the old round does not reproduce its archived ",
                           "forecast (max gap %.2g); it may have been produced by a ",
                           "different qpmR version (%s)"), chk0, old$qpmR_version))
  if (chk4 > 1e-6)
    warning(sprintf("decomposition endpoint differs from the new round's archived forecast (max gap %.2g)",
                    chk4))

  v0 <- fc_values(f0, variables, overlap)
  steps <- list(parameters = f1, data_revisions = f2a, new_data = f2b,
                conditions = f3, judgment = f4)
  vals <- lapply(steps, fc_values, variables = variables, periods = overlap)

  rows <- vector("list", length(variables))
  for (j in seq_along(variables)) {
    prev <- v0[, j]
    contrib <- sapply(vals, function(m) {
      out <- m[, j] - prev
      prev <<- m[, j]
      out
    })
    if (is.null(dim(contrib))) contrib <- matrix(contrib, nrow = 1,
                                                 dimnames = list(NULL, names(vals)))
    rows[[j]] <- data.frame(variable = variables[j], period = overlap,
                            old = v0[, j], new = vals$judgment[, j],
                            total = vals$judgment[, j] - v0[, j],
                            contrib, stringsAsFactors = FALSE, row.names = NULL)
  }
  out <- do.call(rbind, rows)

  dropped <- unique(do.call(rbind, lapply(list(f2b, f3, f4), attr, "dropped")))
  structure(out, class = c("qpm_revision", "data.frame"),
            old_name = old$name, new_name = new$name,
            dropped = dropped,
            labels = new$solution$labels)
}

REV_COMPONENTS <- c("parameters", "data_revisions", "new_data",
                    "conditions", "judgment")
REV_LABELS <- c(parameters = "parameters", data_revisions = "data revisions",
                new_data = "new data (outturns)", conditions = "conditions",
                judgment = "judgment")

#' @export
print.qpm_revision <- function(x, variables = NULL, periods = NULL, ...) {
  df <- as.data.frame(x)
  cat(sprintf("<qpm_revision> %s -> %s\n", attr(x, "old_name"), attr(x, "new_name")))
  dropped <- attr(x, "dropped")
  if (!is.null(dropped) && nrow(dropped))
    cat(sprintf("  note: %d condition/judgment entr%s no longer bind (%s)\n",
                nrow(dropped), if (nrow(dropped) == 1L) "y" else "ies",
                paste(unique(dropped$reason), collapse = "; ")))
  vs <- variables %||%
    utils::head(intersect(c("pi4", "pi", "i", "y_gap"), unique(df$variable)), 3)
  if (length(vs) == 0L) vs <- utils::head(unique(df$variable), 3)
  ps <- periods %||% utils::head(unique(df$period), 1)
  for (v in vs) for (p in ps) {
    d <- df[df$variable == v & df$period == p, , drop = FALSE]
    if (nrow(d) == 0L) next
    cat(sprintf("  %s at %s: %.2f -> %.2f  (%+.2f)\n",
                v, p, d$old, d$new, d$total))
    for (cc in REV_COMPONENTS)
      cat(sprintf("    %+6.2f  %s\n", d[[cc]], REV_LABELS[[cc]]))
  }
  more_p <- setdiff(unique(df$period), ps)
  if (length(more_p))
    cat(sprintf("  (+ %d more period%s; print(x, variables=, periods=) or plot(x, variable=))\n",
                length(more_p), if (length(more_p) == 1L) "" else "s"))
  invisible(x)
}

#' @export
#' @rdname compare_rounds
#' @param x A `qpm_revision`.
#' @param variable Variable to plot.
#' @param ... Unused.
plot.qpm_revision <- function(x, variable = NULL, ...) {
  df <- as.data.frame(x)
  variable <- variable %||% df$variable[1]
  d <- df[df$variable == variable, , drop = FALSE]
  if (nrow(d) == 0L)
    stop(sprintf("variable '%s' not in this revision", variable), call. = FALSE)
  M <- as.matrix(d[, REV_COMPONENTS, drop = FALSE])
  n <- nrow(d)
  cols <- qpm_palette(length(REV_COMPONENTS))
  ylim <- range(rowSums(M * (M > 0)), rowSums(M * (M < 0)), d$total, 0)
  labels <- attr(x, "labels")

  op <- graphics::par(mar = c(2.6, 2.8, 2.0, 0.6), mgp = c(1.6, 0.4, 0),
                      tcl = -0.25, cex.axis = 0.85)
  on.exit(graphics::par(op))
  graphics::plot(NA, xlim = c(0.5, n + 0.5), ylim = ylim, xlab = "",
                 ylab = "revision (pp)", xaxt = "n",
                 main = sprintf("Forecast revision of %s: %s -> %s", variable,
                                attr(x, "old_name"), attr(x, "new_name")))
  period_axis(d$period)
  for (t in seq_len(n)) {
    ypos <- 0; yneg <- 0
    for (j in seq_along(REV_COMPONENTS)) {
      vv <- M[t, j]
      if (vv >= 0) {
        graphics::rect(t - 0.42, ypos, t + 0.42, ypos + vv, col = cols[j], border = NA)
        ypos <- ypos + vv
      } else {
        graphics::rect(t - 0.42, yneg + vv, t + 0.42, yneg, col = cols[j], border = NA)
        yneg <- yneg + vv
      }
    }
  }
  graphics::lines(seq_len(n), d$total, lwd = 2.2, col = "grey15", type = "b", pch = 16, cex = 0.7)
  graphics::abline(h = 0, col = "grey40", lwd = 0.8)
  graphics::legend("topleft", legend = unname(REV_LABELS[REV_COMPONENTS]),
                   fill = cols, border = NA, bty = "n", cex = 0.72, ncol = 2)
  invisible(x)
}
