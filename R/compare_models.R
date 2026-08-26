#' Compare the behaviour of two or more models
#'
#' [qpm_diff()] compares model *structure* — what a country team changed
#' in the code. This compares model *behaviour*: the transmission of a
#' given shock and the moments each specification implies. When a
#' calibration is revised, both questions matter, and the second is the
#' one a policy audience asks.
#'
#' @param models A named list of `qpm_model` or `qpm_solution` objects.
#' @param shock Shock whose impulse responses are compared. Default: the
#'   first shock common to every model.
#' @param vars Variables to compare. Default: those common to all models,
#'   capped at the usual headline set.
#' @param horizon Impulse-response horizon.
#' @return An object of class `qpm_model_comparison` holding the
#'   impulse responses and, for stationary models, the implied moments.
#' @examples
#' base <- qpm_template("bkl")
#' flat <- qpm_calibrate(base, b2 = 0.05)   # a much flatter Phillips curve
#' cmp <- qpm_compare_models(list(baseline = base, flat = flat),
#'                           shock = "eps_y")
#' cmp
#' plot(cmp, vars = c("pi", "i"))
#' @export
qpm_compare_models <- function(models, shock = NULL, vars = NULL,
                               horizon = 20) {
  if (!is.list(models) || length(models) < 2L)
    stop("supply a list of at least two models", call. = FALSE)
  if (is.null(names(models)) || any(names(models) == ""))
    stop("the list of models must be named", call. = FALSE)
  sols <- lapply(models, function(m)
    if (inherits(m, "qpm_model")) qpm_solve(m)
    else if (inherits(m, "qpm_solution")) m
    else stop("models must be qpm_model or qpm_solution objects", call. = FALSE))

  common_sh <- Reduce(intersect, lapply(sols, `[[`, "shocks"))
  if (!length(common_sh))
    stop("the models share no shocks, so their responses cannot be compared",
         call. = FALSE)
  shock <- shock %||% common_sh[1]
  if (!(shock %in% common_sh))
    stop(sprintf("'%s' is not a shock in every model", shock), call. = FALSE)

  common_v <- Reduce(intersect, lapply(sols, `[[`, "vars"))
  if (is.null(vars)) {
    vars <- intersect(c(if ("pi4" %in% common_v) "pi4" else "pi", "pi",
                        "i", "y_gap", "q"), common_v)
    if (!length(vars)) vars <- utils::head(common_v, 4)
  }
  bad <- setdiff(vars, common_v)
  if (length(bad))
    stop(sprintf("variable(s) not common to all models: %s",
                 paste(bad, collapse = ", ")), call. = FALSE)

  irfs <- do.call(rbind, lapply(names(sols), function(nm) {
    ir <- irf(sols[[nm]], shock = shock, horizon = horizon, vars = vars)
    data.frame(model = nm, as.data.frame(ir)[, c("variable", "horizon", "value")],
               stringsAsFactors = FALSE)
  }))

  moments <- NULL
  if (all(vapply(sols, function(s) (s$counts$unit %||% 0L) == 0L, TRUE))) {
    moments <- do.call(rbind, lapply(names(sols), function(nm) {
      p <- model_properties(sols[[nm]], vars = vars, lags = 1)
      data.frame(model = nm, variable = p$variable, sd = p$model_sd,
                 ac1 = p$model_ac1, stringsAsFactors = FALSE)
    }))
  }

  structure(list(models = names(sols), shock = shock, vars = vars,
                 horizon = horizon, irfs = irfs, moments = moments,
                 labels = sols[[1]]$labels),
            class = "qpm_model_comparison")
}

#' @export
print.qpm_model_comparison <- function(x, ...) {
  cat(sprintf("<qpm_model_comparison> %s\n", paste(x$models, collapse = " vs ")))
  cat(sprintf("  response to %s over %d quarters\n", x$shock, x$horizon))
  cat("  peak response by model:\n")
  for (v in x$vars) {
    parts <- vapply(x$models, function(m) {
      d <- x$irfs[x$irfs$model == m & x$irfs$variable == v, ]
      j <- which.max(abs(d$value))
      sprintf("%s %+.2f@%d", m, d$value[j], d$horizon[j])
    }, character(1))
    cat(sprintf("    %-10s %s\n", v, paste(parts, collapse = "   ")))
  }
  if (!is.null(x$moments)) {
    cat("  implied standard deviations:\n")
    for (v in x$vars) {
      d <- x$moments[x$moments$variable == v, ]
      cat(sprintf("    %-10s %s\n", v,
                  paste(sprintf("%s %.2f", d$model, d$sd), collapse = "   ")))
    }
  } else {
    cat("  (moments omitted: at least one model has unit roots)\n")
  }
  invisible(x)
}

#' @export
#' @rdname qpm_compare_models
#' @param x A `qpm_model_comparison`.
#' @param ... Unused.
plot.qpm_model_comparison <- function(x, vars = NULL, ...) {
  vs <- vars %||% x$vars
  bad <- setdiff(vs, x$vars)
  if (length(bad))
    stop(sprintf("not in this comparison: %s", paste(bad, collapse = ", ")),
         call. = FALSE)
  n <- length(vs)
  nc <- ceiling(sqrt(n)); nr <- ceiling(n / nc)
  cols <- qpm_palette(length(x$models))
  op <- graphics::par(mfrow = c(nr, nc), mar = c(2.4, 2.6, 1.8, 0.6),
                      mgp = c(1.5, 0.4, 0), tcl = -0.25, cex.main = 0.95,
                      cex.axis = 0.85)
  on.exit(graphics::par(op))
  for (v in vs) {
    d <- x$irfs[x$irfs$variable == v, ]
    graphics::plot(NA, xlim = range(d$horizon), ylim = range(d$value, 0),
                   xlab = "quarters", ylab = "",
                   main = if (nzchar(x$labels[v] %||% ""))
                     sprintf("%s (%s)", v, x$labels[v]) else v)
    graphics::abline(h = 0, lty = 3, col = "grey55")
    for (j in seq_along(x$models)) {
      dm <- d[d$model == x$models[j], ]
      graphics::lines(dm$horizon, dm$value, col = cols[j], lwd = 2)
    }
    if (v == vs[1])
      graphics::legend("topright", legend = x$models, col = cols, lwd = 2,
                       bty = "n", cex = 0.8)
  }
  invisible(x)
}
