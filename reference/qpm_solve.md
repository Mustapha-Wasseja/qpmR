# Solve a model under model-consistent expectations

Reduces the model to first-order form (adding auxiliary states for
lags/leads beyond one quarter), computes the steady state, and solves
for the unique stable rational-expectations solution \$\$x_t = P
x\_{t-1} + Q e_t\$\$ via the generalized Schur (QZ) decomposition (Klein
2000), with full Blanchard-Kahn diagnostics.

## Usage

``` r
qpm_solve(model, tol = 1e-07)
```

## Arguments

- model:

  A `qpm_model`.

- tol:

  Numerical tolerance for the solution residual check.

## Value

An object of class `qpm_solution` with elements `P`, `Q` (transition and
impact matrices over the expanded state vector), `ss` (steady state),
and an eigenvalue table (see
[`eigen_table()`](https://mustapha-wasseja.github.io/qpmR/reference/eigen_table.md)).

## References

Klein, P. (2000). Using the generalized Schur form to solve a
multivariate linear rational expectations model. Journal of Economic
Dynamics and Control, 24(10), 1405-1423.

## Examples

``` r
sol <- qpm_solve(qpm_template("bkl"))
sol
#> <qpm_solution> Canonical small open economy QPM (BKL, stationary trends)
#>   states: 22 (17 declared + 5 auxiliary) - shocks: 12
#>   Blanchard-Kahn: 22 stable roots = 22 predetermined states -> unique stable solution
#>   roots: largest stable 0.900, smallest unstable 1.419, 17 infinite
#>   steady state:
#>     y_gap = 0, pi = 5, pi4 = 5, i = 9, r = 4, r_gap = 0, q = 0, q_gap = 0,
#>     q_bar = 0, r_bar = 4, dy_obs = 3.5, dy_bar = 3.5, ystar_gap = 0, istar
#>     = 3, pistar = 2, rstar = 1, prem = 3
```
