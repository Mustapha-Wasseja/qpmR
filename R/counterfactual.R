#' Historical counterfactuals
#'
#' Rewrites history with some shocks switched off or scaled: "what if
#' the central bank had simply followed its rule through 2022?" is the
#' path implied by setting the policy shocks to zero over that window and
#' re-running the model from the same starting point with all other
#' shocks unchanged.
#'
#' This differs from [qpm_decompose()], which attributes the history that
#' happened; here the history is replayed under a different assumption.
#' The counterfactual is only as good as the model's invariance to the
#' intervention — a Lucas-critique caveat that applies to every exercise
#' of this kind and is worth stating in any write-up.
#'
#' @param fit A `qpm_filtration`.
#' @param shocks Shocks to modify.
#' @param periods Periods over which to modify them (labels as in the
#'   data, or integer indices). Default: the whole sample.
#' @param factor Multiplier applied to the selected shocks; `0` (the
#'   default) switches them off entirely, `0.5` halves them.
#' @param label Optional name for the scenario.
#' @return An object of class `qpm_counterfactual` holding the actual and
#'   counterfactual paths and their difference.
#' @examples
#' sol <- qpm_solve(qpm_template("bkl"))
#' obs <- simulate(sol, nsim = 60, seed = 4, burn = 20)
#' obs$period <- next_quarters("2010-Q4", 60)
#' fit <- qpm_filter(sol, obs[, c("period", "pi", "i", "q")])
#' cf <- qpm_counterfactual(fit, shocks = "eps_i",
#'                          label = "no policy surprises")
#' cf
#' plot(cf, vars = c("pi", "i", "y_gap"))
#' @export
qpm_counterfactual <- function(fit, shocks, periods = NULL, factor = 0,
                               label = NULL) {
  stopifnot(inherits(fit, "qpm_filtration"))
  sol <- fit$solution
  bad <- setdiff(shocks, sol$shocks)
  if (length(bad))
    stop(sprintf("unknown shock(s): %s", paste(bad, collapse = ", ")),
         call. = FALSE)
  if (!is.numeric(factor) || length(factor) != 1L)
    stop("factor must be a single number", call. = FALSE)

  n <- fit$n_obs
  per <- as.character(fit$period)
  if (is.null(periods)) {
    idx <- seq_len(n)
  } else if (is.numeric(periods)) {
    idx <- as.integer(periods)
    if (any(idx < 1 | idx > n)) stop("period indices out of range", call. = FALSE)
  } else {
    idx <- match(as.character(periods), per)
    if (anyNA(idx))
      stop(sprintf("period(s) not in the sample: %s",
                   paste(periods[is.na(idx)], collapse = ", ")), call. = FALSE)
  }

  eps <- as.matrix(fit$shocks[, sol$shocks, drop = FALSE])
  eps_cf <- eps
  eps_cf[idx, shocks] <- eps[idx, shocks] * factor

  N <- length(sol$vars_all)
  replay <- function(e) {
    x <- matrix(0, n, N)
    prev <- fit$alpha0
    for (t in seq_len(n)) {
      prev <- as.numeric(sol$P %*% prev + sol$Q %*% e[t, ])
      x[t, ] <- prev
    }
    colnames(x) <- sol$vars_all
    x
  }
  dev_actual <- replay(eps)
  dev_cf <- replay(eps_cf)

  # the replay of the actual shocks must reproduce the smoothed history
  gap <- max(abs(dev_actual - fit$states_dev))
  if (gap > 1e-6)
    warning(sprintf("replaying the smoothed shocks reproduces the history only to %.2e", gap))

  vs <- sol$vars
  lev <- function(d) as.data.frame(sweep(d[, vs, drop = FALSE], 2L, -sol$ss[vs]))
  actual <- data.frame(period = fit$period, lev(fit$states_dev), check.names = FALSE)
  counter <- data.frame(period = fit$period, lev(dev_cf), check.names = FALSE)

  structure(list(
    label = label %||% sprintf("%s x %g", paste(shocks, collapse = ", "), factor),
    shocks = shocks, factor = factor, periods = per[idx],
    actual = actual, counterfactual = counter,
    difference = data.frame(period = fit$period,
                            counter[vs] - actual[vs], check.names = FALSE),
    vars = vs, labels = sol$labels, n_obs = n, replay_error = gap,
    fit = fit
  ), class = "qpm_counterfactual")
}

#' @export
print.qpm_counterfactual <- function(x, ...) {
  cat(sprintf("<qpm_counterfactual> %s\n", x$label))
  cat(sprintf("  %s scaled by %g over %d period%s (%s ... %s)\n",
              paste(x$shocks, collapse = ", "), x$factor, length(x$periods),
              if (length(x$periods) == 1L) "" else "s",
              x$periods[1], x$periods[length(x$periods)]))
  d <- x$difference
  mx <- vapply(x$vars, function(v) {
    j <- which.max(abs(d[[v]]))
    c(j, d[[v]][j])
  }, numeric(2))
  ord <- order(-abs(mx[2, ]))
  cat("  largest differences (counterfactual minus actual):\n")
  for (v in x$vars[utils::head(ord, 6)])
    cat(sprintf("    %-10s %+7.2f at %s\n", v,
                mx[2, v], as.character(d$period[mx[1, v]])))
  invisible(x)
}

#' @export
#' @rdname qpm_counterfactual
#' @param x A `qpm_counterfactual`.
#' @param vars Variables to plot.
#' @param ... Unused.
plot.qpm_counterfactual <- function(x, vars = NULL, ...) {
  vs <- vars %||% utils::head(x$vars, 4)
  bad <- setdiff(vs, x$vars)
  if (length(bad))
    stop(sprintf("unknown variable(s): %s", paste(bad, collapse = ", ")),
         call. = FALSE)
  n <- length(vs)
  nc <- ceiling(sqrt(n)); nr <- ceiling(n / nc)
  op <- graphics::par(mfrow = c(nr, nc), mar = c(2.4, 2.6, 1.8, 0.6),
                      mgp = c(1.5, 0.4, 0), tcl = -0.25, cex.main = 0.95,
                      cex.axis = 0.85)
  on.exit(graphics::par(op))
  tt <- seq_len(x$n_obs)
  for (v in vs) {
    a <- x$actual[[v]]; c_ <- x$counterfactual[[v]]
    graphics::plot(NA, xlim = range(tt), ylim = range(a, c_), xaxt = "n",
                   xlab = "", ylab = "",
                   main = if (nzchar(x$labels[v] %||% ""))
                     sprintf("%s (%s)", v, x$labels[v]) else v)
    period_axis(x$actual$period)
    graphics::lines(tt, a, col = "grey25", lwd = 1.8)
    graphics::lines(tt, c_, col = "#c23f2e", lwd = 2, lty = 2)
    if (v == vs[1])
      graphics::legend("topleft", c("actual", x$label),
                       col = c("grey25", "#c23f2e"), lwd = 2, lty = c(1, 2),
                       bty = "n", cex = 0.75)
  }
  invisible(x)
}
