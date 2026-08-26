# Generate consecutive quarter labels

Generate consecutive quarter labels

## Usage

``` r
next_quarters(last, H)
```

## Arguments

- last:

  The starting quarter, `"YYYY-Qq"` style; the sequence begins at the
  following quarter.

- H:

  Number of quarters to generate.

## Value

Character vector of `H` quarter labels.

## Examples

``` r
next_quarters("2026-Q3", 4)
#> [1] "2026-Q4" "2027-Q1" "2027-Q2" "2027-Q3"
```
