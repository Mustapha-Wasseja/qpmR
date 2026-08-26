# Expectations operator (equation syntax only)

`E()` marks model-consistent expectations inside
[`eqs()`](https://mustapha-wasseja.github.io/qpmR/reference/eqs.md)
declarations, e.g. `E(pi[+1])`. It is parsed by
[`qpm_model()`](https://mustapha-wasseja.github.io/qpmR/reference/qpm_model.md)
and never evaluated as an ordinary function.

## Usage

``` r
E(x)
```

## Arguments

- x:

  A variable reference such as `pi[+1]`.

## Value

No return value; calling `E()` outside of model equations is an error by
design.
