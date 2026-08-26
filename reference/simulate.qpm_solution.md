# Simulate a solved model

Draws Gaussian shocks with the model's standard deviations and iterates
the solved transition. Returns variables in levels (steady state plus
simulated deviations). The final full state is stored as an attribute so
a simulation can be handed straight to
[`qpm_forecast()`](https://mustapha-wasseja.github.io/qpmR/reference/qpm_forecast.md).

## Usage

``` r
# S3 method for class 'qpm_solution'
simulate(object, nsim = 40, seed = NULL, sigma = NULL, burn = 0, ...)
```

## Arguments

- object:

  A `qpm_solution`.

- nsim:

  Number of quarters to simulate.

- seed:

  Optional seed for reproducibility.

- sigma:

  Optional named vector of shock standard deviations overriding the
  model's.

- burn:

  Burn-in quarters discarded from the start.

- ...:

  Unused.

## Value

A data frame of class `qpm_sim` (period plus one column per declared
variable), with attributes `state` (final expanded state, deviations)
and `shocks` (the drawn shocks).

## Examples

``` r
sol <- qpm_solve(qpm_template("bkl"))
hist <- simulate(sol, nsim = 60, seed = 42, burn = 20)
head(hist)
#>   period      y_gap        pi       pi4         i         r       r_gap
#> 1      1  1.5995277  8.283823  3.429854  9.651686 -0.379355 -3.94423181
#> 2      2  1.8894368 11.832184  6.311916 12.230678 -0.326973 -3.64465628
#> 3      3  1.5948698 11.197917  8.827732 14.157853  3.455491  0.04989695
#> 4      4  0.8517893 12.511780 10.956426 15.411294  4.963000  1.61671949
#> 5      5  0.2772514 10.020683 11.390641 15.369825  7.362883  3.77357397
#> 6      6 -1.2735379  8.229694 10.490019 13.629126  7.602457  3.96146470
#>           q     q_gap      q_bar    r_bar     dy_obs   dy_bar    ystar_gap
#> 1  8.004499  8.757609 -0.7531098 3.564877 10.1979680 3.669348 -0.462378690
#> 2  7.014375  7.491024 -0.4766494 3.317683  4.5516391 3.826901  0.007169041
#> 3  2.532334  3.091704 -0.5593696 3.405594  0.8618093 3.777375  0.021787637
#> 4 -6.064385 -5.226789 -0.8375966 3.346280 -0.4730472 3.762970  0.235857865
#> 5 -5.993562 -5.421857 -0.5717051 3.589309  1.6876512 3.579494  0.657015713
#> 6 -4.231033 -3.799136 -0.4318975 3.640992 -4.1348660 3.527945  0.605299996
#>      istar   pistar     rstar     prem
#> 1 2.816014 1.539670 1.1382449 5.661308
#> 2 3.356518 1.559802 1.6646569 5.137805
#> 3 2.952610 1.562080 1.2591542 4.865374
#> 4 2.425408 1.361773 0.8721670 4.368602
#> 5 1.835657 1.393745 0.2600351 5.252646
#> 6 2.205646 1.946819 0.2428726 3.435359
```
