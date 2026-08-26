#' qpmR: Quarterly Projection Models for Monetary Policy Analysis
#'
#' Build, solve, and simulate the semi-structural quarterly projection
#' models (QPM) used in central-bank Forecasting and Policy Analysis
#' Systems (FPAS). Start with [qpm_template()] for the canonical
#' Berg-Karam-Laxton small open economy model, or declare your own model
#' with [qpm_model()]. Solve with [qpm_solve()], inspect dynamics with
#' [irf()], simulate with [stats::simulate()], and produce forecasts with
#' fan bands via [qpm_forecast()].
#'
#' @keywords internal
#' @useDynLib qpmR, .registration = TRUE
#' @importFrom Rcpp sourceCpp
"_PACKAGE"

# Canonical symbol separator used internally by the equation parser.
# "@" cannot appear in an R identifier, so rewritten symbols can never
# collide with user-declared names.
CANON_SEP <- "@"

`%||%` <- function(x, y) if (is.null(x)) y else x

fmt_num <- function(x, digits = 3) formatC(x, digits = digits, format = "fg")

# Bare shock names used non-standardly inside shocks() in shipped templates.
utils::globalVariables(c("eps_y", "eps_pi", "eps_i", "eps_q", "eps_qbar",
                         "eps_rbar", "eps_g", "eps_dy", "eps_ystar",
                         "eps_istar", "eps_pistar", "eps_prem",
                         "eps_pifood", "eps_fx", "eps_x", "e"))
