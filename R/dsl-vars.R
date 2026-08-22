#' Declare a model variable with a label and unit
#'
#' Used inside [vars()] to attach documentation to a variable. Units are
#' stored and displayed; unit algebra (automatic consistency checking
#' inside equations) is on the roadmap.
#'
#' When given numeric data instead of a character label, `var()`
#' delegates to [stats::var()], so attaching qpmR does not break variance
#' computations.
#'
#' @param label Human-readable description, e.g. `"Output gap"` (or
#'   numeric data, which is passed to [stats::var()]).
#' @param unit Unit of measurement, e.g. `"pp"`, `"pct pa"`.
#' @param ... Passed to [stats::var()] in the delegation case.
#' @return An object of class `qpm_var`, or the result of [stats::var()].
#' @examples
#' vars(y_gap = var("Output gap", unit = "pp"))
#' var(rnorm(10))  # still the sample variance
#' @export
var <- function(label = "", unit = "", ...) {
  if (!is.character(label))
    return(stats::var(label, ...))
  stopifnot(length(label) == 1L, is.character(unit), length(unit) == 1L)
  structure(list(label = label, unit = unit), class = "qpm_var")
}

#' Declare the endogenous variables of a model
#'
#' @param ... Named arguments, one per variable. Each value is a [var()]
#'   declaration or a character label. Unnamed character arguments are
#'   taken as variable names with empty labels.
#' @return A data frame with columns `name`, `label`, `unit`.
#' @examples
#' vars(
#'   y_gap = var("Output gap", unit = "pp"),
#'   pi    = "CPI inflation, QoQ annualised"
#' )
#' @export
vars <- function(...) {
  x <- list(...)
  if (length(x) == 0L) stop("vars(): declare at least one variable", call. = FALSE)
  nm <- names(x) %||% rep("", length(x))
  rows <- vector("list", length(x))
  for (i in seq_along(x)) {
    v <- x[[i]]
    if (nm[i] == "") {
      if (!is.character(v) || length(v) != 1L)
        stop("vars(): unnamed arguments must be single variable names", call. = FALSE)
      rows[[i]] <- data.frame(name = v, label = "", unit = "", stringsAsFactors = FALSE)
    } else if (inherits(v, "qpm_var")) {
      rows[[i]] <- data.frame(name = nm[i], label = v$label, unit = v$unit,
                              stringsAsFactors = FALSE)
    } else if (is.character(v) && length(v) == 1L) {
      rows[[i]] <- data.frame(name = nm[i], label = v, unit = "",
                              stringsAsFactors = FALSE)
    } else {
      stop(sprintf("vars(): argument '%s' must be var() or a character label", nm[i]),
           call. = FALSE)
    }
  }
  out <- do.call(rbind, rows)
  validate_names(out$name, "variable")
  out
}

#' Declare the structural shocks of a model
#'
#' Accepts bare names or character strings.
#'
#' @param ... Shock names, e.g. `shocks(eps_y, eps_pi)`.
#' @return A character vector of shock names.
#' @examples
#' shocks(eps_y, eps_pi, eps_i)
#' @export
shocks <- function(...) {
  args <- as.list(substitute(list(...)))[-1L]
  out <- vapply(args, function(s) {
    if (is.symbol(s)) return(as.character(s))
    if (is.character(s) && length(s) == 1L) return(s)
    stop("shocks(): arguments must be bare names or strings", call. = FALSE)
  }, character(1))
  validate_names(out, "shock")
  out
}

#' Declare model equations
#'
#' Each equation is a two-sided formula. Lags and leads use index
#' notation: `x[-1]` is the first lag, `x[+1]` the first lead. Wrap
#' expectations in `E()`: `E(pi[+1])` is the model-consistent expectation
#' of next quarter's inflation. Longer lags and leads (e.g. `E(pi4[+4])`)
#' are handled automatically via auxiliary state variables.
#'
#' @param ... Two-sided formulas.
#' @return A list of formulas.
#' @examples
#' eqs(
#'   pi ~ b1 * pi[-1] + (1 - b1) * E(pi[+1]) + b2 * y_gap + eps_pi
#' )
#' @export
eqs <- function(...) {
  out <- list(...)
  ok <- vapply(out, function(f) inherits(f, "formula") && length(f) == 3L, TRUE)
  if (!all(ok))
    stop("eqs(): every equation must be a two-sided formula (lhs ~ rhs)", call. = FALSE)
  out
}

#' Expectations operator (equation syntax only)
#'
#' `E()` marks model-consistent expectations inside [eqs()] declarations,
#' e.g. `E(pi[+1])`. It is parsed by [qpm_model()] and never evaluated as
#' an ordinary function.
#'
#' @param x A variable reference such as `pi[+1]`.
#' @return No return value; calling `E()` outside of model equations is
#'   an error by design.
#' @export
E <- function(x) {
  stop("E() is only meaningful inside qpm model equations declared with eqs()",
       call. = FALSE)
}

# -- internal ----------------------------------------------------------------

validate_names <- function(nms, what) {
  if (anyDuplicated(nms))
    stop(sprintf("duplicated %s names: %s", what,
                 paste(unique(nms[duplicated(nms)]), collapse = ", ")), call. = FALSE)
  bad <- nms[nms != make.names(nms)]
  if (length(bad))
    stop(sprintf("invalid %s names (must be valid R identifiers): %s",
                 what, paste(bad, collapse = ", ")), call. = FALSE)
  aux <- grepl("\\.(L|F)[0-9]+$", nms)
  if (any(aux))
    stop(sprintf("%s names ending in .L<k>/.F<k> are reserved for auxiliary states: %s",
                 what, paste(nms[aux], collapse = ", ")), call. = FALSE)
  invisible(nms)
}
