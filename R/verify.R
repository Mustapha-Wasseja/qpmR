#' Verify that an archived round still reproduces
#'
#' Re-runs a saved forecast round from its own contents — model,
#' calibration, data vintage, conditions and judgment — and checks that
#' the published numbers come back. This is the audit an institution
#' needs and that a folder of scripts cannot provide: a round that no
#' longer reproduces is a finding, not a mystery.
#'
#' When the round is loaded from a store, the human-readable CSV
#' sidecars are checked against the object too, so a hand-edited audit
#' trail is detected.
#'
#' @param round A `qpm_round`, or a round name/path to load from
#'   `store`.
#' @param store Round store used when `round` is a name.
#' @param tol Absolute tolerance on the forecast paths.
#' @return An object of class `qpm_verification`: `$ok`, the largest
#'   deviation, the worst variables, sidecar checks, and the qpmR
#'   versions involved.
#' @examples
#' m <- qpm_template("bkl")
#' obs <- simulate(qpm_solve(m), nsim = 40, seed = 1, burn = 20)
#' obs$period <- next_quarters("2016-Q1", 40)
#' r <- qpm_round("demo", m, obs[, c("period", "pi", "i", "q")], horizon = 8)
#' verify_round(r)
#' @export
verify_round <- function(round, store = "rounds", tol = 1e-6) {
  path <- NULL
  if (is.character(round)) {
    path <- dirname(c(round, file.path(round, "round.rds"),
                      file.path(store, round_slug(round), "round.rds"))[
                        file.exists(c(round, file.path(round, "round.rds"),
                                      file.path(store, round_slug(round), "round.rds")))][1])
    round <- load_round(round, store)
  }
  stopifnot(inherits(round, "qpm_round"))

  fc0 <- round$forecast
  cn <- fc0$conditions
  redo <- tryCatch(
    run_pipeline(round$model, round$data, round$observables, round$horizon,
                 round$bands, round$measurement_error, round$kappa,
                 conditions = cn,
                 anticipated = isTRUE(fc0$anticipated),
                 instruments = fc0$instruments),
    error = function(cnd) cnd)

  if (inherits(redo, "condition")) {
    return(structure(list(ok = FALSE, error = conditionMessage(redo),
                          name = round$name, max_dev = NA_real_,
                          worst = NULL, sidecars = NULL,
                          version_archived = round$qpmR_version,
                          version_now = as.character(utils::packageVersion("qpmR"))),
                     class = "qpm_verification"))
  }

  vs <- round$solution$vars
  a <- fc0$paths; b <- redo$paths
  key <- paste(a$variable, a$h)
  b <- b[match(key, paste(b$variable, b$h)), , drop = FALSE]
  dev <- abs(a$mean - b$mean)
  worst <- vapply(split(dev, a$variable), max, numeric(1))
  worst <- sort(worst[worst > tol], decreasing = TRUE)
  max_dev <- max(dev, na.rm = TRUE)

  sidecars <- NULL
  if (!is.null(path) && dir.exists(path)) {
    sidecars <- list()
    fcsv <- file.path(path, "forecast.csv")
    if (file.exists(fcsv)) {
      arch <- utils::read.csv(fcsv, stringsAsFactors = FALSE)
      sidecars$forecast <- nrow(arch) == nrow(a) &&
        max(abs(arch$mean - a$mean), na.rm = TRUE) < 1e-8
    }
    dcsv <- file.path(path, "data.csv")
    if (file.exists(dcsv)) {
      archd <- utils::read.csv(dcsv, stringsAsFactors = FALSE)
      num <- vapply(round$data, is.numeric, TRUE)
      sidecars$data <- nrow(archd) == nrow(round$data) &&
        isTRUE(all.equal(as.matrix(archd[, names(round$data)[num], drop = FALSE]),
                         as.matrix(round$data[, num, drop = FALSE]),
                         tolerance = 1e-8, check.attributes = FALSE))
    }
    jcsv <- file.path(path, "judgment.csv")
    if (file.exists(jcsv) && !is.null(fc0$judgment)) {
      archj <- utils::read.csv(jcsv, stringsAsFactors = FALSE)
      sidecars$judgment <- nrow(archj) == nrow(fc0$judgment) &&
        max(abs(archj$target - fc0$judgment$target), na.rm = TRUE) < 1e-8
    }
  }

  structure(list(
    ok = max_dev <= tol && all(unlist(sidecars) %||% TRUE),
    error = NULL, name = round$name, max_dev = max_dev, tol = tol,
    worst = worst, sidecars = sidecars, path = path,
    n_conditions = if (is.null(cn)) 0L else sum(cn$source == "condition"),
    n_judgment = if (is.null(fc0$judgment)) 0L else nrow(fc0$judgment),
    version_archived = round$qpmR_version,
    version_now = as.character(utils::packageVersion("qpmR"))
  ), class = "qpm_verification")
}

#' @export
print.qpm_verification <- function(x, ...) {
  cat(sprintf("<qpm_verification> %s\n", x$name))
  if (!is.null(x$error)) {
    cat(sprintf("  x the round does not re-run: %s\n", x$error))
    return(invisible(x))
  }
  cat(sprintf("  archived under qpmR %s, verified under %s%s\n",
              x$version_archived, x$version_now,
              if (x$version_archived != x$version_now) " (version differs)" else ""))
  cat(sprintf("  re-ran the pipeline with %d condition%s and %d judgment entr%s\n",
              x$n_conditions, if (x$n_conditions == 1L) "" else "s",
              x$n_judgment, if (x$n_judgment == 1L) "y" else "ies"))
  if (x$max_dev <= x$tol) {
    cat(sprintf("  v forecast reproduces exactly (largest deviation %.2g)\n", x$max_dev))
  } else {
    cat(sprintf("  x forecast does NOT reproduce: largest deviation %.3g (tolerance %.1g)\n",
                x$max_dev, x$tol))
    cat(sprintf("      worst variables: %s\n",
                paste(sprintf("%s %.3g", names(utils::head(x$worst, 4)),
                              utils::head(x$worst, 4)), collapse = ", ")))
    if (x$version_archived != x$version_now)
      cat("      the qpmR version changed since archiving; that is the usual cause\n")
  }
  if (!is.null(x$sidecars) && length(x$sidecars)) {
    bad <- names(x$sidecars)[!unlist(x$sidecars)]
    if (length(bad))
      cat(sprintf("  x sidecar files do not match the archived object: %s\n",
                  paste(bad, collapse = ", ")))
    else
      cat(sprintf("  v sidecar files match the archived object (%s)\n",
                  paste(names(x$sidecars), collapse = ", ")))
  }
  invisible(x)
}
