m <- qpm_template("bkl")
sol0 <- qpm_solve(m)
obs <- simulate(sol0, nsim = 44, seed = 2, burn = 20)
obs$period <- next_quarters("2015-Q4", 44)
cols <- c("period", "pi", "i", "q")
rA <- qpm_round("June", m, obs[1:40, cols], horizon = 8)

comp <- function(rev, v, p, cc) {
  d <- as.data.frame(rev)
  d[[cc]][d$variable == v & d$period == p]
}

test_that("comparing a round with itself gives zero everywhere", {
  rev <- compare_rounds(rA, rA, variables = c("pi", "i", "y_gap"))
  expect_lt(max(abs(rev$total)), 1e-8)
  for (cc in c("parameters", "data_revisions", "new_data", "conditions", "judgment"))
    expect_lt(max(abs(rev[[cc]])), 1e-8)
})

test_that("judgment-only differences load entirely on the judgment component", {
  rB <- add_judgment(rA, pi = c("2026-Q2" = 0.5), author = "desk", rationale = "x")
  rB$name <- "September"
  rev <- compare_rounds(rA, rB, variables = "pi")
  expect_equal(comp(rev, "pi", "2026-Q2", "judgment"),
               comp(rev, "pi", "2026-Q2", "total"), tolerance = 1e-8)
  expect_equal(comp(rev, "pi", "2026-Q2", "total"), 0.5, tolerance = 1e-8)
  expect_lt(max(abs(rev$new_data)), 1e-8)
  expect_lt(max(abs(rev$parameters)), 1e-8)
})

test_that("calibration-only differences load on the parameters component", {
  m2 <- qpm_calibrate(m, b2 = 0.35, c2 = 2)
  rB <- qpm_round("recal", m2, obs[1:40, cols], horizon = 8)
  rev <- compare_rounds(rA, rB, variables = c("pi", "i"))
  expect_equal(rev$parameters, rev$total, tolerance = 1e-8)
  expect_gt(max(abs(rev$total)), 1e-4)
  expect_lt(max(abs(rev$new_data)), 1e-8)
})

test_that("new quarters load on new_data; revisions on data_revisions", {
  rB <- qpm_round("newdata", m, obs[1:42, cols], horizon = 8)   # +2 quarters
  rev <- compare_rounds(rA, rB, variables = c("pi", "y_gap"))
  expect_equal(rev$new_data, rev$total, tolerance = 1e-8)
  expect_gt(max(abs(rev$total)), 1e-3)

  obs_rev <- obs[1:40, cols]
  obs_rev$pi[35:40] <- obs_rev$pi[35:40] + 0.3    # vintage revision
  rC <- qpm_round("revised", m, obs_rev, horizon = 8)
  rev2 <- compare_rounds(rA, rC, variables = c("pi", "y_gap"))
  expect_equal(rev2$data_revisions, rev2$total, tolerance = 1e-8)
  expect_gt(max(abs(rev2$total)), 1e-3)
})

test_that("condition-only differences load on the conditions component", {
  rB <- qpm_condition(qpm_round("cond", m, obs[1:40, cols], horizon = 8),
                      i = c("2026-Q1" = 9.5), instruments = "eps_i")
  rev <- compare_rounds(rA, rB, variables = c("pi", "i"))
  expect_equal(rev$conditions, rev$total, tolerance = 1e-8)
  expect_equal(comp(rev, "i", "2026-Q1", "total"),
               9.5 - rA$forecast$paths$mean[rA$forecast$paths$variable == "i" &
                                              rA$forecast$paths$h == 1],
               tolerance = 1e-8)
})

test_that("mixed changes telescope exactly and endpoints verify", {
  m2 <- qpm_calibrate(m, b2 = 0.3)
  rB <- qpm_round("mixed", m2, obs[1:42, cols], horizon = 8)
  rB <- add_judgment(rB, pi = c("2026-Q4" = 0.4), author = "desk", rationale = "y")
  rev <- compare_rounds(rA, rB)
  sums <- rev$parameters + rev$data_revisions + rev$new_data +
    rev$conditions + rev$judgment
  expect_equal(sums, rev$total, tolerance = 1e-8)
  expect_equal(rev$new - rev$old, rev$total, tolerance = 1e-10)
  expect_output(print(rev), "new data")
})

test_that("old judgment overtaken by data is dropped with a note", {
  rA2 <- add_judgment(rA, pi = c("2026-Q1" = 0.3), author = "desk",
                      rationale = "will be an outturn next round")
  rB <- qpm_round("later", m, obs[1:42, cols], horizon = 8)  # 2026-Q1 now data
  rev <- compare_rounds(rA2, rB)
  dropped <- attr(rev, "dropped")
  expect_true(!is.null(dropped) && nrow(dropped) >= 1)
  expect_match(dropped$reason[1], "outturn")
  expect_output(print(rev), "no longer bind")
})

test_that("structural mismatches are refused", {
  m_other <- qpm_calibrate(m, b2 = 0.3)
  m_other$vars$name[1] <- m_other$vars$name[1]  # same structure -> fine
  rB <- qpm_round("ok", m_other, obs[1:40, cols], horizon = 8)
  expect_s3_class(compare_rounds(rA, rB, variables = "pi"), "qpm_revision")

  m_diff <- qpm_model(variables = vars(x = "x"), shocks = shocks(e),
                      equations = eqs(x ~ 0.8 * x[-1] + e))
  obs_x <- data.frame(period = obs$period[1:40], x = obs$pi[1:40])
  rX <- qpm_round("different", m_diff, obs_x, horizon = 8)
  expect_error(compare_rounds(rA, rX), "different model structures")
})
