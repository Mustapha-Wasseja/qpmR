toy_fc <- function(f, params = list(), H = 8) {
  sol <- qpm_solve(qpm_model(name = "toy", variables = vars(x = "x"),
                             shocks = shocks(e), equations = eqs(f),
                             params = params))
  list(sol = sol, fc = qpm_forecast(sol, horizon = H))
}

test_that("unanticipated conditioning spreads minimum-norm shocks (backward model)", {
  tw <- toy_fc(x ~ 0.8 * x[-1] + e)
  fc1 <- qpm_condition(tw$fc, x = c(h2 = 1))
  m <- fc1$paths
  # analytic: x2 = .8 e1 + e2, min ||(e1,e2)||: e = (.8, 1)/1.64
  expect_equal(m$mean[m$h == 2], 1, tolerance = 1e-8)
  expect_equal(m$mean[m$h == 1], 0.8 / 1.64, tolerance = 1e-8)
  expect_equal(unname(fc1$shocks_implied[1, "e"]), 0.8 / 1.64, tolerance = 1e-8)
  expect_equal(unname(fc1$shocks_implied[2, "e"]), 1 / 1.64, tolerance = 1e-8)
})

test_that("anticipated and unanticipated coincide in a purely backward model", {
  tw <- toy_fc(x ~ 0.8 * x[-1] + e)
  fu <- qpm_condition(tw$fc, x = c(h3 = 1), anticipated = FALSE)
  fa <- qpm_condition(tw$fc, x = c(h3 = 1), anticipated = TRUE)
  expect_equal(fu$paths$mean, fa$paths$mean, tolerance = 1e-8)
})

test_that("anticipated shocks move forward-looking variables before they arrive", {
  # x = 0.5 E x[+1] + e:  P = 0, N = 0.5. A shock announced for h3 gives
  # the classic geometry (0.25, 0.5, 1, 0, ...); a surprise gives (0,0,1,0).
  tw <- toy_fc(x ~ 0.5 * E(x[+1]) + e)
  fa <- qpm_scenario(tw$fc, shocks = list(e = c(h3 = 1)), anticipated = TRUE)
  fu <- qpm_scenario(tw$fc, shocks = list(e = c(h3 = 1)), anticipated = FALSE)
  ma <- fa$paths$mean[fa$paths$h %in% 1:4]
  mu <- fu$paths$mean[fu$paths$h %in% 1:4]
  expect_equal(ma, c(0.25, 0.5, 1, 0), tolerance = 1e-8)
  expect_equal(mu, c(0, 0, 1, 0), tolerance = 1e-8)
})

test_that("anticipated propagation matches brute-force perfect foresight", {
  a <- 0.5; b <- 0.3
  tw <- toy_fc(x ~ a * x[-1] + b * E(x[+1]) + e, params = list(a = a, b = b),
               H = 10)
  P <- unname(tw$sol$P[1, 1])
  # brute force: A x_{h+1} + B x_h + C x_{h-1} + D e_h = 0 with
  # A = -b, B = 1, C = -a, D = -1, x_0 = 0, terminal x_{T+1} = P x_T
  Tn <- 120; s <- 4
  M <- matrix(0, Tn, Tn); rhs <- rep(0, Tn)
  for (h in seq_len(Tn)) {
    M[h, h] <- 1
    if (h > 1) M[h, h - 1] <- -a
    if (h < Tn) M[h, h + 1] <- -b else M[h, h] <- 1 - b * P
    if (h == s) rhs[h] <- 1
  }
  x_bf <- solve(M, rhs)
  fa <- qpm_scenario(tw$fc, shocks = list(e = stats::setNames(1, paste0("h", s))),
                     anticipated = TRUE)
  expect_equal(fa$paths$mean[fa$paths$h %in% 1:10], x_bf[1:10], tolerance = 1e-8)
})

test_that("conditions are hit exactly and bands collapse at conditioned points", {
  tw <- toy_fc(x ~ 0.8 * x[-1] + e)
  fc1 <- qpm_condition(tw$fc, x = c(h2 = 1, h5 = -0.5))
  m <- fc1$paths
  expect_equal(m$mean[m$h == 2], 1, tolerance = 1e-8)
  expect_equal(m$mean[m$h == 5], -0.5, tolerance = 1e-8)
  w <- m$hi_90 - m$lo_90
  expect_lt(w[2], 1e-4)                       # conditioned: no uncertainty
  expect_lt(w[1], tw$fc$paths$hi_90[1] - tw$fc$paths$lo_90[1])  # narrower
  expect_gt(w[8], 0.1)                        # beyond conditions: uncertainty back
})

test_that("instruments restrict which shocks move, and impossibility is typed", {
  sol <- qpm_solve(qpm_template("bkl"))
  fc <- qpm_forecast(sol, horizon = 8)
  hold <- qpm_condition(fc, i = c(h1 = 9.5, h2 = 9.5), instruments = "eps_i")
  used <- colnames(hold$shocks_implied)[apply(abs(hold$shocks_implied), 2, max) > 1e-8]
  expect_equal(used, "eps_i")
  expect_equal(hold$paths$mean[hold$paths$variable == "i" & hold$paths$h == 1],
               9.5, tolerance = 1e-8)
  # a foreign shock cannot deliver a domestic-only condition combination
  expect_error(
    qpm_condition(fc, ystar_gap = c(h1 = 1), instruments = "eps_pi"),
    class = "qpm_unattainable")
})

test_that("anticipated vs unanticipated rate holds differ in the full model", {
  sol <- qpm_solve(qpm_template("bkl"))
  fc <- qpm_forecast(sol, horizon = 12)
  hold_a <- qpm_condition(fc, i = c(h1 = 9.5, h2 = 9.5, h3 = 9.5, h4 = 9.5),
                          anticipated = TRUE, instruments = "eps_i")
  hold_u <- qpm_condition(fc, i = c(h1 = 9.5, h2 = 9.5, h3 = 9.5, h4 = 9.5),
                          anticipated = FALSE, instruments = "eps_i")
  pa <- hold_a$paths$mean[hold_a$paths$variable == "pi4"]
  pu <- hold_u$paths$mean[hold_u$paths$variable == "pi4"]
  expect_gt(max(abs(pa - pu)), 0.01)
  # both hit the conditioned rate exactly
  for (h in 1:4) {
    expect_equal(hold_a$paths$mean[hold_a$paths$variable == "i" & hold_a$paths$h == h],
                 9.5, tolerance = 1e-7)
    expect_equal(hold_u$paths$mean[hold_u$paths$variable == "i" & hold_u$paths$h == h],
                 9.5, tolerance = 1e-7)
  }
})

test_that("scenario shifts equal impulse responses", {
  sol <- qpm_solve(qpm_template("bkl"))
  fc <- qpm_forecast(sol, horizon = 10)
  sc <- qpm_scenario(fc, shocks = list(eps_q = c(h1 = 1)))
  ir <- irf(sol, shock = "eps_q", horizon = 10, size = 1)
  for (v in c("pi", "i", "q")) {
    shift <- sc$paths$mean[sc$paths$variable == v] -
      fc$paths$mean[fc$paths$variable == v]
    irv <- ir$value[ir$variable == v][1:10]   # scenario h1 = irf impact (h0)
    expect_equal(shift, irv, tolerance = 1e-8)
  }
})

test_that("duplicate and unknown conditions error clearly", {
  tw <- toy_fc(x ~ 0.8 * x[-1] + e)
  expect_error(qpm_condition(tw$fc, x = c(h2 = 1, h2 = 2)), "conflicting")
  expect_error(qpm_condition(tw$fc, zz = c(h2 = 1)), "unknown variable")
  expect_error(qpm_condition(tw$fc, x = c(h99 = 1)), "horizon")
  expect_error(qpm_condition(tw$fc), "no conditions")
})
