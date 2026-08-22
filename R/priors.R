# Prior distributions for Bayesian estimation.
#
# The distribution constructors (normal, beta, gamma, invgamma, uniform,
# truncate) are NOT exported: they exist only inside priors(), which
# evaluates its arguments in an environment that provides them. This
# keeps the pretty syntax without masking base::beta and base::gamma.

make_dist <- function(dist, mean, sd, lower, upper, logd, par) {
  structure(list(dist = dist, mean = mean, sd = sd,
                 lower = lower, upper = upper, logd = logd, par = par),
            class = "qpm_dist")
}

dist_constructors <- function() {
  list(
    normal = function(mean, sd) {
      stopifnot(is.numeric(mean), is.numeric(sd), sd > 0)
      make_dist("normal", mean, sd, -Inf, Inf,
                function(x) stats::dnorm(x, mean, sd, log = TRUE),
                list(mean = mean, sd = sd))
    },
    beta = function(mean, sd) {
      stopifnot(mean > 0, mean < 1, sd > 0)
      if (sd^2 >= mean * (1 - mean))
        stop(sprintf("beta(%.3g, %.3g): sd too large (sd^2 must be < mean*(1-mean))",
                     mean, sd), call. = FALSE)
      k <- mean * (1 - mean) / sd^2 - 1
      a <- mean * k; b <- (1 - mean) * k
      make_dist("beta", mean, sd, 0, 1,
                function(x) stats::dbeta(x, a, b, log = TRUE),
                list(shape1 = a, shape2 = b))
    },
    gamma = function(mean, sd) {
      stopifnot(mean > 0, sd > 0)
      shape <- (mean / sd)^2; rate <- mean / sd^2
      make_dist("gamma", mean, sd, 0, Inf,
                function(x) stats::dgamma(x, shape, rate, log = TRUE),
                list(shape = shape, rate = rate))
    },
    invgamma = function(mean, sd) {
      stopifnot(mean > 0, sd > 0)
      a <- (mean / sd)^2 + 2; b <- mean * (a - 1)
      make_dist("invgamma", mean, sd, 0, Inf,
                function(x) ifelse(x <= 0, -Inf,
                                   a * log(b) - lgamma(a) - (a + 1) * log(x) - b / x),
                list(shape = a, scale = b))
    },
    uniform = function(min, max) {
      stopifnot(is.numeric(min), is.numeric(max), max > min)
      make_dist("uniform", (min + max) / 2, (max - min) / sqrt(12), min, max,
                function(x) stats::dunif(x, min, max, log = TRUE),
                list(min = min, max = max))
    },
    truncate = function(d, lower = -Inf, upper = Inf) {
      stopifnot(inherits(d, "qpm_dist"), upper > lower)
      lo <- max(d$lower, lower); up <- min(d$upper, upper)
      if (up <= lo) stop("truncate(): empty support", call. = FALSE)
      parent_logd <- d$logd
      # renormalize numerically so truncated priors integrate to one --
      # this matters for marginal likelihoods (harmless for MCMC/modes)
      cst <- tryCatch(stats::integrate(function(x) exp(parent_logd(x)),
                                       lo, up, rel.tol = 1e-9)$value,
                      error = function(cnd) NA_real_)
      lc <- if (is.finite(cst) && cst > 0) log(cst) else 0
      make_dist(paste0("trunc-", d$dist), d$mean, d$sd, lo, up,
                function(x) ifelse(x < lo | x > up, -Inf, parent_logd(x) - lc),
                d$par)
    }
  )
}

#' Declare priors for Bayesian estimation
#'
#' One named argument per estimated quantity: a structural parameter name
#' or a shock name (meaning that shock's standard deviation). Everything
#' without a prior stays calibrated.
#'
#' Available distributions (usable only inside `priors()`, so base R's
#' `beta()` and `gamma()` functions are never masked):
#'
#' * `normal(mean, sd)`
#' * `beta(mean, sd)` — on (0, 1), mean/sd parametrization
#' * `gamma(mean, sd)` — on (0, Inf)
#' * `invgamma(mean, sd)` — on (0, Inf); the usual choice for shock sds
#' * `uniform(min, max)`
#' * `truncate(d, lower, upper)` — restrict any of the above; the
#'   normalizing constant is dropped (harmless for modes and MCMC)
#'
#' @param ... Named prior declarations, e.g.
#'   `b1 = beta(0.7, 0.1), c2 = truncate(normal(1.5, 0.25), lower = 1)`.
#' @return An object of class `qpm_priors`.
#' @examples
#' p <- priors(
#'   b1 = beta(0.7, 0.1),
#'   b2 = gamma(0.25, 0.1),
#'   c2 = truncate(normal(1.5, 0.25), lower = 1),
#'   eps_pi = invgamma(1, 0.3)
#' )
#' p
#' @export
priors <- function(...) {
  exprs <- as.list(substitute(list(...)))[-1L]
  nms <- names(exprs)
  if (length(exprs) == 0L) stop("priors(): declare at least one prior", call. = FALSE)
  if (is.null(nms) || any(nms == ""))
    stop("priors(): every prior must be named by a parameter or shock", call. = FALSE)
  env <- list2env(dist_constructors(), parent = parent.frame())
  out <- lapply(exprs, function(e) {
    d <- eval(e, envir = env)
    if (!inherits(d, "qpm_dist"))
      stop("priors(): each prior must be one of normal(), beta(), gamma(), invgamma(), uniform(), truncate()",
           call. = FALSE)
    d
  })
  names(out) <- nms
  structure(out, class = "qpm_priors")
}

#' @export
print.qpm_priors <- function(x, ...) {
  cat(sprintf("<qpm_priors> %d prior%s\n", length(x), if (length(x) == 1L) "" else "s"))
  for (nm in names(x)) {
    d <- x[[nm]]
    bounds <- if (is.finite(d$lower) || is.finite(d$upper))
      sprintf(" on (%s, %s)", fmt_num(d$lower), fmt_num(d$upper)) else ""
    cat(sprintf("  %-10s %s(mean %s, sd %s)%s\n", nm, d$dist,
                fmt_num(d$mean), fmt_num(d$sd), bounds))
  }
  invisible(x)
}

# -- support transforms (to and from unconstrained space) --------------------

tr_fwd <- function(x, d) {
  if (is.finite(d$lower) && is.finite(d$upper))
    stats::qlogis((x - d$lower) / (d$upper - d$lower))
  else if (is.finite(d$lower)) log(x - d$lower)
  else if (is.finite(d$upper)) log(d$upper - x)
  else x
}

tr_inv <- function(u, d) {
  if (is.finite(d$lower) && is.finite(d$upper))
    d$lower + (d$upper - d$lower) * stats::plogis(u)
  else if (is.finite(d$lower)) d$lower + exp(u)
  else if (is.finite(d$upper)) d$upper - exp(u)
  else u
}

# log |dx/du| for the change of variables
tr_logjac <- function(u, d) {
  if (is.finite(d$lower) && is.finite(d$upper)) {
    p <- stats::plogis(u)
    log(d$upper - d$lower) + log(p) + log1p(-p)
  } else if (is.finite(d$lower) || is.finite(d$upper)) u
  else 0
}
