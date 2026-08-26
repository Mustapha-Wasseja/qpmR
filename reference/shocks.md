# Declare the structural shocks of a model

Accepts bare names or character strings.

## Usage

``` r
shocks(...)
```

## Arguments

- ...:

  Shock names, e.g. `shocks(eps_y, eps_pi)`.

## Value

A character vector of shock names.

## Examples

``` r
shocks(eps_y, eps_pi, eps_i)
#> [1] "eps_y"  "eps_pi" "eps_i" 
```
