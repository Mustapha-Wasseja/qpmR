#' Estimate model parameters (Bayesian or maximum likelihood)
#'
#' Estimates any subset of structural parameters and shock standard
#' deviations from data, using the Kalman-filter likelihood of the solved
#' model. `method = "bayes"` finds the posterior mode (in transformed,
#' unconstrained space), seeds an adaptive random-walk Metropolis sampler
#' with the inverse Hessian, and returns posterior draws with split
#' R-hat and effective-sample-size diagnostics. `method = "mle"` uses the
#' same machinery with flat priors on the declared supports.
#'
#' Draws that violate Blanchard-Kahn (indeterminacy or explosiveness)
#' receive zero posterior weight — the usual truncation of the prior to
#' the determinacy region. Everything without a prior stays calibrated
#' at its current value.
#'
#' @param model A `qpm_model`.
#' @param data Data frame in levels (as for [qpm_filter()]).
#' @param priors A [priors()] declaration. Names are structural
#'   parameters or shock names (meaning that shock's sd). Required for
#'   `method = "bayes"`; for `"mle"` it supplies supports (and is
#'   otherwise ignored).
#' @param observables,measurement_error,kappa Passed to the filter.
#' @param method `"bayes"` (default) or `"mle"`.
#' @param iter MCMC iterations per chain (including burn-in).
#' @param burn Burn-in iterations (default `iter/2`).
#' @param chains Number of chains (run sequentially).
#' @param thin Keep every `thin`-th post-burn draw.
#' @param seed Optional RNG seed.
#' @param verbose Print progress.
#' @return An object of class `qpm_estimate`: posterior `draws` (natural
#'   units), the `mode`, acceptance rate, split R-hat and effective
#'   sample sizes, and the originating model/data. Use [coef()] to
#'   extract point estimates and [apply_estimate()] to recalibrate the
#'   model.
#' @examples
#' \donttest{
#' m <- qpm_model(variables = vars(x = "x"), shocks = shocks(e),
#'                equations = eqs(x ~ rho * x[-1] + e),
#'                params = list(rho = 0.5))
#' obs <- simulate(qpm_solve(qpm_calibrate(m, rho = 0.8)), nsim = 200, seed = 1)
#' est <- qpm_estimate(m, obs, priors(rho = beta(0.5, 0.2), e = invgamma(1, 0.3)),
#'                     iter = 1000, chains = 2, seed = 2, verbose = FALSE)
#' est
#' }
#' @export
qpm_estimate <- function(model, data, priors, observables = NULL,
                         measurement_error = 0, kappa = 1e6,
                         method = c("bayes", "mle"),
                         iter = 4000, burn = floor(iter / 2), chains = 2,
                         thin = 1, seed = NULL, verbose = TRUE) {
  stopifnot(inherits(model, "qpm_model"), is.data.frame(data))
  method <- match.arg(method)
  if (!inherits(priors, "qpm_priors"))
    stop("priors must come from priors()", call. = FALSE)
  if (!is.null(seed)) set.seed(seed)

  nm <- names(priors)
  is_par <- nm %in% names(model$params)
  is_shk <- nm %in% model$shocks
  bad <- nm[!(is_par | is_shk)]
  if (length(bad))
    stop(sprintf("priors refer to unknown parameters/shocks: %s",
                 paste(bad, collapse = ", ")), call. = FALSE)

  # data plumbing (mirrors qpm_filter)
  candidates <- setdiff(names(data), "period")
  obs <- observables %||% intersect(candidates, model$vars$name)
  if (length(obs) == 0L) stop("no data columns match declared model variables", call. = FALSE)
  Y <- as.matrix(data[, obs, drop = FALSE]); storage.mode(Y) <- "double"

  set_theta <- function(theta) {
    m2 <- model
    if (any(is_par)) m2$params[nm[is_par]] <- theta[is_par]
    if (any(is_shk)) m2$sigma[nm[is_shk]] <- theta[is_shk]
    m2
  }
  loglik_at <- function(theta) {
    m2 <- set_theta(theta)
    sol <- qpm_solve(m2)
    ssm <- state_space(sol, observables = obs,
                       measurement_error = measurement_error, kappa = kappa)
    kalman_loglik(ssm, Y)
  }
  logprior_at <- function(theta) {
    if (method == "mle") return(0)
    sum(vapply(seq_along(nm), function(j) priors[[j]]$logd(theta[j]), numeric(1)))
  }
  logpost_nat <- function(theta) {
    lp <- logprior_at(theta)
    if (!is.finite(lp)) return(-Inf)
    ll <- tryCatch(loglik_at(theta), error = function(cnd) -Inf)
    if (!is.finite(ll)) return(-Inf)
    ll + lp
  }
  to_u <- function(theta) vapply(seq_along(nm), function(j) tr_fwd(theta[j], priors[[j]]), numeric(1))
  to_nat <- function(u) vapply(seq_along(nm), function(j) tr_inv(u[j], priors[[j]]), numeric(1))
  logjac <- function(u) sum(vapply(seq_along(nm), function(j) tr_logjac(u[j], priors[[j]]), numeric(1)))

  # starting point: current calibration if inside support, else prior mean
  theta0 <- vapply(seq_along(nm), function(j) {
    cur <- if (is_par[j]) unname(model$params[[nm[j]]]) else unname(model$sigma[[nm[j]]])
    d <- priors[[j]]
    if (cur > d$lower && cur < d$upper && is.finite(d$logd(cur))) cur else d$mean
  }, numeric(1))
  names(theta0) <- nm
  if (!is.finite(logpost_nat(theta0)))
    stop("the model does not solve (or has zero likelihood) at the starting values; check the calibration and priors",
         call. = FALSE)

  # -- posterior mode in transformed space (no Jacobian: natural-space mode)
  neg_u <- function(u) {
    v <- logpost_nat(to_nat(u))
    if (!is.finite(v)) 1e12 else -v
  }
  if (verbose) cat("finding the posterior mode...\n")
  u0 <- to_u(theta0)
  o1 <- if (length(u0) == 1L) {
    stats::optim(u0, neg_u, method = "Brent", lower = u0 - 20, upper = u0 + 20)
  } else {
    stats::optim(u0, neg_u, method = "Nelder-Mead", control = list(maxit = 2000))
  }
  o2 <- tryCatch(stats::optim(o1$par, neg_u, method = "BFGS",
                              control = list(maxit = 200), hessian = TRUE),
                 error = function(cnd) NULL)
  if (!is.null(o2) && is.finite(o2$value) && o2$value <= o1$value) {
    u_mode <- o2$par; H <- o2$hessian; mode_val <- -o2$value
  } else {
    u_mode <- o1$par; H <- NULL; mode_val <- -o1$value
  }
  mode_nat <- stats::setNames(to_nat(u_mode), nm)

  d <- length(nm)
  Sig <- NULL
  if (!is.null(H)) {
    Sig <- tryCatch(solve((H + t(H)) / 2), error = function(cnd) NULL)
    if (!is.null(Sig) && any(!is.finite(Sig) | diag(Sig) <= 0)) Sig <- NULL
  }
  if (is.null(Sig)) Sig <- diag(0.01, d)
  Sig <- (Sig + t(Sig)) / 2

  # -- adaptive random-walk Metropolis in transformed space ------------------
  target_u <- function(u) {
    v <- logpost_nat(to_nat(u))
    if (!is.finite(v)) -Inf else v + logjac(u)
  }
  n_keep <- floor((iter - burn) / thin)
  draws <- matrix(NA_real_, n_keep * chains, d, dimnames = list(NULL, nm))
  lp_keep <- numeric(n_keep * chains)
  chain_id <- integer(n_keep * chains)
  acc_total <- 0L

  lc <- log(2.38^2 / d)
  for (ch in seq_len(chains)) {
    if (verbose) cat(sprintf("chain %d/%d: %d iterations...\n", ch, chains, iter))
    u <- u_mode + drop(chol(Sig + diag(1e-10, d)) %*% stats::rnorm(d)) * 0.1
    lp_u <- target_u(u)
    tries <- 0L
    while (!is.finite(lp_u) && tries < 50L) {
      u <- u_mode + drop(chol(Sig + diag(1e-10, d)) %*% stats::rnorm(d)) * 0.01
      lp_u <- target_u(u); tries <- tries + 1L
    }
    if (!is.finite(lp_u)) { u <- u_mode; lp_u <- target_u(u) }

    S_ch <- Sig; lc_ch <- lc
    hist_u <- matrix(NA_real_, iter, d)
    acc_block <- 0L; k_block <- 0L
    kept <- 0L
    for (it in seq_len(iter)) {
      prop <- u + drop(chol(S_ch + diag(1e-12, d)) %*% stats::rnorm(d)) * exp(lc_ch / 2)
      lp_p <- target_u(prop)
      if (is.finite(lp_p) && log(stats::runif(1)) < lp_p - lp_u) {
        u <- prop; lp_u <- lp_p
        acc_block <- acc_block + 1L
        if (it > burn) acc_total <- acc_total + 1L
      }
      hist_u[it, ] <- u
      k_block <- k_block + 1L
      # adapt during burn-in only
      if (it <= burn && it %% 50L == 0L) {
        lc_ch <- lc_ch + (acc_block / k_block - 0.25) / sqrt(it / 50)
        acc_block <- 0L; k_block <- 0L
        if (it >= 200L) {
          S_new <- stats::cov(hist_u[seq_len(it), , drop = FALSE])
          if (all(is.finite(S_new))) S_ch <- S_new + diag(1e-8, d)
        }
      }
      if (it > burn && (it - burn) %% thin == 0L && kept < n_keep) {
        kept <- kept + 1L
        row <- (ch - 1L) * n_keep + kept
        draws[row, ] <- to_nat(u)
        lp_keep[row] <- lp_u - logjac(u)
        chain_id[row] <- ch
      }
    }
  }
  acc_rate <- acc_total / (chains * (iter - burn))

  rhat <- vapply(seq_len(d), function(j)
    split_rhat(draws[, j], chain_id), numeric(1))
  ess <- vapply(seq_len(d), function(j)
    ess_geyer(draws[, j], chain_id), numeric(1))
  names(rhat) <- names(ess) <- nm

  structure(list(
    method = method, priors = priors, names = nm,
    draws = draws, logpost = lp_keep, chain = chain_id,
    mode = mode_nat, mode_logpost = mode_val,
    acceptance = acc_rate, rhat = rhat, ess = ess,
    iter = iter, burn = burn, chains = chains, thin = thin,
    model = model, data = data, observables = obs,
    measurement_error = measurement_error, kappa = kappa
  ), class = "qpm_estimate")
}

split_rhat <- function(x, chain) {
  seqs <- unlist(lapply(split(x, chain), function(z) {
    h <- floor(length(z) / 2)
    list(z[seq_len(h)], z[h + seq_len(h)])
  }), recursive = FALSE)
  n <- min(lengths(seqs))
  seqs <- lapply(seqs, utils::head, n)
  mns <- vapply(seqs, mean, numeric(1))
  vrs <- vapply(seqs, stats::var, numeric(1))
  W <- mean(vrs); B <- n * stats::var(mns)
  if (W <= 0) return(NA_real_)
  sqrt((n - 1) / n + B / (n * W))
}

ess_geyer <- function(x, chain) {
  sum(vapply(split(x, chain), function(z) {
    n <- length(z)
    if (stats::var(z) == 0) return(1)
    rho <- stats::acf(z, lag.max = min(200L, n - 2L), plot = FALSE)$acf[-1]
    s <- 0
    for (k in seq(1, length(rho) - 1, by = 2)) {
      pair <- rho[k] + rho[k + 1]
      if (is.na(pair) || pair <= 0) break
      s <- s + pair
    }
    n / (1 + 2 * s)
  }, numeric(1)))
}

#' @export
print.qpm_estimate <- function(x, ...) {
  cat(sprintf("<qpm_estimate> %s - %d parameter%s, %d chains x %d draws (burn %d, acceptance %.2f)\n",
              if (x$method == "bayes") "Bayesian (adaptive RWM)" else "maximum likelihood",
              length(x$names), if (length(x$names) == 1L) "" else "s",
              x$chains, x$iter, x$burn, x$acceptance))
  cat(sprintf("  log-posterior at mode: %.2f\n", x$mode_logpost))
  qs <- apply(x$draws, 2L, stats::quantile, probs = c(0.05, 0.5, 0.95))
  pm <- colMeans(x$draws)
  psd <- apply(x$draws, 2L, stats::sd)
  cat(sprintf("  %-10s %-18s %8s %8s %8s %8s %6s %6s %s\n",
              "param", "prior", "mode", "mean", "5%", "95%", "R-hat", "ESS", "learned"))
  for (j in seq_along(x$names)) {
    d <- x$priors[[j]]
    learned <- if (x$method == "bayes" && is.finite(d$sd) && d$sd > 0) {
      r <- psd[j] / d$sd
      if (r < 0.5) "yes" else if (r < 0.9) "some" else "little"
    } else ""
    cat(sprintf("  %-10s %-18s %8.3f %8.3f %8.3f %8.3f %6.2f %6.0f %s\n",
                x$names[j], sprintf("%s(%.2g, %.2g)", d$dist, d$mean, d$sd),
                x$mode[j], pm[j], qs[1, j], qs[3, j], x$rhat[j], x$ess[j], learned))
  }
  if (any(x$rhat > 1.1, na.rm = TRUE))
    cat("  ! R-hat above 1.1: chains have not mixed; increase iter\n")
  if (x$method == "bayes")
    cat("  'learned' compares posterior to prior sd (yes < 0.5 < some < 0.9 < little)\n")
  invisible(x)
}

#' @export
plot.qpm_estimate <- function(x, vars = NULL, ...) {
  vs <- vars %||% x$names
  vs <- intersect(vs, x$names)
  n <- length(vs)
  nc <- ceiling(sqrt(n)); nr <- ceiling(n / nc)
  op <- graphics::par(mfrow = c(nr, nc), mar = c(2.4, 2.4, 1.8, 0.5),
                      mgp = c(1.5, 0.4, 0), tcl = -0.25, cex.main = 0.95,
                      cex.axis = 0.85)
  on.exit(graphics::par(op))
  for (v in vs) {
    j <- match(v, x$names)
    dr <- x$draws[, j]
    dpost <- stats::density(dr)
    d <- x$priors[[j]]
    lo <- max(d$lower, min(dr) - 3 * stats::sd(dr), d$mean - 4 * d$sd)
    hi <- min(d$upper, max(dr) + 3 * stats::sd(dr), d$mean + 4 * d$sd)
    grid <- seq(lo + 1e-9, hi - 1e-9, length.out = 300)
    dprior <- exp(vapply(grid, d$logd, numeric(1)))
    ylim <- c(0, max(dpost$y, dprior, na.rm = TRUE))
    graphics::plot(NA, xlim = range(grid, dpost$x), ylim = ylim,
                   xlab = "", ylab = "", main = v)
    graphics::polygon(dpost$x, dpost$y,
                      col = grDevices::adjustcolor("#1f5da8", 0.35), border = "#1f5da8")
    graphics::lines(grid, dprior, col = "grey35", lwd = 1.6, lty = 2)
    graphics::abline(v = x$mode[j], col = "#c23f2e", lwd = 1.4)
    if (v == vs[1])
      graphics::legend("topright", c("posterior", "prior", "mode"),
                       col = c("#1f5da8", "grey35", "#c23f2e"),
                       lwd = c(6, 1.6, 1.4), lty = c(1, 2, 1), bty = "n", cex = 0.75)
  }
  invisible(x)
}

#' @export
#' @rdname qpm_estimate
#' @param object A `qpm_estimate`.
#' @param type Point estimate: posterior `"mean"`, `"mode"`, or `"median"`.
#' @param ... Unused.
#' @importFrom stats coef
coef.qpm_estimate <- function(object, type = c("mean", "mode", "median"), ...) {
  type <- match.arg(type)
  switch(type,
         mean = colMeans(object$draws),
         mode = object$mode,
         median = apply(object$draws, 2L, stats::median))
}

#' Recalibrate a model at an estimate's point values
#'
#' @param est A `qpm_estimate`.
#' @param type Passed to [coef.qpm_estimate()].
#' @return The estimation model recalibrated at the chosen point
#'   estimate (structural parameters and shock sds).
#' @examples
#' # see ?qpm_estimate
#' @export
apply_estimate <- function(est, type = "mean") {
  stopifnot(inherits(est, "qpm_estimate"))
  theta <- coef(est, type = type)
  m2 <- est$model
  is_par <- est$names %in% names(m2$params)
  if (any(is_par)) m2$params[est$names[is_par]] <- theta[is_par]
  if (any(!is_par)) m2$sigma[est$names[!is_par]] <- theta[!is_par]
  m2
}
