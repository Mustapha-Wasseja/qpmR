base <- qpm_template("bkl")

test_that("the food block solves with a coherent steady state", {
  m <- add_block(base, block_food_cpi(weight = 0.4))
  expect_s3_class(m, "qpm_model")
  sol <- qpm_solve(m)
  ss <- steady_state(sol)
  # all three inflation rates at target, relative price pinned at zero
  expect_equal(unname(ss["pi"]), 5, tolerance = 1e-7)
  expect_equal(unname(ss["pi_core"]), 5, tolerance = 1e-7)
  expect_equal(unname(ss["pi_food"]), 5, tolerance = 1e-7)
  expect_equal(unname(ss["rp_food"]), 0, tolerance = 1e-7)
  expect_equal(unname(ss["i"]), 9, tolerance = 1e-7)
  expect_equal(sol$counts$stable, sol$counts$predetermined)
})

test_that("headline is exactly the weighted average of food and core", {
  w <- 0.45
  sol <- qpm_solve(add_block(base, block_food_cpi(weight = w)))
  ir <- irf(sol, shock = "eps_pifood", horizon = 12, size = 1)
  g <- function(v) ir$value[ir$variable == v]
  expect_equal(g("pi"), w * g("pi_food") + (1 - w) * g("pi_core"),
               tolerance = 1e-10)
})

test_that("a food supply shock is a relative-price shock policy looks through", {
  sol <- qpm_solve(add_block(base, block_food_cpi(weight = 0.4)))
  ir <- irf(sol, shock = "eps_pifood", horizon = 16, size = 1)
  g <- function(v) ir$value[ir$variable == v]
  expect_gt(g("pi_food")[1], 0.5)              # food jumps
  expect_gt(g("pi")[1], 0.2)                   # headline follows, scaled
  expect_lt(abs(g("pi_core")[1]), 0.05)        # core barely moves on impact
  expect_lt(max(abs(g("i"))), 0.5 * g("pi_food")[1])  # muted policy response
  # the relative price rises then mean-reverts through the error correction
  rp <- g("rp_food")
  expect_gt(max(rp), 0.2)
  expect_lt(rp[17], max(rp))
})

test_that("the food weight scales headline pass-through monotonically", {
  peak <- function(w) {
    ir <- irf(qpm_solve(add_block(base, block_food_cpi(weight = w))),
              shock = "eps_pifood", horizon = 8, size = 1)
    ir$value[ir$variable == "pi"][1]
  }
  expect_lt(peak(0.2), peak(0.4))
  expect_lt(peak(0.4), peak(0.6))
})

test_that("FX intervention spans float to peg", {
  peak_q <- function(m) {
    ir <- irf(qpm_solve(m), shock = "eps_prem", horizon = 12, size = 1)
    max(abs(ir$value[ir$variable == "q"]))
  }
  float <- peak_q(base)
  managed <- peak_q(add_block(base, block_fx_intervention(intensity = 1)))
  near_peg <- peak_q(add_block(base, block_fx_intervention(intensity = 4)))
  expect_lt(managed, float)
  expect_lt(near_peg, managed)
  expect_lt(near_peg, 0.25 * float)
  # intensity 0 reproduces the float exactly
  expect_equal(peak_q(add_block(base, block_fx_intervention(intensity = 0))),
               float, tolerance = 1e-8)
  # intervention is zero in steady state
  sol <- qpm_solve(add_block(base, block_fx_intervention()))
  expect_equal(unname(steady_state(sol)["fx_int"]), 0, tolerance = 1e-8)
})

test_that("blocks compose and are recorded", {
  m <- add_block(base, list(block_food_cpi(), block_fx_intervention()))
  expect_s3_class(qpm_solve(m), "qpm_solution")
  expect_equal(length(m$meta$blocks), 2L)
  expect_true(all(c("pi_food", "fx_int") %in% m$vars$name))
  expect_equal(m$meta$blocks[[1]]$replaced, "pi")
  expect_setequal(m$meta$blocks[[1]]$added, c("pi_core", "pi_food", "rp_food"))
})

test_that("blocks work with random-walk trends and with the filter", {
  m <- add_block(qpm_template("bkl", trends = "rw"), block_food_cpi())
  sol <- qpm_solve(m)
  expect_gt(sol$counts$unit, 0L)
  truth <- simulate(sol, nsim = 60, seed = 21, burn = 20)
  fit <- qpm_filter(sol, truth[, c("period", "pi4", "i", "q", "dy_obs", "pi_food")])
  expect_true(is.finite(fit$loglik))
  # core inflation is never observed but is recovered
  expect_gt(cor(fit$states$pi_core, truth$pi_core), 0.8)
})

test_that("template shortcuts match explicit block application", {
  expect_equal(vapply(qpm_template("bkl_food")$equations, deparse1, character(1)),
               vapply(add_block(base, block_food_cpi())$equations, deparse1,
                      character(1)))
  expect_true("fx_int" %in% qpm_template("managed_fx")$vars$name)
  expect_s3_class(qpm_solve(qpm_template("bkl_food")), "qpm_solution")
  expect_s3_class(qpm_solve(qpm_template("managed_fx")), "qpm_solution")
})

test_that("block clashes and malformed equations are refused", {
  bad_var <- qpm_block("clash", variables = vars(pi = "duplicate"),
                       equations = eqs(pi ~ pi[-1]))
  expect_error(add_block(base, bad_var), "already exist")

  bad_par <- qpm_block("clash", params = list(b1 = 1),
                       equations = eqs(pi ~ b1 * pi[-1] + eps_pi))
  expect_error(add_block(base, bad_par), "parameters that already exist")

  orphan <- qpm_block("orphan", equations = eqs(zz ~ 0.5 * zz[-1]))
  expect_error(add_block(base, orphan), "neither an existing variable")

  expect_error(qpm_block("no equations", params = list(z = 1)),
               "at least one equation")
})

test_that("qpm_diff reports exactly what a block changed", {
  d <- qpm_diff(base, add_block(base, block_food_cpi()))
  expect_setequal(d$vars_added, c("pi_core", "pi_food", "rp_food"))
  expect_equal(d$shocks_added, "eps_pifood")
  expect_setequal(d$params_added, c("w_food", "f1", "f2", "f3", "f4"))
  expect_equal(d$eqs_changed, "pi")
  expect_length(d$vars_removed, 0L)
  expect_output(print(d), "equations changed")

  # recalibration shows up as such, not as a structural change
  d2 <- qpm_diff(base, qpm_calibrate(base, b2 = 0.4))
  expect_equal(d2$recalibrated, "b2")
  expect_length(d2$eqs_changed, 0L)
  expect_output(print(qpm_diff(base, base)), "identical")
})
