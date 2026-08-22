test_that("unknown symbols are caught at construction", {
  expect_error(
    qpm_model(variables = vars(x = "x"), shocks = shocks(e),
              equations = eqs(x ~ 0.5 * zz[-1] + e)),
    "unknown"
  )
})

test_that("equation/variable count mismatch is caught", {
  expect_error(
    qpm_model(variables = vars(x = "x", y = "y"), shocks = shocks(e),
              equations = eqs(x ~ 0.5 * x[-1] + e)),
    "2 variables"
  )
})

test_that("variables never used are caught", {
  expect_error(
    qpm_model(variables = vars(x = "x", y = "y"), shocks = shocks(e, u),
              equations = eqs(x ~ 0.5 * x[-1] + e, x ~ x[-1] + u)),
    "never appear"
  )
})

test_that("nonlinear equations are rejected", {
  expect_error(
    qpm_solve(qpm_model(variables = vars(x = "x"), shocks = shocks(e),
                        equations = eqs(x ~ 0.5 * x[-1]^2 + e))),
    class = "qpm_nonlinear"
  )
})

test_that("shocks with lags are rejected", {
  expect_error(
    qpm_model(variables = vars(x = "x"), shocks = shocks(e),
              equations = eqs(x ~ 0.5 * x[-1] + e[-1])),
    "contemporaneous"
  )
})

test_that("duplicate names across sets are rejected", {
  expect_error(
    qpm_model(variables = vars(x = "x"), shocks = shocks(x),
              equations = eqs(x ~ 0.5 * x[-1])),
    "more than once"
  )
})

test_that("reserved auxiliary suffixes are rejected", {
  expect_error(vars(x.L1 = "bad"), "reserved")
})

test_that("calibration typos are caught with the parameter list", {
  m <- qpm_template("bkl")
  expect_error(qpm_calibrate(m, b99 = 1), "unknown parameter")
  m2 <- qpm_calibrate(m, b2 = 0.3)
  expect_equal(unname(m2$params[["b2"]]), 0.3)
})

test_that("parameters named like base constants are shadowed correctly", {
  # a variable named pi must never pick up base::pi
  m <- qpm_model(variables = vars(pi = "inflation"), shocks = shocks(e),
                 equations = eqs(pi ~ 0.5 * pi[-1] + e))
  sol <- qpm_solve(m)
  expect_equal(unname(steady_state(sol)["pi"]), 0, tolerance = 1e-10)
})
