# State-space representation of a solved model

Exposes the exact matrices qpmR itself uses for filtering, so other
estimators and filters can be built on top of a solved model. The
representation (in deviations from steady state) is \$\$a_t = T
a\_{t-1} + R e_t, e_t ~ N(0, Qc)\$\$ \$\$y_t = Z a_t + d + u_t, u_t ~
N(0, H)\$\$ with `d` the steady state of the observables and `P1` the
stationary (Lyapunov) covariance used to initialize the filter.

## Usage

``` r
state_space(solution, observables = NULL, measurement_error = 0, kappa = 1e+06)
```

## Arguments

- solution:

  A `qpm_solution`.

- observables:

  Character vector of observed variables (a subset of the declared
  variables). Default: all declared variables.

- measurement_error:

  Measurement-error standard deviation(s): a scalar recycled over
  observables, or a named vector.

- kappa:

  Diffuse-prior variance scale for unit-root directions (only used when
  the model has unit roots).

## Value

A list with elements `T`, `R`, `Z`, `d`, `Qc`, `H`, `P1`, `vars_all`,
`observables`, `diffuse`, `n_unit`.

## Details

For stationary models `P1` is the exact stationary covariance. When the
model has unit roots (random-walk trends), an approximate diffuse
initialization is used: `P1` solves the Lyapunov equation for the
slightly damped transition `sqrt(1 - 1/kappa) * T`, which reproduces the
stationary covariance in stable directions and a variance of order
`kappa` in unit-root directions, with the exact cross-coupling. Exact
Durbin-Koopman diffuse recursions are on the roadmap.

## Examples

``` r
sol <- qpm_solve(qpm_template("bkl"))
ss <- state_space(sol, observables = c("pi", "i", "q"))
dim(ss$T); ss$d
#> [1] 22 22
#>            pi             i             q 
#>  5.000000e+00  9.000000e+00 -2.942091e-14 
```
