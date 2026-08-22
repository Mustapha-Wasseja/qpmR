#' Forecast with parameter uncertainty (posterior fan)
#'
#' Produces a forecast whose fan bands integrate over the posterior:
#' for each sampled parameter draw the model is re-solved, the data
#' re-filtered (so the initial state reflects that draw), and a path
#' sampled from the resulting Gaussian predictive; pointwise band
#' quantiles are then taken across draws. The bands therefore combine
#' future-shock uncertainty with parameter uncertainty — they are wider
#' than the fixed-parameter fans of [qpm_forecast()].
#'
#' @param est A `qpm_estimate` (method `"bayes"`).
#' @param horizon Forecast horizon in quarters.
#' @param ndraws Number of posterior draws to propagate.
#' @param bands Coverage levels for the fan.
#' @return A `qpm_forecast`-compatible object (posterior-mean path,
#'   quantile bands, smoothed history from the posterior-mean model);
#'   `$posterior` records the number of draws used.
#' @examples
#' \donttest{
#' m <- qpm_model(variables = vars(x = "x"), shocks = shocks(e),
#'                equations = eqs(x ~ rho * x[-1] + e),
#'                params = list(rho = 0.5))
#' obs <- simulate(qpm_solve(qpm_calibrate(m, rho = 0.8)), nsim = 120, seed = 1)
#' est <- qpm_estimate(m, obs, priors(rho = beta(0.5, 0.2)),
#'                     iter = 800, chains = 2, seed = 2, verbose = FALSE)
#' fc <- posterior_forecast(est, horizon = 8, ndraws = 100)
#' plot(fc, vars = "x")
#' }
#' @export
posterior_forecast <- function(est, horizon = 12, ndraws = 200,
                               bands = c(0.5, 0.7, 0.9)) {
  stopifnot(inherits(est, "qpm_estimate"))
  ndraws <- min(ndraws, nrow(est$draws))
  pick <- sample.int(nrow(est$draws), ndraws)

  # reference model at the posterior mean (for history, labels, steady state)
  m_ref <- apply_estimate(est, "mean")
  sol_ref <- qpm_solve(m_ref)
  fit_ref <- qpm_filter(sol_ref, est$data, observables = est$observables,
                        measurement_error = est$measurement_error,
                        kappa = est$kappa)
  vs <- sol_ref$vars

  sampled <- array(NA_real_, c(ndraws, horizon, length(vs)),
                   dimnames = list(NULL, NULL, vs))
  mean_acc <- matrix(0, horizon, length(vs), dimnames = list(NULL, vs))
  n_ok <- 0L
  for (i in seq_len(ndraws)) {
    theta <- est$draws[pick[i], ]
    m2 <- est$model
    is_par <- est$names %in% names(m2$params)
    if (any(is_par)) m2$params[est$names[is_par]] <- theta[is_par]
    if (any(!is_par)) m2$sigma[est$names[!is_par]] <- theta[!is_par]
    ok <- tryCatch({
      sol <- qpm_solve(m2)
      fit <- qpm_filter(sol, est$data, observables = est$observables,
                        measurement_error = est$measurement_error,
                        kappa = est$kappa)
      fc <- qpm_forecast(sol, from = fit, horizon = horizon, bands = bands)
      bmax <- max(bands)
      hi_col <- sprintf("hi_%.0f", 100 * bmax)
      zq <- stats::qnorm(0.5 + bmax / 2)
      for (v in vs) {
        d <- fc$paths[fc$paths$variable == v, , drop = FALSE]
        sdv <- (d[[hi_col]] - d$mean) / zq
        sampled[i, , v] <- stats::rnorm(horizon, d$mean, pmax(sdv, 0))
        mean_acc[, v] <- mean_acc[, v] + d$mean
      }
      TRUE
    }, error = function(cnd) FALSE)
    if (ok) n_ok <- n_ok + 1L
  }
  if (n_ok < ndraws * 0.5)
    warning(sprintf("only %d of %d posterior draws produced a valid forecast", n_ok, ndraws))
  keep <- !is.na(sampled[, 1L, 1L])
  sampled <- sampled[keep, , , drop = FALSE]
  mean_path <- mean_acc / n_ok

  rows <- vector("list", length(vs))
  for (j in seq_along(vs)) {
    v <- vs[j]
    d <- data.frame(variable = v, h = seq_len(horizon), mean = mean_path[, v])
    for (b in bands) {
      qs <- apply(sampled[, , v, drop = FALSE], 2L, stats::quantile,
                  probs = c(0.5 - b / 2, 0.5 + b / 2), na.rm = TRUE)
      d[[sprintf("lo_%.0f", 100 * b)]] <- qs[1, ]
      d[[sprintf("hi_%.0f", 100 * b)]] <- qs[2, ]
    }
    rows[[j]] <- d
  }
  paths <- do.call(rbind, rows)
  rownames(paths) <- NULL

  structure(list(paths = paths, bands = bands, horizon = horizon,
                 history = fit_ref$states, ss = sol_ref$ss[vs],
                 labels = sol_ref$labels, units = sol_ref$units,
                 name = sprintf("%s (posterior, %d draws)", sol_ref$name, n_ok),
                 periods = make_forecast_periods(fit_ref, horizon),
                 solution = sol_ref, x0 = fit_ref$states_dev[nrow(fit_ref$states_dev), ],
                 sigma = sol_ref$sigma,
                 dev = mean_path - matrix(sol_ref$ss[vs], horizon, length(vs),
                                          byrow = TRUE, dimnames = list(NULL, vs)),
                 sd_uncond = NULL, baseline_dev = NULL, conditions = NULL,
                 judgment = NULL, shocks_implied = NULL, anticipated = NULL,
                 instruments = NULL, scenario = NULL,
                 posterior = list(ndraws = n_ok)),
            class = "qpm_forecast")
}
