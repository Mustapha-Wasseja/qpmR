# Check a model for common specification problems

Runs static checks (unused shocks/parameters, bare leads outside
[`E()`](https://mustapha-wasseja.github.io/qpmR/reference/E.md),
calibrations outside plausible ranges when the template documents them)
and then attempts to solve the model, reporting the Blanchard-Kahn
outcome. Unit algebra on declared units is on the roadmap.

## Usage

``` r
qpm_lint(model)
```

## Arguments

- model:

  A `qpm_model`.

## Value

An object of class `qpm_lint` (a data frame of checks with status `ok`,
`note`, `warn`, or `fail`), printed with markers.

## Examples

``` r
qpm_lint(qpm_template("bkl"))
#> <qpm_lint>
#>   v 17 equations for 17 variables
#>   v every declared shock appears in an equation
#>   v all calibrated parameters inside documented ranges
#>   v solves: unique stable solution (Blanchard-Kahn satisfied); largest
#>       stable root 0.900
#>   v steady state exists and is unique (e.g. y_gap = 0, pi = 5, pi4 = 5)
#>   all checks passed
```
