m <- qpm_template("bkl")
sol0 <- qpm_solve(m)
obs <- simulate(sol0, nsim = 44, seed = 1, burn = 20)
obs$period <- next_quarters("2015-Q4", 44)
cols <- c("period", "pi", "i", "q")

test_that("a round runs the pipeline and prints", {
  r <- qpm_round("2026-Q4 test", m, obs[1:40, cols], horizon = 8)
  expect_s3_class(r, "qpm_round")
  expect_s3_class(r$fit, "qpm_filtration")
  expect_s3_class(r$forecast, "qpm_forecast")
  expect_equal(r$forecast$periods[1], "2026-Q1")   # data ends 2025-Q4
  expect_output(print(r), "0 conditions, 0 judgment")
})

test_that("conditions, scenarios and judgment apply to rounds directly", {
  r <- qpm_round("r", m, obs[1:40, cols], horizon = 8)
  r <- qpm_condition(r, i = c("2026-Q1" = 9.5), instruments = "eps_i")
  expect_equal(nrow(r$forecast$conditions), 1L)
  r <- add_judgment(r, pi = c("2026-Q2" = 0.4), author = "desk",
                    rationale = "tariff")
  expect_equal(nrow(r$forecast$judgment), 1L)
  expect_output(print(r), "1 condition, 1 judgment")
  expect_output(judgment_log(r), "tariff")
  r2 <- qpm_scenario(r, shocks = list(eps_q = c("2026-Q3" = 1)))
  expect_s3_class(r2, "qpm_round")
})

test_that("save/load round-trips and the store lists correctly", {
  store <- file.path(tempdir(), "qpmr-store-test")
  unlink(store, recursive = TRUE)
  r <- qpm_round("2026-Q4 June round", m, obs[1:40, cols], horizon = 8)
  r <- add_judgment(r, pi = c("2026-Q2" = 0.4), author = "desk", rationale = "x")
  dir <- save_round(r, store)
  expect_true(file.exists(file.path(dir, "round.rds")))
  expect_true(file.exists(file.path(dir, "forecast.csv")))
  expect_true(file.exists(file.path(dir, "calibration.csv")))
  expect_true(file.exists(file.path(dir, "judgment.csv")))
  expect_error(save_round(r, store), "already exists")
  expect_silent(save_round(r, store, overwrite = TRUE))

  r2 <- load_round("2026-Q4 June round", store)
  expect_equal(r2$forecast$paths$mean, r$forecast$paths$mean)
  expect_equal(r2$forecast$judgment$rationale, "x")

  lst <- list_rounds(store)
  expect_equal(nrow(lst), 1L)
  expect_equal(lst$name, "2026-Q4 June round")
  expect_equal(lst$n_judgment, 1L)
  expect_error(load_round("nope", store), "not found")
  unlink(store, recursive = TRUE)
})

test_that("serialized rounds stay lean (formula environments stripped)", {
  r <- qpm_round("lean", m, obs[1:40, cols], horizon = 8)
  expect_lt(length(serialize(r, NULL)) / 1e6, 5)   # a few MB at most
})
