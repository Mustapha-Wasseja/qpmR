# Standard R generics for qpmR objects. The quantities are already
# computed by the filter and the sampler; exposing them through the
# usual interfaces means AIC(), BIC() and the rest work without qpmR
# having to reimplement anything.

#' Log-likelihood of a filtration or an estimate
#'
#' For a `qpm_filtration` this is the Kalman-filter log-likelihood of
#' the data under the calibrated model, with zero degrees of freedom
#' (nothing was estimated). For a `qpm_estimate` it is the
#' log-likelihood at the posterior mode (or at the maximum for
#' `method = "mle"`), with degrees of freedom equal to the number of
#' estimated parameters — so [stats::AIC()] and [stats::BIC()] work.
#'
#' @param object A `qpm_filtration` or `qpm_estimate`.
#' @param ... Unused.
#' @return An object of class `logLik`.
#' @examples
#' sol <- qpm_solve(qpm_template("bkl"))
#' obs <- simulate(sol, nsim = 40, seed = 1, burn = 20)
#' fit <- qpm_filter(sol, obs[, c("period", "pi", "i", "q")])
#' logLik(fit)
#' @importFrom stats logLik
#' @export
logLik.qpm_filtration <- function(object, ...) {
  structure(object$loglik, df = 0L, nobs = object$n_obs, class = "logLik")
}

#' @rdname logLik.qpm_filtration
#' @export
logLik.qpm_estimate <- function(object, ...) {
  ll <- object$mode_logpost
  if (object$method == "bayes")
    ll <- ll - sum(vapply(seq_along(object$names),
                          function(j) object$priors[[j]]$logd(object$mode[j]),
                          numeric(1)))
  structure(ll, df = length(object$names), nobs = nrow(object$data),
            class = "logLik")
}

#' Number of observations
#'
#' @param object A `qpm_filtration` or `qpm_estimate`.
#' @param ... Unused.
#' @return Number of time periods used.
#' @examples
#' sol <- qpm_solve(qpm_template("bkl"))
#' obs <- simulate(sol, nsim = 40, seed = 1, burn = 20)
#' nobs(qpm_filter(sol, obs[, c("period", "pi", "i")]))
#' @importFrom stats nobs
#' @export
nobs.qpm_filtration <- function(object, ...) object$n_obs

#' @rdname nobs.qpm_filtration
#' @export
nobs.qpm_estimate <- function(object, ...) nrow(object$data)

#' One-step-ahead prediction errors and fitted values
#'
#' `residuals()` returns the filter's one-step-ahead prediction errors
#' for the observed series (`type = "innovation"`), the same divided by
#' their standard deviations (`"standardized"`, which is what the
#' outlier flags use), or the smoothed structural shocks
#' (`"shock"`). `fitted()` returns the one-step-ahead predictions of the
#' observables, so that `observed = fitted + innovation`.
#'
#' @param object A `qpm_filtration`.
#' @param type Which residuals to return.
#' @param ... Unused.
#' @return A data frame with a `period` column and one column per series.
#' @examples
#' sol <- qpm_solve(qpm_template("bkl"))
#' obs <- simulate(sol, nsim = 40, seed = 1, burn = 20)
#' fit <- qpm_filter(sol, obs[, c("period", "pi", "i", "q")])
#' head(residuals(fit, "standardized"))
#' head(fitted(fit))
#' @importFrom stats residuals
#' @export
residuals.qpm_filtration <- function(object,
                                     type = c("innovation", "standardized",
                                              "shock"), ...) {
  type <- match.arg(type)
  m <- switch(type,
              innovation = object$innov,
              standardized = object$innov_std,
              shock = as.matrix(object$shocks[, object$solution$shocks,
                                              drop = FALSE]))
  data.frame(period = object$period, m, check.names = FALSE)
}

#' @rdname residuals.qpm_filtration
#' @importFrom stats fitted
#' @export
fitted.qpm_filtration <- function(object, ...) {
  obs <- as.matrix(object$data[, object$observables, drop = FALSE])
  data.frame(period = object$period, obs - object$innov, check.names = FALSE)
}

#' Posterior covariance and credible intervals
#'
#' @param object A `qpm_estimate`.
#' @param ... Unused.
#' @return `vcov()` returns the posterior covariance matrix of the
#'   estimated parameters; `confint()` returns equal-tailed posterior
#'   credible intervals (posterior quantiles, not asymptotic intervals).
#' @examples
#' \donttest{
#' m <- qpm_model(variables = vars(x = "x"), shocks = shocks(e),
#'                equations = eqs(x ~ rho * x[-1] + e),
#'                params = list(rho = 0.5))
#' obs <- simulate(qpm_solve(qpm_calibrate(m, rho = 0.8)), nsim = 120, seed = 1)
#' est <- qpm_estimate(m, obs, priors(rho = beta(0.5, 0.2)),
#'                     iter = 600, chains = 2, seed = 2, verbose = FALSE)
#' vcov(est)
#' confint(est)
#' }
#' @importFrom stats vcov
#' @export
vcov.qpm_estimate <- function(object, ...) stats::cov(object$draws)

#' @rdname vcov.qpm_estimate
#' @param parm Parameters to report; default all.
#' @param level Credible level.
#' @importFrom stats confint
#' @export
confint.qpm_estimate <- function(object, parm = NULL, level = 0.9, ...) {
  parm <- parm %||% object$names
  bad <- setdiff(parm, object$names)
  if (length(bad))
    stop(sprintf("not estimated: %s", paste(bad, collapse = ", ")), call. = FALSE)
  a <- (1 - level) / 2
  q <- t(apply(object$draws[, parm, drop = FALSE], 2L, stats::quantile,
               probs = c(a, 1 - a)))
  colnames(q) <- sprintf("%.1f%%", 100 * c(a, 1 - a))
  q
}

#' Summarise an estimate
#'
#' Returns the posterior summary as a data frame — prior, mode, mean,
#' standard deviation, credible interval, R-hat and effective sample
#' size — so it can be used programmatically rather than only read.
#'
#' @param object A `qpm_estimate`.
#' @param level Credible level for the interval.
#' @param ... Unused.
#' @return A data frame, one row per estimated parameter.
#' @examples
#' \donttest{
#' m <- qpm_model(variables = vars(x = "x"), shocks = shocks(e),
#'                equations = eqs(x ~ rho * x[-1] + e),
#'                params = list(rho = 0.5))
#' obs <- simulate(qpm_solve(qpm_calibrate(m, rho = 0.8)), nsim = 120, seed = 1)
#' est <- qpm_estimate(m, obs, priors(rho = beta(0.5, 0.2)),
#'                     iter = 600, chains = 2, seed = 2, verbose = FALSE)
#' summary(est)
#' }
#' @export
summary.qpm_estimate <- function(object, level = 0.9, ...) {
  ci <- confint(object, level = level)
  data.frame(
    parameter = object$names,
    prior = vapply(object$priors, function(d)
      sprintf("%s(%s, %s)", d$dist, trimws(fmt_num(d$mean)),
              trimws(fmt_num(d$sd))), character(1)),
    mode = unname(object$mode),
    mean = unname(colMeans(object$draws)),
    sd = unname(apply(object$draws, 2L, stats::sd)),
    lower = unname(ci[, 1]), upper = unname(ci[, 2]),
    rhat = unname(object$rhat), ess = unname(object$ess),
    row.names = NULL, stringsAsFactors = FALSE
  )
}

#' Summarise a filtration
#'
#' @param object A `qpm_filtration`.
#' @param ... Unused.
#' @return A data frame with, for each model variable, whether it was
#'   observed and the mean, standard deviation and range of its smoothed
#'   path, plus the mean estimation standard error for latent states.
#' @examples
#' sol <- qpm_solve(qpm_template("bkl"))
#' obs <- simulate(sol, nsim = 40, seed = 1, burn = 20)
#' summary(qpm_filter(sol, obs[, c("period", "pi", "i", "q")]))
#' @export
summary.qpm_filtration <- function(object, ...) {
  vs <- object$solution$vars
  data.frame(
    variable = vs,
    observed = vs %in% object$observables,
    mean = vapply(vs, function(v) mean(object$states[[v]]), numeric(1)),
    sd = vapply(vs, function(v) stats::sd(object$states[[v]]), numeric(1)),
    min = vapply(vs, function(v) min(object$states[[v]]), numeric(1)),
    max = vapply(vs, function(v) max(object$states[[v]]), numeric(1)),
    se = vapply(vs, function(v) mean(object$se[, v]), numeric(1)),
    row.names = NULL, stringsAsFactors = FALSE
  )
}
