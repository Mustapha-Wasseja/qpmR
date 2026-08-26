# Forecast rounds: one replayable artifact per forecast

A forecast round binds everything that produced a forecast – the model
and its calibration, the data vintage, the filtration, the forecast with
its conditions and judgment – into one object that can be saved,
reloaded, re-run, and compared with later rounds via
[`compare_rounds()`](https://mustapha-wasseja.github.io/qpmR/reference/compare_rounds.md).
This is the object an institution archives: next quarter, "why did the
forecast move?" is answered from the rounds, not from memory.

## Usage

``` r
qpm_round(
  name,
  model,
  data,
  observables = NULL,
  horizon = 12,
  bands = c(0.5, 0.7, 0.9),
  measurement_error = 0,
  kappa = 1e+06
)
```

## Arguments

- name:

  Round name, e.g. `"2026-Q3 September"`.

- model:

  A `qpm_model`.

- data:

  Data frame in levels with a `period` column; passed to
  [`qpm_filter()`](https://mustapha-wasseja.github.io/qpmR/reference/qpm_filter.md).
  Quarter labels (`"2026-Q3"` style) are required for cross-round
  comparison.

- observables:

  Columns treated as observed (default: all columns matching declared
  variables).

- horizon:

  Forecast horizon in quarters.

- bands:

  Fan coverage levels.

- measurement_error, kappa:

  Passed to
  [`qpm_filter()`](https://mustapha-wasseja.github.io/qpmR/reference/qpm_filter.md).

## Value

An object of class `qpm_round` with elements `model`, `data`,
`solution`, `fit`, and `forecast`.

## Details

`qpm_round()` runs the standard pipeline (solve, filter, baseline
forecast). Conditions, scenarios, and judgment are then applied to the
round directly:
[`qpm_condition()`](https://mustapha-wasseja.github.io/qpmR/reference/qpm_condition.md),
[`qpm_scenario()`](https://mustapha-wasseja.github.io/qpmR/reference/qpm_scenario.md),
and
[`add_judgment()`](https://mustapha-wasseja.github.io/qpmR/reference/add_judgment.md)
all accept a round and update its forecast.

## Examples

``` r
m <- qpm_template("bkl")
sol <- qpm_solve(m)
obs <- simulate(sol, nsim = 40, seed = 1, burn = 20)
obs$period <- next_quarters("2016-Q1", 40)
r <- qpm_round("test round", m, obs[, c("period", "pi", "i", "q")],
               horizon = 8)
r
#> <qpm_round> test round
#>   created 2026-08-26 20:51 - qpmR 1.0.0.9000
#>   model: Canonical small open economy QPM (BKL, stationary trends) - 25 parameters
#>   data: 2016-Q2 ... 2026-Q1 (40 quarters) - observables: pi, i, q
#>   filter: log-likelihood -195.15
#>   forecast: 8 quarters (2026-Q2 ... 2028-Q1) - 0 conditions, 0 judgment entries
```
