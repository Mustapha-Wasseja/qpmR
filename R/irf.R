#' Impulse response functions
#'
#' @param x A `qpm_solution` from [qpm_solve()].
#' @param ... Passed to methods.
#' @return A data frame of class `qpm_irf` in long format with columns
#'   `shock`, `variable`, `horizon`, `value` (deviations from steady
#'   state). Printing shows peak effects; `plot()` draws panel charts.
#' @examples
#' sol <- qpm_solve(qpm_template("bkl"))
#' ir <- irf(sol, shock = "eps_i", horizon = 16)
#' ir
#' plot(ir, vars = c("pi", "y_gap", "i", "q"))
#' @export
irf <- function(x, ...) UseMethod("irf")

#' @rdname irf
#' @param shock Shock name(s); default all shocks.
#' @param horizon Number of quarters after impact.
#' @param size Shock size(s). Default is one standard deviation (from the
#'   model's `sigma`); a named vector or a single number can override.
#' @param vars Variables to include; default all declared (non-auxiliary)
#'   variables.
#' @export
irf.qpm_solution <- function(x, shock = NULL, horizon = 24, size = NULL,
                             vars = NULL, ...) {
  shock <- shock %||% x$shocks
  bad <- setdiff(shock, x$shocks)
  if (length(bad))
    stop(sprintf("unknown shock(s): %s", paste(bad, collapse = ", ")), call. = FALSE)
  vars <- vars %||% x$vars
  badv <- setdiff(vars, x$vars_all)
  if (length(badv))
    stop(sprintf("unknown variable(s): %s", paste(badv, collapse = ", ")), call. = FALSE)

  sizes <- x$sigma[shock]
  if (!is.null(size)) {
    if (is.null(names(size))) sizes[] <- size else sizes[names(size)] <- size
  }

  out <- vector("list", length(shock))
  for (si in seq_along(shock)) {
    s <- shock[si]
    N <- length(x$vars_all)
    path <- matrix(0, horizon + 1L, N)
    path[1L, ] <- x$Q[, s] * sizes[[s]]
    for (h in seq_len(horizon))
      path[h + 1L, ] <- x$P %*% path[h, ]
    colnames(path) <- x$vars_all
    keep <- path[, vars, drop = FALSE]
    out[[si]] <- data.frame(
      shock = s,
      variable = rep(vars, each = horizon + 1L),
      horizon = rep(0:horizon, times = length(vars)),
      value = as.vector(keep),
      stringsAsFactors = FALSE
    )
  }
  res <- do.call(rbind, out)
  structure(res, class = c("qpm_irf", "data.frame"),
            labels = x$labels, units = x$units, sizes = sizes)
}

#' @export
print.qpm_irf <- function(x, ...) {
  df <- as.data.frame(x)
  sizes <- attr(x, "sizes")
  cat("<qpm_irf> impulse responses (deviations from steady state)\n")
  cat(sprintf("  shocks: %s\n",
              paste(sprintf("%s (size %s)", names(sizes), fmt_num(sizes)),
                    collapse = ", ")))
  cat("  peak effects:\n")
  sp <- split(df, list(df$shock, df$variable), drop = TRUE)
  peaks <- do.call(rbind, lapply(sp, function(d) {
    j <- which.max(abs(d$value))
    data.frame(shock = d$shock[1], variable = d$variable[1],
               peak = d$value[j], quarter = d$horizon[j])
  }))
  peaks <- peaks[order(peaks$shock, -abs(peaks$peak)), ]
  rownames(peaks) <- NULL
  peaks$peak <- round(peaks$peak, 4)
  print(peaks, row.names = FALSE)
  invisible(x)
}

#' @export
plot.qpm_irf <- function(x, vars = NULL, ...) {
  df <- as.data.frame(x)
  if (!is.null(vars)) df <- df[df$variable %in% vars, , drop = FALSE]
  vs <- if (is.null(vars)) unique(df$variable) else vars[vars %in% df$variable]
  shks <- unique(df$shock)
  labels <- attr(x, "labels")
  cols <- qpm_palette(length(shks))

  n <- length(vs)
  nc <- ceiling(sqrt(n)); nr <- ceiling(n / nc)
  op <- graphics::par(mfrow = c(nr, nc), mar = c(2.4, 2.6, 1.8, 0.6),
                      mgp = c(1.5, 0.4, 0), tcl = -0.25, cex.main = 0.95,
                      cex.axis = 0.85)
  on.exit(graphics::par(op))
  for (v in vs) {
    d <- df[df$variable == v, , drop = FALSE]
    ylim <- range(d$value, 0)
    graphics::plot(NA, xlim = range(d$horizon), ylim = ylim,
                   xlab = "quarters", ylab = "",
                   main = if (!is.null(labels) && nzchar(labels[v] %||% ""))
                     sprintf("%s (%s)", v, labels[v]) else v)
    graphics::abline(h = 0, lty = 3, col = "grey55")
    for (si in seq_along(shks)) {
      ds <- d[d$shock == shks[si], , drop = FALSE]
      graphics::lines(ds$horizon, ds$value, col = cols[si], lwd = 2)
    }
    if (length(shks) > 1 && v == vs[1])
      graphics::legend("topright", legend = shks, col = cols, lwd = 2,
                       bty = "n", cex = 0.8)
  }
  invisible(x)
}

qpm_palette <- function(n) {
  base <- c("#1f5da8", "#c23f2e", "#2c8455", "#8455a0", "#b0791f",
            "#3c94a8", "#a04f78", "#5a5a5a", "#7fb2e5", "#e5a13c",
            "#66b28a", "#b88ac4", "#8a6d3b", "#495e8a")
  if (n <= length(base)) return(base[seq_len(n)])
  grDevices::hcl.colors(n, "Dark 3")
}
