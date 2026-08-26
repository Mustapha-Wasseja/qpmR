# Identification diagnostics (Iskrev-style Jacobian analysis)

Checks, before any estimation is run, whether the chosen parameters can
be told apart by the data. Two Jacobians are analysed numerically at the
current calibration, in the spirit of Iskrev (2010):

## Usage

``` r
qpm_identify(model, params = NULL, observables = NULL, lags = 3, h = 1e-05)
```

## Arguments

- model:

  A `qpm_model`.

- params:

  Parameters to check: a character vector of structural parameter and/or
  shock names, or a
  [`priors()`](https://mustapha-wasseja.github.io/qpmR/reference/priors.md)
  object (its names are used). Default: all structural parameters.

- observables:

  Observed variables the moment analysis conditions on. Default: all
  declared variables.

- lags:

  Autocovariance lags in the moment vector.

- h:

  Relative step for the central differences.

## Value

An object of class `qpm_identification` with the ranks, singular values,
and flagged parameters; printed as a verdict list.

## Details

- **solution level**: derivatives of the solved transition, shock
  loading, and observable steady state with respect to the parameters.
  Rank deficiency here means some parameter movements do not change the
  model's solution at all.

- **moment level** (stationary models only): derivatives of the
  observables' first and second moments (means, and autocovariances up
  to `lags`). Rank deficiency here means some parameter movements are
  observationally equivalent in population.

The report names parameters with (numerically) no effect, parameter
combinations spanning any null space, and near-collinear pairs of
Jacobian columns (correlation above 0.995) that are only jointly
identified.

## References

Iskrev, N. (2010). Local identification in DSGE models. Journal of
Monetary Economics, 57(2), 189-202.

## Examples

``` r
qpm_identify(qpm_template("bkl"),
             params = c("b1", "b2", "b3", "c1", "c2"),
             observables = c("pi", "i", "q", "dy_obs"))
#> <qpm_identification> 5 parameters, observables: pi, i, q, dy_obs
#>   v solution level: full rank (5), smallest/largest singular value 0.05
#>   v moment level (means + autocovariances to lag 3): full rank (5), smallest/largest singular value 0.03
#>   ! moment level (means + autocovariances to lag 3): near-collinear pairs (only jointly identified): c1 ~ c2 (-0.995)
```
