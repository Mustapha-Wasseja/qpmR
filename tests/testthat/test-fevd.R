sol <- qpm_solve(qpm_template("bkl"))

test_that("variance shares sum to one for every variable and horizon", {
  fv <- fevd(sol, horizon = 24)
  tot <- tapply(fv$share, list(fv$variable, fv$horizon), sum, na.rm = TRUE)
  expect_lt(max(abs(tot - 1), na.rm = TRUE), 1e-10)
  expect_true(all(fv$share >= -1e-12, na.rm = TRUE))
  expect_true(all(fv$share <= 1 + 1e-12, na.rm = TRUE))
})

test_that("an exogenous AR(1) process is driven entirely by its own shock", {
  fv <- fevd(sol, horizon = 12)
  for (pair in list(c("prem", "eps_prem"), c("istar", "eps_istar"),
                    c("ystar_gap", "eps_ystar"), c("q_bar", "eps_qbar"))) {
    d <- fv[fv$variable == pair[1] & fv$shock == pair[2], ]
    expect_equal(unique(round(d$share, 10)), 1, info = pair[1])
  }
})

test_that("the one-step decomposition matches the impact matrix directly", {
  fv <- fevd(sol, horizon = 1)
  Q <- sol$Q; sig2 <- sol$sigma^2
  for (v in c("pi", "i", "q", "y_gap")) {
    num <- Q[v, ]^2 * sig2
    expect_equal(fv$share[fv$variable == v][order(fv$shock[fv$variable == v])],
                 unname(num / sum(num))[order(names(num))], tolerance = 1e-10)
  }
})

test_that("fevd is consistent with the analytic AR(1) variance", {
  m <- qpm_model(variables = vars(x = "x"), shocks = shocks(e),
                 equations = eqs(x ~ 0.8 * x[-1] + e))
  s <- qpm_solve(qpm_calibrate(m, sigma = c(e = 2)))
  fv <- fevd(s, horizon = 5)
  # V_h = sigma^2 * sum_{j<h} rho^(2j)
  expect_equal(fv$variance, 4 * cumsum(0.8^(2 * (0:4))), tolerance = 1e-10)
  expect_equal(unique(fv$share), 1)                 # only one shock
})

test_that("fevd works on models with unit roots and accepts a model", {
  rw <- qpm_solve(qpm_template("bkl", trends = "rw"))
  fv <- fevd(rw, horizon = 8, vars = c("pi4", "q_bar"))
  tot <- tapply(fv$share, list(fv$variable, fv$horizon), sum, na.rm = TRUE)
  expect_lt(max(abs(tot - 1), na.rm = TRUE), 1e-10)
  expect_true(all(is.finite(fv$variance)))
  expect_s3_class(fevd(qpm_template("bkl"), horizon = 4), "qpm_fevd")
})

test_that("subsetting keeps printing sensible (attribute partial matching)", {
  fv <- fevd(sol, horizon = 6, vars = "pi")
  out <- utils::capture.output(print(fv[1:5, ]))
  expect_true(any(grepl("Canonical small open economy", out)))
  p <- model_properties(sol, vars = c("pi", "i"))
  out2 <- utils::capture.output(print(p[1, ]))
  expect_true(any(grepl("Canonical small open economy", out2)))
})

test_that("fevd printing, plotting and argument checks behave", {
  fv <- fevd(sol, horizon = 8, vars = c("pi", "i"), shocks = c("eps_pi", "eps_i"))
  expect_setequal(unique(fv$variable), c("pi", "i"))
  expect_setequal(unique(fv$shock), c("eps_pi", "eps_i"))
  expect_output(print(fv), "forecast error variance")
  tf <- tempfile(fileext = ".png")
  grDevices::png(tf); plot(fevd(sol, horizon = 12), var = "pi"); grDevices::dev.off()
  expect_true(file.exists(tf)); unlink(tf)
  expect_error(fevd(sol, vars = "zz"), "unknown variable")
  expect_error(fevd(sol, shocks = "zz"), "unknown shock")
  expect_error(fevd(sol, horizon = 0), "at least 1")
})
