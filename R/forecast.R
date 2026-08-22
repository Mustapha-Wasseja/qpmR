#' Unconditional model forecast with uncertainty bands
#'
#' Iterates the solved model forward from an initial state and computes
#' analytic forecast uncertainty from the shock variances,
#' \deqn{V_h = P V_{h-1} P' + Q S Q'}
#' giving Gaussian fan bands around the mean path.
#'
#' Conditional forecasts, judgment, and filtered initial states are the
#' subject of qpmR 0.2/0.3; in 0.1 the initial state comes from a
#' simulation (or is the steady state).
#'
#' @param object A `qpm_solution`.
#' @param from Initial state: a `qpm_sim` from [simulate()] (its final
#'   state is used, and its path is kept as history for plotting), a full
#'   named deviation vector over `object$vars_all`, or `NULL` (steady
#'   state).
#' @param horizon Forecast horizon in quarters.
#' @param bands Coverage levels for the fan, e.g. `c(0.5, 0.7, 0.9)`.
#' @param sigma Optional named vector of shock standard deviations.
#' @return An object of class `qpm_forecast`: a list with `paths` (long
#'   data frame: `variable`, `h`, `mean`, and `lo_*`/`hi_*` per band, in
#'   levels), plus attributes for plotting.
#' @examples
#' sol <- qpm_solve(qpm_template("bkl"))
#' histq <- simulate(sol, nsim = 40, seed = 7, burn = 20)
#' fc <- qpm_forecast(sol, from = histq, horizon = 12)
#' fc
#' plot(fc, vars = c("pi", "i", "y_gap", "q"))
#' @export
qpm_forecast <- function(object, from = NULL, horizon = 12,
                         bands = c(0.5, 0.7, 0.9), sigma = NULL) {
  stopifnot(inherits(object, "qpm_solution"))
  N <- length(object$vars_all)

  history <- NULL
  if (is.null(from)) {
    x0 <- rep(0, N)
  } else if (inherits(from, "qpm_sim")) {
    x0 <- attr(from, "state")
    history <- from
  } else if (is.numeric(from) && length(from) == N) {
    x0 <- as.numeric(from)
  } else {
    stop(paste0("from must be NULL, a qpm_sim, or a full deviation vector over ",
                "object$vars_all (filtered initial states arrive with qpm_filter in 0.2)"),
         call. = FALSE)
  }

  sig <- object$sigma
  if (!is.null(sigma)) sig[names(sigma)] <- sigma
  S <- diag(sig^2, length(sig), length(sig))
  QSQ <- object$Q %*% S %*% t(object$Q)

  mean_path <- matrix(0, horizon, N)
  sd_path <- matrix(0, horizon, N)
  x <- x0
  V <- matrix(0, N, N)
  for (h in seq_len(horizon)) {
    x <- as.numeric(object$P %*% x)
    V <- object$P %*% V %*% t(object$P) + QSQ
    mean_path[h, ] <- x
    sd_path[h, ] <- sqrt(pmax(diag(V), 0))
  }
  colnames(mean_path) <- colnames(sd_path) <- object$vars_all

  vs <- object$vars
  ssv <- object$ss[vs]
  rows <- vector("list", length(vs))
  for (j in seq_along(vs)) {
    v <- vs[j]
    d <- data.frame(variable = v, h = seq_len(horizon),
                    mean = mean_path[, v] + ssv[[v]])
    for (b in bands) {
      zq <- stats::qnorm(0.5 + b / 2)
      d[[sprintf("lo_%.0f", 100 * b)]] <- d$mean - zq * sd_path[, v]
      d[[sprintf("hi_%.0f", 100 * b)]] <- d$mean + zq * sd_path[, v]
    }
    rows[[j]] <- d
  }
  paths <- do.call(rbind, rows)
  rownames(paths) <- NULL

  structure(list(paths = paths, bands = bands, horizon = horizon,
                 history = history, ss = ssv,
                 labels = object$labels, units = object$units,
                 name = object$name),
            class = "qpm_forecast")
}

#' @export
print.qpm_forecast <- function(x, ...) {
  cat(sprintf("<qpm_forecast> %s - %d quarters ahead\n", x$name, x$horizon))
  hs <- unique(pmin(c(1, 4, 8, x$horizon), x$horizon))
  b <- max(x$bands)
  lo <- sprintf("lo_%.0f", 100 * b); hi <- sprintf("hi_%.0f", 100 * b)
  cat(sprintf("  mean (%d%% band) at h = %s:\n", round(100 * b),
              paste(hs, collapse = ", ")))
  for (v in unique(x$paths$variable)) {
    d <- x$paths[x$paths$variable == v & x$paths$h %in% hs, , drop = FALSE]
    cells <- sprintf("%s (%s, %s)", fmt_num(round(d$mean, 2)),
                     fmt_num(round(d[[lo]], 2)), fmt_num(round(d[[hi]], 2)))
    cat(sprintf("    %-10s %s\n", v, paste(cells, collapse = "  ")))
  }
  invisible(x)
}

#' @export
plot.qpm_forecast <- function(x, vars = NULL, ...) {
  vs <- vars %||% utils::head(unique(x$paths$variable), 4)
  n <- length(vs)
  nc <- ceiling(sqrt(n)); nr <- ceiling(n / nc)
  op <- graphics::par(mfrow = c(nr, nc), mar = c(2.4, 2.6, 1.8, 0.6),
                      mgp = c(1.5, 0.4, 0), tcl = -0.25, cex.main = 0.95,
                      cex.axis = 0.85)
  on.exit(graphics::par(op))

  hist <- x$history
  T0 <- if (!is.null(hist)) nrow(hist) else 0L
  col_line <- "#1f5da8"

  for (v in vs) {
    d <- x$paths[x$paths$variable == v, , drop = FALSE]
    hx <- T0 + d$h
    ylim <- range(d[, grepl("^(lo|hi)_", names(d))], d$mean,
                  if (T0) hist[[v]])
    xlim <- c(if (T0) max(1, T0 - 24) else 1, T0 + x$horizon)
    graphics::plot(NA, xlim = xlim, ylim = ylim, xlab = "quarter", ylab = "",
                   main = if (nzchar(x$labels[v] %||% ""))
                     sprintf("%s (%s)", v, x$labels[v]) else v)
    for (bi in rev(seq_along(x$bands))) {
      b <- x$bands[bi]
      lo <- d[[sprintf("lo_%.0f", 100 * b)]]
      hi <- d[[sprintf("hi_%.0f", 100 * b)]]
      graphics::polygon(c(hx, rev(hx)), c(lo, rev(hi)),
                        col = grDevices::adjustcolor(col_line, alpha.f = 0.14),
                        border = NA)
    }
    graphics::lines(hx, d$mean, col = col_line, lwd = 2)
    if (T0) {
      graphics::lines(seq_len(T0), hist[[v]], col = "grey25", lwd = 1.6)
      graphics::abline(v = T0 + 0.5, lty = 3, col = "grey55")
    }
    graphics::abline(h = x$ss[[v]], lty = 3, col = "grey70")
  }
  invisible(x)
}
