# Posterior covariance and credible intervals

Posterior covariance and credible intervals

## Usage

``` r
# S3 method for class 'qpm_estimate'
vcov(object, ...)

# S3 method for class 'qpm_estimate'
confint(object, parm = NULL, level = 0.9, ...)
```

## Arguments

- object:

  A `qpm_estimate`.

- ...:

  Unused.

- parm:

  Parameters to report; default all.

- level:

  Credible level.

## Value

[`vcov()`](https://rdrr.io/r/stats/vcov.html) returns the posterior
covariance matrix of the estimated parameters;
[`confint()`](https://rdrr.io/r/stats/confint.html) returns equal-tailed
posterior credible intervals (posterior quantiles, not asymptotic
intervals).

## Examples

``` r
# \donttest{
m <- qpm_model(variables = vars(x = "x"), shocks = shocks(e),
               equations = eqs(x ~ rho * x[-1] + e),
               params = list(rho = 0.5))
obs <- simulate(qpm_solve(qpm_calibrate(m, rho = 0.8)), nsim = 120, seed = 1)
est <- qpm_estimate(m, obs, priors(rho = beta(0.5, 0.2)),
                    iter = 600, chains = 2, seed = 2, verbose = FALSE)
vcov(est)
#>             rho
#> rho 0.003439043
confint(est)
#>          5.0%     95.0%
#> rho 0.6364812 0.8354914
# }
```
