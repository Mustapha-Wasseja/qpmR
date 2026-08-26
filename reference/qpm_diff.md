# Compare two models structurally

Shows what a customization actually changed: variables, shocks and
parameters added or removed, equations changed, and recalibrations. This
is how a model review works when country teams adapt a template.

## Usage

``` r
qpm_diff(old, new, tol = 1e-10)
```

## Arguments

- old, new:

  `qpm_model` objects.

- tol:

  Relative tolerance for calling a parameter changed.

## Value

An object of class `qpm_model_diff`, printed as a report.

## Examples

``` r
qpm_diff(qpm_template("bkl"),
         add_block(qpm_template("bkl"), block_food_cpi()))
#> <qpm_model_diff>
#>   from: Canonical small open economy QPM (BKL, stationary trends)
#>   to:   Canonical small open economy QPM (BKL, stationary trends) + food CPI
#>   + variables: pi_core, pi_food, rp_food
#>   + shocks: eps_pifood
#>   + parameters: w_food, f1, f2, f3, f4
#>   + equations:
#>       pi_core ~ b1 * pi_core[-1] + (1 - b1) * E(pi_core[+1]) + b2 * y_gap + b3 * q_gap + eps_pi
#>       pi_food ~ f1 * pi_food[-1] + (1 - f1) * E(pi[+1]) + f2 * y_gap + f3 * q_gap - f4 * rp_food[-1] + eps_pifood
#>       rp_food ~ rp_food[-1] + (pi_food - pi_core)/4
#>   ~ equations changed:
#>       - pi ~ b1 * pi[-1] + (1 - b1) * E(pi[+1]) + b2 * y_gap + b3 * q_gap + eps_pi
#>       + pi ~ w_food * pi_food + (1 - w_food) * pi_core
```
