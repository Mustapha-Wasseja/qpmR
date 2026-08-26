# Number of observations

Number of observations

## Usage

``` r
# S3 method for class 'qpm_filtration'
nobs(object, ...)

# S3 method for class 'qpm_estimate'
nobs(object, ...)
```

## Arguments

- object:

  A `qpm_filtration` or `qpm_estimate`.

- ...:

  Unused.

## Value

Number of time periods used.

## Examples

``` r
sol <- qpm_solve(qpm_template("bkl"))
obs <- simulate(sol, nsim = 40, seed = 1, burn = 20)
nobs(qpm_filter(sol, obs[, c("period", "pi", "i")]))
#> [1] 40
```
