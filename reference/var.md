# Declare a model variable with a label and unit

Used inside
[`vars()`](https://mustapha-wasseja.github.io/qpmR/reference/vars.md) to
attach documentation to a variable. Units are stored and displayed; unit
algebra (automatic consistency checking inside equations) is on the
roadmap.

## Usage

``` r
var(label = "", unit = "", ...)
```

## Arguments

- label:

  Human-readable description, e.g. `"Output gap"` (or numeric data,
  which is passed to
  [`stats::var()`](https://rdrr.io/r/stats/cor.html)).

- unit:

  Unit of measurement, e.g. `"pp"`, `"pct pa"`.

- ...:

  Passed to [`stats::var()`](https://rdrr.io/r/stats/cor.html) in the
  delegation case.

## Value

An object of class `qpm_var`, or the result of
[`stats::var()`](https://rdrr.io/r/stats/cor.html).

## Details

When given numeric data instead of a character label, `var()` delegates
to [`stats::var()`](https://rdrr.io/r/stats/cor.html), so attaching qpmR
does not break variance computations.

## Examples

``` r
vars(y_gap = var("Output gap", unit = "pp"))
#>    name      label unit
#> 1 y_gap Output gap   pp
var(rnorm(10))  # still the sample variance
#> [1] 1.575348
```
