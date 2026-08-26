# Log-likelihood of a filtration or an estimate

For a `qpm_filtration` this is the Kalman-filter log-likelihood of the
data under the calibrated model, with zero degrees of freedom (nothing
was estimated). For a `qpm_estimate` it is the log-likelihood at the
posterior mode (or at the maximum for `method = "mle"`), with degrees of
freedom equal to the number of estimated parameters — so
[`stats::AIC()`](https://rdrr.io/r/stats/AIC.html) and
[`stats::BIC()`](https://rdrr.io/r/stats/AIC.html) work.

## Usage

``` r
# S3 method for class 'qpm_filtration'
logLik(object, ...)

# S3 method for class 'qpm_estimate'
logLik(object, ...)
```

## Arguments

- object:

  A `qpm_filtration` or `qpm_estimate`.

- ...:

  Unused.

## Value

An object of class `logLik`.

## Examples

``` r
sol <- qpm_solve(qpm_template("bkl"))
obs <- simulate(sol, nsim = 40, seed = 1, burn = 20)
fit <- qpm_filter(sol, obs[, c("period", "pi", "i", "q")])
logLik(fit)
#> 'log Lik.' -195.152 (df=0)
```
