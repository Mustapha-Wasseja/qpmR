# Summarise an estimate

Returns the posterior summary as a data frame — prior, mode, mean,
standard deviation, credible interval, R-hat and effective sample size —
so it can be used programmatically rather than only read.

## Usage

``` r
# S3 method for class 'qpm_estimate'
summary(object, level = 0.9, ...)
```

## Arguments

- object:

  A `qpm_estimate`.

- level:

  Credible level for the interval.

- ...:

  Unused.

## Value

A data frame, one row per estimated parameter.

## Examples

``` r
# \donttest{
m <- qpm_model(variables = vars(x = "x"), shocks = shocks(e),
               equations = eqs(x ~ rho * x[-1] + e),
               params = list(rho = 0.5))
obs <- simulate(qpm_solve(qpm_calibrate(m, rho = 0.8)), nsim = 120, seed = 1)
est <- qpm_estimate(m, obs, priors(rho = beta(0.5, 0.2)),
                    iter = 600, chains = 2, seed = 2, verbose = FALSE)
summary(est)
#>   parameter          prior      mode      mean         sd     lower     upper
#> 1       rho beta(0.5, 0.2) 0.7335069 0.7333054 0.05864336 0.6364812 0.8354914
#>       rhat      ess
#> 1 1.019201 165.9419
# }
```
