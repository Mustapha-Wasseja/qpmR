test_that("prior constructors reproduce their stated moments", {
  p <- priors(a = beta(0.6, 0.15), b = gamma(0.25, 0.1),
              c = invgamma(1, 0.3), d = normal(1.5, 0.25),
              e = uniform(0, 2))
  # beta: check shapes give back mean/sd
  sh <- p$a$par
  m <- sh$shape1 / (sh$shape1 + sh$shape2)
  v <- sh$shape1 * sh$shape2 /
    ((sh$shape1 + sh$shape2)^2 * (sh$shape1 + sh$shape2 + 1))
  expect_equal(m, 0.6, tolerance = 1e-10)
  expect_equal(sqrt(v), 0.15, tolerance = 1e-10)
  # gamma
  expect_equal(p$b$par$shape / p$b$par$rate, 0.25, tolerance = 1e-10)
  expect_equal(sqrt(p$b$par$shape) / p$b$par$rate, 0.1, tolerance = 1e-10)
  # invgamma: mean = scale/(shape-1), var = scale^2/((shape-1)^2 (shape-2))
  a <- p$c$par$shape; b <- p$c$par$scale
  expect_equal(b / (a - 1), 1, tolerance = 1e-10)
  expect_equal(b^2 / ((a - 1)^2 * (a - 2)), 0.09, tolerance = 1e-10)
  # log densities integrate-ish: finite inside support, -Inf outside
  expect_true(is.finite(p$a$logd(0.5)))
  expect_false(is.finite(p$b$logd(-1)))
  expect_false(is.finite(p$c$logd(0)))
  expect_output(print(p), "invgamma")
})

test_that("invalid prior parameters are rejected", {
  expect_error(priors(a = beta(0.5, 0.6)), "sd too large")
  expect_error(priors(beta(0.5, 0.1)), "named")
  expect_error(priors(a = "not a dist"), "must be one of")
})

test_that("truncation restricts support without breaking the density", {
  p <- priors(c2 = truncate(normal(1.5, 0.25), lower = 1))
  expect_equal(p$c2$lower, 1)
  expect_false(is.finite(p$c2$logd(0.9)))
  expect_true(is.finite(p$c2$logd(1.4)))
  expect_error(priors(z = truncate(normal(0, 1), lower = 2, upper = 1)))
})

test_that("transforms round-trip and the Jacobian matches numerically", {
  p <- priors(a = beta(0.6, 0.15), b = gamma(0.25, 0.1),
              c = normal(0, 1), d = truncate(normal(1.5, 0.25), lower = 1))
  for (nm in names(p)) {
    d <- p[[nm]]
    x <- d$mean
    u <- tr_fwd(x, d)
    expect_equal(tr_inv(u, d), x, tolerance = 1e-10)
    # numerical Jacobian check: log |dx/du|
    eps <- 1e-6
    num <- log(abs(tr_inv(u + eps, d) - tr_inv(u - eps, d)) / (2 * eps))
    expect_equal(tr_logjac(u, d), num, tolerance = 1e-4)
  }
})
