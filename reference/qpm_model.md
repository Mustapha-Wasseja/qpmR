# Define a quarterly projection model

Declares a linear semi-structural model with model-consistent
expectations. Equations are parsed immediately, so unknown symbols and
malformed lag/lead references are caught at construction time.
Coefficients are extracted from the current calibration when the model
is solved with
[`qpm_solve()`](https://mustapha-wasseja.github.io/qpmR/reference/qpm_solve.md).

## Usage

``` r
qpm_model(
  name = "QPM model",
  variables,
  shocks,
  equations,
  params = list(),
  sigma = NULL,
  meta = list()
)
```

## Arguments

- name:

  Model name used in printed output.

- variables:

  Variable declarations from
  [`vars()`](https://mustapha-wasseja.github.io/qpmR/reference/vars.md).

- shocks:

  Shock declarations from
  [`shocks()`](https://mustapha-wasseja.github.io/qpmR/reference/shocks.md).

- equations:

  Equations from
  [`eqs()`](https://mustapha-wasseja.github.io/qpmR/reference/eqs.md);
  one per variable.

- params:

  Named list/vector of parameter values.

- sigma:

  Named vector of shock standard deviations. Defaults to 1 for every
  shock.

- meta:

  Optional list of metadata (e.g. plausible parameter `ranges` used by
  [`qpm_lint()`](https://mustapha-wasseja.github.io/qpmR/reference/qpm_lint.md)).

## Value

An object of class `qpm_model`.

## Examples

``` r
m <- qpm_model(
  name      = "AR(1) toy",
  variables = vars(x = "A persistent process"),
  shocks    = shocks(eps_x),
  equations = eqs(x ~ rho * x[-1] + eps_x),
  params    = list(rho = 0.8)
)
m
#> <qpm_model> AR(1) toy
#>   1 endogenous variables - 1 shocks - 1 parameters
#>   dynamics: max lag 1, max lead 0
#>   calibration:
#>     rho = 0.8
#>   variables: x
```
