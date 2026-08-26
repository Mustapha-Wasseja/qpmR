# The standard forecast-round chart pack

Produces the chart set a forecast round is discussed from: the forecast
fans, the filtered latent states, the historical shock decomposition of
inflation, and the model's monetary transmission. Output is a multi-page
PDF by default, or numbered PNGs.

## Usage

``` r
chart_pack(
  round,
  file = NULL,
  charts = NULL,
  vars = NULL,
  width = 9,
  height = 6.5
)
```

## Arguments

- round:

  A `qpm_round`.

- file:

  Output file. A `.pdf` extension gives one multi-page document; a
  `.png` extension gives numbered files (`name-1.png`, ...). `NULL`
  draws to the current device.

- charts:

  Which charts to include, from `"forecast"`, `"gaps"`,
  `"decomposition"`, `"transmission"`. Default: all four.

- vars:

  Variables for the forecast page. Default: the model's headline set,
  whichever of `pi4`/`pi`, `i`, `y_gap`, `q` exist.

- width, height:

  Page size in inches.

## Value

The output path (invisibly), or `NULL` when drawing to the current
device.

## Examples

``` r
m <- qpm_template("bkl")
obs <- simulate(qpm_solve(m), nsim = 40, seed = 1, burn = 20)
obs$period <- next_quarters("2016-Q1", 40)
r <- qpm_round("demo", m, obs[, c("period", "pi", "i", "q")], horizon = 8)
pdf_path <- file.path(tempdir(), "pack.pdf")
chart_pack(r, pdf_path)
```
