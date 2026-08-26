m <- qpm_template("bkl")

test_that("the loss uses the model's own stationary variances", {
  ev <- qpm_rule_eval(m, data.frame(c2 = 1.5), loss = c(pi = 1, y_gap = 0.5))
  p <- model_properties(m, vars = c("pi", "y_gap"))
  expect_equal(ev$var_pi, p$model_sd[p$variable == "pi"]^2, tolerance = 1e-10)
  expect_equal(ev$var_y_gap, p$model_sd[p$variable == "y_gap"]^2, tolerance = 1e-10)
  expect_equal(ev$loss, ev$var_pi + 0.5 * ev$var_y_gap, tolerance = 1e-10)
})

test_that("the first-difference penalty matches a long simulation", {
  ev <- qpm_rule_eval(m, data.frame(c2 = 1.5), loss = c(pi = 1),
                      diff_loss = c(i = 0.5))
  sim <- simulate(qpm_solve(m), nsim = 60000, seed = 21, burn = 200)
  expect_lt(abs(ev$vard_i / stats::var(diff(sim$i)) - 1), 0.06)
  expect_equal(ev$loss, ev$var_pi + 0.5 * ev$vard_i, tolerance = 1e-10)
})

test_that("a stronger response to inflation lowers inflation variance", {
  ev <- qpm_rule_eval(m, data.frame(c2 = c(1.5, 2, 3)), loss = c(pi = 1))
  expect_true(all(diff(ev$var_pi) < 0))
  expect_equal(ev$status, rep("ok", 3))
})

test_that("rules that fail Blanchard-Kahn are reported, not dropped", {
  ev <- qpm_rule_eval(m, data.frame(c2 = c(-0.5, 1.5)), loss = c(pi = 1))
  expect_equal(nrow(ev), 2L)
  expect_equal(ev$status[1], "indeterminate")
  expect_true(is.na(ev$loss[1]))
  expect_equal(ev$status[2], "ok")
  expect_output(print(ev), "do not deliver a unique stable solution")
})

test_that("a grid over two coefficients ranks and plots", {
  grid <- expand.grid(c2 = c(1.2, 1.5, 2, 3), c3 = c(0, 0.5, 1))
  ev <- qpm_rule_eval(m, grid, loss = c(pi = 1, y_gap = 0.5),
                      diff_loss = c(i = 0.5))
  expect_equal(nrow(ev), 12L)
  expect_true(all(ev$status == "ok"))
  best <- ev[which.min(ev$loss), ]
  expect_equal(best$c2, 3)          # the strongest response wins this loss
  expect_output(print(ev), "best")
  tf <- tempfile(fileext = ".png")
  grDevices::png(tf); plot(ev); grDevices::dev.off()
  expect_true(file.exists(tf)); unlink(tf)
})

test_that("the frontier can be traced against instrument volatility", {
  grid <- expand.grid(c2 = seq(1.1, 4, length.out = 10),
                      c3 = seq(0, 1.5, length.out = 5))
  ev <- qpm_rule_eval(m, grid, loss = c(pi = 1, y_gap = 0.5),
                      diff_loss = c(i = 0.5))
  ok <- ev[ev$status == "ok", ]
  pareto <- function(xs, ys) vapply(seq_along(xs), function(i)
    !any(xs <= xs[i] & ys <= ys[i] & (xs < xs[i] | ys < ys[i])), TRUE)
  # against output there is no trade-off here; against the instrument there is
  expect_equal(sum(pareto(ok$var_y_gap, ok$var_pi)), 1L)
  expect_gt(sum(pareto(ok$vard_i, ok$var_pi)), 5L)
  tf <- tempfile(fileext = ".png")
  grDevices::png(tf); plot(ev, xvar = "vard_i"); grDevices::dev.off()
  expect_true(file.exists(tf)); unlink(tf)
  expect_error(plot(ev, xvar = "zz"), "was not scored")
})

test_that("subsetting keeps printing sensible (attribute partial matching)", {
  ev <- qpm_rule_eval(m, data.frame(c2 = c(1.5, 2, 3)), loss = c(pi = 1))
  out <- utils::capture.output(print(ev[1:2, ]))
  expect_true(any(grepl("Canonical small open economy", out)))
  expect_false(any(grepl("<qpm_rule_eval> c2", out)))
})

test_that("shock standard deviations can be varied too", {
  ev <- qpm_rule_eval(m, data.frame(eps_pi = c(1, 2)), loss = c(pi = 1))
  expect_true(all(ev$status == "ok"))
  expect_gt(ev$var_pi[2], ev$var_pi[1])   # noisier cost-push, noisier inflation
})

test_that("unit-root models and bad arguments are handled", {
  rw <- qpm_rule_eval(qpm_template("bkl", trends = "rw"),
                      data.frame(c2 = 1.5), loss = c(pi = 1))
  expect_equal(rw$status, "unit root")
  expect_true(is.na(rw$loss))
  expect_error(qpm_rule_eval(m, data.frame(zz = 1)), "not parameters or shocks")
  expect_error(qpm_rule_eval(m, data.frame(c2 = 1.5), loss = c(zz = 1)),
               "unknown variable")
  expect_error(qpm_rule_eval(m, data.frame(c2 = 1.5), loss = c(pi = -1)),
               ">= 0")
})
