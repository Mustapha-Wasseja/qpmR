# Apply an extension block to a model

Apply an extension block to a model

## Usage

``` r
add_block(model, block)
```

## Arguments

- model:

  A `qpm_model`.

- block:

  A
  [`qpm_block()`](https://mustapha-wasseja.github.io/qpmR/reference/qpm_block.md),
  or a list of blocks applied in order.

## Value

The extended `qpm_model`, with the block recorded in `meta$blocks`.

## Examples

``` r
m <- add_block(qpm_template("bkl"), block_food_cpi(weight = 0.4))
m
#> <qpm_model> Canonical small open economy QPM (BKL, stationary trends) + food CPI
#>   20 endogenous variables - 13 shocks - 30 parameters
#>   dynamics: max lag 3, max lead 4 (auxiliary states added automatically at solve time)
#>   calibration:
#>     a1 = 0.7, a2 = 0.1, a3 = 0.2, a4 = 0.1, a5 = 0.25, b1 = 0.7, b2 = 0.25,
#>     b3 = 0.1, c1 = 0.7, c2 = 1.5, c3 = 0.5, e1 = 0.7, pi_tar = 5, istar_ss
#>     = 3, pistar_ss = 2, prem_ss = 3, qbar_ss = 0, g_ss = 3.5, rho_qbar =
#>     0.9, rho_rbar = 0.9, rho_g = 0.85, rho_ystar = 0.8, rho_istar = 0.85,
#>     rho_pistar = 0.7, rho_prem = 0.85, w_food = 0.4, f1 = 0.5, f2 = 0.2, f3
#>     = 0.25, f4 = 0.1
#>   variables: y_gap, pi, pi4, i, r, r_gap, q, q_gap, ... (see summary())
```
