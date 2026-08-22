sol_rw <- qpm_solve(qpm_template("bkl", trends = "rw"))

test_that("the rw template solves with two unit roots and a clean normalization", {
  expect_equal(sol_rw$counts$unit, 2L)
  expect_equal(sol_rw$ss_free, 2L)
  ss <- steady_state(sol_rw)
  # unit roots must not contaminate the economics: gaps zero, pi at target
  expect_equal(unname(ss["y_gap"]), 0, tolerance = 1e-7)
  expect_equal(unname(ss["pi"]), 5, tolerance = 1e-7)
  expect_equal(unname(ss["i"]), 9, tolerance = 1e-7)
  expect_equal(unname(ss["r_bar"]), 4, tolerance = 1e-7)
  expect_equal(unname(ss["q"]), 0, tolerance = 1e-7)
  expect_equal(unname(ss["dy_bar"]), 0, tolerance = 1e-7)
  expect_true(any(eigen_table(sol_rw)$unit))
})

test_that("diffuse filtering recovers latent trends from rw data", {
  truth <- simulate(sol_rw, nsim = 80, seed = 5, burn = 10)
  fit <- qpm_filter(sol_rw, truth[, c("period", "pi4", "i", "q", "dy_obs")])
  expect_true(fit$diffuse)
  expect_equal(fit$n_unit, 2L)
  expect_true(is.finite(fit$loglik))
  expect_gt(cor(fit$states$y_gap, truth$y_gap), 0.85)   # observed: 0.94
  expect_gt(cor(fit$states$dy_bar, truth$dy_bar), 0.7)  # observed: 0.83
  expect_gt(cor(fit$states$q_bar, truth$q_bar), 0.4)    # observed: 0.61
  expect_output(print(fit), "diffuse")
})

test_that("unit-root uncertainty grows without bound; stationary does not", {
  truth <- simulate(sol_rw, nsim = 80, seed = 5, burn = 10)
  fit <- qpm_filter(sol_rw, truth[, c("period", "pi4", "i", "q", "dy_obs")])
  fc <- qpm_forecast(sol_rw, from = fit, horizon = 40)
  bw <- function(v) {
    d <- fc$paths[fc$paths$variable == v, ]
    d$hi_90 - d$lo_90
  }
  expect_gt(bw("q_bar")[40] / bw("q_bar")[5], 2)     # keeps widening
  expect_lt(bw("y_gap")[40] / bw("y_gap")[5], 1.6)   # plateaus
})

test_that("the stationary template is unaffected by the growth block", {
  sol <- qpm_solve(qpm_template("bkl"))
  expect_equal(sol$counts$unit, 0L)
  ss <- steady_state(sol)
  expect_equal(unname(ss["dy_obs"]), 3.5, tolerance = 1e-7)  # g_ss
  expect_equal(unname(ss["dy_bar"]), 3.5, tolerance = 1e-7)
})
