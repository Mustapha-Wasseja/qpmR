#' Marginal likelihood of an estimated model
#'
#' Computes the log marginal likelihood \eqn{\log p(y)} of a Bayesian
#' estimate -- the quantity whose differences across models on the same
#' data are log Bayes factors. Two estimators are reported:
#'
#' * **Modified harmonic mean** (Geweke 1999) from the posterior draws,
#'   computed for a range of truncation probabilities; a small spread
#'   across truncations indicates a reliable estimate.
#' * **Laplace approximation** at the posterior mode in transformed
#'   space (parametrization-invariant because the Jacobian is included),
#'   with a numerically differenced Hessian.
#'
#' Truncated priors created with `truncate()` are renormalized
#' numerically at construction, so they contribute proper densities
#' here.
#'
#' @param est A `qpm_estimate` with `method = "bayes"`.
#' @param taus Truncation probabilities for the modified harmonic mean.
#' @return An object of class `qpm_logml`: `$logml` (harmonic-mean
#'   estimate, averaged over `taus`), `$by_tau`, `$laplace`, and the
#'   spread across truncations.
#' @references Geweke, J. (1999). Using simulation methods for Bayesian
#'   econometric models. Econometric Reviews, 18(1), 1-73.
#' @examples
#' \donttest{
#' m <- qpm_model(variables = vars(x = "x"), shocks = shocks(e),
#'                equations = eqs(x ~ rho * x[-1] + e),
#'                params = list(rho = 0.5))
#' obs <- simulate(qpm_solve(qpm_calibrate(m, rho = 0.8)), nsim = 150, seed = 1)
#' est <- qpm_estimate(m, obs, priors(rho = beta(0.5, 0.2)),
#'                     iter = 1000, chains = 2, seed = 2, verbose = FALSE)
#' marginal_likelihood(est)
#' }
#' @export
marginal_likelihood <- function(est, taus = seq(0.1, 0.9, by = 0.2)) {
  stopifnot(inherits(est, "qpm_estimate"))
  if (est$method != "bayes")
    stop("marginal likelihoods need a Bayesian estimate (method = \"bayes\")",
         call. = FALSE)

  X <- est$draws
  lp <- est$logpost
  n <- nrow(X); d <- ncol(X)

  # -- modified harmonic mean ------------------------------------------------
  mu <- colMeans(X)
  V <- stats::cov(X) + diag(1e-10, d)
  ch <- chol(V)
  ldetV <- 2 * sum(log(diag(ch)))
  Q <- stats::mahalanobis(X, mu, V)
  by_tau <- vapply(taus, function(tau) {
    crit <- stats::qchisq(tau, d)
    inside <- Q <= crit
    if (sum(inside) < 10L) return(NA_real_)
    logf <- -0.5 * (d * log(2 * pi) + ldetV + Q[inside]) - log(tau)
    # log( (1/n) sum exp(logf - lp) ) over the truncated set
    z <- logf - lp[inside]
    -(logsumexp(z) - log(n))
  }, numeric(1))
  logml_hm <- mean(by_tau, na.rm = TRUE)

  # -- Laplace at the mode in transformed space ------------------------------
  ob <- estimation_objective(est$model, est$data, est$priors, est$observables,
                             est$measurement_error, est$kappa, est$method)
  target_u <- function(u) {
    v <- ob$logpost_nat(ob$to_nat(u))
    if (!is.finite(v)) -Inf else v + ob$logjac(u)
  }
  u0 <- ob$to_u(est$mode)
  o <- tryCatch(stats::optim(u0, function(u) {
    v <- target_u(u); if (!is.finite(v)) 1e12 else -v
  }, method = "BFGS", control = list(maxit = 100)), error = function(cnd) NULL)
  u_star <- if (!is.null(o) && is.finite(o$value)) o$par else u0
  H <- num_hessian(function(u) target_u(u), u_star)
  laplace <- NA_real_
  ev <- tryCatch(eigen((H + t(H)) / 2, symmetric = TRUE,
                       only.values = TRUE)$values, error = function(cnd) NULL)
  if (!is.null(ev) && all(ev < 0))
    laplace <- target_u(u_star) + d / 2 * log(2 * pi) - 0.5 * sum(log(-ev))

  structure(list(logml = logml_hm, by_tau = stats::setNames(by_tau, taus),
                 spread = diff(range(by_tau, na.rm = TRUE)),
                 laplace = laplace, ndraws = n, d = d),
            class = "qpm_logml")
}

logsumexp <- function(x) {
  m <- max(x)
  if (!is.finite(m)) return(m)
  m + log(sum(exp(x - m)))
}

num_hessian <- function(f, x, h = 1e-4) {
  d <- length(x)
  H <- matrix(NA_real_, d, d)
  f0 <- f(x)
  hh <- h * pmax(1, abs(x))
  for (i in seq_len(d)) {
    for (j in i:d) {
      if (i == j) {
        xp <- x; xp[i] <- xp[i] + hh[i]
        xm <- x; xm[i] <- xm[i] - hh[i]
        H[i, i] <- (f(xp) - 2 * f0 + f(xm)) / hh[i]^2
      } else {
        xpp <- x; xpp[i] <- xpp[i] + hh[i]; xpp[j] <- xpp[j] + hh[j]
        xpm <- x; xpm[i] <- xpm[i] + hh[i]; xpm[j] <- xpm[j] - hh[j]
        xmp <- x; xmp[i] <- xmp[i] - hh[i]; xmp[j] <- xmp[j] + hh[j]
        xmm <- x; xmm[i] <- xmm[i] - hh[i]; xmm[j] <- xmm[j] - hh[j]
        H[i, j] <- H[j, i] <-
          (f(xpp) - f(xpm) - f(xmp) + f(xmm)) / (4 * hh[i] * hh[j])
      }
    }
  }
  H
}

#' @export
print.qpm_logml <- function(x, ...) {
  cat(sprintf("<qpm_logml> log marginal likelihood: %.2f\n", x$logml))
  cat(sprintf("  modified harmonic mean over %d draws, %d parameters\n",
              x$ndraws, x$d))
  cat(sprintf("  by truncation: %s (spread %.2f%s)\n",
              paste(sprintf("%.2f", x$by_tau), collapse = ", "), x$spread,
              if (is.finite(x$spread) && x$spread > 1) " - unstable, increase draws" else ""))
  if (is.finite(x$laplace))
    cat(sprintf("  Laplace approximation: %.2f\n", x$laplace))
  cat("  differences across models on the same data are log Bayes factors\n")
  invisible(x)
}
