# Declare priors for Bayesian estimation

One named argument per estimated quantity: a structural parameter name
or a shock name (meaning that shock's standard deviation). Everything
without a prior stays calibrated.

## Usage

``` r
priors(...)
```

## Arguments

- ...:

  Named prior declarations, e.g.
  `b1 = beta(0.7, 0.1), c2 = truncate(normal(1.5, 0.25), lower = 1)`.

## Value

An object of class `qpm_priors`.

## Details

Available distributions (usable only inside `priors()`, so base R's
[`beta()`](https://rdrr.io/r/base/Special.html) and
[`gamma()`](https://rdrr.io/r/base/Special.html) functions are never
masked):

- `normal(mean, sd)`

- `beta(mean, sd)` — on (0, 1), mean/sd parametrization

- `gamma(mean, sd)` — on (0, Inf)

- `invgamma(mean, sd)` — on (0, Inf); the usual choice for shock sds

- `uniform(min, max)`

- `truncate(d, lower, upper)` — restrict any of the above; the
  normalizing constant is dropped (harmless for modes and MCMC)

## Examples

``` r
p <- priors(
  b1 = beta(0.7, 0.1),
  b2 = gamma(0.25, 0.1),
  c2 = truncate(normal(1.5, 0.25), lower = 1),
  eps_pi = invgamma(1, 0.3)
)
p
#> <qpm_priors> 4 priors
#>   b1         beta(mean  0.7, sd  0.1) on (0,    1)
#>   b2         gamma(mean 0.25, sd  0.1) on (0,  Inf)
#>   c2         trunc-normal(mean  1.5, sd 0.25) on (   1,  Inf)
#>   eps_pi     invgamma(mean    1, sd  0.3) on (0,  Inf)
```
