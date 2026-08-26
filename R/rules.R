#' Evaluate alternative policy rules
#'
#' Answers the question a policy committee actually asks — *what if we
#' responded differently?* — by re-solving the model over a grid of rule
#' parameters and scoring each one by the unconditional loss
#' \deqn{L = sum_v w_v var(v) + sum_v w^d_v var(v - v_{-1})}
#' computed from the model's stationary covariance rather than by
#' simulation, so it is exact. Tracing the resulting variance pairs gives
#' the inflation-output variability frontier (the Taylor curve).
#'
#' Rules that violate Blanchard-Kahn are reported as such rather than
#' dropped: a policy response too weak to deliver determinacy is a
#' finding, not a missing row.
#'
#' @param model A `qpm_model`.
#' @param grid A data frame of parameter values, one row per rule and one
#'   column per parameter (e.g. from [expand.grid()]).
#' @param loss Named weights on the variances of levels, e.g.
#'   `c(pi = 1, y_gap = 0.5)`.
#' @param diff_loss Named weights on the variances of first differences,
#'   e.g. `c(i = 0.5)` to penalise instrument volatility.
#' @return A data frame of class `qpm_rule_eval`: the grid, the variance
#'   of each targeted variable, the loss, and the Blanchard-Kahn outcome.
#' @examples
#' m <- qpm_template("bkl")
#' grid <- expand.grid(c2 = c(1.2, 1.5, 2, 3), c3 = c(0, 0.5, 1))
#' ev <- qpm_rule_eval(m, grid, loss = c(pi = 1, y_gap = 0.5),
#'                     diff_loss = c(i = 0.5))
#' ev
#' plot(ev)
#' @export
qpm_rule_eval <- function(model, grid, loss = c(pi = 1, y_gap = 0.5),
                          diff_loss = NULL) {
  stopifnot(inherits(model, "qpm_model"))
  if (!is.data.frame(grid)) grid <- as.data.frame(grid)
  if (!nrow(grid)) stop("grid has no rows", call. = FALSE)
  unknown <- setdiff(names(grid), c(names(model$params), model$shocks))
  if (length(unknown))
    stop(sprintf("grid columns are not parameters or shocks: %s",
                 paste(unknown, collapse = ", ")), call. = FALSE)
  tv <- unique(c(names(loss), names(diff_loss)))
  badv <- setdiff(tv, model$vars$name)
  if (length(badv))
    stop(sprintf("loss refers to unknown variable(s): %s",
                 paste(badv, collapse = ", ")), call. = FALSE)
  if (any(c(loss, diff_loss) < 0)) stop("loss weights must be >= 0", call. = FALSE)

  is_shk <- names(grid) %in% model$shocks
  res <- vector("list", nrow(grid))
  for (i in seq_len(nrow(grid))) {
    m2 <- model
    for (j in seq_along(grid)) {
      nm <- names(grid)[j]
      if (is_shk[j]) m2$sigma[[nm]] <- grid[[j]][i] else m2$params[[nm]] <- grid[[j]][i]
    }
    row <- as.list(grid[i, , drop = FALSE])
    sol <- tryCatch(qpm_solve(m2), error = function(cnd) cnd)
    if (inherits(sol, "condition")) {
      row$status <- if (inherits(sol, "qpm_bk_indeterminate")) "indeterminate"
                    else if (inherits(sol, "qpm_bk_explosive")) "explosive"
                    else "no solution"
      for (v in tv) row[[paste0("var_", v)]] <- NA_real_
      if (!is.null(diff_loss))
        for (v in names(diff_loss)) row[[paste0("vard_", v)]] <- NA_real_
      row$loss <- NA_real_
    } else if ((sol$counts$unit %||% 0L) > 0L) {
      row$status <- "unit root"
      for (v in tv) row[[paste0("var_", v)]] <- NA_real_
      if (!is.null(diff_loss))
        for (v in names(diff_loss)) row[[paste0("vard_", v)]] <- NA_real_
      row$loss <- NA_real_
    } else {
      P <- unname(sol$P)
      S <- diag(sol$sigma^2, length(sol$sigma), length(sol$sigma))
      V <- solve_lyapunov(P, sol$Q %*% S %*% t(sol$Q))
      PV <- P %*% V
      idx <- match(tv, sol$vars_all)
      names(idx) <- tv
      L <- 0
      for (v in names(loss)) {
        vv <- V[idx[[v]], idx[[v]]]
        row[[paste0("var_", v)]] <- vv
        L <- L + loss[[v]] * vv
      }
      for (v in setdiff(tv, names(loss)))
        row[[paste0("var_", v)]] <- V[idx[[v]], idx[[v]]]
      if (!is.null(diff_loss)) for (v in names(diff_loss)) {
        k <- idx[[v]]
        # var(x_t - x_{t-1}) = 2 (V_kk - cov(x_t, x_{t-1}))
        vd <- 2 * (V[k, k] - PV[k, k])
        row[[paste0("vard_", v)]] <- vd
        L <- L + diff_loss[[v]] * vd
      }
      row$status <- "ok"
      row$loss <- L
    }
    res[[i]] <- as.data.frame(row, stringsAsFactors = FALSE)
  }
  out <- do.call(rbind, res)
  rownames(out) <- NULL
  structure(out, class = c("qpm_rule_eval", "data.frame"),
            loss = loss, diff_loss = diff_loss, params = names(grid),
            name = model$name)
}

#' @export
print.qpm_rule_eval <- function(x, n = 8, ...) {
  df <- as.data.frame(x)
  lo <- attr(x, "loss"); dl <- attr(x, "diff_loss")
  cat(sprintf("<qpm_rule_eval> %s - %d rule%s\n", attr(x, "name", exact = TRUE), nrow(df),
              if (nrow(df) == 1L) "" else "s"))
  cat(sprintf("  loss: %s%s\n",
              paste(sprintf("%g*var(%s)", lo, names(lo)), collapse = " + "),
              if (!is.null(dl))
                paste0(" + ", paste(sprintf("%g*var(d%s)", dl, names(dl)),
                                    collapse = " + ")) else ""))
  bad <- df$status != "ok"
  if (any(bad)) {
    tb <- table(df$status[bad])
    cat(sprintf("  %d rule%s do not deliver a unique stable solution (%s)\n",
                sum(bad), if (sum(bad) == 1L) "" else "s",
                paste(sprintf("%d %s", tb, names(tb)), collapse = ", ")))
  }
  ok <- df[df$status == "ok", , drop = FALSE]
  if (nrow(ok)) {
    ok <- ok[order(ok$loss), ]
    cat(sprintf("  best %d by loss:\n", min(n, nrow(ok))))
    show <- utils::head(ok, n)
    num <- vapply(show, is.numeric, TRUE)
    show[num] <- lapply(show[num], round, 3)
    show$status <- NULL
    print(show, row.names = FALSE, right = FALSE)
  }
  invisible(x)
}

#' @export
#' @rdname qpm_rule_eval
#' @param x A `qpm_rule_eval`.
#' @param xvar,yvar Axes of the frontier. Either a variable name, whose
#'   level variance is used, or a scored column name directly — so
#'   `xvar = "vard_i"` traces the classic trade-off against instrument
#'   volatility. Defaults to the first two entries in `loss`.
#' @param ... Unused.
plot.qpm_rule_eval <- function(x, xvar = NULL, yvar = NULL, ...) {
  df <- as.data.frame(x)
  ok <- df[df$status == "ok", , drop = FALSE]
  if (!nrow(ok)) stop("no rule in this grid solves", call. = FALSE)
  lo <- attr(x, "loss")
  yv <- yvar %||% names(lo)[1]
  xv <- xvar %||% (if (length(lo) > 1) names(lo)[2] else names(lo)[1])
  resolve_col <- function(v) {
    if (paste0("var_", v) %in% names(ok)) return(paste0("var_", v))
    if (v %in% names(ok)) return(v)
    stop(sprintf("'%s' was not scored; add it to loss or diff_loss", v),
         call. = FALSE)
  }
  xc <- resolve_col(xv); yc <- resolve_col(yv)
  axis_label <- function(cn, v)
    if (startsWith(cn, "vard_")) sprintf("var(change in %s)", sub("^vard_", "", cn))
    else sprintf("var(%s)", sub("^var_", "", cn))

  op <- graphics::par(mar = c(3.0, 3.2, 2.0, 0.6), mgp = c(1.9, 0.4, 0),
                      tcl = -0.25, cex.axis = 0.85)
  on.exit(graphics::par(op))
  graphics::plot(ok[[xc]], ok[[yc]], pch = 16, cex = 0.7,
                 col = grDevices::adjustcolor("#1f5da8", 0.5),
                 xlab = axis_label(xc, xv), ylab = axis_label(yc, yv),
                 main = sprintf("Policy frontier: %s", attr(x, "name", exact = TRUE)))
  # Pareto frontier: rules not dominated on both axes at once. When policy
  # improves both variances over the whole grid this collapses to a single
  # rule, which is itself worth seeing rather than an empty line.
  xs <- ok[[xc]]; ys <- ok[[yc]]
  eff <- vapply(seq_along(xs), function(i)
    !any(xs <= xs[i] & ys <= ys[i] & (xs < xs[i] | ys < ys[i])), TRUE)
  o <- order(xs[eff])
  graphics::points(xs[eff], ys[eff], pch = 16, cex = 0.95, col = "#c23f2e")
  if (sum(eff) > 1L)
    graphics::lines(xs[eff][o], ys[eff][o], col = "#c23f2e", lwd = 2)
  best <- ok[which.min(ok$loss), ]
  graphics::points(best[[xc]], best[[yc]], pch = 1, cex = 2.4, col = "grey15", lwd = 2)
  graphics::legend("topright",
                   c("rules", sprintf("efficient (%d)", sum(eff)), "minimum loss"),
                   pch = c(16, 16, 1), pt.cex = c(0.7, 0.95, 1.6),
                   col = c(grDevices::adjustcolor("#1f5da8", 0.5), "#c23f2e", "grey15"),
                   bty = "n", cex = 0.8)
  invisible(x)
}
