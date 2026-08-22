#' Identification diagnostics (Iskrev-style Jacobian analysis)
#'
#' Checks, before any estimation is run, whether the chosen parameters
#' can be told apart by the data. Two Jacobians are analyzed numerically
#' at the current calibration, in the spirit of Iskrev (2010):
#'
#' * **solution level**: derivatives of the solved transition, shock
#'   loading, and observable steady state with respect to the
#'   parameters. Rank deficiency here means some parameter movements do
#'   not change the model's solution at all.
#' * **moment level** (stationary models only): derivatives of the
#'   observables' first and second moments (means, and autocovariances
#'   up to `lags`). Rank deficiency here means some parameter movements
#'   are observationally equivalent in population.
#'
#' The report names parameters with (numerically) no effect, parameter
#' combinations spanning any null space, and near-collinear pairs of
#' Jacobian columns (correlation above 0.995) that are only jointly
#' identified.
#'
#' @param model A `qpm_model`.
#' @param params Parameters to check: a character vector of structural
#'   parameter and/or shock names, or a [priors()] object (its names are
#'   used). Default: all structural parameters.
#' @param observables Observed variables the moment analysis conditions
#'   on. Default: all declared variables.
#' @param lags Autocovariance lags in the moment vector.
#' @param h Relative step for the central differences.
#' @return An object of class `qpm_identification` with the ranks,
#'   singular values, and flagged parameters; printed as a verdict list.
#' @references Iskrev, N. (2010). Local identification in DSGE models.
#'   Journal of Monetary Economics, 57(2), 189-202.
#' @examples
#' qpm_identify(qpm_template("bkl"),
#'              params = c("b1", "b2", "b3", "c1", "c2"),
#'              observables = c("pi", "i", "q", "dy_obs"))
#' @export
qpm_identify <- function(model, params = NULL, observables = NULL,
                         lags = 3, h = 1e-5) {
  stopifnot(inherits(model, "qpm_model"))
  if (inherits(params, "qpm_priors")) params <- names(params)
  params <- params %||% names(model$params)
  is_par <- params %in% names(model$params)
  is_shk <- params %in% model$shocks
  bad <- params[!(is_par | is_shk)]
  if (length(bad))
    stop(sprintf("unknown parameters/shocks: %s", paste(bad, collapse = ", ")),
         call. = FALSE)
  observables <- observables %||% model$vars$name
  badv <- setdiff(observables, model$vars$name)
  if (length(badv))
    stop(sprintf("unknown observable(s): %s", paste(badv, collapse = ", ")),
         call. = FALSE)

  theta0 <- vapply(seq_along(params), function(j)
    if (is_par[j]) unname(model$params[[params[j]]])
    else unname(model$sigma[[params[j]]]), numeric(1))

  sol0 <- qpm_solve(model)
  stationary <- (sol0$counts$unit %||% 0L) == 0L
  oidx <- match(observables, sol0$vars_all)

  pieces <- function(theta) {
    m2 <- model
    if (any(is_par)) m2$params[params[is_par]] <- theta[is_par]
    if (any(is_shk)) m2$sigma[params[is_shk]] <- theta[is_shk]
    sol <- qpm_solve(m2)
    Tm <- unname(sol$P)
    Qc <- diag(sol$sigma^2, length(sol$sigma))
    RQR <- sol$Q %*% Qc %*% t(sol$Q)
    tau <- c(as.vector(Tm), as.vector(RQR), unname(sol$ss[oidx]))
    mom <- NULL
    if (stationary) {
      V <- solve_lyapunov(Tm, RQR)
      Zv <- V[oidx, oidx, drop = FALSE]
      mom <- c(unname(sol$ss[oidx]), Zv[lower.tri(Zv, diag = TRUE)])
      Tl <- diag(nrow(Tm))
      for (l in seq_len(lags)) {
        Tl <- Tm %*% Tl
        G <- (Tl %*% V)[oidx, oidx, drop = FALSE]
        mom <- c(mom, as.vector(G))
      }
    }
    list(tau = tau, mom = mom)
  }

  k <- length(params)
  J_tau <- NULL; J_mom <- NULL
  for (j in seq_len(k)) {
    hj <- h * max(1, abs(theta0[j]))
    tp <- theta0; tp[j] <- tp[j] + hj
    tm <- theta0; tm[j] <- tm[j] - hj
    pp <- tryCatch(pieces(tp), error = function(cnd) NULL)
    pm <- tryCatch(pieces(tm), error = function(cnd) NULL)
    if (is.null(pp) || is.null(pm))
      stop(sprintf("the model fails to solve when perturbing '%s'; move the calibration off the boundary",
                   params[j]), call. = FALSE)
    dt <- (pp$tau - pm$tau) / (2 * hj)
    J_tau <- cbind(J_tau, dt)
    if (stationary) J_mom <- cbind(J_mom, (pp$mom - pm$mom) / (2 * hj))
  }
  colnames(J_tau) <- params
  if (stationary) colnames(J_mom) <- params

  analyze <- function(J) {
    norms <- sqrt(colSums(J^2))
    dead <- params[norms < 1e-9 * max(norms, .Machine$double.xmin)]
    live <- setdiff(params, dead)
    out <- list(dead = dead, rank = 0L, k_live = length(live),
                weak = character(0), pairs = character(0), min_sv_ratio = NA_real_)
    if (length(live) >= 1L) {
      Jl <- J[, live, drop = FALSE]
      Jl <- sweep(Jl, 2L, sqrt(colSums(Jl^2)), "/")
      sv <- svd(Jl)
      tol <- 1e-7 * max(sv$d)
      out$rank <- sum(sv$d > tol)
      out$min_sv_ratio <- min(sv$d) / max(sv$d)
      if (out$rank < length(live)) {
        nullv <- sv$v[, (out$rank + 1L):length(live), drop = FALSE]
        out$weak <- unique(unlist(apply(nullv, 2L, function(v) {
          live[order(abs(v), decreasing = TRUE)][seq_len(min(3L, length(live)))]
        }, simplify = FALSE)))
      }
      if (length(live) >= 2L) {
        cc <- suppressWarnings(stats::cor(Jl))
        idx <- which(abs(cc) > 0.995 & upper.tri(cc), arr.ind = TRUE)
        if (nrow(idx))
          out$pairs <- apply(idx, 1L, function(r)
            sprintf("%s ~ %s (%.3f)", live[r[1]], live[r[2]], cc[r[1], r[2]]))
      }
    }
    out
  }

  structure(list(params = params, observables = observables,
                 stationary = stationary, lags = lags,
                 solution = analyze(J_tau),
                 moments = if (stationary) analyze(J_mom) else NULL),
            class = "qpm_identification")
}

#' @export
print.qpm_identification <- function(x, ...) {
  cat(sprintf("<qpm_identification> %d parameter%s, observables: %s\n",
              length(x$params), if (length(x$params) == 1L) "" else "s",
              paste(x$observables, collapse = ", ")))
  show <- function(a, label, k_total) {
    if (length(a$dead))
      cat(sprintf("  x %s: no effect at all: %s\n", label,
                  paste(a$dead, collapse = ", ")))
    if (a$rank < a$k_live) {
      cat(sprintf("  x %s: rank %d < %d - parameters not separately identified\n",
                  label, a$rank, a$k_live))
      cat(sprintf("      combinations involved: %s\n", paste(a$weak, collapse = ", ")))
    } else if (a$k_live > 0L) {
      cat(sprintf("  v %s: full rank (%d), smallest/largest singular value %.2g\n",
                  label, a$rank, a$min_sv_ratio))
    }
    if (length(a$pairs))
      cat(sprintf("  ! %s: near-collinear pairs (only jointly identified): %s\n",
                  label, paste(a$pairs, collapse = "; ")))
  }
  show(x$solution, "solution level", length(x$params))
  if (is.null(x$moments)) {
    cat("  i moment level skipped: the model has unit roots (population moments\n")
    cat("    do not exist); the solution-level check above still applies\n")
  } else {
    show(x$moments, sprintf("moment level (means + autocovariances to lag %d)", x$lags),
         length(x$params))
  }
  invisible(x)
}
