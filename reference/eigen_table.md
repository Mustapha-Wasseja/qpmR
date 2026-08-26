# Generalized eigenvalues of a solved model

Generalized eigenvalues of a solved model

## Usage

``` r
eigen_table(x)
```

## Arguments

- x:

  A `qpm_solution`.

## Value

A data frame with the moduli of the generalized eigenvalues of the model
companion pencil, sorted ascending, with stability flags.

## Examples

``` r
head(eigen_table(qpm_solve(qpm_template("bkl"))))
#>   modulus stable  unit infinite
#> 1       0   TRUE FALSE    FALSE
#> 2       0   TRUE FALSE    FALSE
#> 3       0   TRUE FALSE    FALSE
#> 4       0   TRUE FALSE    FALSE
#> 5       0   TRUE FALSE    FALSE
#> 6       0   TRUE FALSE    FALSE
```
