# Declare model equations

Each equation is a two-sided formula. Lags and leads use index notation:
`x[-1]` is the first lag, `x[+1]` the first lead. Wrap expectations in
[`E()`](https://mustapha-wasseja.github.io/qpmR/reference/E.md):
`E(pi[+1])` is the model-consistent expectation of next quarter's
inflation. Longer lags and leads (e.g. `E(pi4[+4])`) are handled
automatically via auxiliary state variables.

## Usage

``` r
eqs(...)
```

## Arguments

- ...:

  Two-sided formulas.

## Value

A list of formulas.

## Examples

``` r
eqs(
  pi ~ b1 * pi[-1] + (1 - b1) * E(pi[+1]) + b2 * y_gap + eps_pi
)
#> [[1]]
#> pi ~ b1 * pi[-1] + (1 - b1) * E(pi[+1]) + b2 * y_gap + eps_pi
#> <environment: 0x56192c59d178>
#> 
```
