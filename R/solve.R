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
    ss_free = attr(ss, "n_free") %||% 0L,
    vars = model$vars$name, vars_all = sys$vars_all,
    aux = setdiff(sys$vars_all, model$vars$name),
    shocks = model$shocks, sigma = model$sigma,
    eigen = kl$eigen, counts = kl$counts,
    labels = stats::setNames(model$vars$label, model$vars$name),
    units = stats::setNames(model$vars$unit, model$vars$name),
    structural = list(A = sys$A, B = sys$B, C = sys$C, D = sys$D),
    model = model, residual = resid
  ), class = "qpm_solution")
}

# -- first-order reduction ---------------------------------------------------
# Turns the parsed equations (any lags/leads) into
#   A x_{t+1} + B x_t + C x_{t-1} + D eps_t + const = 0
# by introducing auxiliary states v.Lk (lags) and v.Fk (leads).
# Everything about the first-order system that does not depend on the
# parameter values: which auxiliary states are needed, the expanded state
# vector, and the exact cell of A, B, C or D that each equation's
# coefficient lands in. Estimation re-solves the model thousands of times
# with the same equations and different numbers, so this is computed once
# per model and only the values are recomputed per solve.
build_structure <- function(model) {
  parsed <- model$parsed
  varnames <- model$vars$name
  n_eq <- length(parsed)

  # the symbol order eq_coefs_values() returns: variables then shocks
  nv <- vapply(parsed, function(p) nrow(p$vars), integer(1))
  ns <- vapply(parsed, function(p) nrow(p$shocks), integer(1))
  off <- c(0L, cumsum(nv + ns))

  # flatten every variable reference across equations
  eq_of <- rep(seq_len(n_eq), nv)
  var_of <- unlist(lapply(parsed, function(p) as.character(p$vars$var)),
                   use.names = FALSE)
  shift_of <- unlist(lapply(parsed, function(p) as.integer(p$vars$shift)),
                     use.names = FALSE)
  flat_of <- unlist(lapply(seq_len(n_eq), function(i)
    if (nv[i]) off[i] + seq_len(nv[i]) else integer(0)), use.names = FALSE)
  if (is.null(var_of)) { var_of <- character(0); shift_of <- integer(0) }

  # auxiliary states per variable, from the deepest lag and lead it takes
  aux_names <- character(0)
  aux_rows <- list()
  for (v in varnames) {
    sh <- shift_of[var_of == v]
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

  # remap deep lags and leads onto their auxiliary states
  deep_lag <- shift_of <= -2L
  var_of[deep_lag] <- paste0(var_of[deep_lag], ".L", -shift_of[deep_lag] - 1L)
  shift_of[deep_lag] <- -1L
  deep_lead <- shift_of >= 2L
  var_of[deep_lead] <- paste0(var_of[deep_lead], ".F", shift_of[deep_lead] - 1L)
  shift_of[deep_lead] <- 1L

  vars_all <- c(varnames, aux_names)
  N <- length(vars_all)
  n_orig <- length(varnames)
  col_of <- match(var_of, vars_all)          # the one-off O(N) lookup

  # linear indices into an N x N matrix, split by which matrix they land in
  lin <- eq_of + (col_of - 1L) * N
  by_mat <- function(sel) list(lin = lin[sel], flat = flat_of[sel])
  Aix <- by_mat(shift_of == 1L)
  Bix <- by_mat(shift_of == 0L)
  Cix <- by_mat(shift_of == -1L)
  for (ix in list(Aix, Bix, Cix))
    if (anyDuplicated(ix$lin))
      stop("internal: two coefficients target the same cell of the first-order system",
           call. = FALSE)

  # shocks -> D
  k <- length(model$shocks)
  eq_s <- rep(seq_len(n_eq), ns)
  shk_of <- unlist(lapply(parsed, function(p) as.character(p$shocks$shock)),
                   use.names = FALSE)
  flat_s <- unlist(lapply(seq_len(n_eq), function(i)
    if (ns[i]) off[i] + nv[i] + seq_len(ns[i]) else integer(0)), use.names = FALSE)
  if (is.null(shk_of)) shk_of <- character(0)
  Dix <- list(lin = eq_s + (match(shk_of, model$shocks) - 1L) * N,
              flat = flat_s)

  # the auxiliary identities themselves carry fixed +/-1 coefficients
  aux_lin <- list(A = integer(0), B = integer(0), C = integer(0))
  aux_val <- list(A = numeric(0), B = numeric(0), C = numeric(0))
  for (i in seq_along(aux_rows)) {
    eqi <- n_orig + i
    d <- aux_rows[[i]]
    for (r in seq_len(nrow(d))) {
      m <- if (d$shift[r] == 1L) "A" else if (d$shift[r] == 0L) "B" else "C"
      aux_lin[[m]] <- c(aux_lin[[m]], eqi + (match(d$var[r], vars_all) - 1L) * N)
      aux_val[[m]] <- c(aux_val[[m]], d$coef[r])
    }
  }

  list(vars_all = vars_all, N = N, n_eq = n_eq, n_aux = length(aux_names),
       A = Aix, B = Bix, C = Cix, D = Dix,
       aux_lin = aux_lin, aux_val = aux_val)
}

build_first_order <- function(model) {
  # Rebuild if the cache is absent (a model serialised by an older qpmR)
  # or no longer matches the equations it was built from.
  st <- model$structure
  if (is.null(st) || !identical(st$n_eq, length(model$parsed)) ||
      !identical(utils::head(st$vars_all, nrow(model$vars)), model$vars$name))
    st <- build_structure(model)
  parenv <- list2env(as.list(model$params), parent = baseenv())
  vals <- lapply(model$parsed, eq_coefs_values, parenv = parenv)
  coef_flat <- unlist(lapply(vals, `[[`, "coefs"), use.names = FALSE)
  consts <- vapply(vals, function(z) z$const, numeric(1))

  N <- st$N
  A <- B <- C <- matrix(0, N, N)
  D <- matrix(0, N, length(model$shocks),
              dimnames = list(NULL, model$shocks))
  if (length(st$A$lin)) A[st$A$lin] <- coef_flat[st$A$flat]
  if (length(st$B$lin)) B[st$B$lin] <- coef_flat[st$B$flat]
  if (length(st$C$lin)) C[st$C$lin] <- coef_flat[st$C$flat]
  if (length(st$D$lin)) D[st$D$lin] <- coef_flat[st$D$flat]
  if (length(st$aux_lin$A)) A[st$aux_lin$A] <- st$aux_val$A
  if (length(st$aux_lin$B)) B[st$aux_lin$B] <- st$aux_val$B
  if (length(st$aux_lin$C)) C[st$aux_lin$C] <- st$aux_val$C

  list(A = A, B = B, C = C, D = D,
       const = c(consts, rep(0, st$n_aux)), vars_all = st$vars_all)
}

# -- steady state ------------------------------------------------------------
# With unit-root (random-walk) trends the long-run matrix is singular: the
# level of a pure trend is a free normalization. We return the minimum-norm
# least-squares steady state (free levels normalized toward zero) and error
# only when no fixed point exists at all (e.g. a drifted random walk).
solve_steady_state <- function(sys) {
  M <- sys$A + sys$B + sys$C
  N <- nrow(M)
  sv <- svd(M)
  tolr <- 1e-9 * max(sv$d, .Machine$double.xmin)
  pos <- sv$d > tolr
  x <- sv$v[, pos, drop = FALSE] %*%
    ((t(sv$u[, pos, drop = FALSE]) %*% (-sys$const)) / sv$d[pos])
  x <- as.numeric(x)
  resid <- max(abs(M %*% x + sys$const))
  if (resid > 1e-8 * (1 + max(abs(sys$const)))) {
    load <- abs(sv$u[, which.min(sv$d)])
    culprits <- sys$vars_all[order(load, decreasing = TRUE)][seq_len(min(3, N))]
    stop(errorCondition(sprintf(paste0(
      "no steady state exists: a unit-root process appears to have a nonzero ",
      "drift (e.g. a random walk with drift), so the model has a growth path, ",
      "not a fixed point. Balanced-growth steady states are not yet supported: ",
      "set the drift to zero or detrend the data.\n",
      "  equations most involved: near %s"), paste(culprits, collapse = ", ")),
      class = c("qpm_no_steady_state", "qpm_error", "error", "condition")))
  }
  attr(x, "n_free") <- N - sum(pos)
  x
}

# -- Klein (2000) via ordered QZ --------------------------------------------
# Roots inside the unit circle count as stable; roots within unit_tol of the
# unit circle (random-walk trends) also count as stable, following the usual
# qz-criterium convention, and are reported separately as unit roots.
solve_klein <- function(A, B, C, D, unit_tol = 1e-6) {
  N <- nrow(A)
  Z0 <- matrix(0, N, N)
  Fm <- rbind(cbind(A, Z0), cbind(Z0, diag(N)))    # pencil: G z = lambda F z
  Gm <- rbind(cbind(-B, -C), cbind(diag(N), Z0))

  gz <- QZ::qz(Gm, Fm)
  mod <- eig_modulus(gz$ALPHAR, gz$ALPHAI, gz$BETA)

  sel <- as.integer(mod < 1 + unit_tol)
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
  n_unit <- sum(abs(mod[sel == 1L] - 1) < unit_tol)

  eigen_df <- data.frame(modulus = mod_o,
                         stable = mod_o < 1 + unit_tol,
                         unit = abs(mod_o - 1) < unit_tol,
                         infinite = !is.finite(mod_o))
  eigen_df <- eigen_df[order(eigen_df$modulus), , drop = FALSE]
  rownames(eigen_df) <- NULL
  counts <- list(stable = n_stable, unit = n_unit,
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
      "  A backward-looking root exceeds one: check autoregressive ",
      "coefficients and persistence sums in the calibration."), n_stable, N),
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
  fin <- x$eigen$modulus[is.finite(x$eigen$modulus) & !x$eigen$unit]
  st <- fin[fin < 1]; un <- fin[fin >= 1]
  cat(sprintf("  roots: largest stable %.3f%s%s%s\n",
              max(st),
              if (ct$unit %||% 0) sprintf(", %d unit (random-walk trends -> diffuse filtering)", ct$unit) else "",
              if (length(un)) sprintf(", smallest unstable %.3f", min(un)) else "",
              if (ct$infinite) sprintf(", %d infinite", ct$infinite) else ""))
  ssv <- steady_state(x)
  ps <- paste(names(ssv), "=", fmt_num(round(ssv, 6)), collapse = ", ")
  cat(if ((x$ss_free %||% 0) > 0)
        "  steady state (free trend levels normalized to minimum norm):\n"
      else "  steady state:\n")
  cat(strwrap(ps, width = 76, indent = 4, exdent = 4), sep = "\n")
  invisible(x)
}
