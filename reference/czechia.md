# Czech quarterly macroeconomic dataset

Quarterly data for Czechia, 1996Q1 onward, in the units and sign
conventions of the
[`qpm_template()`](https://mustapha-wasseja.github.io/qpmR/reference/qpm_template.md)
model, ready for
[`qpm_filter()`](https://mustapha-wasseja.github.io/qpmR/reference/qpm_filter.md).
Czechia is the canonical FPAS economy: a small open inflation targeter
(since 1998) with three decades of clean data, a large disinflation, a
currency-crisis start, the GFC, a floor episode, COVID, and the 2022
inflation wave.

## Usage

``` r
czechia
```

## Format

A data frame with one row per quarter and columns:

- period:

  Quarter label, `"1996-Q1"` style.

- pi:

  CPI inflation, QoQ annualised percent, seasonally adjusted with
  [`stats::stl()`](https://rdrr.io/r/stats/stl.html) on the quarterly
  log index.

- pi4:

  CPI inflation, year on year percent (no adjustment needed).

- i:

  3-month PRIBOR, percent p.a., quarterly average – a proxy for the CNB
  policy rate.

- q:

  Real CZK/EUR exchange rate, 100 times log, CPI-based, normalized so
  the 2015 average is zero; an increase is a real depreciation of the
  koruna.

- dy_obs:

  Real GDP growth, QoQ annualised percent, from seasonally and calendar
  adjusted chain-linked volumes.

- istar:

  3-month EURIBOR, percent p.a., quarterly average.

- pistar:

  Euro-area HICP inflation, year on year percent.

## Source

Compiled by `data-raw/czechia.R` from FRED series `CLVMNACSCAB1GQCZ`
(Eurostat national accounts), `CZECPIALLMINMEI`, `IR3TIB01CZM156N`,
`IR3TIB01EZM156N` (OECD Main Economic Indicators), `CP0000EZ19M086NEST`
(Eurostat HICP), and the ECB reference exchange rate
`EXR/Q.CZK.EUR.SP00.A`. Retrieved 2026-08-22.

## Details

Missing values are genuine ragged edges (e.g. the euro exists only from
1999, so `q`, `istar` start later);
[`qpm_filter()`](https://mustapha-wasseja.github.io/qpmR/reference/qpm_filter.md)
handles them. Observe `pi4` *or* `pi`, not both – they are linked by an
identity and the filter will report the collinearity.

## Examples

``` r
head(czechia)
#>    period     pi    pi4       i  q  dy_obs  istar pistar
#> 1 1996-Q1     NA     NA 10.8606 NA      NA 5.6300     NA
#> 2 1996-Q2 6.6142     NA 11.8249 NA  2.9106 5.1367     NA
#> 3 1996-Q3 8.6118     NA 12.6919 NA  1.4749 5.0000     NA
#> 4 1996-Q4 7.1523     NA 12.6862 NA  0.6456 4.5867     NA
#> 5 1997-Q1 5.2831 6.9153 12.3835 NA -1.7792 4.4400     NA
#> 6 1997-Q2 5.5224 6.6424 19.6704 NA -1.6144 4.3267     NA
m <- qpm_calibrate(qpm_template("bkl", trends = "rw"),
                   pi_tar = 2, istar_ss = 2, pistar_ss = 2, prem_ss = 1)
cz <- czechia[czechia$period >= "1999",
              c("period", "pi4", "i", "q", "dy_obs", "istar", "pistar")]
fit <- qpm_filter(m, cz)
fit
#> <qpm_filtration> Canonical small open economy QPM (BKL, rw trends)
#>   periods 1999-Q1-2026-Q2 (110) - observables: pi4, i, q, dy_obs, istar, pistar - missing: 12 of 660
#>   log-likelihood: -1982.51 (approximate diffuse init, 2 unit roots)
#>   innovation diagnostics: Ljung-Box min p = 0.00 (q) - autocorrelated innovations, check specification
#>   outliers (|std innov| > 3): 49; largest: period 2023-Q1 pi4 (+17.0 sd)
#>   latent states estimated: y_gap, pi, r, r_gap, q_gap, q_bar, r_bar, dy_bar, ...
```
