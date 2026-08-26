# Shock-based alternative scenarios

Adds a specified path of structural shocks to a forecast – "what if oil
pushes the exchange rate 10 percent weaker next quarter?" – without any
inversion. Under `anticipated = TRUE` the shock path is announced at the
start of the forecast and expectations react ahead of it.

## Usage

``` r
qpm_scenario(fc, shocks, anticipated = FALSE, label = NULL)
```

## Arguments

- fc:

  A `qpm_forecast`.

- shocks:

  Named list: one entry per shock, each a named vector of shock sizes
  (raw equation units) by period, e.g. `list(eps_q = c(h1 = 1.5))`.

- anticipated:

  Announced at start (`TRUE`) or surprises (`FALSE`).

- label:

  Optional scenario label for printing.

## Value

The shifted `qpm_forecast` (bands unchanged: a deterministic scenario
shifts the mean, not the uncertainty).

## Examples

``` r
sol <- qpm_solve(qpm_template("bkl"))
fc <- qpm_forecast(sol, horizon = 8)
dep <- qpm_scenario(fc, shocks = list(eps_q = c(h1 = 3)),
                    label = "10pct depreciation")
```
