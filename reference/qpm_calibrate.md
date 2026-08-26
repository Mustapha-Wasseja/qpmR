# Update a model's calibration

Update a model's calibration

## Usage

``` r
qpm_calibrate(model, ..., sigma = NULL)
```

## Arguments

- model:

  A `qpm_model`.

- ...:

  Named parameter values to update. Every name must already exist in the
  model (typo protection).

- sigma:

  Optional named vector of shock standard deviations to update.

## Value

The updated `qpm_model`.

## Examples

``` r
m <- qpm_template("bkl")
m <- qpm_calibrate(m, b2 = 0.3, c2 = 2)
```
