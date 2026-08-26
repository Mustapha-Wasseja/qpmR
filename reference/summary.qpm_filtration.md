# Summarise a filtration

Summarise a filtration

## Usage

``` r
# S3 method for class 'qpm_filtration'
summary(object, ...)
```

## Arguments

- object:

  A `qpm_filtration`.

- ...:

  Unused.

## Value

A data frame with, for each model variable, whether it was observed and
the mean, standard deviation and range of its smoothed path, plus the
mean estimation standard error for latent states.

## Examples

``` r
sol <- qpm_solve(qpm_template("bkl"))
obs <- simulate(sol, nsim = 40, seed = 1, burn = 20)
summary(qpm_filter(sol, obs[, c("period", "pi", "i", "q")]))
#>     variable observed        mean         sd        min        max           se
#> 1      y_gap    FALSE  0.04519559 1.54784127 -2.8505898  3.1067732 7.020476e-01
#> 2         pi     TRUE  5.04893869 3.18063241 -0.7145051 11.0223756 4.757478e-16
#> 3        pi4    FALSE  5.00742119 2.77174497  0.2513834  9.9821936 3.658192e-02
#> 4          i     TRUE  8.79328569 2.26363254  4.7734276 14.2616921 2.451105e-16
#> 5          r    FALSE  3.79193663 2.12811527  0.6103611  9.8832048 2.585730e-01
#> 6      r_gap    FALSE -0.22335620 2.08082042 -3.4703693  5.6069414 4.122907e-01
#> 7          q     TRUE -0.41534943 3.23538008 -8.6234934  5.3182994 4.031918e-16
#> 8      q_gap    FALSE -0.34318267 3.23983308 -8.7061285  5.4990956 6.144938e-01
#> 9      q_bar    FALSE -0.07216676 0.20561635 -0.3919603  0.2248449 6.144938e-01
#> 10     r_bar    FALSE  4.01529283 0.19619457  3.7457290  4.2908480 4.118036e-01
#> 11    dy_obs    FALSE  3.62226029 3.14190201 -4.4097589  8.4451094 2.532576e+00
#> 12    dy_bar    FALSE  3.50000000 0.00000000  3.5000000  3.5000000 3.796632e-01
#> 13 ystar_gap    FALSE  0.02624463 0.15748631 -0.2585446  0.2734507 4.691442e-01
#> 14     istar    FALSE  2.93719109 0.14990160  2.5868953  3.1850594 5.182067e-01
#> 15    pistar    FALSE  2.01735334 0.08915607  1.8443020  2.2971455 6.843049e-01
#> 16     rstar    FALSE  0.92504375 0.19766030  0.3788935  1.2592933 6.743169e-01
#> 17      prem    FALSE  2.82553081 0.41639335  1.8524869  3.5140539 6.858641e-01
```
