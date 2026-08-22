test_that("the czechia dataset is well-formed", {
  expect_true(is.data.frame(czechia))
  expect_named(czechia, c("period", "pi", "pi4", "i", "q", "dy_obs",
                          "istar", "pistar"))
  expect_gt(nrow(czechia), 100)
  expect_equal(czechia$period[1], "1996-Q1")
  # plausibility windows on real data
  expect_true(all(czechia$pi4 > -3 & czechia$pi4 < 25, na.rm = TRUE))
  expect_true(all(czechia$i > 0 & czechia$i < 25, na.rm = TRUE))
  expect_true(all(abs(czechia$q) < 60, na.rm = TRUE))
  expect_true(all(czechia$dy_obs > -40 & czechia$dy_obs < 40, na.rm = TRUE))
  # the 2015 normalization of the real exchange rate
  expect_lt(abs(mean(czechia$q[substr(czechia$period, 1, 4) == "2015"])), 1e-6)
})

test_that("filtering real Czech data reproduces the known history", {
  m <- qpm_calibrate(qpm_template("bkl", trends = "rw"),
                     pi_tar = 2, istar_ss = 2, pistar_ss = 2, prem_ss = 1,
                     a5 = 0.4)
  cz <- czechia[czechia$period >= "1999", ]
  fit <- qpm_filter(m, cz[, c("period", "pi4", "i", "q", "dy_obs",
                              "istar", "pistar")])
  expect_true(fit$diffuse)
  expect_true(is.finite(fit$loglik))

  g <- function(p) fit$states$y_gap[fit$period == p]
  expect_gt(g("2007-Q4"), 1)      # pre-GFC boom
  expect_lt(g("2009-Q2"), -0.5)   # GFC recession
  expect_lt(g("2020-Q2"), -4)     # COVID crater
  # trend real appreciation of the koruna: q_bar falls by tens of log points
  qb <- fit$states$q_bar
  expect_gt(qb[1] - qb[length(qb)], 25)
  # potential growth: convergence boom faster than the post-GFC slump
  dyb <- function(p) fit$states$dy_bar[fit$period == p]
  expect_gt(dyb("2006-Q1"), dyb("2012-Q1"))
})

test_that("observing pi and pi4 together reports the identity", {
  m <- qpm_calibrate(qpm_template("bkl", trends = "rw"),
                     pi_tar = 2, istar_ss = 2, pistar_ss = 2, prem_ss = 1)
  cz <- czechia[czechia$period >= "2005", ]
  expect_error(qpm_filter(m, cz[, c("period", "pi", "pi4", "i", "q")]),
               class = "qpm_singular_F")
})
