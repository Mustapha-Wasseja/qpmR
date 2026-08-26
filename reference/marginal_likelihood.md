# Marginal likelihood of an estimated model

Computes the log marginal likelihood \\\log p(y)\\ of a Bayesian
estimate – the quantity whose differences across models on the same data
are log Bayes factors. Two estimators are reported:

## Usage

``` r
marginal_likelihood(est, taus = seq(0.1, 0.9, by = 0.2))
```

## Arguments

- est:

  A `qpm_estimate` with `method = "bayes"`.

- taus:

  Truncation probabilities for the modified harmonic mean.

## Value

An object of class `qpm_logml`: `$logml` (harmonic-mean estimate,
averaged over `taus`), `$by_tau`, `$laplace`, and the spread across
truncations.

## Details

- **Modified harmonic mean** (Geweke 1999) from the posterior draws,
  computed for a range of truncation probabilities; a small spread
  across truncations indicates a reliable estimate.

- **Laplace approximation** at the posterior mode in transformed space
  (parametrization-invariant because the Jacobian is included), with a
  numerically differenced Hessian.

Truncated priors created with
[`truncate()`](https://rdrr.io/r/base/seek.html) are renormalized
numerically at construction, so they contribute proper densities here.

## References

Geweke, J. (1999). Using simulation methods for Bayesian econometric
models. Econometric Reviews, 18(1), 1-73.

## Examples

``` r
# \donttest{
m <- qpm_model(variables = vars(x = "x"), shocks = shocks(e),
               equations = eqs(x ~ rho * x[-1] + e),
               params = list(rho = 0.5))
obs <- simulate(qpm_solve(qpm_calibrate(m, rho = 0.8)), nsim = 150, seed = 1)
est <- qpm_estimate(m, obs, priors(rho = beta(0.5, 0.2)),
                    iter = 1000, chains = 2, seed = 2, verbose = FALSE)
marginal_likelihood(est)
#> <qpm_logml> log marginal likelihood: -201.22
#>   modified harmonic mean over 1000 draws, 1 parameters
#>   by truncation: -201.11, -201.27, -201.26, -201.23, -201.25 (spread 0.16)
#>   Laplace approximation: -201.31
#>   differences across models on the same data are log Bayes factors
# }
```
