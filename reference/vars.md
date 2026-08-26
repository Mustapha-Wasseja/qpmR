# Declare the endogenous variables of a model

Declare the endogenous variables of a model

## Usage

``` r
vars(...)
```

## Arguments

- ...:

  Named arguments, one per variable. Each value is a
  [`var()`](https://mustapha-wasseja.github.io/qpmR/reference/var.md)
  declaration or a character label. Unnamed character arguments are
  taken as variable names with empty labels.

## Value

A data frame with columns `name`, `label`, `unit`.

## Examples

``` r
vars(
  y_gap = var("Output gap", unit = "pp"),
  pi    = "CPI inflation, QoQ annualised"
)
#>    name                         label unit
#> 1 y_gap                    Output gap   pp
#> 2    pi CPI inflation, QoQ annualised     
```
