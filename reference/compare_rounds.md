# Compare two forecast rounds: the revision decomposition

Decomposes the forecast revision between two rounds – "inflation for
2027-Q1 is 0.4pp higher than we said in June: why?" – into the
contributions of new data (outturns), data revisions, calibration
changes, changed conditions, and judgment, by re-running the full
pipeline swapping one ingredient at a time. The contributions telescope,
so they sum to the total revision exactly; the final step is verified
against the new round's archived forecast.

## Usage

``` r
compare_rounds(old, new, variables = NULL, store = "rounds")

# S3 method for class 'qpm_revision'
plot(x, variable = NULL, ...)
```

## Arguments

- old, new:

  `qpm_round` objects (or names to
  [`load_round()`](https://mustapha-wasseja.github.io/qpmR/reference/save_round.md)
  from `store`).

- variables:

  Variables to decompose (default: all).

- store:

  Round store used when `old`/`new` are names.

- x:

  A `qpm_revision`.

- variable:

  Variable to plot.

- ...:

  Unused.

## Value

An object of class `qpm_revision`: a data frame with one row per
variable and overlap period, columns `old`, `new`, `total`, and the five
contributions. Print shows waterfall tables;
[`plot()`](https://rdrr.io/r/graphics/plot.default.html) draws stacked
contribution bars across the overlap.

## Details

Requirements: both rounds must use the same model structure and the same
observables, and their data must carry `"YYYY-Qq"` period labels so the
calendars align. Comparison covers the calendar quarters both rounds
forecast.

## Examples

``` r
m <- qpm_template("bkl")
obs <- simulate(qpm_solve(m), nsim = 44, seed = 1, burn = 20)
obs$period <- next_quarters("2015-Q4", 44)
rA <- qpm_round("June", m, obs[1:40, c("period", "pi", "i", "q")], horizon = 8)
rB <- qpm_round("September", m, obs[, c("period", "pi", "i", "q")], horizon = 8)
rB <- add_judgment(rB, pi = stats::setNames(0.3, rB$forecast$periods[2]),
                   author = "desk", rationale = "tariff")
rev <- compare_rounds(rA, rB)
rev
#> <qpm_revision> June -> September
#>   pi4 at 2027-Q1: 4.41 -> 6.47  (+2.06)
#>      +0.00  parameters
#>      +0.00  data revisions
#>      +2.02  new data (outturns)
#>      +0.00  conditions
#>      +0.04  judgment
#>   pi at 2027-Q1: 3.78 -> 6.23  (+2.45)
#>      +0.00  parameters
#>      +0.00  data revisions
#>      +2.31  new data (outturns)
#>      +0.00  conditions
#>      +0.15  judgment
#>   i at 2027-Q1: 8.18 -> 10.95  (+2.77)
#>      +0.00  parameters
#>      +0.00  data revisions
#>      +2.72  new data (outturns)
#>      +0.00  conditions
#>      +0.05  judgment
#>   (+ 3 more periods; print(x, variables=, periods=) or plot(x, variable=))
```
