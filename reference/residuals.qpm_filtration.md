# One-step-ahead prediction errors and fitted values

[`residuals()`](https://rdrr.io/r/stats/residuals.html) returns the
filter's one-step-ahead prediction errors for the observed series
(`type = "innovation"`), the same divided by their standard deviations
(`"standardized"`, which is what the outlier flags use), or the smoothed
structural shocks (`"shock"`).
[`fitted()`](https://rdrr.io/r/stats/fitted.values.html) returns the
one-step-ahead predictions of the observables, so that
`observed = fitted + innovation`.

## Usage

``` r
# S3 method for class 'qpm_filtration'
residuals(object, type = c("innovation", "standardized", "shock"), ...)

# S3 method for class 'qpm_filtration'
fitted(object, ...)
```

## Arguments

- object:

  A `qpm_filtration`.

- type:

  Which residuals to return.

- ...:

  Unused.

## Value

A data frame with a `period` column and one column per series.

## Examples

``` r
sol <- qpm_solve(qpm_template("bkl"))
obs <- simulate(sol, nsim = 40, seed = 1, burn = 20)
fit <- qpm_filter(sol, obs[, c("period", "pi", "i", "q")])
head(residuals(fit, "standardized"))
#>   period         pi          i           q
#> 1      1 -0.2623455 -1.1169182  0.05802988
#> 2      2  0.5047356  1.6872857  0.60812441
#> 3      3  1.4771568  0.1429061  0.58580718
#> 4      4 -1.8937494 -2.1347610 -0.73077504
#> 5      5 -0.3236902 -1.6057420 -2.69342460
#> 6      6  1.1445926  0.9991086  2.25398381
head(fitted(fit))
#>   period       pi         i             q
#> 1      1 5.000000  9.000000 -2.942091e-14
#> 2      2 4.936529  7.080871  1.099241e-01
#> 3      3 6.556487  9.444801 -1.965672e-01
#> 4      4 8.996486 10.969614 -1.467530e+00
#> 5      5 5.470894  9.368298 -2.717956e+00
#> 6      6 3.516976  7.520989 -4.902630e+00
```
