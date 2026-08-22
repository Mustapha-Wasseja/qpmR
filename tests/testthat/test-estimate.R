# AR(1) laboratory: cheap likelihood, known truth
m0 <- qpm_model(variables = vars(x = "x"), shocks = shocks(e),
                equations = eqs(x ~ rho * x[-1] + e),
                params = list(rho = 0.5))
m_true <- qpm_calibrate(m0, rho = 0.8, sigma = c(e = 1.5))
obs <- simulate(qpm_solve(m_true), nsim = 250, seed = 4)

test_that("the posterior concentrates on the truth (AR(1))", {
  est <- qpm_estimate(m0, obs,
                      priors(rho = beta(0.5, 0.2), e = invgamma(1, 0.5)),
                      iter = 1200, chains = 2, seed = 5, verbose = FALSE)
  pm <- coef(est, "mean")
  expect_gt(pm[["rho"]], 0.7); expect_lt(pm[["rho"]], 0.9)
  expect_gt(pm[["e"]], 1.2); expect_lt(pm[["e"]], 1.8)
  expect_lt(abs(est$mode[["rho"]] - 0.8), 0.1)
  expect_true(all(est$rhat < 1.2, na.rm = TRUE))
  expect_true(all(est$ess > 20))
  expect_gt(est$acceptance, 0.08); expect_lt(est$acceptance, 0.65)
  expect_output(print(est), "R-hat")
  expect_output(print(est), "learned")

  tf <- tempfile(fileext = ".png")
  grDevices::png(tf); plot(est); grDevices::dev.off()
  expect_true(file.exists(tf)); unlink(tf)

  m_hat <- apply_estimate(est, "mean")
  expect_equal(unname(m_hat$params[["rho"]]), unname(pm[["rho"]]))
  expect_s3_class(qpm_solve(m_hat), "qpm_solution")

  fc <- posterior_forecast(est, horizon = 8, ndraws = 60)
  expect_s3_class(fc, "qpm_forecast")
  d <- fc$paths[fc$paths$variable == "x", ]
  expect_true(all(d$lo_90 <= d$mean + 1e-8 & d$mean <= d$hi_90 + 1e-8))
  # parameter uncertainty widens the fan relative to the point model
  fc0 <- qpm_forecast(qpm_solve(m_hat),
                      from = qpm_filter(qpm_solve(m_hat), obs), horizon = 8)
  d0 <- fc0$paths[fc0$paths$variable == "x", ]
  expect_gt(d$hi_90[8] - d$lo_90[8], 0.85 * (d0$hi_90[8] - d0$lo_90[8]))
})

test_that("MLE agrees with the known AR(1) estimator", {
  est <- qpm_estimate(m0, obs,
                      priors(rho = uniform(-0.99, 0.99), e = uniform(0.01, 10)),
                      method = "mle", iter = 200, chains = 1, seed = 6,
                      verbose = FALSE)
  x <- obs$x - mean(obs$x)
  rho_ols <- sum(x[-1] * x[-length(x)]) / sum(x[-length(x)]^2)
  expect_lt(abs(est$mode[["rho"]] - rho_ols), 0.05)
})

test_that("bad prior names and broken starting points are caught", {
  expect_error(qpm_estimate(m0, obs, priors(zz = normal(0, 1)),
                            iter = 10, verbose = FALSE),
               "unknown parameters")
  expect_error(qpm_estimate(m0, obs, "not priors", iter = 10, verbose = FALSE),
               "priors\\(\\)")
})

test_that("estimation runs on the full template (smoke)", {
  m <- qpm_template("bkl")
  truth <- simulate(qpm_solve(m), nsim = 80, seed = 8, burn = 20)
  est <- qpm_estimate(m, truth[, c("period", "pi", "i", "q", "y_gap")],
                      priors(b2 = gamma(0.25, 0.1)),
                      iter = 240, burn = 120, chains = 1, seed = 9,
                      verbose = FALSE)
  expect_true(is.finite(est$mode_logpost))
  expect_gt(coef(est, "mean")[["b2"]], 0.05)
  expect_lt(coef(est, "mean")[["b2"]], 0.6)
})
