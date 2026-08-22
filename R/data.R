#' Czech quarterly macroeconomic dataset
#'
#' Quarterly data for Czechia, 1996Q1 onward, in the units and sign
#' conventions of the [qpm_template()] model, ready for
#' [qpm_filter()]. Czechia is the canonical FPAS economy: a small open
#' inflation targeter (since 1998) with three decades of clean data, a
#' large disinflation, a currency-crisis start, the GFC, a floor episode,
#' COVID, and the 2022 inflation wave.
#'
#' Missing values are genuine ragged edges (e.g. the euro exists only
#' from 1999, so `q`, `istar` start later); [qpm_filter()] handles them.
#' Observe `pi4` *or* `pi`, not both -- they are linked by an identity
#' and the filter will report the collinearity.
#'
#' @format A data frame with one row per quarter and columns:
#' \describe{
#'   \item{period}{Quarter label, `"1996-Q1"` style.}
#'   \item{pi}{CPI inflation, QoQ annualised percent, seasonally adjusted
#'     with [stats::stl()] on the quarterly log index.}
#'   \item{pi4}{CPI inflation, year on year percent (no adjustment
#'     needed).}
#'   \item{i}{3-month PRIBOR, percent p.a., quarterly average -- a proxy
#'     for the CNB policy rate.}
#'   \item{q}{Real CZK/EUR exchange rate, 100 times log, CPI-based,
#'     normalized so the 2015 average is zero; an increase is a real
#'     depreciation of the koruna.}
#'   \item{dy_obs}{Real GDP growth, QoQ annualised percent, from
#'     seasonally and calendar adjusted chain-linked volumes.}
#'   \item{istar}{3-month EURIBOR, percent p.a., quarterly average.}
#'   \item{pistar}{Euro-area HICP inflation, year on year percent.}
#' }
#' @source Compiled by `data-raw/czechia.R` from FRED series
#'   `CLVMNACSCAB1GQCZ` (Eurostat national accounts), `CZECPIALLMINMEI`,
#'   `IR3TIB01CZM156N`, `IR3TIB01EZM156N` (OECD Main Economic
#'   Indicators), `CP0000EZ19M086NEST` (Eurostat HICP), and the ECB
#'   reference exchange rate `EXR/Q.CZK.EUR.SP00.A`. Retrieved 2026-08-22.
#' @examples
#' head(czechia)
#' m <- qpm_calibrate(qpm_template("bkl", trends = "rw"),
#'                    pi_tar = 2, istar_ss = 2, pistar_ss = 2, prem_ss = 1)
#' cz <- czechia[czechia$period >= "1999",
#'               c("period", "pi4", "i", "q", "dy_obs", "istar", "pistar")]
#' fit <- qpm_filter(m, cz)
#' fit
"czechia"
