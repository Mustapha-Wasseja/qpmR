#' State-space representation of a solved model
#'
#' Exposes the exact matrices qpmR itself uses for filtering, so other
#' estimators and filters can be built on top of a solved model. The
#' representation (in deviations from steady state) is
#' \deqn{a_t = T a_{t-1} + R e_t,  e_t ~ N(0, Qc)}
#' \deqn{y_t = Z a_t + d + u_t,   u_t ~ N(0, H)}
#' with `d` the steady state of the observables and `P1` the stationary
#' (Lyapunov) covariance used to initialize the filter.
#'
#' For stationary models `P1` is the exact stationary covariance. When
#' the model has unit roots (random-walk trends), an approximate diffuse
#' initialization is used: `P1` solves the Lyapunov equation for the
#' slightly damped transition `sqrt(1 - 1/kappa) * T`, which reproduces
#' the stationary covariance in stable directions and a variance of order
#' `kappa` in unit-root directions, with the exact cross-coupling. Exact
#' Durbin-Koopman diffuse recursions are on the roadmap.
#'
#' @param solution A `qpm_solution`.
#' @param observables Character vector of observed variables (a subset of
#'   the declared variables). Default: all declared variables.
#' @param measurement_error Measurement-error standard deviation(s):
#'   a scalar recycled over observables, or a named vector.
#' @param kappa Diffuse-prior variance scale for unit-root directions
#'   (only used when the model has unit roots).
#' @return A list with elements `T`, `R`, `Z`, `d`, `Qc`, `H`, `P1`,
#'   `vars_all`, `observables`, `diffuse`, `n_unit`.
#' @examples
#' sol <- qpm_solve(qpm_template("bkl"))
#' ss <- state_space(sol, observables = c("pi", "i", "q"))
#' dim(ss$T); ss$d
#' @export
state_space <- function(solution, observables = NULL, measurement_error = 0,
                        kappa = 1e6) {
  stopifnot(inherits(solution, "qpm_solution"))
  observables <- observables %||% solution$vars
  bad <- setdiff(observables, solution$vars)
  if (length(bad))
    stop(sprintf("observables must be declared model variables; unknown: %s",
                 paste(bad, collapse = ", ")), call. = FALSE)
  if (anyDuplicated(observables))
    stop("duplicated observables", call. = FALSE)

  N <- length(solution$vars_all)
  p <- length(observables)
  Zc <- matrix(0, p, N, dimnames = list(observables, solution$vars_all))
  Zc[cbind(seq_len(p), match(observables, solution$vars_all))] <- 1

  me <- measurement_error
  if (is.null(names(me))) {
    if (length(me) != 1L)
      stop("measurement_error must be a scalar or a named vector", call. = FALSE)
    me <- stats::setNames(rep(me, p), observables)
  } else {
    unknown <- setdiff(names(me), observables)
    if (length(unknown))
      stop(sprintf("measurement_error names are not observables: %s",
                   paste(unknown, collapse = ", ")), call. = FALSE)
    full <- stats::setNames(rep(0, p), observables)
    full[names(me)] <- me
    me <- full
  }
  if (any(me < 0)) stop("measurement_error must be >= 0", call. = FALSE)

  Qc <- diag(solution$sigma^2, length(solution$sigma), length(solution$sigma))
  dimnames(Qc) <- list(solution$shocks, solution$shocks)
  RQR <- solution$Q %*% Qc %*% t(solution$Q)

  n_unit <- solution$counts$unit %||% 0L
  Tm <- unname(solution$P)
  P1 <- if (n_unit > 0L) {
    solve_lyapunov(sqrt(1 - 1 / kappa) * Tm, RQR)   # approximate diffuse
  } else {
    solve_lyapunov(Tm, RQR)
  }

  list(T = Tm, R = unname(solution$Q), Z = unname(Zc),
       d = solution$ss[observables], Qc = Qc,
       H = diag(me^2, p, p),
       P1 = P1,
       vars_all = solution$vars_all, observables = observables,
       diffuse = n_unit > 0L, n_unit = n_unit)
}

# Stationary covariance: V = T V T' + W, solved by vec(V) = (I - T (x) T)^-1 vec(W).
solve_lyapunov <- function(Tt, W) {
  N <- nrow(Tt)
  V <- matrix(solve(diag(N * N) - kronecker(Tt, Tt), as.vector(W)), N, N)
  (V + t(V)) / 2
}

# Moore-Penrose pseudo-inverse via SVD (state covariances are singular
# whenever the expanded state contains exact static identities).
pinv <- function(M, tol = 1e-10) {
  s <- svd(M)
  pos <- s$d > tol * max(s$d, .Machine$double.xmin)
  if (!any(pos)) return(matrix(0, ncol(M), nrow(M)))
  s$v[, pos, drop = FALSE] %*% ((1 / s$d[pos]) * t(s$u[, pos, drop = FALSE]))
}

# Kalman filter + RTS smoother with per-period missing data.
# Y: n x p matrix of observables in levels (NAs allowed). Returns smoothed
# states/disturbances in deviations.
kalman_smooth <- function(m, Y) {
  n <- nrow(Y); N <- nrow(m$T); p <- ncol(Y)
  Tt <- m$T; RQR <- m$R %*% m$Qc %*% t(m$R)

  a_f <- vector("list", n + 1L); P_f <- vector("list", n + 1L)
  a_p <- vector("list", n + 1L); P_p <- vector("list", n + 1L)
  a_f[[1L]] <- rep(0, N); P_f[[1L]] <- m$P1     # t = 0 prior (stationary)
  v_mat <- matrix(NA_real_, n, p); vstd_mat <- matrix(NA_real_, n, p)
  colnames(v_mat) <- colnames(vstd_mat) <- m$observables
  loglik <- 0

  for (t in seq_len(n)) {
    ap <- as.numeric(Tt %*% a_f[[t]])
    Pp <- Tt %*% P_f[[t]] %*% t(Tt) + RQR
    Pp <- (Pp + t(Pp)) / 2
    a_p[[t + 1L]] <- ap; P_p[[t + 1L]] <- Pp

    idx <- which(!is.na(Y[t, ]))
    if (length(idx) == 0L) {
      a_f[[t + 1L]] <- ap; P_f[[t + 1L]] <- Pp
      next
    }
    Zt <- m$Z[idx, , drop = FALSE]
    Ht <- m$H[idx, idx, drop = FALSE]
    v <- as.numeric(Y[t, idx] - Zt %*% ap - m$d[idx])
    Fm <- Zt %*% Pp %*% t(Zt) + Ht
    Fm <- (Fm + t(Fm)) / 2
    ch <- tryCatch(chol(Fm), error = function(cnd) NULL)
    if (is.null(ch) || min(diag(ch)) < 1e-8 * max(diag(ch)))
      stop(errorCondition(sprintf(paste0(
        "innovation covariance is singular at period %d: some observables are ",
        "exact combinations of others given the model (an identity links them).\n",
        "  Drop one of the collinear observables or set a small measurement_error."), t),
        class = c("qpm_singular_F", "qpm_error", "error", "condition")))
    Finv_v <- backsolve(ch, forwardsolve(t(ch), v))
    K <- Pp %*% t(Zt) %*% chol2inv(ch)
    af <- ap + as.numeric(K %*% v)
    IKZ <- diag(N) - K %*% Zt
    Pf <- IKZ %*% Pp %*% t(IKZ) + K %*% Ht %*% t(K)   # Joseph form
    a_f[[t + 1L]] <- af; P_f[[t + 1L]] <- (Pf + t(Pf)) / 2

    loglik <- loglik - 0.5 * (length(idx) * log(2 * pi) +
                              2 * sum(log(diag(ch))) + sum(v * Finv_v))
    v_mat[t, idx] <- v
    vstd_mat[t, idx] <- v / sqrt(diag(Fm))
  }

  # RTS smoother (pseudo-inverse handles singular predicted covariances)
  ahat <- matrix(0, n + 1L, N); Vd <- matrix(0, n + 1L, N)
  ahat[n + 1L, ] <- a_f[[n + 1L]]
  Vt <- P_f[[n + 1L]]; Vd[n + 1L, ] <- pmax(diag(Vt), 0)
  for (t in seq(n, 1L)) {
    J <- P_f[[t]] %*% t(Tt) %*% pinv(P_p[[t + 1L]])
    ahat[t, ] <- a_f[[t]] + as.numeric(J %*% (ahat[t + 1L, ] - a_p[[t + 1L]]))
    Vt <- P_f[[t]] + J %*% (Vt - P_p[[t + 1L]]) %*% t(J)
    Vt <- (Vt + t(Vt)) / 2
    Vd[t, ] <- pmax(diag(Vt), 0)
  }

  # Smoothed structural shocks: R e_t = ahat_t - T ahat_{t-1}
  Rp <- pinv(m$R)
  ehat <- t(Rp %*% (t(ahat[-1L, , drop = FALSE]) - Tt %*% t(ahat[-(n + 1L), , drop = FALSE])))
  colnames(ehat) <- colnames(m$Qc)

  list(loglik = loglik,
       ahat = ahat[-1L, , drop = FALSE],      # smoothed states t = 1..n
       alpha0 = ahat[1L, ],                   # smoothed pre-sample state
       se = sqrt(Vd[-1L, , drop = FALSE]),
       shocks = ehat,
       innov = v_mat, innov_std = vstd_mat)
}
