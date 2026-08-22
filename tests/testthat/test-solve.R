toy <- function(f, params = list()) {
  qpm_model(name = "toy", variables = vars(x = "x"), shocks = shocks(e),
            equations = eqs(f), params = params)
}

test_that("backward AR(1) reproduces its root exactly", {
  sol <- qpm_solve(toy(x ~ 0.8 * x[-1] + e))
  expect_equal(unname(sol$P["x", "x"]), 0.8, tolerance = 1e-10)
  expect_equal(unname(sol$Q["x", "e"]), 1, tolerance = 1e-10)
})

test_that("static equation solves", {
  sol <- qpm_solve(toy(x ~ e))
  expect_equal(unname(sol$P["x", "x"]), 0, tolerance = 1e-12)
  expect_equal(unname(sol$Q["x", "e"]), 1, tolerance = 1e-12)
})

test_that("purely forward equation has P = 0, Q = 1", {
  sol <- qpm_solve(toy(x ~ 0.5 * E(x[+1]) + e))
  expect_equal(unname(sol$P["x", "x"]), 0, tolerance = 1e-10)
  expect_equal(unname(sol$Q["x", "e"]), 1, tolerance = 1e-10)
})

test_that("hybrid equation matches the analytic stable root", {
  a <- 0.5; b <- 0.3
  sol <- qpm_solve(toy(x ~ a * x[-1] + b * E(x[+1]) + e, params = list(a = a, b = b)))
  root <- (1 - sqrt(1 - 4 * a * b)) / (2 * b)
  expect_equal(unname(sol$P["x", "x"]), root, tolerance = 1e-8)
})

test_that("indeterminacy is detected", {
  expect_error(qpm_solve(toy(x ~ 1.5 * E(x[+1]) + e)), class = "qpm_bk_indeterminate")
})

test_that("explosive models are detected", {
  expect_error(qpm_solve(toy(x ~ 1.5 * x[-1] + e)), class = "qpm_bk_explosive")
})

test_that("unit roots are reported as singular steady state or BK failure", {
  expect_error(qpm_solve(toy(x ~ x[-1] + e)), class = "qpm_error")
})

test_that("deep lags work via auxiliaries", {
  sol <- qpm_solve(toy(x ~ 0.5 * x[-3] + e))
  ir <- irf(sol, shock = "e", horizon = 6, size = 1)
  v <- ir$value[ir$variable == "x"]
  expect_equal(v[1], 1, tolerance = 1e-10)     # h = 0
  expect_equal(v[2], 0, tolerance = 1e-10)
  expect_equal(v[3], 0, tolerance = 1e-10)
  expect_equal(v[4], 0.5, tolerance = 1e-10)   # h = 3
  expect_equal(v[7], 0.25, tolerance = 1e-10)  # h = 6
})

test_that("constants shift the steady state", {
  m <- qpm_model(name = "ss", variables = vars(x = "x"), shocks = shocks(e),
                 equations = eqs(x ~ 0.5 * x[-1] + 2 + e))
  sol <- qpm_solve(m)
  expect_equal(unname(steady_state(sol)["x"]), 4, tolerance = 1e-10)
})

test_that("eigen_table is sorted and flags stability", {
  et <- eigen_table(qpm_solve(toy(x ~ 0.8 * x[-1] + e)))
  expect_true(is.data.frame(et))
  expect_false(is.unsorted(et$modulus))
  expect_equal(sum(et$stable), 1)
})
