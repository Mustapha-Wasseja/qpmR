sol <- qpm_solve(qpm_template("bkl"))
truth <- simulate(sol, nsim = 50, seed = 9, burn = 20)
fit <- qpm_filter(sol, truth[, c("period", "pi", "i", "q", "y_gap")])
dec <- qpm_decompose(fit)

test_that("contributions sum exactly to the smoothed states", {
  d <- as.data.frame(dec)
  for (v in c("pi", "y_gap", "i")) {
    tot <- tapply(d$value[d$variable == v], d$period_i[d$variable == v], sum)
    expect_equal(as.numeric(tot), as.numeric(fit$states_dev[, v]), tolerance = 1e-8)
  }
})

test_that("components are the shocks plus the initial state", {
  expect_setequal(unique(dec$component), c(sol$shocks, "initial"))
})

test_that("the initial-state contribution dies out", {
  d <- as.data.frame(dec)
  ini <- d$value[d$variable == "pi" & d$component == "initial"]
  expect_lt(abs(ini[length(ini)]), abs(ini[1]) + 1e-10)
  expect_lt(abs(ini[length(ini)]), 0.1)
})

test_that("printing and plotting run", {
  expect_output(print(dec), "qpm_decomposition")
  tf <- tempfile(fileext = ".png")
  grDevices::png(tf); plot(dec, var = "pi"); grDevices::dev.off()
  expect_true(file.exists(tf))
  unlink(tf)
})
