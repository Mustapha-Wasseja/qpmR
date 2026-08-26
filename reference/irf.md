# Impulse response functions

Impulse response functions

## Usage

``` r
irf(x, ...)

# S3 method for class 'qpm_solution'
irf(x, shock = NULL, horizon = 24, size = NULL, vars = NULL, ...)
```

## Arguments

- x:

  A `qpm_solution` from
  [`qpm_solve()`](https://mustapha-wasseja.github.io/qpmR/reference/qpm_solve.md).

- ...:

  Passed to methods.

- shock:

  Shock name(s); default all shocks.

- horizon:

  Number of quarters after impact.

- size:

  Shock size(s). Default is one standard deviation (from the model's
  `sigma`); a named vector or a single number can override.

- vars:

  Variables to include; default all declared (non-auxiliary) variables.

## Value

A data frame of class `qpm_irf` in long format with columns `shock`,
`variable`, `horizon`, `value` (deviations from steady state). Printing
shows peak effects;
[`plot()`](https://rdrr.io/r/graphics/plot.default.html) draws panel
charts.

## Examples

``` r
sol <- qpm_solve(qpm_template("bkl"))
ir <- irf(sol, shock = "eps_i", horizon = 16)
ir
#> <qpm_irf> impulse responses (deviations from steady state)
#>   shocks: eps_i (size  0.5)
#>   peak effects:
#>  shock  variable    peak quarter
#>  eps_i    dy_obs -0.6655       0
#>  eps_i         r  0.6032       0
#>  eps_i     r_gap  0.6032       0
#>  eps_i         i  0.3389       0
#>  eps_i        pi -0.3185       2
#>  eps_i         q  0.2815       4
#>  eps_i     q_gap  0.2815       4
#>  eps_i       pi4 -0.2785       4
#>  eps_i     y_gap -0.2244       1
#>  eps_i    dy_bar  0.0000       0
#>  eps_i     istar  0.0000       0
#>  eps_i    pistar  0.0000       0
#>  eps_i      prem  0.0000       0
#>  eps_i     q_bar  0.0000       0
#>  eps_i     r_bar  0.0000       0
#>  eps_i     rstar  0.0000       0
#>  eps_i ystar_gap  0.0000       0
plot(ir, vars = c("pi", "y_gap", "i", "q"))
```
