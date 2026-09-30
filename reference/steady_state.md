# Steady state of a model or solution

Steady state of a model or solution

## Usage

``` r
steady_state(x, ...)
```

## Arguments

- x:

  A `qpm_model` or `qpm_solution`.

- ...:

  Unused.

## Value

Named vector of steady-state values for the declared variables.

## Examples

``` r
steady_state(qpm_template("bkl"))
#>         y_gap            pi           pi4             i             r 
#> -8.659740e-15  5.000000e+00  5.000000e+00  9.000000e+00  4.000000e+00 
#>         r_gap             q         q_gap         q_bar         r_bar 
#>  5.329071e-15  2.531308e-14  1.776357e-14  1.154632e-14  4.000000e+00 
#>        dy_obs        dy_bar     ystar_gap         istar        pistar 
#>  3.500000e+00  3.500000e+00 -1.043610e-14  3.000000e+00  2.000000e+00 
#>         rstar          prem 
#>  1.000000e+00  3.000000e+00 
```
