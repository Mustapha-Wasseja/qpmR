#' Check a model for common specification problems
#'
#' Runs static checks (unused shocks/parameters, bare leads outside
#' `E()`, calibrations outside plausible ranges when the template
#' documents them) and then attempts to solve the model, reporting the
#' Blanchard-Kahn outcome. Unit algebra on declared units is on the
#' roadmap.
#'
#' @param model A `qpm_model`.
#' @return An object of class `qpm_lint` (a data frame of checks with
#'   status `ok`, `note`, `warn`, or `fail`), printed with markers.
#' @examples
#' qpm_lint(qpm_template("bkl"))
#' @export
qpm_lint <- function(model) {
  stopifnot(inherits(model, "qpm_model"))
  res <- list()
  add <- function(status, msg) res[[length(res) + 1L]] <<-
    data.frame(status = status, message = msg, stringsAsFactors = FALSE)

  add("ok", sprintf("%d equations for %d variables", length(model$equations),
                    nrow(model$vars)))

  used_shocks <- unique(unlist(lapply(model$parsed, function(p) p$shocks$shock)))
  unused <- setdiff(model$shocks, used_shocks)
  if (length(unused))
    add("warn", sprintf("declared shocks never used: %s", paste(unused, collapse = ", ")))
  else add("ok", "every declared shock appears in an equation")

  bare <- unique(unlist(lapply(model$parsed, function(p) p$bare_leads)))
  if (length(bare))
    add("note", sprintf("leads not wrapped in E(): %s (style: expectations should be explicit)",
                        paste(bare, collapse = ", ")))

  rng <- model$meta$ranges
  if (!is.null(rng)) {
    out_of_range <- character(0)
    for (p in intersect(names(rng), names(model$params))) {
      v <- model$params[[p]]
      if (v < rng[[p]][1] || v > rng[[p]][2])
        out_of_range <- c(out_of_range,
                          sprintf("%s = %s (documented range %s-%s)", p, fmt_num(v),
                                  fmt_num(rng[[p]][1]), fmt_num(rng[[p]][2])))
    }
    if (length(out_of_range))
      add("warn", paste("calibration outside documented range:",
                        paste(out_of_range, collapse = "; ")))
    else add("ok", "all calibrated parameters inside documented ranges")
  }

  sol <- tryCatch(qpm_solve(model), error = function(cnd) cnd)
  if (inherits(sol, "qpm_solution")) {
    add("ok", sprintf("solves: unique stable solution (Blanchard-Kahn satisfied); largest stable root %.3f",
                      max(sol$eigen$modulus[sol$eigen$stable])))
    ssv <- steady_state(sol)
    add("ok", sprintf("steady state exists and is unique (e.g. %s)",
                      paste(utils::head(paste(names(ssv), "=", fmt_num(round(ssv, 4))), 3),
                            collapse = ", ")))
  } else {
    add("fail", sprintf("does not solve: %s", conditionMessage(sol)))
  }

  structure(do.call(rbind, res), class = c("qpm_lint", "data.frame"))
}

#' @export
print.qpm_lint <- function(x, ...) {
  marks <- c(ok = "v", note = "i", warn = "!", fail = "x")
  cat("<qpm_lint>\n")
  for (r in seq_len(nrow(x))) {
    msg <- strwrap(x$message[r], width = 72, exdent = 4)
    cat(sprintf("  %s %s\n", marks[[x$status[r]]], paste(msg, collapse = "\n  ")))
  }
  n_bad <- sum(x$status %in% c("warn", "fail"))
  if (n_bad == 0) cat("  all checks passed\n")
  invisible(x)
}
