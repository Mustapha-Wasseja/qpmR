sol <- qpm_solve(qpm_template("bkl"))
fc <- qpm_forecast(sol, horizon = 8)

test_that("the two-piece normal parameters satisfy their defining moments", {
  checked <- 0L
  for (v in c(0.5, 1, 4)) for (s in c(-0.8, -0.2, 0.3, 1.1)) {
    p <- qpmR:::tpn_params(v, s)
    # a skew too large for the variance has no two-piece normal: that is
    # a legitimate refusal, not a failure
    if (anyNA(p)) next
    checked <- checked + 1L
    s1 <- p[1]; s2 <- p[2]
    # mean - mode = sqrt(2/pi) (s2 - s1); var = (1-2/pi)(s2-s1)^2 + s1 s2
    expect_equal(sqrt(2 / pi) * (s2 - s1), s, tolerance = 1e-10)
    expect_equal((1 - 2 / pi) * (s2 - s1)^2 + s1 * s2, v, tolerance = 1e-10)
    expect_gt(s1, 0); expect_gt(s2, 0)
  }
  expect_gt(checked, 6L)          # most combinations are feasible
  expect_true(anyNA(qpmR:::tpn_params(0.5, 5)))   # this one cannot be
})

test_that("the quantile function inverts the two-piece normal cdf", {
  s1 <- 1.2; s2 <- 2.1; mu <- 3
  cdf <- function(x) ifelse(x < mu,
    (2 * s1 / (s1 + s2)) * stats::pnorm((x - mu) / s1),
    (s1 - s2) / (s1 + s2) + (2 * s2 / (s1 + s2)) * stats::pnorm((x - mu) / s2))
  for (p in c(0.05, 0.25, 0.5, 0.75, 0.95))
    expect_equal(cdf(qpmR:::tpn_quantile(p, mu, s1, s2)), p, tolerance = 1e-10)
  # a positive skew puts more than half the mass below the mode
  expect_gt(qpmR:::tpn_quantile(0.5, mu, s1, s2), mu)
})

test_that("a skew moves the mean but not the mode, and tilts the bands", {
  rk <- qpm_risk(fc, pi = 0.4, rationale = "upside energy risk")
  b <- fc$paths[fc$paths$variable == "pi", ]
  r <- rk$paths[rk$paths$variable == "pi", ]
  expect_equal(r$mode, b$mean, tolerance = 1e-12)      # central path unchanged
  expect_equal(r$mean - r$mode, rep(0.4, 8), tolerance = 1e-8)
  # the upside band is wider than the downside
  expect_true(all((r$hi_90 - r$mode) > (r$mode - r$lo_90)))
  expect_true(all((r$hi_50 - r$mode) > (r$mode - r$lo_50)))
  # other variables keep symmetric bands
  ri <- rk$paths[rk$paths$variable == "i", ]
  expect_equal(ri$hi_90 - ri$mode, ri$mode - ri$lo_90, tolerance = 1e-10)
})

test_that("a downside skew tilts the other way and zero skew is symmetric", {
  down <- qpm_risk(fc, pi = -0.5)
  r <- down$paths[down$paths$variable == "pi", ]
  expect_true(all((r$hi_90 - r$mode) < (r$mode - r$lo_90)))
  flat <- qpm_risk(fc, pi = 0)
  f <- flat$paths[flat$paths$variable == "pi", ]
  b <- fc$paths[fc$paths$variable == "pi", ]
  expect_equal(f$lo_90, b$lo_90, tolerance = 1e-10)
  expect_equal(f$hi_90, b$hi_90, tolerance = 1e-10)
})

test_that("risks can be stated per period and are logged", {
  rk <- qpm_risk(fc, pi = c(h2 = 0.3, h5 = -0.6), i = 0.2,
                 author = "MPC", rationale = "tariffs")
  expect_equal(nrow(rk$risk), 8L + 2L)          # 2 for pi, 8 for i
  r <- rk$paths[rk$paths$variable == "pi", ]
  expect_equal(r$mean[2] - r$mode[2], 0.3, tolerance = 1e-8)
  expect_equal(r$mean[5] - r$mode[5], -0.6, tolerance = 1e-8)
  expect_equal(r$mean[3], r$mode[3])            # unstated horizons symmetric
  expect_output(risk_log(rk), "tariffs")
  expect_output(risk_log(rk), "mean minus mode")
  expect_output(print(rk), "balance of risks")
})

test_that("risk works on rounds and rejects bad input", {
  obs <- simulate(sol, nsim = 40, seed = 2, burn = 20)
  obs$period <- next_quarters("2016-Q1", 40)
  r <- qpm_round("demo", qpm_template("bkl"), obs[, c("period", "pi", "i", "q")],
                 horizon = 6)
  rr <- qpm_risk(r, pi = 0.3)
  expect_s3_class(rr, "qpm_round")
  expect_equal(nrow(rr$forecast$risk), 6L)
  expect_output(risk_log(rr), "balance of risks")

  expect_error(qpm_risk(fc, zz = 0.1), "unknown variable")
  expect_error(qpm_risk(fc), "no risks given")
  expect_error(qpm_risk(fc, pi = c(1, 2)), "named by period")
  expect_error(qpm_risk(qpm_risk(fc, pi = c(h1 = 0.2)), pi = c(h1 = 0.3)),
               "two risks at one period")
})

test_that("an impossibly large skew falls back to symmetric bands", {
  # skew far beyond what the variance can support leaves the bands Gaussian
  huge <- qpm_risk(fc, pi = 50)
  r <- huge$paths[huge$paths$variable == "pi", ]
  b <- fc$paths[fc$paths$variable == "pi", ]
  expect_equal(r$lo_90, b$lo_90, tolerance = 1e-10)
  expect_equal(r$mean, r$mode)
})
