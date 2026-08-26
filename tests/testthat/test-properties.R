sol <- qpm_solve(qpm_template("bkl"))

test_that("model moments match a long simulation from the same model", {
  obs <- simulate(sol, nsim = 4000, seed = 11, burn = 200)
  p <- model_properties(sol, data = obs, vars = c("y_gap", "pi", "i", "q"))
  expect_s3_class(p, "qpm_properties")
  # the population moments are the truth; a long sample should be close
  expect_lt(max(abs(p$model_sd / p$data_sd - 1)), 0.12)
  expect_lt(max(abs(p$model_ac1 - p$data_ac1)), 0.06)
  expect_output(print(p), "model-implied moments")
})

test_that("the analytic AR(1) moments are reproduced exactly", {
  m <- qpm_model(variables = vars(x = "x"), shocks = shocks(e),
                 equations = eqs(x ~ 0.8 * x[-1] + e))
  p <- model_properties(qpm_calibrate(m, sigma = c(e = 1.5)), lags = c(1, 2, 4))
  expect_equal(p$model_sd, 1.5 / sqrt(1 - 0.64), tolerance = 1e-10)
  expect_equal(p$model_ac1, 0.8, tolerance = 1e-10)
  expect_equal(p$model_ac2, 0.8^2, tolerance = 1e-10)
  expect_equal(p$model_ac4, 0.8^4, tolerance = 1e-10)
  expect_equal(p$main_shock, "e (100%)")
})

test_that("unit-root models report that population moments do not exist", {
  p <- model_properties(qpm_template("bkl", trends = "rw"),
                        vars = c("pi", "q_bar"))
  expect_false(attr(p, "stationary"))
  expect_false("model_sd" %in% names(p))
  expect_output(print(p), "population moments do not exist")
})

test_that("data columns that are absent are reported, not silently dropped", {
  obs <- simulate(sol, nsim = 100, seed = 12, burn = 50)
  obs$q <- NULL
  p <- model_properties(sol, data = obs, vars = c("pi", "q"))
  expect_true(is.na(p$data_sd[p$variable == "q"]))
  expect_equal(attr(p, "missing_cols"), "q")
  expect_output(print(p), "not in the data")
})

test_that("a badly scaled calibration is flagged against the data", {
  obs <- simulate(sol, nsim = 300, seed = 13, burn = 50)
  loud <- qpm_calibrate(qpm_template("bkl"), sigma = c(eps_pi = 8))
  p <- model_properties(loud, data = obs, vars = c("pi", "y_gap"))
  expect_output(print(p), "differ by more than")
})

test_that("argument checks", {
  expect_error(model_properties(sol, vars = "zz"), "unknown variable")
  expect_error(model_properties(sol, lags = 0), "positive")
  expect_error(model_properties(sol, data = "not a frame"), "data frame")
})
