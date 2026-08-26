# Estimate model parameters (Bayesian or maximum likelihood)

Estimates any subset of structural parameters and shock standard
deviations from data, using the Kalman-filter likelihood of the solved
model. `method = "bayes"` finds the posterior mode (in transformed,
unconstrained space), seeds an adaptive random-walk Metropolis sampler
with the inverse Hessian, and returns posterior draws with split R-hat
and effective-sample-size diagnostics. `method = "mle"` uses the same
machinery with flat priors on the declared supports.

## Usage

``` r
qpm_estimate(
  model,
  data,
  priors,
  observables = NULL,
  measurement_error = 0,
  kappa = 1e+06,
  method = c("bayes", "mle"),
  iter = 4000,
  burn = floor(iter/2),
  chains = 2,
  thin = 1,
  seed = NULL,
  verbose = TRUE
)

# S3 method for class 'qpm_estimate'
coef(object, type = c("mean", "mode", "median"), ...)
```

## Arguments

- model:

  A `qpm_model`.

- data:

  Data frame in levels (as for
  [`qpm_filter()`](https://mustapha-wasseja.github.io/qpmR/reference/qpm_filter.md)).

- priors:

  A
  [`priors()`](https://mustapha-wasseja.github.io/qpmR/reference/priors.md)
  declaration. Names are structural parameters or shock names (meaning
  that shock's sd). Required for `method = "bayes"`; for `"mle"` it
  supplies supports (and is otherwise ignored).

- observables, measurement_error, kappa:

  Passed to the filter.

- method:

  `"bayes"` (default) or `"mle"`.

- iter:

  MCMC iterations per chain (including burn-in).

- burn:

  Burn-in iterations (default `iter/2`).

- chains:

  Number of chains (run sequentially).

- thin:

  Keep every `thin`-th post-burn draw.

- seed:

  Optional RNG seed.

- verbose:

  Print progress.

- object:

  A `qpm_estimate`.

- type:

  Point estimate: posterior `"mean"`, `"mode"`, or `"median"`.

- ...:

  Unused.

## Value

An object of class `qpm_estimate`: posterior `draws` (natural units),
the `mode`, acceptance rate, split R-hat and effective sample sizes, and
the originating model/data. Use
[`coef()`](https://rdrr.io/r/stats/coef.html) to extract point estimates
and
[`apply_estimate()`](https://mustapha-wasseja.github.io/qpmR/reference/apply_estimate.md)
to recalibrate the model.

## Details

Draws that violate Blanchard-Kahn (indeterminacy or explosiveness)
receive zero posterior weight — the usual truncation of the prior to the
determinacy region. Everything without a prior stays calibrated at its
current value.

## Examples

``` r
# \donttest{
m <- qpm_model(variables = vars(x = "x"), shocks = shocks(e),
               equations = eqs(x ~ rho * x[-1] + e),
               params = list(rho = 0.5))
obs <- simulate(qpm_solve(qpm_calibrate(m, rho = 0.8)), nsim = 200, seed = 1)
est <- qpm_estimate(m, obs, priors(rho = beta(0.5, 0.2), e = invgamma(1, 0.3)),
                    iter = 1000, chains = 2, seed = 2, verbose = FALSE)
est
#> <qpm_estimate> Bayesian (adaptive RWM) - 2 parameters, 2 chains x 1000 draws (burn 500, acceptance 0.28)
#>   log-posterior at mode: -268.79
#>   param      prior                  mode     mean       5%      95%  R-hat    ESS learned
#>   rho        beta(0.5, 0.2)        0.790    0.790    0.730    0.855   1.01    162 yes
#>   e          invgamma(1, 0.3)      0.925    0.924    0.857    0.998   1.01    127 yes
#>   'learned' compares posterior to prior sd (yes < 0.5 < some < 0.9 < little)
# }
```
