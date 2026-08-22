# Quarter-label helpers. Forecast periods inherit "YYYY-Qq" labels from a
# filtration when possible, and fall back to "h1", "h2", ...

is_quarter_label <- function(x) grepl("^[0-9]{4}-Q[1-4]$", x)

next_quarters <- function(last, H) {
  yr <- as.integer(substr(last, 1, 4))
  qt <- as.integer(substr(last, 7, 7))
  idx <- (yr * 4L + (qt - 1L)) + seq_len(H)
  sprintf("%d-Q%d", idx %/% 4L, idx %% 4L + 1L)
}

make_forecast_periods <- function(from, H) {
  last <- NULL
  if (inherits(from, "qpm_filtration")) last <- as.character(from$period[from$n_obs])
  if (inherits(from, "qpm_sim")) last <- as.character(from$period[nrow(from)])
  if (!is.null(last) && is_quarter_label(last)) return(next_quarters(last, H))
  paste0("h", seq_len(H))
}

# Resolve user-supplied period names ("2027-Q1", "h3", or "3") to horizons.
resolve_horizons <- function(nms, periods) {
  if (is.null(nms) || any(nms == ""))
    stop("conditions and judgment must be named by period, e.g. c(\"2027-Q1\" = 2) or c(h3 = 2)",
         call. = FALSE)
  vapply(nms, function(nm) {
    j <- match(nm, periods)
    if (!is.na(j)) return(as.integer(j))
    if (grepl("^h?[0-9]+$", nm)) {
      h <- as.integer(sub("^h", "", nm))
      if (h >= 1L && h <= length(periods)) return(h)
    }
    stop(sprintf("period '%s' is outside the forecast horizon (%s ... %s)",
                 nm, periods[1], periods[length(periods)]), call. = FALSE)
  }, integer(1))
}
