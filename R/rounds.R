#' Forecast rounds: one replayable artifact per forecast
#'
#' A forecast round binds everything that produced a forecast -- the
#' model and its calibration, the data vintage, the filtration, the
#' forecast with its conditions and judgment -- into one object that can
#' be saved, reloaded, re-run, and compared with later rounds via
#' [compare_rounds()]. This is the object an institution archives: next
#' quarter, "why did the forecast move?" is answered from the rounds, not
#' from memory.
#'
#' `qpm_round()` runs the standard pipeline (solve, filter, baseline
#' forecast). Conditions, scenarios, and judgment are then applied to the
#' round directly: [qpm_condition()], [qpm_scenario()], and
#' [add_judgment()] all accept a round and update its forecast.
#'
#' @param name Round name, e.g. `"2026-Q3 September"`.
#' @param model A `qpm_model`.
#' @param data Data frame in levels with a `period` column; passed to
#'   [qpm_filter()]. Quarter labels (`"2026-Q3"` style) are required for
#'   cross-round comparison.
#' @param observables Columns treated as observed (default: all columns
#'   matching declared variables).
#' @param horizon Forecast horizon in quarters.
#' @param bands Fan coverage levels.
#' @param measurement_error,kappa Passed to [qpm_filter()].
#' @return An object of class `qpm_round` with elements `model`, `data`,
#'   `solution`, `fit`, and `forecast`.
#' @examples
#' m <- qpm_template("bkl")
#' sol <- qpm_solve(m)
#' obs <- simulate(sol, nsim = 40, seed = 1, burn = 20)
#' obs$period <- next_quarters("2016-Q1", 40)
#' r <- qpm_round("test round", m, obs[, c("period", "pi", "i", "q")],
#'                horizon = 8)
#' r
#' @export
qpm_round <- function(name, model, data, observables = NULL, horizon = 12,
                      bands = c(0.5, 0.7, 0.9), measurement_error = 0,
                      kappa = 1e6) {
  stopifnot(is.character(name), length(name) == 1L, inherits(model, "qpm_model"),
            is.data.frame(data))
  if (!("period" %in% names(data)) || !all(is_quarter_label(as.character(data$period))))
    warning("data has no 'YYYY-Qq' period labels; this round cannot be compared across vintages")

  sol <- qpm_solve(model)
  fit <- qpm_filter(sol, data, observables = observables,
                    measurement_error = measurement_error, kappa = kappa)
  fc <- qpm_forecast(sol, from = fit, horizon = horizon, bands = bands)

  structure(list(name = name,
                 created = format(Sys.time(), "%Y-%m-%d %H:%M"),
                 qpmR_version = as.character(utils::packageVersion("qpmR")),
                 model = model, data = data,
                 observables = fit$observables, horizon = horizon,
                 bands = bands, measurement_error = measurement_error,
                 kappa = kappa,
                 solution = sol, fit = fit, forecast = fc),
            class = "qpm_round")
}

#' @export
print.qpm_round <- function(x, ...) {
  cat(sprintf("<qpm_round> %s\n", x$name))
  cat(sprintf("  created %s - qpmR %s\n", x$created, x$qpmR_version))
  cat(sprintf("  model: %s - %d parameters\n", x$model$name, length(x$model$params)))
  cat(sprintf("  data: %s ... %s (%d quarters) - observables: %s\n",
              x$fit$period[1], x$fit$period[x$fit$n_obs], x$fit$n_obs,
              paste(x$observables, collapse = ", ")))
  cat(sprintf("  filter: log-likelihood %.2f%s\n", x$fit$loglik,
              if (isTRUE(x$fit$diffuse)) sprintf(" (diffuse, %d unit roots)", x$fit$n_unit) else ""))
  fc <- x$forecast
  nc <- if (is.null(fc$conditions)) 0L else sum(fc$conditions$source == "condition")
  nj <- if (is.null(fc$judgment)) 0L else nrow(fc$judgment)
  cat(sprintf("  forecast: %d quarters (%s ... %s) - %d condition%s, %d judgment entr%s\n",
              fc$horizon, fc$periods[1], fc$periods[fc$horizon],
              nc, if (nc == 1L) "" else "s", nj, if (nj == 1L) "y" else "ies"))
  invisible(x)
}

#' @export
plot.qpm_round <- function(x, ...) plot(x$forecast, ...)

round_slug <- function(name) gsub("(^-|-$)", "", gsub("[^a-z0-9]+", "-", tolower(name)))

#' Save, load, and list forecast rounds
#'
#' A round store is a plain directory: each round lives in
#' `store/<slug>/` as a self-contained `round.rds` plus human-readable
#' sidecars (`forecast.csv`, `data.csv`, `calibration.csv`, and
#' `judgment.csv` when judgment was applied) so that a round can be
#' audited without R.
#'
#' @param round A `qpm_round`.
#' @param store Directory of the round store (created if missing).
#' @param overwrite Allow replacing an existing round of the same name.
#' @return `save_round()` returns the round directory invisibly;
#'   `load_round()` returns the `qpm_round`; `list_rounds()` returns a
#'   data frame of the store's contents.
#' @examples
#' m <- qpm_template("bkl")
#' obs <- simulate(qpm_solve(m), nsim = 40, seed = 1, burn = 20)
#' obs$period <- next_quarters("2016-Q1", 40)
#' r <- qpm_round("demo", m, obs[, c("period", "pi", "i", "q")], horizon = 8)
#' store <- file.path(tempdir(), "rounds")
#' save_round(r, store)
#' list_rounds(store)
#' r2 <- load_round("demo", store)
#' @export
save_round <- function(round, store = "rounds", overwrite = FALSE) {
  stopifnot(inherits(round, "qpm_round"))
  dir <- file.path(store, round_slug(round$name))
  if (dir.exists(dir) && !overwrite)
    stop(sprintf("round '%s' already exists in %s (use overwrite = TRUE)",
                 round$name, store), call. = FALSE)
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)

  saveRDS(round, file.path(dir, "round.rds"))
  meta <- list(name = round$name, created = round$created,
               qpmR_version = round$qpmR_version,
               data_span = c(as.character(round$fit$period[1]),
                             as.character(round$fit$period[round$fit$n_obs])),
               horizon = round$horizon, loglik = round$fit$loglik,
               n_judgment = if (is.null(round$forecast$judgment)) 0L
                            else nrow(round$forecast$judgment))
  saveRDS(meta, file.path(dir, "meta.rds"))
  utils::write.csv(round$forecast$paths, file.path(dir, "forecast.csv"),
                   row.names = FALSE)
  utils::write.csv(round$data, file.path(dir, "data.csv"), row.names = FALSE)
  utils::write.csv(data.frame(parameter = c(names(round$model$params),
                                            paste0("sigma_", names(round$model$sigma))),
                              value = c(unname(round$model$params),
                                        unname(round$model$sigma))),
                   file.path(dir, "calibration.csv"), row.names = FALSE)
  if (!is.null(round$forecast$judgment) && nrow(round$forecast$judgment))
    utils::write.csv(round$forecast$judgment, file.path(dir, "judgment.csv"),
                     row.names = FALSE)
  invisible(dir)
}

#' @rdname save_round
#' @param name Round name (or its slug), or a direct path to a round
#'   directory or `round.rds`.
#' @export
load_round <- function(name, store = "rounds") {
  cand <- c(name,
            file.path(name, "round.rds"),
            file.path(store, round_slug(name), "round.rds"))
  path <- cand[file.exists(cand) & !dir.exists(cand)][1]
  if (is.na(path))
    stop(sprintf("round '%s' not found in store '%s'", name, store), call. = FALSE)
  out <- readRDS(path)
  if (!inherits(out, "qpm_round"))
    stop(sprintf("'%s' is not a saved qpm_round", path), call. = FALSE)
  out
}

#' @rdname save_round
#' @export
list_rounds <- function(store = "rounds") {
  metas <- list.files(store, pattern = "^meta\\.rds$", recursive = TRUE,
                      full.names = TRUE)
  if (length(metas) == 0L)
    return(data.frame(name = character(0), created = character(0),
                      data_to = character(0), horizon = integer(0),
                      n_judgment = integer(0)))
  rows <- lapply(metas, function(p) {
    m <- readRDS(p)
    data.frame(name = m$name, created = m$created,
               data_to = m$data_span[2], horizon = m$horizon,
               n_judgment = m$n_judgment, stringsAsFactors = FALSE)
  })
  out <- do.call(rbind, rows)
  out[order(out$created), , drop = FALSE]
}
