base <- qpm_template("bkl")

test_that("identical models give identical responses and moments", {
  cmp <- qpm_compare_models(list(a = base, b = base), shock = "eps_y")
  ia <- cmp$irfs[cmp$irfs$model == "a", ]
  ib <- cmp$irfs[cmp$irfs$model == "b", ]
  expect_equal(ia$value, ib$value)
  ma <- cmp$moments[cmp$moments$model == "a", ]
  mb <- cmp$moments[cmp$moments$model == "b", ]
  expect_equal(ma$sd, mb$sd)
})

test_that("a flatter Phillips curve mutes the inflation response", {
  flat <- qpm_calibrate(base, b2 = 0.05)
  cmp <- qpm_compare_models(list(baseline = base, flat = flat), shock = "eps_y")
  peak <- function(m, v) {
    d <- cmp$irfs[cmp$irfs$model == m & cmp$irfs$variable == v, ]
    max(abs(d$value))
  }
  expect_lt(peak("flat", "pi"), peak("baseline", "pi"))
  # and lower implied inflation volatility
  sd_of <- function(m) cmp$moments$sd[cmp$moments$model == m &
                                        cmp$moments$variable == "pi"]
  expect_lt(sd_of("flat"), sd_of("baseline"))
  expect_output(print(cmp), "peak response")
  expect_output(print(cmp), "implied standard deviations")
})

test_that("comparison works across models with different structures", {
  food <- qpm_template("bkl_food")
  cmp <- qpm_compare_models(list(plain = base, food = food),
                            shock = "eps_pi", vars = c("pi", "i"))
  expect_equal(cmp$vars, c("pi", "i"))
  expect_equal(nrow(cmp$irfs), 2L * 2L * 21L)
  tf <- tempfile(fileext = ".png")
  grDevices::png(tf); plot(cmp); grDevices::dev.off()
  expect_true(file.exists(tf)); unlink(tf)
})

test_that("unit-root models skip the moment table", {
  cmp <- qpm_compare_models(list(a = qpm_template("bkl", trends = "rw"),
                                 b = qpm_template("bkl", trends = "rw")),
                            shock = "eps_pi", vars = c("pi", "i"))
  expect_null(cmp$moments)
  expect_output(print(cmp), "unit roots")
})

test_that("argument checks", {
  expect_error(qpm_compare_models(list(base)), "at least two")
  expect_error(qpm_compare_models(list(base, base)), "must be named")
  expect_error(qpm_compare_models(list(a = base, b = base), shock = "zz"),
               "not a shock in every model")
  expect_error(qpm_compare_models(list(a = base, b = base), vars = "zz"),
               "not common to all models")
  expect_error(qpm_compare_models(list(a = base, b = "nope")),
               "qpm_model or qpm_solution")
})
