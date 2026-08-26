#' Define a quarterly projection model
#'
#' Declares a linear semi-structural model with model-consistent
#' expectations. Equations are parsed immediately, so unknown symbols and
#' malformed lag/lead references are caught at construction time.
#' Coefficients are extracted from the current calibration when the model
#' is solved with [qpm_solve()].
#'
#' @param name Model name used in printed output.
#' @param variables Variable declarations from [vars()].
#' @param shocks Shock declarations from [shocks()].
#' @param equations Equations from [eqs()]; one per variable.
#' @param params Named list/vector of parameter values.
#' @param sigma Named vector of shock standard deviations. Defaults to 1
#'   for every shock.
#' @param meta Optional list of metadata (e.g. plausible parameter
#'   `ranges` used by [qpm_lint()]).
#' @return An object of class `qpm_model`.
#' @examples
#' m <- qpm_model(
#'   name      = "AR(1) toy",
#'   variables = vars(x = "A persistent process"),
#'   shocks    = shocks(eps_x),
#'   equations = eqs(x ~ rho * x[-1] + eps_x),
#'   params    = list(rho = 0.8)
#' )
#' m
#' @export
qpm_model <- function(name = "QPM model", variables, shocks, equations,
                      params = list(), sigma = NULL, meta = list()) {
  if (is.character(variables)) variables <- do.call(vars, as.list(variables))
  stopifnot(is.data.frame(variables), all(c("name", "label", "unit") %in% names(variables)))
  if (!is.character(shocks)) stop("shocks must come from shocks()", call. = FALSE)
  if (!is.list(equations)) stop("equations must come from eqs()", call. = FALSE)

  params <- unlist(params)
  if (length(params) && (is.null(names(params)) || any(names(params) == "")))
    stop("all parameters must be named", call. = FALSE)
  if (length(params)) validate_names(names(params), "parameter")

  varnames <- variables$name
  all_names <- c(varnames, shocks, names(params))
  if (anyDuplicated(all_names))
    stop(sprintf("names used more than once across variables/shocks/parameters: %s",
                 paste(unique(all_names[duplicated(all_names)]), collapse = ", ")),
         call. = FALSE)

  if (length(equations) != length(varnames))
    stop(sprintf("model has %d equations but %d variables; these must match",
                 length(equations), length(varnames)), call. = FALSE)

  # formulas are kept for display only; drop their environments so that
  # serialized models (forecast rounds) stay small and self-contained
  equations <- lapply(equations, function(f) { environment(f) <- baseenv(); f })

  labels <- vapply(seq_along(equations), function(i)
    sprintf("%d (%s)", i, deparse1(equations[[i]][[2L]])), character(1))
  parsed <- Map(parse_qpm_equation, equations, eq_label = labels,
                MoreArgs = list(varnames = varnames, shknames = shocks,
                                parnames = names(params)))

  used_vars <- unique(unlist(lapply(parsed, function(p) p$vars$var)))
  missing_vars <- setdiff(varnames, used_vars)
  if (length(missing_vars))
    stop(sprintf("variable(s) never appear in any equation: %s",
                 paste(missing_vars, collapse = ", ")), call. = FALSE)

  if (is.null(sigma)) sigma <- stats::setNames(rep(1, length(shocks)), shocks)
  sigma <- check_sigma(sigma, shocks)

  out <- structure(list(name = name, vars = variables, shocks = shocks,
                        params = params, sigma = sigma,
                        equations = equations, parsed = parsed, meta = meta),
                   class = "qpm_model")

  # Linearity is a property of the equations, so check it once here rather
  # than on every solve; the same call surfaces unknown symbols early.
  parenv <- list2env(as.list(params), parent = baseenv())
  invisible(lapply(parsed, eq_coefficients, params = params, parenv = parenv))

  # Cache the parameter-independent structure of the first-order system.
  # qpm_calibrate() and estimation change only values, so this stays valid.
  out$structure <- build_structure(out)
  out
}

#' Update a model's calibration
#'
#' @param model A `qpm_model`.
#' @param ... Named parameter values to update. Every name must already
#'   exist in the model (typo protection).
#' @param sigma Optional named vector of shock standard deviations to
#'   update.
#' @return The updated `qpm_model`.
#' @examples
#' m <- qpm_template("bkl")
#' m <- qpm_calibrate(m, b2 = 0.3, c2 = 2)
#' @export
qpm_calibrate <- function(model, ..., sigma = NULL) {
  stopifnot(inherits(model, "qpm_model"))
  upd <- unlist(list(...))
  if (length(upd)) {
    if (is.null(names(upd)) || any(names(upd) == ""))
      stop("qpm_calibrate(): all parameter updates must be named", call. = FALSE)
    unknown <- setdiff(names(upd), names(model$params))
    if (length(unknown))
      stop(sprintf("unknown parameter(s): %s\n  declared parameters: %s",
                   paste(unknown, collapse = ", "),
                   paste(names(model$params), collapse = ", ")), call. = FALSE)
    model$params[names(upd)] <- upd
  }
  if (!is.null(sigma)) {
    unknown <- setdiff(names(sigma), model$shocks)
    if (length(unknown))
      stop(sprintf("sigma names are not declared shocks: %s",
                   paste(unknown, collapse = ", ")), call. = FALSE)
    model$sigma[names(sigma)] <- sigma
  }
  model
}

check_sigma <- function(sigma, shocks) {
  if (is.null(names(sigma)) || any(names(sigma) == ""))
    stop("sigma must be a named vector (one name per shock)", call. = FALSE)
  unknown <- setdiff(names(sigma), shocks)
  if (length(unknown))
    stop(sprintf("sigma names are not declared shocks: %s",
                 paste(unknown, collapse = ", ")), call. = FALSE)
  out <- stats::setNames(rep(1, length(shocks)), shocks)
  out[names(sigma)] <- sigma
  if (any(out < 0)) stop("shock standard deviations must be >= 0", call. = FALSE)
  out
}

model_shift_range <- function(model) {
  shifts <- unlist(lapply(model$parsed, function(p) p$vars$shift))
  c(min(c(shifts, 0L)), max(c(shifts, 0L)))
}

#' @export
print.qpm_model <- function(x, ...) {
  rng <- model_shift_range(x)
  cat(sprintf("<qpm_model> %s\n", x$name))
  cat(sprintf("  %d endogenous variables - %d shocks - %d parameters\n",
              nrow(x$vars), length(x$shocks), length(x$params)))
  cat(sprintf("  dynamics: max lag %d, max lead %d%s\n", -rng[1], rng[2],
              if (rng[1] < -1 || rng[2] > 1)
                " (auxiliary states added automatically at solve time)" else ""))
  if (length(x$params)) {
    ps <- paste(names(x$params), "=", fmt_num(x$params), collapse = ", ")
    cat("  calibration:\n")
    cat(strwrap(ps, width = 76, indent = 4, exdent = 4), sep = "\n")
  }
  cat("  variables: ", paste(utils::head(x$vars$name, 8), collapse = ", "),
      if (nrow(x$vars) > 8) ", ... (see summary())" else "", "\n", sep = "")
  invisible(x)
}

#' @export
summary.qpm_model <- function(object, ...) {
  print(object)
  cat("\nVariables:\n")
  v <- object$vars
  v$label <- ifelse(v$label == "", "-", v$label)
  v$unit <- ifelse(v$unit == "", "-", v$unit)
  print(v, row.names = FALSE, right = FALSE)
  cat("\nEquations:\n")
  for (i in seq_along(object$equations))
    cat(sprintf("  %2d. %s\n", i, deparse1(object$equations[[i]])))
  cat("\nShock standard deviations:\n")
  s <- object$sigma
  cat(strwrap(paste(names(s), "=", fmt_num(s), collapse = ", "),
              width = 76, indent = 2, exdent = 2), sep = "\n")
  invisible(object)
}
