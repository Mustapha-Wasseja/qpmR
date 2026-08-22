sol <- qpm_solve(qpm_template("bkl"))
fc0 <- qpm_forecast(sol, horizon = 8)

test_that("judgment shifts the forecast by the stated amount and is logged", {
  base_pi2 <- fc0$paths$mean[fc0$paths$variable == "pi" & fc0$paths$h == 2]
  fc1 <- add_judgment(fc0, pi = c(h2 = 0.5), author = "desk",
                      rationale = "announced electricity tariff")
  got <- fc1$paths$mean[fc1$paths$variable == "pi" & fc1$paths$h == 2]
  expect_equal(got, base_pi2 + 0.5, tolerance = 1e-8)
  expect_equal(nrow(fc1$judgment), 1L)
  expect_equal(fc1$judgment$author, "desk")
  expect_output(judgment_log(fc1), "electricity tariff")
  expect_output(judgment_log(fc1), "implied shocks")
})

test_that("judgment accumulates and both entries hold jointly", {
  fc1 <- add_judgment(fc0, pi = c(h2 = 0.5), author = "desk", rationale = "tariff")
  fc2 <- add_judgment(fc1, y_gap = c(h1 = 0.3), author = "chief",
                      rationale = "stronger momentum in monthly indicators")
  expect_equal(nrow(fc2$judgment), 2L)
  expect_equal(sort(unique(fc2$judgment$id)), c(1L, 2L))
  # the pi target from entry 1 still holds after entry 2 is added
  expect_equal(fc2$paths$mean[fc2$paths$variable == "pi" & fc2$paths$h == 2],
               fc2$judgment$target[fc2$judgment$variable == "pi"],
               tolerance = 1e-8)
  expect_equal(fc2$paths$mean[fc2$paths$variable == "y_gap" & fc2$paths$h == 1],
               fc2$judgment$target[fc2$judgment$variable == "y_gap"],
               tolerance = 1e-8)
})

test_that("implausible judgment is flagged in standard deviations", {
  fc_big <- add_judgment(fc0, pi = c(h1 = 8), author = "desk",
                         rationale = "stress")
  expect_gt(max(abs(fc_big$shocks_implied_std)), 2)
  expect_output(print(fc_big), "above 2 sd")
})

test_that("judgment colliding with an existing condition errors", {
  fc1 <- qpm_condition(fc0, pi = c(h2 = 5.5))
  expect_error(add_judgment(fc1, pi = c(h2 = 0.3), author = "desk"),
               "collides")
})

test_that("judgment on a filtration-based forecast uses quarter labels", {
  truth <- simulate(sol, nsim = 40, seed = 11, burn = 10)
  truth$period <- next_quarters("2016-Q1", 40)
  fit <- qpm_filter(sol, truth[, c("period", "pi", "i", "q")])
  fc <- qpm_forecast(sol, from = fit, horizon = 8)
  expect_equal(fc$periods[1], "2026-Q2")
  fcj <- add_judgment(fc, pi = c("2026-Q3" = 0.4), author = "desk",
                      rationale = "tariff")
  expect_equal(fcj$judgment$period, "2026-Q3")
  expect_equal(fcj$judgment$h, 2L)
})
