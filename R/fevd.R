#' Forecast error variance decomposition
#'
#' Splits the forecast error variance of each variable at each horizon
#' into the contributions of the structural shocks — "how much of
#' inflation uncertainty two years out is the cost-push shock?". For
#' \deqn{x_t = P x_{t-1} + Q e_t,  e_t ~ N(0, S)}
#' the h-step forecast error variance is
#' \deqn{V_h = sum_{j<h} P^j Q S Q' (P^j)'}
#' and the share of shock `k` is the same sum with only column `k` of
#' `Q` active.
#' Shares sum to one across shocks for every variable and horizon.
#'
#' Shares remain well defined when the model has unit roots, even though
#' the variances themselves grow without bound.
#'
#' @param x A `qpm_solution`, or a `qpm_model` (solved first).
#' @param ... Passed to methods.
#' @return A data frame of class `qpm_fevd` in long format with columns
#'   `variable`, `shock`, `horizon`, `share` and `variance`.
#'   `print()` shows the dominant shocks; `plot()` draws stacked shares.
#' @examples
#' sol <- qpm_solve(qpm_template("bkl"))
#' fv <- fevd(sol, horizon = 20)
#' fv
#' plot(fv, var = "pi")
#' @export
fevd <- function(x, ...) UseMethod("fevd")

#' @export
fevd.qpm_model <- function(x, ...) fevd(qpm_solve(x), ...)

#' @rdname fevd
#' @param horizon Largest forecast horizon.
#' @param vars Variables to include; default all declared variables.
#' @param shocks Shocks to include; default all.
#' @export
fevd.qpm_solution <- function(x, horizon = 24, vars = NULL, shocks = NULL, ...) {
  vars <- vars %||% x$vars
  bad <- setdiff(vars, x$vars_all)
  if (length(bad))
    stop(sprintf("unknown variable(s): %s", paste(bad, collapse = ", ")), call. = FALSE)
  shocks <- shocks %||% x$shocks
  bads <- setdiff(shocks, x$shocks)
  if (length(bads))
    stop(sprintf("unknown shock(s): %s", paste(bads, collapse = ", ")), call. = FALSE)
  if (horizon < 1) stop("horizon must be at least 1", call. = FALSE)

  P <- unname(x$P); Q <- unname(x$Q)
  N <- nrow(P); k <- length(x$shocks)
  sig2 <- x$sigma^2
  vi <- match(vars, x$vars_all)
  si <- match(shocks, x$shocks)

  # accumulate diag(P^j Q_k S_k Q_k' (P^j)') for each shock, and the total
  contrib <- array(0, c(horizon, length(vars), length(shocks)))
  total <- matrix(0, horizon, length(vars))
  Pj_Q <- Q                                   # j = 0
  for (h in seq_len(horizon)) {
    for (m in seq_along(si)) {
      col <- Pj_Q[vi, si[m]]
      contrib[h, , m] <- (if (h > 1) contrib[h - 1L, , m] else 0) +
        col^2 * sig2[[si[m]]]
    }
    allc <- Pj_Q[vi, , drop = FALSE]
    total[h, ] <- (if (h > 1) total[h - 1L, ] else 0) +
      as.numeric(allc^2 %*% sig2)
    Pj_Q <- P %*% Pj_Q
  }

  denom <- ifelse(total > .Machine$double.eps, total, NA_real_)
  out <- data.frame(
    variable = rep(vars, each = horizon, times = length(shocks)),
    shock = rep(shocks, each = horizon * length(vars)),
    horizon = rep(seq_len(horizon), times = length(vars) * length(shocks)),
    variance = as.vector(contrib),
    share = as.vector(contrib / array(denom, dim(contrib))),
    stringsAsFactors = FALSE
  )
  structure(out, class = c("qpm_fevd", "data.frame"),
            labels = x$labels, horizon = horizon, name = x$name)
}

#' @export
print.qpm_fevd <- function(x, horizons = NULL, ...) {
  df <- as.data.frame(x)
  H <- attr(x, "horizon")
  hs <- horizons %||% unique(pmin(c(1, 4, 8, H), H))
  cat(sprintf("<qpm_fevd> %s - shares of forecast error variance\n", attr(x, "name", exact = TRUE)))
  cat(sprintf("  horizons %s; dominant shocks per variable:\n",
              paste(hs, collapse = ", ")))
  for (v in unique(df$variable)) {
    parts <- vapply(hs, function(h) {
      d <- df[df$variable == v & df$horizon == h, ]
      d <- d[order(-d$share), ]
      if (!nrow(d) || is.na(d$share[1])) return("-")
      sprintf("%s %.0f%%", d$shock[1], 100 * d$share[1])
    }, character(1))
    cat(sprintf("    %-10s %s\n", v, paste(parts, collapse = "   ")))
  }
  invisible(x)
}

#' @export
#' @rdname fevd
#' @param var Variable to plot.
#' @param drop_zero Omit shocks that never contribute.
plot.qpm_fevd <- function(x, var = NULL, drop_zero = TRUE, ...) {
  df <- as.data.frame(x)
  var <- var %||% df$variable[1]
  d <- df[df$variable == var, , drop = FALSE]
  if (nrow(d) == 0L)
    stop(sprintf("variable '%s' not in this decomposition", var), call. = FALSE)
  shocks <- unique(d$shock)
  if (drop_zero)
    shocks <- shocks[vapply(shocks, function(s)
      max(d$share[d$shock == s], na.rm = TRUE) > 1e-4, TRUE)]
  H <- max(d$horizon)
  M <- vapply(shocks, function(s) d$share[d$shock == s][order(d$horizon[d$shock == s])],
              numeric(H))
  M[is.na(M)] <- 0
  cols <- qpm_palette(length(shocks))
  labels <- attr(x, "labels")

  op <- graphics::par(mar = c(2.6, 2.8, 2.0, 0.6), mgp = c(1.6, 0.4, 0),
                      tcl = -0.25, cex.axis = 0.85)
  on.exit(graphics::par(op))
  graphics::plot(NA, xlim = c(0.5, H + 0.5), ylim = c(0, 1.28),
                 xlab = "quarters ahead", ylab = "share of forecast error variance",
                 yaxt = "n",
                 main = sprintf("Variance decomposition of %s%s", var,
                                if (nzchar(labels[var] %||% ""))
                                  sprintf(" (%s)", labels[var]) else ""))
  graphics::axis(2, at = seq(0, 1, 0.25), labels = paste0(seq(0, 100, 25), "%"))
  for (h in seq_len(H)) {
    base <- 0
    for (j in seq_along(shocks)) {
      graphics::rect(h - 0.5, base, h + 0.5, base + M[h, j], col = cols[j], border = NA)
      base <- base + M[h, j]
    }
  }
  graphics::legend("top", legend = shocks, fill = cols, border = NA,
                   bty = "n", cex = 0.72, ncol = 4)
  invisible(x)
}
