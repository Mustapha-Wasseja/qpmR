sol <- qpm_solve(qpm_template("bkl"))
obs <- simulate(sol, nsim = 60, seed = 4, burn = 20)
obs$period <- next_quarters("2010-Q4", 60)
fit <- qpm_filter(sol, obs[, c("period", "pi", "i", "q")])

test_that("replaying the smoothed shocks reproduces the smoothed history", {
  cf <- qpm_counterfactual(fit, shocks = "eps_i", factor = 1)
  expect_lt(cf$replay_error, 1e-8)
  # factor = 1 changes nothing at all
  for (v in c("pi", "i", "y_gap", "q"))
    expect_equal(cf$counterfactual[[v]], cf$actual[[v]], tolerance = 1e-8)
  expect_lt(max(abs(as.matrix(cf$difference[cf$vars]))), 1e-8)
})

test_that("switching a shock off changes history in the expected direction", {
  cf <- qpm_counterfactual(fit, shocks = "eps_i", factor = 0)
  d <- cf$difference
  expect_gt(max(abs(d$i)), 0.1)          # the policy path really moves
  # where the actual policy shock was positive (tighter than the rule),
  # the counterfactual rate is lower
  eps <- fit$shocks$eps_i
  big <- which.max(abs(eps))
  expect_equal(sign(d$i[big]), -sign(eps[big]))
})

test_that("shutting off all shocks leaves only the initial condition", {
  cf <- qpm_counterfactual(fit, shocks = sol$shocks, factor = 0)
  # with no shocks the economy decays from alpha0 back to steady state
  last <- vapply(c("pi", "i", "y_gap"),
                 function(v) cf$counterfactual[[v]][fit$n_obs], numeric(1))
  ss <- steady_state(sol)[c("pi", "i", "y_gap")]
  expect_lt(max(abs(last - ss)), 0.05)
})

test_that("a period window restricts the intervention", {
  win <- as.character(fit$period[10:20])
  cf <- qpm_counterfactual(fit, shocks = "eps_i", periods = win)
  d <- cf$difference
  expect_lt(max(abs(d$i[1:9])), 1e-9)     # nothing before the window
  expect_gt(max(abs(d$i[10:20])), 1e-6)   # something inside it
  expect_equal(cf$periods, win)
  # integer indices work too
  cf2 <- qpm_counterfactual(fit, shocks = "eps_i", periods = 10:20)
  expect_equal(cf2$difference$i, d$i, tolerance = 1e-12)
})

test_that("partial scaling lies between the extremes", {
  full <- qpm_counterfactual(fit, shocks = "eps_i", factor = 0)$difference$i
  half <- qpm_counterfactual(fit, shocks = "eps_i", factor = 0.5)$difference$i
  expect_equal(half, full / 2, tolerance = 1e-8)   # the model is linear
})

test_that("printing, plotting and argument checks behave", {
  cf <- qpm_counterfactual(fit, shocks = "eps_i", label = "no surprises")
  expect_output(print(cf), "no surprises")
  expect_output(print(cf), "largest differences")
  tf <- tempfile(fileext = ".png")
  grDevices::png(tf); plot(cf, vars = c("pi", "i")); grDevices::dev.off()
  expect_true(file.exists(tf)); unlink(tf)
  expect_error(qpm_counterfactual(fit, shocks = "zz"), "unknown shock")
  expect_error(qpm_counterfactual(fit, "eps_i", periods = "1066-Q1"), "not in the sample")
  expect_error(qpm_counterfactual(fit, "eps_i", periods = 999), "out of range")
  expect_error(qpm_counterfactual(fit, "eps_i", factor = c(1, 2)), "single number")
  expect_error(plot(cf, vars = "zz"), "unknown variable")
})
