test_that("a known unidentified product is detected", {
  # a and b enter only as a*b: classic local non-identification
  m <- qpm_model(variables = vars(x = "x"), shocks = shocks(e),
                 equations = eqs(x ~ a * b * x[-1] + e),
                 params = list(a = 0.6, b = 0.9))
  id <- qpm_identify(m, params = c("a", "b"))
  expect_lt(id$solution$rank, 2L)
  expect_setequal(id$solution$weak, c("a", "b"))
  expect_true(length(id$solution$pairs) >= 1)
  expect_output(print(id), "not separately identified")
})

test_that("an identified model passes at full rank", {
  m <- qpm_model(variables = vars(x = "x"), shocks = shocks(e),
                 equations = eqs(x ~ rho * x[-1] + e),
                 params = list(rho = 0.8))
  id <- qpm_identify(m, params = c("rho", "e"))
  expect_equal(id$solution$rank, 2L)
  expect_equal(id$moments$rank, 2L)
  expect_output(print(id), "full rank")
})

test_that("parameters with no effect are flagged", {
  # in the rw template, qbar_ss and rho_qbar drop out of the equations
  m <- qpm_template("bkl", trends = "rw")
  id <- qpm_identify(m, params = c("b1", "b2", "qbar_ss", "rho_qbar"),
                     observables = c("pi4", "i", "q", "dy_obs"))
  expect_true(all(c("qbar_ss", "rho_qbar") %in% id$solution$dead))
  expect_output(print(id), "no effect")
  # unit roots: moment level is skipped with a note
  expect_null(id$moments)
  expect_output(print(id), "unit roots")
})

test_that("the stationary template's core parameters are identified", {
  id <- qpm_identify(qpm_template("bkl"),
                     params = c("b1", "b2", "b3", "c1", "c2", "a1", "a3"),
                     observables = c("pi", "i", "q", "y_gap", "dy_obs"))
  expect_equal(id$solution$rank, 7L)
  expect_s3_class(id, "qpm_identification")
})

test_that("priors objects and bad names are handled", {
  m <- qpm_template("bkl")
  id <- qpm_identify(m, params = priors(b2 = gamma(0.25, 0.1)))
  expect_equal(id$params, "b2")
  expect_error(qpm_identify(m, params = "zz"), "unknown")
  expect_error(qpm_identify(m, observables = "zz"), "unknown observable")
})
