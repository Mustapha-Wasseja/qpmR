# Use the compiled Kalman filter

qpmR ships a compiled (C++) Kalman filter and an equivalent reference
implementation in R. The compiled one is used by default because
estimation runs it once per posterior draw; the R one is kept because
the two agreeing to machine precision is what makes the compiled path
trustworthy, and it is useful when debugging.

## Usage

``` r
qpm_use_cpp()
```

## Value

`TRUE` if the compiled filter will be used.

## Details

Set `options(qpmR.use_cpp = FALSE)` to force the R implementation.

## Examples

``` r
qpm_use_cpp()
#> [1] TRUE
```
