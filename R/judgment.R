#' Add logged judgment to a forecast
#'
#' Central-bank forecasts are never raw model output: the desk knows
#' about the announced electricity tariff, the tax change, the one-off
#' the model cannot see. `add_judgment()` makes that adjustment a
#' first-class, logged operation: you state the change you want (in
#' percentage points, relative to the current forecast), qpmR back-solves
#' the structural shocks needed to support it while keeping the whole
#' forecast model-consistent, records who imposed it and why, and flags
#' judgment that requires implausibly large shocks.
#'
#' Judgment entries are stored as absolute targets, so the ledger is
#' replayable; the full set of conditions and judgment is re-solved
#' jointly each time. Inspect the ledger with [judgment_log()].
#'
#' @param fc A `qpm_forecast` or a `qpm_round`.
#' @param ... Named adjustments: one argument per variable, each a named
#'   vector of *additions* (percentage points, relative to the current
#'   forecast) by period, e.g. `pi = c("2027-Q1" = 0.4)`.
#' @param author Who is imposing the judgment (logged).
#' @param rationale Why (logged; make it meaningful -- the ledger is the
#'   audit trail read back before the policy meeting).
#' @param anticipated Expectation mode for the re-solve; defaults to the
#'   forecast's current mode, or unanticipated.
#' @param instruments Shocks allowed to move; defaults to the forecast's
#'   current instruments, or all shocks.
#' @return The adjusted `qpm_forecast` with the entry appended to its
#'   judgment ledger.
#' @examples
#' sol <- qpm_solve(qpm_template("bkl"))
#' fc <- qpm_forecast(sol, horizon = 8)
#' fc2 <- add_judgment(fc, pi = c(h2 = 0.5),
#'                     author = "desk",
#'                     rationale = "announced electricity tariff increase")
#' judgment_log(fc2)
#' @export
add_judgment <- function(fc, ..., author = "desk", rationale = "",
                         anticipated = NULL, instruments = NULL) {
  if (inherits(fc, "qpm_round")) {
    fc$forecast <- add_judgment(fc$forecast, ..., author = author,
                                rationale = rationale,
                                anticipated = anticipated,
                                instruments = instruments)
    return(fc)
  }
  stopifnot(inherits(fc, "qpm_forecast"))
  sol <- fc$solution
  if (is.null(sol))
    stop("this forecast predates qpmR 0.3; re-run qpm_forecast()", call. = FALSE)
  spec <- list(...)
  if (length(spec) == 0L) stop("no judgment given", call. = FALSE)
  if (is.null(names(spec)) || any(names(spec) == ""))
    stop("judgment must be named by variable", call. = FALSE)
  badv <- setdiff(names(spec), sol$vars)
  if (length(badv))
    stop(sprintf("unknown variable(s): %s", paste(badv, collapse = ", ")), call. = FALSE)

  anticipated <- anticipated %||% fc$anticipated %||% FALSE
  instruments <- instruments %||% fc$instruments
  if (is.null(fc$baseline_dev)) fc$baseline_dev <- fc$dev
  next_id <- if (is.null(fc$judgment)) 1L else max(fc$judgment$id) + 1L

  rows <- lapply(names(spec), function(v) {
    x <- spec[[v]]
    h <- resolve_horizons(names(x), fc$periods)
    cur <- fc$dev[cbind(h, match(v, sol$vars_all))] + sol$ss[match(v, sol$vars_all)]
    data.frame(id = next_id, time = format(Sys.time(), "%Y-%m-%d %H:%M"),
               author = author, variable = v, period = fc$periods[h], h = h,
               add = as.numeric(x), target = cur + as.numeric(x),
               rationale = rationale, stringsAsFactors = FALSE)
  })
  entry <- do.call(rbind, rows)

  clash <- merge(entry[, c("variable", "h")],
                 if (is.null(fc$conditions)) data.frame(variable = character(0), h = integer(0))
                 else fc$conditions[, c("variable", "h")])
  if (nrow(clash))
    stop(sprintf("judgment collides with an existing condition/judgment at: %s",
                 paste(sprintf("%s@h%d", clash$variable, clash$h), collapse = ", ")),
         call. = FALSE)

  fc$judgment <- rbind(fc$judgment, entry)
  fc$conditions <- rbind(fc$conditions,
                         data.frame(variable = entry$variable, period = entry$period,
                                    h = entry$h, value = entry$target,
                                    source = "judgment", stringsAsFactors = FALSE))
  recondition(fc, anticipated = anticipated, instruments = instruments)
}

#' Print a forecast's judgment ledger
#'
#' @param fc A `qpm_forecast` with judgment applied.
#' @return The ledger data frame, invisibly.
#' @examples
#' sol <- qpm_solve(qpm_template("bkl"))
#' fc <- add_judgment(qpm_forecast(sol, horizon = 8), pi = c(h2 = 0.5),
#'                    author = "desk", rationale = "tariff")
#' judgment_log(fc)
#' @export
judgment_log <- function(fc) {
  if (inherits(fc, "qpm_round")) fc <- fc$forecast
  stopifnot(inherits(fc, "qpm_forecast"))
  j <- fc$judgment
  if (is.null(j) || nrow(j) == 0L) {
    cat("no judgment on this forecast\n")
    return(invisible(NULL))
  }
  cat(sprintf("<judgment ledger> %d entr%s\n", nrow(j),
              if (nrow(j) == 1L) "y" else "ies"))
  show <- j[, c("id", "time", "author", "variable", "period", "add", "target",
                "rationale")]
  show$add <- sprintf("%+.2f", show$add)
  show$target <- round(show$target, 2)
  print(show, row.names = FALSE, right = FALSE)
  print_implied_shocks(fc)
  invisible(j)
}
