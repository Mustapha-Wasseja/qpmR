sol <- qpm_solve(qpm_template("bkl"))
truth <- simulate(sol, nsim = 60, seed = 3, burn = 20)

test_that("filter log-likelihood matches the exact Gaussian likelihood (AR(1))", {
  m1 <- qpm_model(variables = vars(x = "x"), shocks = shocks(e),
                  equations = eqs(x ~ 0.8 * x[-1] + e))
  s1 <- qpm_solve(m1)
  set.seed(11); n <- 12
  y <- as.numeric(stats::arima.sim(list(ar = 0.8), n))
  fit <- qpm_filter(s1, data.frame(x = y))
  Sg <- 0.8^abs(outer(1:n, 1:n, "-")) / (1 - 0.64)
  ll <- -0.5 * (n * log(2 * pi) + as.numeric(determinant(Sg)$modulus) +
                  as.numeric(t(y) %*% solve(Sg, y)))
  expect_equal(fit$loglik, ll, tolerance = 1e-8)
  # with no measurement error, observed series are reproduced exactly
  expect_lt(max(abs(fit$states$x - y)), 1e-8)
})

test_that("latent states are recovered without being observed", {
  fit <- qpm_filter(sol, truth[, c("period", "pi", "i", "q")])
  expect_s3_class(fit, "qpm_filtration")
  expect_gt(cor(fit$states$y_gap, truth$y_gap), 0.8)   # observed: 0.88
  expect_gt(cor(fit$states$r_bar, truth$r_bar), 0.5)   # observed: 0.69
  expect_lt(sqrt(mean((fit$states$y_gap - truth$y_gap)^2)),
            0.7 * stats::sd(truth$y_gap))
  expect_true(all(is.finite(fit$se)))
  expect_output(print(fit), "latent states estimated")
})

test_that("near-full observation reproduces states and shocks", {
  fit <- qpm_filter(sol, truth, measurement_error = 1e-4)
  expect_lt(max(abs(fit$states$y_gap - truth$y_gap)), 1e-5)
  # shocks are exact once the pre-sample lag states are identified (t >= 5);
  # the first few periods are imprecise by construction, not by bug
  tr_sh <- attr(truth, "shocks")
  keep <- 5:nrow(tr_sh)
  for (s in c("eps_pi", "eps_i", "eps_y", "eps_q"))
    expect_lt(max(abs(fit$shocks[[s]][keep] - tr_sh[keep, s])), 1e-4)
})

test_that("missing data and ragged edges are handled", {
  d <- truth[, c("period", "pi", "i", "q")]
  d$pi[c(5, 20, 21)] <- NA
  d$q[1:3] <- NA
  fit <- qpm_filter(sol, d)
  expect_true(is.finite(fit$loglik))
  expect_false(anyNA(fit$states))
  expect_equal(fit$n_missing, 6)
})

test_that("collinear observables with no measurement error give a typed error", {
  expect_error(qpm_filter(sol, truth[, c("period", "pi", "pi4", "i", "q")]),
               class = "qpm_singular_F")
})

test_that("state_space exposes consistent matrices", {
  m <- state_space(sol, observables = c("pi", "i"))
  N <- length(sol$vars_all)
  expect_equal(dim(m$T), c(N, N))
  expect_equal(dim(m$Z), c(2L, N))
  expect_equal(unname(m$d), unname(sol$ss[c("pi", "i")]))
  # Lyapunov fixed point: P1 = T P1 T' + R Qc R'
  resid <- m$P1 - (m$T %*% m$P1 %*% t(m$T) + m$R %*% m$Qc %*% t(m$R))
  expect_lt(max(abs(resid)), 1e-8)
})

test_that("forecasting from a filtration uses the smoothed state", {
  fit <- qpm_filter(sol, truth[, c("period", "pi", "i", "q")])
  fc <- qpm_forecast(sol, from = fit, horizon = 8)
  expect_s3_class(fc, "qpm_forecast")
  # h = 1 mean must equal P %*% (smoothed final state) + steady state
  x1 <- as.numeric(sol$P %*% fit$states_dev[nrow(fit$states_dev), ])
  names(x1) <- sol$vars_all
  got <- fc$paths$mean[fc$paths$variable == "pi" & fc$paths$h == 1]
  expect_equal(got, x1[["pi"]] + unname(sol$ss["pi"]), tolerance = 1e-10)
})
