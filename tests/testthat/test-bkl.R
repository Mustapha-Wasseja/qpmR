sol <- qpm_solve(qpm_template("bkl"))

test_that("the canonical model solves with a unique stable solution", {
  expect_s3_class(sol, "qpm_solution")
  expect_equal(sol$counts$stable, sol$counts$predetermined)
  expect_lt(sol$residual, 1e-8)
})

test_that("the steady state matches the calibration", {
  ss <- steady_state(sol)
  expect_equal(unname(ss["pi"]), 5, tolerance = 1e-7)     # inflation at target
  expect_equal(unname(ss["pi4"]), 5, tolerance = 1e-7)
  expect_equal(unname(ss["r_bar"]), 4, tolerance = 1e-7)  # istar - pistar + prem
  expect_equal(unname(ss["i"]), 9, tolerance = 1e-7)      # r_bar + pi_tar
  expect_equal(unname(ss["r"]), 4, tolerance = 1e-7)
  expect_equal(unname(ss["y_gap"]), 0, tolerance = 1e-7)
  expect_equal(unname(ss["q_gap"]), 0, tolerance = 1e-7)
  expect_equal(unname(ss["q"]), 0, tolerance = 1e-7)
})

test_that("a policy tightening is disinflationary and appreciates the currency", {
  ir <- irf(sol, shock = "eps_i", horizon = 12, size = 1)
  g <- function(v) ir$value[ir$variable == v]
  expect_true(all(g("y_gap")[1:4] < 1e-10))   # output falls (h = 0..3)
  expect_true(all(g("pi")[1:6] < 1e-10))      # inflation falls (h = 0..5)
  expect_lt(min(g("pi")), -0.3)               # with a meaningful trough
  expect_lt(sum(g("pi")), 0)                  # and a net disinflation
  expect_lt(g("q")[1], 0)                     # real appreciation on impact
  expect_gt(g("i")[1], 0)                     # the rate does rise
  expect_gt(g("r")[1], 1)                     # the real rate rises more
})

test_that("pi4 is the 4-quarter average of pi (auxiliary lag machinery)", {
  ir <- irf(sol, shock = "eps_pi", horizon = 10, size = 1)
  pi_v <- ir$value[ir$variable == "pi"]
  pi4_v <- ir$value[ir$variable == "pi4"]
  for (h in 4:10)
    expect_equal(pi4_v[h + 1], mean(pi_v[(h - 3):h + 1]), tolerance = 1e-8)
})

test_that("violating the Taylor principle produces a BK failure", {
  weak <- qpm_calibrate(qpm_template("bkl"), c2 = -0.5)
  expect_error(qpm_solve(weak), class = "qpm_bk")
})

test_that("simulation is reproducible and forecast reverts to steady state", {
  s1 <- simulate(sol, nsim = 40, seed = 42, burn = 10)
  s2 <- simulate(sol, nsim = 40, seed = 42, burn = 10)
  expect_equal(s1$pi, s2$pi)

  fc <- qpm_forecast(sol, from = s1, horizon = 60)
  last <- fc$paths[fc$paths$h == 60, ]
  ss <- steady_state(sol)
  for (v in c("pi", "i", "y_gap"))
    expect_equal(last$mean[last$variable == v], unname(ss[v]), tolerance = 0.05)
  # bands widen then stabilise, and are ordered
  d <- fc$paths[fc$paths$variable == "pi", ]
  expect_true(all(d$lo_90 <= d$mean & d$mean <= d$hi_90))
  expect_gt(d$hi_90[10] - d$lo_90[10], d$hi_90[1] - d$lo_90[1])
})

test_that("irf peak printing and lint run cleanly", {
  expect_output(print(irf(sol, shock = "eps_q", horizon = 8)), "peak")
  li <- qpm_lint(qpm_template("bkl"))
  expect_false(any(li$status == "fail"))
  expect_output(print(li), "solves")
})
