# AR(1) laboratory (cheap likelihoods)
m0 <- qpm_model(variables = vars(x = "x"), shocks = shocks(e),
                equations = eqs(x ~ rho * x[-1] + e),
                params = list(rho = 0.5))
m_true <- qpm_calibrate(m0, rho = 0.8)
obs <- simulate(qpm_solve(m_true), nsim = 200, seed = 14)

est_full <- qpm_estimate(m0, obs,
                         priors(rho = beta(0.5, 0.2), e = invgamma(1, 0.5)),
                         iter = 1200, chains = 2, seed = 15, verbose = FALSE)

test_that("the harmonic-mean estimate is stable and Laplace agrees", {
  ml <- marginal_likelihood(est_full)
  expect_true(is.finite(ml$logml))
  expect_lt(ml$spread, 1.5)                     # stable across truncations
  expect_true(is.finite(ml$laplace))
  expect_lt(abs(ml$laplace - ml$logml), 3)      # same order, as they should be
  expect_output(print(ml), "Bayes factors")
})

test_that("the true model beats a misspecified one by a large Bayes factor", {
  # restricted model: rho fixed at 0 (white noise), only the shock sd estimated
  m_wn <- qpm_calibrate(m0, rho = 0)
  est_wn <- qpm_estimate(m_wn, obs, priors(e = invgamma(1, 0.5)),
                         iter = 1200, chains = 2, seed = 16, verbose = FALSE)
  ml_full <- marginal_likelihood(est_full)
  ml_wn <- marginal_likelihood(est_wn)
  expect_gt(ml_full$logml - ml_wn$logml, 10)    # decisive
})

test_that("MLE estimates refuse a marginal likelihood", {
  est_mle <- qpm_estimate(m0, obs, priors(rho = uniform(-0.99, 0.99)),
                          method = "mle", iter = 200, chains = 1, seed = 17,
                          verbose = FALSE)
  expect_error(marginal_likelihood(est_mle), "Bayesian")
})

test_that("truncated priors are properly normalized", {
  p <- priors(c2 = truncate(normal(1.5, 0.25), lower = 1))
  d <- p$c2
  z <- stats::integrate(function(x) exp(d$logd(x)), 1, Inf)$value
  expect_equal(z, 1, tolerance = 1e-6)
})
