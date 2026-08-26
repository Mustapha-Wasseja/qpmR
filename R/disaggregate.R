#' Temporal disaggregation of low-frequency data
#'
#' Turns annual series into quarterly ones consistent with the annual
#' totals. Many of the economies these models are built for publish
#' national accounts annually, so a quarterly projection model has to
#' start by constructing quarterly GDP — usually from an indicator such
#' as industrial production, imports or credit.
#'
#' Two standard methods:
#'
#' * `"denton"` — Denton-Cholette proportional first differences.
#'   Minimises the squared change in the ratio of the quarterly series to
#'   the indicator (or, without an indicator, in the series itself),
#'   subject to matching the annual figures. Purely a smoothing method:
#'   no regression, no parameters.
#' * `"chow-lin"` — generalised least squares on the indicator with
#'   AR(1) quarterly residuals, distributing the annual residual across
#'   quarters. Uses the indicator's regression relationship, so it is the
#'   better choice when the indicator genuinely tracks the target.
#'
#' Both enforce the aggregation constraint exactly: `"sum"` for flows
#' (annual GDP is the sum of quarters), `"average"` for stocks and index
#' levels.
#'
#' @param annual Numeric vector of low-frequency values.
#' @param indicator Optional numeric vector of high-frequency indicator
#'   values, length `frequency * length(annual)`. Required for
#'   `"chow-lin"`.
#' @param frequency Periods per low-frequency observation (4 for
#'   annual-to-quarterly).
#' @param method `"denton"` or `"chow-lin"`.
#' @param conversion `"sum"` or `"average"`.
#' @param rho AR(1) coefficient for `"chow-lin"`. `NULL` estimates it by
#'   a grid search on the profile GLS likelihood. Note that `rho` is
#'   identified only from the *low-frequency* residuals, so a short
#'   sample cannot pin it down: with ten annual observations the estimate
#'   is typically driven to zero even when the quarterly residual is
#'   strongly autocorrelated. Around thirty low-frequency observations
#'   are needed before the estimate is informative; supply `rho`
#'   directly when the sample is shorter.
#' @return An object of class `qpm_disaggregation`: the high-frequency
#'   series, the method used and the fitted parameters.
#' @references Denton, F. T. (1971); Chow, G. C. and Lin, A. (1971).
#' @examples
#' # annual GDP with a quarterly indicator
#' set.seed(1)
#' q_true <- cumsum(rnorm(40, 0.5)) + 100
#' annual <- colSums(matrix(q_true, nrow = 4))
#' ind <- q_true + rnorm(40, 0, 1)
#' d <- qpm_disaggregate(annual, ind, method = "chow-lin")
#' d
#' plot(d)
#' @export
qpm_disaggregate <- function(annual, indicator = NULL, frequency = 4,
                             method = c("denton", "chow-lin"),
                             conversion = c("sum", "average"), rho = NULL) {
  method <- match.arg(method)
  conversion <- match.arg(conversion)
  annual <- as.numeric(annual)
  if (anyNA(annual)) stop("annual data must not contain missing values", call. = FALSE)
  m <- length(annual)
  if (m < 2L) stop("need at least two low-frequency observations", call. = FALSE)
  n <- m * frequency

  if (!is.null(indicator)) {
    indicator <- as.numeric(indicator)
    if (length(indicator) != n)
      stop(sprintf("indicator must have %d values (frequency %d x %d observations)",
                   n, frequency, m), call. = FALSE)
    if (anyNA(indicator)) stop("indicator must not contain missing values", call. = FALSE)
  } else if (method == "chow-lin") {
    stop("chow-lin needs an indicator; use method = \"denton\" without one",
         call. = FALSE)
  }

  # aggregation matrix
  C <- matrix(0, m, n)
  w <- if (conversion == "sum") 1 else 1 / frequency
  for (i in seq_len(m)) C[i, ((i - 1) * frequency + 1):(i * frequency)] <- w

  if (method == "denton") {
    z <- indicator %||% rep(1, n)
    if (any(z <= 0)) stop("the indicator must be positive for proportional Denton",
                          call. = FALSE)
    # minimise sum_t ( x_t/z_t - x_{t-1}/z_{t-1} )^2 s.t. C x = annual
    D <- diag(n); D[cbind(2:n, 1:(n - 1))] <- -1; D <- D[-1, , drop = FALSE]
    Zi <- diag(1 / z, n, n)
    A <- t(Zi) %*% t(D) %*% D %*% Zi
    # A is singular (it annihilates the indicator direction), and that
    # direction is exactly what the aggregation constraint has to supply,
    # so solve the KKT system rather than inverting A
    KKT <- rbind(cbind(2 * A, t(C)),
                 cbind(C, matrix(0, m, m)))
    sol_kkt <- tryCatch(solve(KKT, c(rep(0, n), annual)),
                        error = function(cnd)
                          stop("Denton system is singular; check the indicator",
                               call. = FALSE))
    x <- as.numeric(sol_kkt[seq_len(n)])
    fit <- list(rho = NA_real_, beta = NA_real_)
  } else {
    X <- cbind(1, indicator)
    best <- NULL
    grid <- if (is.null(rho)) seq(0, 0.95, by = 0.05) else rho
    for (r in grid) {
      V <- r^abs(outer(seq_len(n), seq_len(n), "-")) / (1 - min(r, 0.999)^2)
      CVC <- C %*% V %*% t(C)
      CVCi <- tryCatch(solve(CVC), error = function(cnd) NULL)
      if (is.null(CVCi)) next
      CX <- C %*% X
      b <- tryCatch(solve(t(CX) %*% CVCi %*% CX, t(CX) %*% CVCi %*% annual),
                    error = function(cnd) NULL)
      if (is.null(b)) next
      u <- annual - CX %*% b
      # profile likelihood: the residual variance must be concentrated out,
      # otherwise the 1/(1-rho^2) scaling of V makes the values across rho
      # incomparable and rho is always driven to zero
      s2 <- as.numeric(t(u) %*% CVCi %*% u) / m
      if (!is.finite(s2) || s2 <= 0) next
      ll <- -0.5 * (m * log(s2) + as.numeric(determinant(CVC)$modulus))
      if (is.null(best) || ll > best$ll)
        best <- list(ll = as.numeric(ll), rho = r, beta = as.numeric(b),
                     V = V, CVCi = CVCi, u = u)
    }
    if (is.null(best)) stop("chow-lin failed to fit; check the indicator", call. = FALSE)
    x <- as.numeric(X %*% best$beta +
                      best$V %*% t(C) %*% best$CVCi %*% best$u)
    fit <- list(rho = best$rho, beta = best$beta)
  }

  resid <- as.numeric(C %*% x) - annual
  if (max(abs(resid)) > 1e-6 * max(1, max(abs(annual))))
    warning(sprintf("aggregation constraint satisfied only to %.2e", max(abs(resid))))

  structure(list(values = x, annual = annual, indicator = indicator,
                 frequency = frequency, method = method,
                 conversion = conversion, rho = fit$rho, beta = fit$beta,
                 constraint_error = max(abs(resid))),
            class = "qpm_disaggregation")
}

#' @export
print.qpm_disaggregation <- function(x, ...) {
  cat(sprintf("<qpm_disaggregation> %s, %s conversion\n", x$method, x$conversion))
  cat(sprintf("  %d low-frequency observations -> %d high-frequency values\n",
              length(x$annual), length(x$values)))
  if (is.finite(x$rho))
    cat(sprintf("  AR(1) rho = %.2f, beta = (%s)\n", x$rho,
                paste(sprintf("%.3f", x$beta), collapse = ", ")))
  cat(sprintf("  aggregation constraint holds to %.2e\n", x$constraint_error))
  cat(sprintf("  first values: %s ...\n",
              paste(sprintf("%.2f", utils::head(x$values, 6)), collapse = ", ")))
  invisible(x)
}

#' @export
#' @rdname qpm_disaggregate
#' @param x A `qpm_disaggregation`.
#' @param ... Unused.
plot.qpm_disaggregation <- function(x, ...) {
  n <- length(x$values); f <- x$frequency
  op <- graphics::par(mar = c(2.8, 3.0, 2.0, 0.6), mgp = c(1.8, 0.4, 0),
                      tcl = -0.25, cex.axis = 0.85)
  on.exit(graphics::par(op))
  ann_at <- seq(f, n, by = f) - (f - 1) / 2
  ann_lvl <- if (x$conversion == "sum") x$annual / f else x$annual
  graphics::plot(seq_len(n), x$values, type = "l", col = "#1f5da8", lwd = 2,
                 xlab = "high-frequency period", ylab = "",
                 main = sprintf("Temporal disaggregation (%s)", x$method))
  graphics::points(ann_at, ann_lvl, pch = 16, col = "#c23f2e", cex = 0.9)
  leg <- c("disaggregated", if (x$conversion == "sum")
    "annual / frequency" else "annual")
  cols <- c("#1f5da8", "#c23f2e")
  if (!is.null(x$indicator)) {
    sc <- stats::sd(x$values) / stats::sd(x$indicator)
    graphics::lines(seq_len(n),
                    mean(x$values) + (x$indicator - mean(x$indicator)) * sc,
                    col = "grey50", lwd = 1.2, lty = 2)
    leg <- c(leg, "indicator (rescaled)"); cols <- c(cols, "grey50")
  }
  graphics::legend("topleft", leg, col = cols, lwd = c(2, NA, 1.2),
                   pch = c(NA, 16, NA), lty = c(1, NA, 2), bty = "n", cex = 0.75)
  invisible(x)
}
