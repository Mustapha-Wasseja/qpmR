#' Model-implied moments, and how they compare with the data
#'
#' The standard calibration check: does the model reproduce the
#' volatilities and persistence actually observed? Reports the
#' population standard deviation and autocorrelations implied by the
#' solved model — from the stationary covariance
#' \eqn{V = P V P' + Q S Q'} and \eqn{corr_k = diag(P^k V) / diag(V)} —
#' next to the same statistics computed from data, plus the shock that
#' accounts for most of each variable's unconditional variance.
#'
#' Population moments exist only for stationary models. When the model
#' has unit roots (random-walk trends) they are undefined, and the
#' function reports that rather than returning nonsense; use
#' [fevd()] and [qpm_filter()] diagnostics instead.
#'
#' @param x A `qpm_solution` or `qpm_model`.
#' @param data Optional data frame of observations in levels (columns
#'   named for model variables, an optional `period` column) whose
#'   moments are shown alongside. Missing values are dropped per
#'   variable.
#' @param vars Variables to report; default all declared variables.
#' @param lags Autocorrelation orders to report.
#' @return An object of class `qpm_properties`: a data frame with the
#'   model and (optionally) data moments.
#' @examples
#' sol <- qpm_solve(qpm_template("bkl"))
#' model_properties(sol, vars = c("y_gap", "pi", "i", "q"))
#'
#' # against simulated data
#' obs <- simulate(sol, nsim = 200, seed = 5, burn = 50)
#' model_properties(sol, data = obs, vars = c("y_gap", "pi", "i"))
#' @export
model_properties <- function(x, data = NULL, vars = NULL, lags = c(1, 4)) {
  sol <- if (inherits(x, "qpm_model")) qpm_solve(x) else x
  stopifnot(inherits(sol, "qpm_solution"))
  vars <- vars %||% sol$vars
  bad <- setdiff(vars, sol$vars_all)
  if (length(bad))
    stop(sprintf("unknown variable(s): %s", paste(bad, collapse = ", ")),
         call. = FALSE)
  lags <- sort(unique(as.integer(lags)))
  if (any(lags < 1)) stop("lags must be positive", call. = FALSE)

  stationary <- (sol$counts$unit %||% 0L) == 0L
  vi <- match(vars, sol$vars_all)
  out <- data.frame(variable = vars, stringsAsFactors = FALSE)

  if (stationary) {
    P <- unname(sol$P)
    S <- diag(sol$sigma^2, length(sol$sigma), length(sol$sigma))
    V <- solve_lyapunov(P, sol$Q %*% S %*% t(sol$Q))
    dv <- diag(V)
    out$model_sd <- sqrt(pmax(dv[vi], 0))
    Pk <- diag(nrow(P))
    for (l in seq_len(max(lags))) {
      Pk <- P %*% Pk
      if (l %in% lags) {
        ac <- diag(Pk %*% V)[vi] / ifelse(dv[vi] > 0, dv[vi], NA_real_)
        out[[sprintf("model_ac%d", l)]] <- ac
      }
    }
    # unconditional variance share by shock
    fv <- fevd(sol, horizon = 200, vars = vars)
    top <- vapply(vars, function(v) {
      d <- fv[fv$variable == v & fv$horizon == max(fv$horizon), ]
      d <- d[order(-d$share), ]
      if (!nrow(d) || is.na(d$share[1])) return(NA_character_)
      sprintf("%s (%.0f%%)", d$shock[1], 100 * d$share[1])
    }, character(1))
    out$main_shock <- unname(top)
  }

  if (!is.null(data)) {
    if (!is.data.frame(data)) stop("data must be a data frame", call. = FALSE)
    miss <- setdiff(vars, names(data))
    dsd <- rep(NA_real_, length(vars)); names(dsd) <- vars
    dac <- lapply(lags, function(l) stats::setNames(rep(NA_real_, length(vars)), vars))
    for (j in seq_along(vars)) {
      v <- vars[j]
      if (v %in% miss) next
      z <- data[[v]]; z <- z[!is.na(z)]
      if (length(z) < 8L) next
      dsd[j] <- stats::sd(z)
      a <- stats::acf(z, lag.max = max(lags), plot = FALSE)$acf
      for (li in seq_along(lags)) dac[[li]][j] <- a[lags[li] + 1L]
    }
    out$data_sd <- unname(dsd)
    for (li in seq_along(lags))
      out[[sprintf("data_ac%d", lags[li])]] <- unname(dac[[li]])
    if (length(miss))
      attr(out, "missing_cols") <- miss
  }

  structure(out, class = c("qpm_properties", "data.frame"),
            stationary = stationary, lags = lags, name = sol$name,
            has_data = !is.null(data))
}

#' @export
print.qpm_properties <- function(x, digits = 2, ...) {
  df <- as.data.frame(x)
  cat(sprintf("<qpm_properties> %s\n", attr(x, "name", exact = TRUE)))
  if (!attr(x, "stationary")) {
    cat("  i the model has unit roots, so population moments do not exist;\n")
    cat("    only the data moments are shown (use fevd() for variance shares)\n")
  }
  if (isTRUE(attr(x, "has_data")))
    cat("  model-implied moments next to the same statistics in the data\n")
  num <- vapply(df, is.numeric, TRUE)
  df[num] <- lapply(df[num], round, digits)
  print(df, row.names = FALSE, right = FALSE)
  miss <- attr(x, "missing_cols")
  if (length(miss))
    cat(sprintf("  (not in the data: %s)\n", paste(miss, collapse = ", ")))
  if (isTRUE(attr(x, "has_data")) && "model_sd" %in% names(df) &&
      "data_sd" %in% names(df)) {
    r <- df$model_sd / df$data_sd
    off <- df$variable[is.finite(r) & (r > 2 | r < 0.5)]
    if (length(off))
      cat(sprintf("  ! model and data volatility differ by more than 2x for: %s\n",
                  paste(off, collapse = ", ")))
  }
  invisible(x)
}
