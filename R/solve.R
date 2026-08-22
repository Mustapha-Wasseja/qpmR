#' Solve a model under model-consistent expectations
#'
#' Reduces the model to first-order form (adding auxiliary states for
#' lags/leads beyond one quarter), computes the steady state, and solves
#' for the unique stable rational-expectations solution
#' \deqn{x_t = P x_{t-1} + Q e_t}
#' via the generalized Schur (QZ) decomposition (Klein 2000), with full
#' Blanchard-Kahn diagnostics.
#'
#' @param model A `qpm_model`.
#' @param tol Numerical tolerance for the solution residual check.
#' @return An object of class `qpm_solution` with elements `P`, `Q`
#'   (transition and impact matrices over the expanded state vector),
#'   `ss` (steady state), and an eigenvalue table (see [eigen_table()]).
#' @references Klein, P. (2000). Using the generalized Schur form to solve
#'   a multivariate linear rational expectations model. Journal of Economic
#'   Dynamics and Control, 24(10), 1405-1423.
#' @examples
#' sol <- qpm_solve(qpm_template("bkl"))
#' sol
#' @export
qpm_solve <- function(model, tol = 1e-7) {
  stopifnot(inherits(model, "qpm_model"))
  sys <- build_first_order(model)

  ss <- solve_steady_state(sys)

  kl <- solve_klein(sys$A, sys$B, sys$C, sys$D)

  resid <- max(abs(sys$A %*% kl$P %*% kl$P + sys$B %*% kl$P + sys$C))
  if (resid > tol)
    warning(sprintf("solution residual %.2e exceeds tol=%.1e; treat results with caution",
                    resid, tol))

  P <- kl$P; Q <- kl$Q
  dimnames(P) <- list(sys$vars_all, sys$vars_all)
  dimnames(Q) <- list(sys$vars_all, model$shocks)
  names(ss) <- sys$vars_all

  structure(list(
    name = model$name, P = P, Q = Q, ss = ss,
    vars = model$vars$name, vars_all = sys$vars_all,
    aux = setdiff(sys$vars_all, model$vars$name),
    shocks = model$shocks, sigma = model$sigma,
    eigen = kl$eigen, counts = kl$counts,
    labels = stats::setNames(model$vars$label, model$vars$name),
    units = stats::setNames(model$vars$unit, model$vars$name),
    model = model, residual = resid
  ), class = "qpm_solution")
}

# -- first-order reduction ---------------------------------------------------
# Turns the parsed equations (any lags/leads) into
#   A x_{t+1} + B x_t + C x_{t-1} + D eps_t + const = 0
# by introducing auxiliary states v.Lk (lags) and v.Fk (leads).
build_first_order <- function(model) {
  co <- lapply(model$parsed, eq_coefficients, params = model$params)
  varnames <- model$vars$name

  inc <- do.call(rbind, lapply(seq_along(co), function(i) {
    d <- co[[i]]$var_coefs
    if (nrow(d)) cbind(eq = i, d) else NULL
  }))
  shk <- do.call(rbind, lapply(seq_along(co), function(i) {
    d <- co[[i]]$shk_coefs
    if (nrow(d)) cbind(eq = i, d) else NULL
  }))
  consts <- vapply(co, function(z) z$const, numeric(1))

  # auxiliary states per variable
  aux_names <- character(0)
  aux_rows <- list()
  for (v in varnames) {
    sh <- inc$shift[inc$var == v]
    L <- max(0L, -min(c(sh, 0L)))
    Fd <- max(0L, max(c(sh, 0L)))
    if (L >= 2L) {
      for (k in seq_len(L - 1L)) {
        nm <- paste0(v, ".L", k)
        tgt <- if (k == 1L) v else paste0(v, ".L", k - 1L)
        aux_names <- c(aux_names, nm)
        aux_rows[[length(aux_rows) + 1L]] <-
          data.frame(var = c(nm, tgt), shift = c(0L, -1L), coef = c(1, -1),
                     stringsAsFactors = FALSE)
      }
    }
    if (Fd >= 2L) {
      for (k in seq_len(Fd - 1L)) {
        nm <- paste0(v, ".F", k)
        tgt <- if (k == 1L) v else paste0(v, ".F", k - 1L)
        aux_names <- c(aux_names, nm)
        aux_rows[[length(aux_rows) + 1L]] <-
          data.frame(var = c(nm, tgt), shift = c(0L, 1L), coef = c(1, -1),
                     stringsAsFactors = FALSE)
      }
    }
  }

  # remap deep lags/leads onto auxiliaries
  if (!is.null(inc) && nrow(inc)) {
    deep_lag <- inc$shift <= -2L
    inc$var[deep_lag] <- paste0(inc$var[deep_lag], ".L", -inc$shift[deep_lag] - 1L)
    inc$shift[deep_lag] <- -1L
    deep_lead <- inc$shift >= 2L
    inc$var[deep_lead] <- paste0(inc$var[deep_lead], ".F", inc$shift[deep_lead] - 1L)
    inc$shift[deep_lead] <- 1L
  }

  vars_all <- c(varnames, aux_names)
  N <- length(vars_all)
  n_orig <- length(varnames)

  A <- B <- C <- matrix(0, N, N)
  D <- matrix(0, N, length(model$shocks),
              dimnames = list(NULL, model$shocks))
  const <- c(consts, rep(0, length(aux_names)))

  put <- function(M, eq, v, coef) {
    j <- match(v, vars_all)
    M[cbind(eq, j)] <- M[cbind(eq, j)] + coef
    M
  }
  for (r in seq_len(nrow(inc))) {
    s <- inc$shift[r]
    if (s == 1L) A <- put(A, inc$eq[r], inc$var[r], inc$coef[r])
    else if (s == 0L) B <- put(B, inc$eq[r], inc$var[r], inc$coef[r])
    else C <- put(C, inc$eq[r], inc$var[r], inc$coef[r])
  }
  if (!is.null(shk) && nrow(shk)) {
    for (r in seq_len(nrow(shk)))
      D[shk$eq[r], shk$shock[r]] <- D[shk$eq[r], shk$shock[r]] + shk$coef[r]
  }
  for (i in seq_along(aux_rows)) {
    eqi <- n_orig + i
    d <- aux_rows[[i]]
    for (r in seq_len(nrow(d))) {
      s <- d$shift[r]
      if (s == 1L) A <- put(A, eqi, d$var[r], d$coef[r])
      else if (s == 0L) B <- put(B, eqi, d$var[r], d$coef[r])
      else C <- put(C, eqi, d$var[r], d$coef[r])
    }
  }

  list(A = A, B = B, C = C, D = D, const = const, vars_all = vars_all)
}

# -- steady state ------------------------------------------------------------
solve_steady_state <- function(sys) {
  M <- sys$A + sys$B + sys$C
  sv <- svd(M)
  if (max(sv$d) < 1e-300 || min(sv$d) < 1e-10 * max(sv$d)) {
    load <- abs(sv$v[, which.min(sv$d)])
    culprits <- sys$vars_all[order(load, decreasing = TRUE)][seq_len(min(3, length(load)))]
    stop(errorCondition(sprintf(paste0(
      "no unique steady state: the long-run system is singular ",
      "(likely a unit root / random-walk process; qpmR 0.1 requires stationary models).\n",
      "  variables most involved: %s"), paste(culprits, collapse = ", ")),
      class = c("qpm_singular_steady_state", "qpm_error", "error", "condition")))
  }
  as.numeric(solve(M, -sys$const))
}

# -- Klein (2000) via ordered QZ --------------------------------------------
solve_klein <- function(A, B, C, D) {
  N <- nrow(A)
  Z0 <- matrix(0, N, N)
  Fm <- rbind(cbind(A, Z0), cbind(Z0, diag(N)))    # pencil: G z = lambda F z
  Gm <- rbind(cbind(-B, -C), cbind(diag(N), Z0))

  gz <- QZ::qz(Gm, Fm)
  mod <- eig_modulus(gz$ALPHAR, gz$ALPHAI, gz$BETA)

  sel <- as.integer(mod < 1)
  # never split a complex conjugate pair (they share a 2x2 block)
  i <- 1L
  while (i < length(sel)) {
    if (gz$ALPHAI[i] != 0) {
      sel[i] <- sel[i + 1L] <- max(sel[i], sel[i + 1L])
      i <- i + 2L
    } else i <- i + 1L
  }

  os <- QZ::qz.dtgsen(gz$S, gz$T, gz$Q, gz$Z, select = sel)
  mod_o <- eig_modulus(os$ALPHAR, os$ALPHAI, os$BETA)
  n_stable <- sum(sel)

  eigen_df <- data.frame(modulus = mod_o,
                         stable = mod_o < 1,
                         infinite = !is.finite(mod_o))
  eigen_df <- eigen_df[order(eigen_df$modulus), , drop = FALSE]
  rownames(eigen_df) <- NULL
  counts <- list(stable = n_stable,
                 unstable = sum(is.finite(mod)) - n_stable,
                 infinite = sum(!is.finite(mod)),
                 predetermined = N)

  if (n_stable > N)
    stop(errorCondition(sprintf(paste0(
      "Blanchard-Kahn failure: %d stable roots for %d predetermined states ",
      "(indeterminacy - multiple stable solutions / sunspots).\n",
      "  A too-weak policy response is the usual cause: check that the rule ",
      "satisfies the Taylor principle (long-run response of the nominal rate ",
      "to inflation above one)."), n_stable, N),
      class = c("qpm_bk_indeterminate", "qpm_bk", "qpm_error", "error", "condition")))
  if (n_stable < N)
    stop(errorCondition(sprintf(paste0(
      "Blanchard-Kahn failure: %d stable roots for %d predetermined states ",
      "(no stable solution - the system is explosive).\n",
      "  Common causes: a near-unit or explosive backward root, or an exact ",
      "unit root from pure UIP / random-walk trends (use a dampened/hybrid ",
      "specification in qpmR 0.1)."), n_stable, N),
      class = c("qpm_bk_explosive", "qpm_bk", "qpm_error", "error", "condition")))

  Z <- os$Z
  Z11 <- Z[1:N, 1:N, drop = FALSE]
  Z21 <- Z[(N + 1):(2 * N), 1:N, drop = FALSE]
  P <- tryCatch(Z11 %*% solve(Z21), error = function(cnd)
    stop(errorCondition(paste0(
      "Blanchard-Kahn rank condition fails: the stable subspace cannot be ",
      "expressed in terms of the predetermined states"),
      class = c("qpm_bk_rank", "qpm_bk", "qpm_error", "error", "condition"))))
  P[abs(P) < 1e-12] <- 0

  Q <- -solve(A %*% P + B, D)
  Q[abs(Q) < 1e-12] <- 0

  list(P = P, Q = Q, eigen = eigen_df, counts = counts)
}

eig_modulus <- function(alphar, alphai, beta) {
  ifelse(abs(beta) < 1e-13, Inf,
         Mod(complex(real = alphar, imaginary = alphai)) / abs(beta))
}

# -- accessors and printing --------------------------------------------------

#' Generalized eigenvalues of a solved model
#'
#' @param x A `qpm_solution`.
#' @return A data frame with the moduli of the generalized eigenvalues of
#'   the model companion pencil, sorted ascending, with stability flags.
#' @examples
#' head(eigen_table(qpm_solve(qpm_template("bkl"))))
#' @export
eigen_table <- function(x) {
  stopifnot(inherits(x, "qpm_solution"))
  x$eigen
}

#' Steady state of a model or solution
#'
#' @param x A `qpm_model` or `qpm_solution`.
#' @param ... Unused.
#' @return Named vector of steady-state values for the declared variables.
#' @examples
#' steady_state(qpm_template("bkl"))
#' @export
steady_state <- function(x, ...) UseMethod("steady_state")

#' @export
steady_state.qpm_solution <- function(x, ...) x$ss[x$vars]

#' @export
steady_state.qpm_model <- function(x, ...) steady_state(qpm_solve(x))

#' @export
print.qpm_solution <- function(x, ...) {
  cat(sprintf("<qpm_solution> %s\n", x$name))
  cat(sprintf("  states: %d (%d declared + %d auxiliary) - shocks: %d\n",
              length(x$vars_all), length(x$vars), length(x$aux), length(x$shocks)))
  ct <- x$counts
  cat(sprintf("  Blanchard-Kahn: %d stable roots = %d predetermined states -> unique stable solution\n",
              ct$stable, ct$predetermined))
  fin <- x$eigen$modulus[is.finite(x$eigen$modulus)]
  st <- fin[fin < 1]; un <- fin[fin >= 1]
  cat(sprintf("  roots: largest stable %.3f%s%s\n",
              max(st),
              if (length(un)) sprintf(", smallest unstable %.3f", min(un)) else "",
              if (ct$infinite) sprintf(", %d infinite", ct$infinite) else ""))
  ssv <- steady_state(x)
  ps <- paste(names(ssv), "=", fmt_num(round(ssv, 6)), collapse = ", ")
  cat("  steady state:\n")
  cat(strwrap(ps, width = 76, indent = 4, exdent = 4), sep = "\n")
  invisible(x)
}
