# Model-implied moments, and how they compare with the data

The standard calibration check: does the model reproduce the
volatilities and persistence actually observed? Reports the population
standard deviation and autocorrelations implied by the solved model —
from the stationary covariance \\V = P V P' + Q S Q'\\ and \\corr_k =
diag(P^k V) / diag(V)\\ — next to the same statistics computed from
data, plus the shock that accounts for most of each variable's
unconditional variance.

## Usage

``` r
model_properties(x, data = NULL, vars = NULL, lags = c(1, 4))
```

## Arguments

- x:

  A `qpm_solution` or `qpm_model`.

- data:

  Optional data frame of observations in levels (columns named for model
  variables, an optional `period` column) whose moments are shown
  alongside. Missing values are dropped per variable.

- vars:

  Variables to report; default all declared variables.

- lags:

  Autocorrelation orders to report.

## Value

An object of class `qpm_properties`: a data frame with the model and
(optionally) data moments.

## Details

Population moments exist only for stationary models. When the model has
unit roots (random-walk trends) they are undefined, and the function
reports that rather than returning nonsense; use
[`fevd()`](https://mustapha-wasseja.github.io/qpmR/reference/fevd.md)
and
[`qpm_filter()`](https://mustapha-wasseja.github.io/qpmR/reference/qpm_filter.md)
diagnostics instead.

## Examples

``` r
sol <- qpm_solve(qpm_template("bkl"))
model_properties(sol, vars = c("y_gap", "pi", "i", "q"))
#> <qpm_properties> Canonical small open economy QPM (BKL, stationary trends)
#>  variable model_sd model_ac1 model_ac4 main_shock  
#>  y_gap    1.61     0.82      -0.09     eps_pi (40%)
#>  pi       2.89     0.81      -0.06     eps_pi (61%)
#>  i        2.50     0.90       0.15     eps_pi (36%)
#>  q        3.24     0.62      -0.11     eps_q (44%) 

# against simulated data
obs <- simulate(sol, nsim = 200, seed = 5, burn = 50)
model_properties(sol, data = obs, vars = c("y_gap", "pi", "i"))
#> <qpm_properties> Canonical small open economy QPM (BKL, stationary trends)
#>   model-implied moments next to the same statistics in the data
#>  variable model_sd model_ac1 model_ac4 main_shock   data_sd data_ac1 data_ac4
#>  y_gap    1.61     0.82      -0.09     eps_pi (40%) 1.45    0.80     -0.12   
#>  pi       2.89     0.81      -0.06     eps_pi (61%) 2.48    0.76     -0.01   
#>  i        2.50     0.90       0.15     eps_pi (36%) 2.37    0.90      0.27   
```
