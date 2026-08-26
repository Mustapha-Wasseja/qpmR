# The compiled filter and Lyapunov solver are trusted only because they
# agree with the reference implementations in R. These tests are what make
# that claim, so they compare on real data, on missing data, and on the
# near-unit-root case used for diffuse initialisation.

sol <- qpm_solve(qpm_template("bkl"))
obs <- simulate(sol, nsim = 80, seed = 5, burn = 20)
ssm <- state_space(sol, observables = c("pi", "i", "q"))
Y <- as.matrix(obs[, c("pi", "i", "q")]); storage.mode(Y) <- "double"

test_that("the compiled filter matches the R filter to machine precision", {
  ll_c <- kalman_loglik(ssm, Y, use_cpp = TRUE)
  ll_r <- kalman_loglik_r(ssm, Y)
  expect_equal(ll_c, ll_r, tolerance = 1e-10)
  expect_lt(abs(ll_c - ll_r), 1e-8 * max(1, abs(ll_r)))
})

test_that("they agree with missing data and with an all-missing period", {
  Y2 <- Y
  Y2[c(5, 30), "pi"] <- NA
  Y2[1:3, "q"] <- NA
  Y2[40, ] <- NA                      # nothing observed at all that quarter
  expect_equal(kalman_loglik(ssm, Y2, use_cpp = TRUE),
               kalman_loglik_r(ssm, Y2), tolerance = 1e-10)
})

test_that("they agree with measurement error and on real data", {
  m2 <- state_space(sol, observables = c("pi", "i", "q"),
                    measurement_error = c(pi = 0.3, i = 0.1))
  expect_equal(kalman_loglik(m2, Y, use_cpp = TRUE),
               kalman_loglik_r(m2, Y), tolerance = 1e-10)

  mcz <- qpm_calibrate(qpm_template("bkl", trends = "rw"),
                       pi_tar = 2, istar_ss = 2, pistar_ss = 2, prem_ss = 1)
  ob <- c("pi4", "i", "q", "dy_obs", "istar", "pistar")
  cz <- czechia[czechia$period >= "1999", ob]
  Yc <- as.matrix(cz); storage.mode(Yc) <- "double"
  mc <- state_space(qpm_solve(mcz), observables = ob)
  expect_equal(kalman_loglik(mc, Yc, use_cpp = TRUE),
               kalman_loglik_r(mc, Yc), tolerance = 1e-8)
})

test_that("the compiled path raises the same typed error on collinear observables", {
  bad <- state_space(sol, observables = c("pi", "pi4", "i"))
  Yb <- as.matrix(obs[, c("pi", "pi4", "i")]); storage.mode(Yb) <- "double"
  expect_error(kalman_loglik(bad, Yb, use_cpp = TRUE), class = "qpm_singular_F")
  expect_error(kalman_loglik_r(bad, Yb), class = "qpm_singular_F")
})

test_that("the compiled Lyapunov solver matches the direct solve", {
  S <- diag(sol$sigma^2, length(sol$sigma))
  W <- sol$Q %*% S %*% t(sol$Q)
  P <- unname(sol$P)
  Vc <- solve_lyapunov(P, W, use_cpp = TRUE)
  Vr <- solve_lyapunov_r(P, W)
  expect_lt(max(abs(Vc - Vr)) / max(abs(Vr)), 1e-9)
  # and it actually solves the equation it claims to
  expect_lt(max(abs(Vc - P %*% Vc %*% t(P) - W)) / max(abs(W)), 1e-9)
  expect_equal(Vc, t(Vc), tolerance = 1e-12)

  # the damped near-unit-root case used for diffuse initialisation
  Pd <- sqrt(1 - 1e-6) * unname(qpm_solve(qpm_template("bkl", trends = "rw"))$P)
  srw <- qpm_solve(qpm_template("bkl", trends = "rw"))
  Wd <- srw$Q %*% diag(srw$sigma^2, length(srw$sigma)) %*% t(srw$Q)
  Vd <- solve_lyapunov(Pd, Wd, use_cpp = TRUE)
  expect_lt(max(abs(Vd - Pd %*% Vd %*% t(Pd) - Wd)) / max(abs(Wd)), 1e-6)
  expect_true(all(is.finite(Vd)))
})

test_that("the option switches implementations and filtering is unaffected", {
  expect_true(qpm_use_cpp())
  withr_opt <- options(qpmR.use_cpp = FALSE)
  expect_false(qpm_use_cpp())
  f_r <- qpm_filter(sol, obs[, c("period", "pi", "i", "q")])
  options(withr_opt)
  expect_true(qpm_use_cpp())
  f_c <- qpm_filter(sol, obs[, c("period", "pi", "i", "q")])
  # the smoother is shared, but P1 comes from the Lyapunov solver
  expect_equal(f_c$loglik, f_r$loglik, tolerance = 1e-8)
  expect_equal(f_c$states$y_gap, f_r$states$y_gap, tolerance = 1e-8)
})

test_that("estimation reaches the same answer either way", {
  m0 <- qpm_model(variables = vars(x = "x"), shocks = shocks(e),
                  equations = eqs(x ~ rho * x[-1] + e), params = list(rho = 0.5))
  o <- simulate(qpm_solve(qpm_calibrate(m0, rho = 0.8)), nsim = 150, seed = 6)
  pr <- priors(rho = beta(0.5, 0.2))
  e_c <- qpm_estimate(m0, o, pr, iter = 400, chains = 1, seed = 9, verbose = FALSE)
  op <- options(qpmR.use_cpp = FALSE)
  e_r <- qpm_estimate(m0, o, pr, iter = 400, chains = 1, seed = 9, verbose = FALSE)
  options(op)
  # the modes are found by the same optimiser on the same objective
  expect_equal(unname(e_c$mode), unname(e_r$mode), tolerance = 1e-6)
  expect_equal(e_c$mode_logpost, e_r$mode_logpost, tolerance = 1e-6)
})
