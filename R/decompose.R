#' Historical shock decomposition
#'
#' Splits the smoothed history of every variable into the additive
#' contributions of each structural shock plus the carry-over of the
#' pre-sample initial state: with smoothed shocks \eqn{e_t},
#' \deqn{a_t = sum_j c_j(t) + c_0(t),  c_j(t) = P c_j(t-1) + Q_j e_{j,t}}
#' The contributions sum exactly to the smoothed state (deviations from
#' steady state); this identity is verified internally.
#'
#' @param fit A `qpm_filtration` from [qpm_filter()].
#' @param vars Variables to keep (default: all declared variables).
#' @return A long data frame of class `qpm_decomposition` with columns
#'   `period`, `variable`, `component` (shock names plus `"initial"`),
#'   and `value` (contribution, in deviations from steady state).
#'   `plot()` draws a stacked-bar decomposition with the smoothed total
#'   overlaid.
#' @examples
#' sol <- qpm_solve(qpm_template("bkl"))
#' obs <- simulate(sol, nsim = 60, seed = 3, burn = 20)
#' fit <- qpm_filter(sol, obs[, c("period", "pi", "i", "q")])
#' dec <- qpm_decompose(fit)
#' plot(dec, var = "pi")
#' @export
qpm_decompose <- function(fit, vars = NULL) {
  stopifnot(inherits(fit, "qpm_filtration"))
  sol <- fit$solution
  vars <- vars %||% sol$vars
  bad <- setdiff(vars, sol$vars)
  if (length(bad))
    stop(sprintf("unknown variable(s): %s", paste(bad, collapse = ", ")), call. = FALSE)

  n <- fit$n_obs
  N <- length(sol$vars_all)
  k <- length(sol$shocks)
  ehat <- as.matrix(fit$shocks[, sol$shocks, drop = FALSE])

  comps <- c(sol$shocks, "initial")
  contrib <- array(0, dim = c(n, N, k + 1L),
                   dimnames = list(NULL, sol$vars_all, comps))
  prev <- matrix(0, N, k + 1L)
  prev[, k + 1L] <- fit$alpha0
  for (t in seq_len(n)) {
    cur <- sol$P %*% prev
    cur[, seq_len(k)] <- cur[, seq_len(k)] + sol$Q %*% diag(ehat[t, ], k, k)
    contrib[t, , ] <- cur
    prev <- cur
  }

  # exact additivity check against the smoothed states
  total <- apply(contrib, c(1, 2), sum)
  gap <- max(abs(total - fit$states_dev))
  if (gap > 1e-6)
    warning(sprintf("decomposition residual %.2e: contributions do not sum exactly", gap))

  rows <- vector("list", length(vars))
  for (jv in seq_along(vars)) {
    v <- vars[jv]
    rows[[jv]] <- data.frame(
      period = rep(fit$period, times = k + 1L),
      period_i = rep(seq_len(n), times = k + 1L),
      variable = v,
      component = rep(comps, each = n),
      value = as.vector(contrib[, v, ]),
      stringsAsFactors = FALSE
    )
  }
  out <- do.call(rbind, rows)
  structure(out, class = c("qpm_decomposition", "data.frame"),
            labels = sol$labels, ss = sol$ss[sol$vars],
            states_dev = fit$states_dev[, vars, drop = FALSE])
}

#' @export
print.qpm_decomposition <- function(x, ...) {
  df <- as.data.frame(x)
  vs <- unique(df$variable)
  comps <- unique(df$component)
  cat(sprintf("<qpm_decomposition> %d periods - %d variables - components: %s\n",
              max(df$period_i), length(vs),
              paste(comps, collapse = ", ")))
  v <- vs[1]
  d <- df[df$variable == v, ]
  m <- sort(tapply(abs(d$value), d$component, mean), decreasing = TRUE)
  cat(sprintf("  mean |contribution| to %s: %s\n", v,
              paste(sprintf("%s %.2f", names(m), m), collapse = ", ")))
  cat("  plot(x, var = \"...\") for stacked charts\n")
  invisible(x)
}

#' @export
plot.qpm_decomposition <- function(x, var = NULL, drop_zero = TRUE, ...) {
  df <- as.data.frame(x)
  var <- var %||% df$variable[1]
  d <- df[df$variable == var, , drop = FALSE]
  if (nrow(d) == 0L)
    stop(sprintf("variable '%s' not in this decomposition", var), call. = FALSE)

  comps <- setdiff(unique(d$component), "initial")
  if (drop_zero)
    comps <- comps[vapply(comps, function(cc)
      max(abs(d$value[d$component == cc])) > 1e-9, TRUE)]
  comps <- c(comps, "initial")
  n <- max(d$period_i)
  M <- sapply(comps, function(cc) d$value[d$component == cc][order(d$period_i[d$component == cc])])
  if (is.null(dim(M))) M <- matrix(M, nrow = n)
  total <- attr(x, "states_dev")[, var]

  cols <- c(qpm_palette(length(comps) - 1L), "grey72")
  ylim <- range(rowSums(M * (M > 0)), rowSums(M * (M < 0)), total)
  labels <- attr(x, "labels")

  op <- graphics::par(mar = c(2.6, 2.8, 2.0, 0.6), mgp = c(1.6, 0.4, 0),
                      tcl = -0.25, cex.axis = 0.85)
  on.exit(graphics::par(op))
  graphics::plot(NA, xlim = c(0.5, n + 0.5), ylim = ylim, xlab = "period",
                 ylab = "deviation from steady state",
                 main = sprintf("Decomposition of %s%s", var,
                                if (nzchar(labels[var] %||% ""))
                                  sprintf(" (%s)", labels[var]) else ""))
  for (t in seq_len(n)) {
    ypos <- 0; yneg <- 0
    for (j in seq_along(comps)) {
      vv <- M[t, j]
      if (vv >= 0) {
        graphics::rect(t - 0.42, ypos, t + 0.42, ypos + vv, col = cols[j], border = NA)
        ypos <- ypos + vv
      } else {
        graphics::rect(t - 0.42, yneg + vv, t + 0.42, yneg, col = cols[j], border = NA)
        yneg <- yneg + vv
      }
    }
  }
  graphics::lines(seq_len(n), total, lwd = 2.2, col = "grey15")
  graphics::abline(h = 0, col = "grey40", lwd = 0.8)
  graphics::legend("topleft", legend = comps, fill = cols, border = NA,
                   bty = "n", cex = 0.72, ncol = 2)
  invisible(x)
}
