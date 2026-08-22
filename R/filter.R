#' Estimate latent states from data (Kalman filter/smoother)
#'
#' Runs the Kalman filter and RTS smoother over the solved model, jointly
#' inferring every latent variable — output gap, neutral rate, equilibrium
#' exchange rate, trend processes — and the historical structural shocks
#' from whatever subset of variables you actually observe. Missing values
#' (ragged edges, gappy series) are handled naturally.
#'
#' The filter is initialized at the model's stationary distribution
#' (Lyapunov covariance), which is exact for the stationary models qpmR
#' currently supports.
#'
#' @param x A `qpm_model` (solved internally) or `qpm_solution`.
#' @param data A data frame in levels (model units). Columns whose names
#'   match declared variables are used as observables; an optional
#'   `period` column provides labels. `NA`s are allowed anywhere.
#' @param observables Optional character vector restricting which columns
#'   are treated as observed.
#' @param measurement_error Measurement-error standard deviation(s):
#'   scalar or named vector over observables. Defaults to 0.
#' @param kappa Diffuse-prior variance scale used when the model has
#'   unit-root (random-walk) trends; see [state_space()].
#' @return An object of class `qpm_filtration`: smoothed states in levels
#'   (`$states`), their standard errors (`$se`), smoothed structural
#'   shocks (`$shocks`), the log-likelihood (`$loglik`), innovation
#'   diagnostics (`$diag`), and the full expanded-state matrix
#'   (`$states_dev`). Feed it to [qpm_decompose()] for historical shock
#'   decompositions or to [qpm_forecast()] to forecast from the smoothed
#'   current state.
#' @examples
#' sol <- qpm_solve(qpm_template("bkl"))
#' obs <- simulate(sol, nsim = 60, seed = 3, burn = 20)
#' fit <- qpm_filter(sol, obs[, c("period", "pi", "i", "q")])
#' fit
#' plot(fit, vars = c("y_gap", "r_bar"))
#' @export
qpm_filter <- function(x, data, observables = NULL, measurement_error = 0,
                       kappa = 1e6) {
  solution <- if (inherits(x, "qpm_model")) qpm_solve(x) else x
  stopifnot(inherits(solution, "qpm_solution"))
  if (!is.data.frame(data)) stop("data must be a data frame", call. = FALSE)

  period <- if ("period" %in% names(data)) data[["period"]] else seq_len(nrow(data))
  candidates <- setdiff(names(data), "period")
  obs <- observables %||% intersect(candidates, solution$vars)
  if (length(obs) == 0L)
    stop(sprintf(paste0("no data columns match declared model variables.\n",
                        "  data columns: %s\n  model variables: %s"),
                 paste(candidates, collapse = ", "),
                 paste(solution$vars, collapse = ", ")), call. = FALSE)
  ignored <- setdiff(candidates, c(obs, solution$vars))
  if (is.null(observables) && length(ignored))
    message(sprintf("ignoring non-model columns: %s", paste(ignored, collapse = ", ")))

  m <- state_space(solution, observables = obs,
                   measurement_error = measurement_error, kappa = kappa)
  Y <- as.matrix(data[, obs, drop = FALSE])
  storage.mode(Y) <- "double"

  ks <- kalman_smooth(m, Y)

  states_dev <- ks$ahat
  colnames(states_dev) <- solution$vars_all
  lev <- sweep(states_dev, 2L, -solution$ss)   # deviations + steady state
  se <- ks$se
  colnames(se) <- solution$vars_all

  states <- data.frame(period = period,
                       lev[, solution$vars, drop = FALSE],
                       check.names = FALSE)
  shocks <- data.frame(period = period, ks$shocks, check.names = FALSE)
  shocks_std <- sweep(ks$shocks, 2L, pmax(solution$sigma, 1e-12), "/")

  # innovation diagnostics
  lb <- sapply(obs, function(v) {
    z <- ks$innov_std[, v]
    z <- z[!is.na(z)]
    if (length(z) < 12L) return(NA_real_)
    stats::Box.test(z, lag = min(8L, floor(length(z) / 4)), type = "Ljung-Box")$p.value
  })
  out_idx <- which(abs(ks$innov_std) > 3, arr.ind = TRUE)
  outliers <- if (nrow(out_idx)) {
    data.frame(period = period[out_idx[, 1L]],
               series = colnames(ks$innov_std)[out_idx[, 2L]],
               std_innov = round(ks$innov_std[out_idx], 2))
  } else {
    data.frame(period = character(0), series = character(0), std_innov = numeric(0))
  }

  structure(list(
    name = solution$name,
    states = states, states_dev = states_dev, se = se,
    shocks = shocks, shocks_std = shocks_std,
    alpha0 = ks$alpha0, loglik = ks$loglik,
    innov = ks$innov, innov_std = ks$innov_std,
    diag = list(ljung_box = lb, outliers = outliers),
    observables = obs, period = period, data = data,
    n_missing = sum(is.na(Y)), n_obs = nrow(Y),
    diffuse = m$diffuse, n_unit = m$n_unit,
    solution = solution
  ), class = "qpm_filtration")
}

#' @export
print.qpm_filtration <- function(x, ...) {
  cat(sprintf("<qpm_filtration> %s\n", x$name))
  cat(sprintf("  periods %s-%s (%d) - observables: %s - missing: %d of %d\n",
              x$period[1], x$period[x$n_obs], x$n_obs,
              paste(x$observables, collapse = ", "),
              x$n_missing, x$n_obs * length(x$observables)))
  cat(sprintf("  log-likelihood: %.2f%s\n", x$loglik,
              if (isTRUE(x$diffuse))
                sprintf(" (approximate diffuse init, %d unit roots)", x$n_unit)
              else ""))
  lb <- x$diag$ljung_box
  if (any(!is.na(lb))) {
    j <- which.min(lb)
    cat(sprintf("  innovation diagnostics: Ljung-Box min p = %.2f (%s)%s\n",
                lb[j], names(lb)[j],
                if (lb[j] < 0.05) " - autocorrelated innovations, check specification" else ""))
  }
  no <- x$diag$outliers
  if (nrow(no)) {
    k <- which.max(abs(no$std_innov))
    cat(sprintf("  outliers (|std innov| > 3): %d; largest: period %s %s (%+.1f sd)\n",
                nrow(no), no$period[k], no$series[k], no$std_innov[k]))
  } else {
    cat("  outliers (|std innov| > 3): none\n")
  }
  lat <- setdiff(x$solution$vars, x$observables)
  if (length(lat))
    cat("  latent states estimated: ",
        paste(utils::head(lat, 8), collapse = ", "),
        if (length(lat) > 8) ", ..." else "", "\n", sep = "")
  invisible(x)
}

#' @export
plot.qpm_filtration <- function(x, vars = NULL, level = 0.9, ...) {
  vs <- vars %||% utils::head(setdiff(x$solution$vars, x$observables), 4)
  if (length(vs) == 0L) vs <- utils::head(x$solution$vars, 4)
  bad <- setdiff(vs, x$solution$vars)
  if (length(bad))
    stop(sprintf("unknown variable(s): %s", paste(bad, collapse = ", ")), call. = FALSE)
  z <- stats::qnorm(0.5 + level / 2)
  labels <- x$solution$labels
  col_line <- "#1f5da8"

  n <- length(vs)
  nc <- ceiling(sqrt(n)); nr <- ceiling(n / nc)
  op <- graphics::par(mfrow = c(nr, nc), mar = c(2.4, 2.6, 1.8, 0.6),
                      mgp = c(1.5, 0.4, 0), tcl = -0.25, cex.main = 0.95,
                      cex.axis = 0.85)
  on.exit(graphics::par(op))
  tt <- seq_len(x$n_obs)
  for (v in vs) {
    est <- x$states[[v]]
    se <- x$se[, v]
    lo <- est - z * se; hi <- est + z * se
    obs_pts <- if (v %in% x$observables) x$data[[v]] else NULL
    ylim <- range(lo, hi, obs_pts, na.rm = TRUE)
    graphics::plot(NA, xlim = range(tt), ylim = ylim, xlab = "", ylab = "",
                   xaxt = "n",
                   main = if (nzchar(labels[v] %||% ""))
                     sprintf("%s (%s)", v, labels[v]) else v)
    period_axis(x$period)
    graphics::polygon(c(tt, rev(tt)), c(lo, rev(hi)),
                      col = grDevices::adjustcolor(col_line, alpha.f = 0.18),
                      border = NA)
    graphics::lines(tt, est, col = col_line, lwd = 2)
    if (!is.null(obs_pts))
      graphics::points(tt, obs_pts, pch = 16, cex = 0.5, col = "grey25")
    graphics::abline(h = x$solution$ss[v], lty = 3, col = "grey60")
  }
  invisible(x)
}

# axis with period labels at pretty positions (falls back to indices)
period_axis <- function(period, side = 1) {
  n <- length(period)
  at <- unique(round(pretty(seq_len(n), n = 6)))
  at <- at[at >= 1 & at <= n]
  graphics::axis(side, at = at, labels = as.character(period)[at], cex.axis = 0.8)
}
