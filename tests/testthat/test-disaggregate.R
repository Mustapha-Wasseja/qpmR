set.seed(7)
q_true <- cumsum(stats::rnorm(40, 0.5)) + 100
annual_sum <- colSums(matrix(q_true, nrow = 4))
annual_avg <- colMeans(matrix(q_true, nrow = 4))
ind <- q_true + stats::rnorm(40, 0, 1)

test_that("the aggregation constraint holds exactly for both methods", {
  for (mth in c("denton", "chow-lin")) {
    d <- qpm_disaggregate(annual_sum, ind, method = mth)
    expect_lt(d$constraint_error, 1e-8)
    agg <- colSums(matrix(d$values, nrow = 4))
    expect_equal(agg, annual_sum, tolerance = 1e-8)
    expect_length(d$values, 40L)
  }
})

test_that("both methods recover a known quarterly series from its annual totals", {
  for (mth in c("denton", "chow-lin")) {
    d <- qpm_disaggregate(annual_sum, ind, method = mth)
    expect_gt(cor(d$values, q_true), 0.95)
    expect_lt(sqrt(mean((d$values - q_true)^2)), 0.15 * stats::sd(q_true))
  }
})

test_that("Denton works without an indicator", {
  d <- qpm_disaggregate(annual_sum, method = "denton")
  expect_lt(d$constraint_error, 1e-8)
  expect_gt(cor(d$values, q_true), 0.9)
  # the result is smooth: no jumps at year boundaries beyond the trend
  expect_lt(stats::sd(diff(d$values)), 2 * stats::sd(diff(q_true)))
})

test_that("average conversion matches annual averages", {
  d <- qpm_disaggregate(annual_avg, ind, method = "chow-lin",
                        conversion = "average")
  expect_lt(d$constraint_error, 1e-8)
  expect_equal(colMeans(matrix(d$values, nrow = 4)), annual_avg, tolerance = 1e-8)
})

test_that("chow-lin picks up genuine residual persistence", {
  # rho is identified only from the low-frequency residuals, so this needs
  # a reasonable number of annual observations (30 here, not 10)
  set.seed(12)
  u <- as.numeric(stats::arima.sim(list(ar = 0.85), 120))
  x <- 2 + 0.5 * seq_len(120) + u
  a <- colSums(matrix(x, nrow = 4))
  d <- qpm_disaggregate(a, seq_len(120), method = "chow-lin")
  expect_gte(d$rho, 0.5)
  expect_lt(d$constraint_error, 1e-8)
  expect_length(d$beta, 2L)

  # white-noise residuals must not be given spurious persistence
  set.seed(13)
  xw <- 2 + 0.5 * seq_len(120) + stats::rnorm(120)
  dw <- qpm_disaggregate(colSums(matrix(xw, nrow = 4)), seq_len(120),
                         method = "chow-lin")
  expect_lt(dw$rho, 0.4)

  # a supplied rho is honoured rather than estimated
  expect_equal(qpm_disaggregate(a, seq_len(120), method = "chow-lin",
                                rho = 0.6)$rho, 0.6)
})

test_that("a different frequency works", {
  set.seed(3)
  mth_true <- cumsum(stats::rnorm(36, 0.2)) + 50
  q <- colSums(matrix(mth_true, nrow = 3))
  d <- qpm_disaggregate(q, mth_true + stats::rnorm(36, 0, 0.5), frequency = 3,
                        method = "chow-lin")
  expect_length(d$values, 36L)
  expect_equal(colSums(matrix(d$values, nrow = 3)), q, tolerance = 1e-8)
})

test_that("printing, plotting and argument checks behave", {
  d <- qpm_disaggregate(annual_sum, ind, method = "chow-lin")
  expect_output(print(d), "aggregation constraint")
  tf <- tempfile(fileext = ".png")
  grDevices::png(tf); plot(d); grDevices::dev.off()
  expect_true(file.exists(tf)); unlink(tf)

  expect_error(qpm_disaggregate(annual_sum, method = "chow-lin"), "needs an indicator")
  expect_error(qpm_disaggregate(annual_sum, ind[1:10]), "must have 40 values")
  expect_error(qpm_disaggregate(c(1, NA, 3), method = "denton"), "missing values")
  expect_error(qpm_disaggregate(5, method = "denton"), "at least two")
  expect_error(qpm_disaggregate(annual_sum, rep(0, 40), method = "denton"),
               "must be positive")
})
