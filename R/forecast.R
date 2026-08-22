#' Model forecast with uncertainty bands
#'
#' Iterates the solved model forward from an initial state and computes
#' analytic forecast uncertainty from the shock variances,
#' \deqn{V_h = P V_{h-1} P' + Q S Q'}
#' giving Gaussian fan bands around the mean path. The result can then be
#' conditioned on assumed paths with [qpm_condition()], shifted by shock
#' scenarios with [qpm_scenario()], or adjusted with logged judgment via
#' [add_judgment()].
#'
#' @param object A `qpm_solution`.
#' @param from Initial state: a `qpm_filtration` from [qpm_filter()] (the
#'   smoothed end-of-sample state is used and the smoothed history is kept
#'   for plotting), a `qpm_sim` from [simulate()], a full named deviation
#'   vector over `object$vars_all`, or `NULL` (steady state).
#' @param horizon Forecast horizon in quarters.
#' @param bands Coverage levels for the fan, e.g. `c(0.5, 0.7, 0.9)`.
#' @param sigma Optional named vector of shock standard deviations.
#' @return An object of class `qpm_forecast`: a list with `paths` (long
#'   data frame: `variable`, `h`, `mean`, and `lo_*`/`hi_*` per band, in
#'   levels), forecast-period labels in `$periods`, plus the machinery
#'   needed for conditioning.
#' @examples
#' sol <- qpm_solve(qpm_template("bkl"))
#' histq <- simulate(sol, nsim = 40, seed = 7, burn = 20)
#' fc <- qpm_forecast(sol, from = histq, horizon = 12)
#' fc
#' plot(fc, vars = c("pi", "i", "y_gap", "q"))
#' @export
qpm_forecast <- function(object, from = NULL, horizon = 12,
                         bands = c(0.5, 0.7, 0.9), sigma = NULL) {
  stopifnot(inherits(object, "qpm_solution"))
  N <- length(object$vars_all)

  history <- NULL
  if (is.null(from)) {
    x0 <- rep(0, N)
  } else if (inherits(from, "qpm_filtration")) {
    x0 <- from$states_dev[nrow(from$states_dev), ]
    history <- from$states
  } else if (inherits(from, "qpm_sim")) {
    x0 <- attr(from, "state")
    history <- from
  } else if (is.numeric(from) && length(from) == N) {
    x0 <- as.numeric(from)
  } else {
    stop(paste0("from must be NULL, a qpm_filtration, a qpm_sim, or a full ",
                "deviation vector over object$vars_all"),
         call. = FALSE)
  }

  sig <- object$sigma
  if (!is.null(sigma)) sig[names(sigma)] <- sigma
  S <- diag(sig^2, length(sig), length(sig))
  QSQ <- object$Q %*% S %*% t(object$Q)

  mean_path <- matrix(0, horizon, N)
  sd_path <- matrix(0, horizon, N)
  x <- x0
  V <- matrix(0, N, N)
  for (h in seq_len(horizon)) {
    x <- as.numeric(object$P %*% x)
    V <- object$P %*% V %*% t(object$P) + QSQ
    mean_path[h, ] <- x
    sd_path[h, ] <- sqrt(pmax(diag(V), 0))
  }
  colnames(mean_path) <- colnames(sd_path) <- object$vars_all

  structure(list(paths = assemble_paths(object, mean_path, sd_path, bands, horizon),
                 bands = bands, horizon = horizon,
                 history = history, ss = object$ss[object$vars],
                 labels = object$labels, units = object$units,
                 name = object$name,
                 periods = make_forecast_periods(from, horizon),
                 solution = object, x0 = x0, sigma = sig,
                 dev = mean_path, sd_uncond = sd_path,
                 baseline_dev = NULL, conditions = NULL, judgment = NULL,
                 shocks_implied = NULL, anticipated = NULL,
                 instruments = NULL, scenario = NULL),
            class = "qpm_forecast")
}

# levels + bands long data frame from a deviation path and sd matrix
assemble_paths <- function(sol, dev, sd_path, bands, horizon) {
  vs <- sol$vars
  ssv <- sol$ss[vs]
  rows <- vector("list", length(vs))
  for (j in seq_along(vs)) {
    v <- vs[j]
    d <- data.frame(variable = v, h = seq_len(horizon),
                    mean = dev[, v] + ssv[[v]])
    for (b in bands) {
      zq <- stats::qnorm(0.5 + b / 2)
      d[[sprintf("lo_%.0f", 100 * b)]] <- d$mean - zq * sd_path[, v]
      d[[sprintf("hi_%.0f", 100 * b)]] <- d$mean + zq * sd_path[, v]
    }
    rows[[j]] <- d
  }
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}

#' @export
print.qpm_forecast <- function(x, ...) {
  cat(sprintf("<qpm_forecast> %s - %d quarters ahead (%s ... %s)\n",
              x$name, x$horizon, x$periods[1], x$periods[x$horizon]))
  if (!is.null(x$scenario))
    cat(sprintf("  scenario: %s (%s)\n", x$scenario$label,
                if (isTRUE(x$scenario$anticipated)) "anticipated" else "unanticipated"))
  if (!is.null(x$conditions) && nrow(x$conditions)) {
    nj <- sum(x$conditions$source == "judgment")
    nc <- sum(x$conditions$source == "condition")
    cat(sprintf("  conditions: %d%s on %s (%s; instruments: %s)\n",
                nc, if (nj) sprintf(" + %d judgment", nj) else "",
                paste(unique(x$conditions$variable), collapse = ", "),
                if (isTRUE(x$anticipated)) "anticipated" else "unanticipated",
                if (length(x$instruments) == length(x$solution$shocks)) "all shocks"
                else paste(x$instruments, collapse = ", ")))
    print_implied_shocks(x)
  }
  hs <- unique(pmin(c(1, 4, 8, x$horizon), x$horizon))
  b <- max(x$bands)
  lo <- sprintf("lo_%.0f", 100 * b); hi <- sprintf("hi_%.0f", 100 * b)
  cat(sprintf("  mean (%d%% band) at h = %s:\n", round(100 * b),
              paste(hs, collapse = ", ")))
  for (v in unique(x$paths$variable)) {
    d <- x$paths[x$paths$variable == v & x$paths$h %in% hs, , drop = FALSE]
    cells <- sprintf("%s (%s, %s)", fmt_num(round(d$mean, 2)),
                     fmt_num(round(d[[lo]], 2)), fmt_num(round(d[[hi]], 2)))
    cat(sprintf("    %-10s %s\n", v, paste(cells, collapse = "  ")))
  }
  if (!is.null(x$judgment) && nrow(x$judgment))
    cat(sprintf("  judgment: %d entr%s (see judgment_log())\n",
                nrow(x$judgment), if (nrow(x$judgment) == 1L) "y" else "ies"))
  invisible(x)
}

print_implied_shocks <- function(x) {
  u <- x$shocks_implied_std
  if (is.null(u)) return(invisible(NULL))
  mx <- apply(abs(u), 2L, max)
  used <- mx > 1e-8
  if (!any(used)) return(invisible(NULL))
  parts <- sprintf("%s %.2f%s", names(mx)[used], mx[used],
                   ifelse(mx[used] > 2, " (!)", ""))
  cat("  implied shocks, max |sd|: ",
      paste(parts, collapse = ", "), "\n", sep = "")
  if (any(mx > 2))
    cat("    (!) shocks above 2 sd: the conditioned path is far from model-typical\n")
  invisible(NULL)
}

#' @export
plot.qpm_forecast <- function(x, vars = NULL, ...) {
  vs <- vars %||% utils::head(unique(x$paths$variable), 4)
  n <- length(vs)
  nc <- ceiling(sqrt(n)); nr <- ceiling(n / nc)
  op <- graphics::par(mfrow = c(nr, nc), mar = c(2.4, 2.6, 1.8, 0.6),
                      mgp = c(1.5, 0.4, 0), tcl = -0.25, cex.main = 0.95,
                      cex.axis = 0.85)
  on.exit(graphics::par(op))

  hist <- x$history
  T0 <- if (!is.null(hist)) nrow(hist) else 0L
  col_line <- "#1f5da8"

  for (v in vs) {
    d <- x$paths[x$paths$variable == v, , drop = FALSE]
    hx <- T0 + d$h
    cn <- if (!is.null(x$conditions))
      x$conditions[x$conditions$variable == v, , drop = FALSE] else NULL
    ylim <- range(c(as.matrix(d[, grepl("^(lo|hi)_", names(d))]), d$mean,
                    if (T0) hist[[v]] else numeric(0),
                    if (!is.null(cn)) cn$value else numeric(0)))
    xlim <- c(if (T0) max(1, T0 - 24) else 1, T0 + x$horizon)
    graphics::plot(NA, xlim = xlim, ylim = ylim, xlab = "quarter", ylab = "",
                   main = if (nzchar(x$labels[v] %||% ""))
                     sprintf("%s (%s)", v, x$labels[v]) else v)
    for (bi in rev(seq_along(x$bands))) {
      b <- x$bands[bi]
      lo <- d[[sprintf("lo_%.0f", 100 * b)]]
      hi <- d[[sprintf("hi_%.0f", 100 * b)]]
      graphics::polygon(c(hx, rev(hx)), c(lo, rev(hi)),
                        col = grDevices::adjustcolor(col_line, alpha.f = 0.14),
                        border = NA)
    }
    graphics::lines(hx, d$mean, col = col_line, lwd = 2)
    if (T0) {
      graphics::lines(seq_len(T0), hist[[v]], col = "grey25", lwd = 1.6)
      graphics::abline(v = T0 + 0.5, lty = 3, col = "grey55")
    }
    graphics::abline(h = x$ss[[v]], lty = 3, col = "grey70")
    if (!is.null(cn) && nrow(cn))
      graphics::points(T0 + cn$h, cn$value, pch = 16, cex = 0.9,
                       col = ifelse(cn$source == "judgment", "#c23f2e", "#1f3a5f"))
  }
  invisible(x)
}
