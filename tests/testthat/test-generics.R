sol <- qpm_solve(qpm_template("bkl"))
obs <- simulate(sol, nsim = 60, seed = 1, burn = 20)
fit <- qpm_filter(sol, obs[, c("period", "pi", "i", "q")])

test_that("logLik and nobs agree with the filter, and AIC/BIC work", {
  ll <- logLik(fit)
  expect_s3_class(ll, "logLik")
  expect_equal(as.numeric(ll), fit$loglik)
  expect_equal(attr(ll, "df"), 0L)       # a filtration estimates nothing
  expect_equal(attr(ll, "nobs"), 60L)
  expect_equal(nobs(fit), 60L)
  expect_equal(AIC(fit), -2 * fit$loglik)
  expect_equal(BIC(fit), -2 * fit$loglik)   # df = 0, so no penalty
})

test_that("observed equals fitted plus innovation", {
  f <- fitted(fit); r <- residuals(fit)
  expect_named(f, c("period", "pi", "i", "q"))
  for (v in c("pi", "i", "q"))
    expect_equal(f[[v]] + r[[v]], obs[[v]], tolerance = 1e-10)
})

test_that("residual types return the right quantities", {
  expect_equal(residuals(fit, "innovation")$pi, unname(fit$innov[, "pi"]))
  expect_equal(residuals(fit, "standardized")$pi, unname(fit$innov_std[, "pi"]))
  sh <- residuals(fit, "shock")
  expect_true(all(sol$shocks %in% names(sh)))
  expect_equal(nrow(sh), 60L)
  # standardized innovations should be roughly unit variance
  z <- residuals(fit, "standardized")$pi
  expect_gt(stats::sd(z, na.rm = TRUE), 0.5)
  expect_lt(stats::sd(z, na.rm = TRUE), 2)
  expect_error(residuals(fit, "nope"))
})

test_that("summary of a filtration flags observed vs latent states", {
  s <- summary(fit)
  expect_true(all(c("variable", "observed", "mean", "sd", "se") %in% names(s)))
  expect_true(all(s$observed[s$variable %in% c("pi", "i", "q")]))
  expect_false(s$observed[s$variable == "y_gap"])
  # observed series carry (almost) no estimation uncertainty
  expect_lt(max(s$se[s$observed]), 1e-8)
  expect_gt(s$se[s$variable == "y_gap"], 1e-4)
})

test_that("estimate generics expose the posterior", {
  skip_on_cran()
  m0 <- qpm_model(variables = vars(x = "x"), shocks = shocks(e),
                  equations = eqs(x ~ rho * x[-1] + e), params = list(rho = 0.5))
  o2 <- simulate(qpm_solve(qpm_calibrate(m0, rho = 0.8)), nsim = 150, seed = 3)
  est <- qpm_estimate(m0, o2, priors(rho = beta(0.5, 0.2), e = invgamma(1, 0.5)),
                      iter = 600, chains = 2, seed = 4, verbose = FALSE)

  ll <- logLik(est)
  expect_equal(attr(ll, "df"), 2L)
  expect_true(is.finite(as.numeric(ll)))
  # log posterior = log likelihood + log prior, evaluated at the mode
  # (the log prior may be positive: these are densities, not probabilities)
  lp <- sum(vapply(seq_along(est$names),
                   function(j) est$priors[[j]]$logd(est$mode[j]), numeric(1)))
  expect_equal(as.numeric(ll) + lp, est$mode_logpost, tolerance = 1e-10)
  expect_equal(AIC(est), -2 * as.numeric(ll) + 4)
  expect_equal(nobs(est), 150L)

  V <- vcov(est)
  expect_equal(dim(V), c(2L, 2L))
  expect_equal(rownames(V), c("rho", "e"))
  expect_true(all(diag(V) > 0))
  expect_equal(V, t(V))

  ci <- confint(est, level = 0.9)
  expect_equal(dim(ci), c(2L, 2L))
  expect_true(all(ci[, 1] < ci[, 2]))
  pm <- coef(est, "mean")
  expect_true(all(ci[, 1] < pm & pm < ci[, 2]))
  expect_error(confint(est, parm = "zz"), "not estimated")

  s <- summary(est)
  expect_equal(nrow(s), 2L)
  expect_true(all(c("parameter", "prior", "mode", "mean", "sd",
                    "lower", "upper", "rhat", "ess") %in% names(s)))
  expect_equal(s$mean, unname(pm))
  expect_false(any(grepl("  ", s$prior)))   # no padding artefacts
})
