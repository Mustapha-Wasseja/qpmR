# The first-order system is assembled from a cached, parameter-independent
# structure. These tests are what make that cache safe: the cached path must
# produce exactly the same matrices as building from scratch, and must stay
# correct when the calibration changes, which is the whole point of caching.

strip_structure <- function(m) { m$structure <- NULL; m }

expect_same_system <- function(m, info = NULL) {
  cached <- build_first_order(m)
  fresh <- build_first_order(strip_structure(m))
  expect_equal(cached$A, fresh$A, info = info)
  expect_equal(cached$B, fresh$B, info = info)
  expect_equal(cached$C, fresh$C, info = info)
  expect_equal(cached$D, fresh$D, info = info)
  expect_equal(cached$const, fresh$const, info = info)
  expect_equal(cached$vars_all, fresh$vars_all, info = info)
}

test_that("the cached structure reproduces the system exactly", {
  for (tpl in c("bkl", "bkl_food", "managed_fx"))
    expect_same_system(qpm_template(tpl), info = tpl)
  expect_same_system(qpm_template("bkl", trends = "rw"), info = "rw")
})

test_that("it holds for deep lags and leads, which need auxiliary states", {
  m <- qpm_model(variables = vars(x = "x", y = "y"), shocks = shocks(e, u),
                 equations = eqs(x ~ 0.3 * x[-4] + 0.2 * E(y[+3]) + e,
                                 y ~ 0.5 * y[-1] + 0.1 * x[-2] + u))
  expect_same_system(m, info = "deep")
  sys <- build_first_order(m)
  expect_true(all(c("x.L1", "x.L2", "x.L3", "y.F1", "y.F2") %in% sys$vars_all))
  expect_s3_class(qpm_solve(m), "qpm_solution")
})

test_that("recalibration keeps the cache valid and changes the answer", {
  m <- qpm_template("bkl")
  m2 <- qpm_calibrate(m, b2 = 0.4, c2 = 2.5)
  expect_same_system(m2, info = "recalibrated")
  # the structure is shared but the numbers are not
  s1 <- build_first_order(m); s2 <- build_first_order(m2)
  expect_equal(s1$vars_all, s2$vars_all)
  expect_false(isTRUE(all.equal(s1$B, s2$B)))
  # and solving gives what recalibration should give
  expect_false(isTRUE(all.equal(qpm_solve(m)$P, qpm_solve(m2)$P)))
})

test_that("shock standard deviations do not touch the system matrices", {
  m <- qpm_template("bkl")
  m2 <- qpm_calibrate(m, sigma = c(eps_pi = 3))
  s1 <- build_first_order(m); s2 <- build_first_order(m2)
  expect_equal(s1$D, s2D <- s2$D)      # D holds loadings, not sds
  expect_equal(s1$A, s2$A)
})

test_that("a stale or missing cache is detected and rebuilt", {
  m <- qpm_template("bkl")
  # missing entirely (a model from an older version)
  expect_silent(build_first_order(strip_structure(m)))
  # stale: structure from a different model
  bad <- m
  bad$structure <- qpm_template("bkl_food")$structure
  expect_equal(build_first_order(bad)$vars_all, build_first_order(m)$vars_all)
  expect_s3_class(qpm_solve(bad), "qpm_solution")
})

test_that("the cache survives serialisation", {
  m <- qpm_template("bkl_food")
  f <- tempfile(fileext = ".rds")
  saveRDS(m, f)
  m2 <- readRDS(f)
  unlink(f)
  expect_false(is.null(m2$structure))
  expect_equal(qpm_solve(m2)$P, qpm_solve(m)$P)
  expect_same_system(m2, info = "round-tripped")
})

test_that("nonlinear equations are still rejected, at construction", {
  expect_error(
    qpm_model(variables = vars(x = "x"), shocks = shocks(e),
              equations = eqs(x ~ 0.5 * x[-1]^2 + e)),
    class = "qpm_nonlinear")
})

test_that("the coefficient values match the reference extraction", {
  m <- qpm_template("bkl")
  parenv <- list2env(as.list(m$params), parent = baseenv())
  for (i in seq_along(m$parsed)) {
    fast <- qpmR:::eq_coefs_values(m$parsed[[i]], parenv)
    ref <- qpmR:::eq_coefficients(m$parsed[[i]], m$params, parenv)
    expect_equal(fast$const, ref$const, info = i)
    expect_equal(unname(fast$coefs),
                 c(ref$var_coefs$coef, ref$shk_coefs$coef), info = i)
  }
})
