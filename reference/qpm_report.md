# Write (and optionally render) a monetary policy report

Turns a forecast round into the document a policy meeting is run from:
an executive summary with the numbers filled in, the forecast table and
fan charts, the filtered gaps, the shock decomposition, the judgment
ledger, an optional revision decomposition against the previous round,
and a reproducibility appendix.

## Usage

``` r
qpm_report(
  round,
  file = "mpr.html",
  compare_to = NULL,
  store = "rounds",
  render = TRUE,
  engine = c("auto", "quarto", "rmarkdown"),
  quiet = TRUE
)
```

## Arguments

- round:

  A `qpm_round`.

- file:

  Output path. The extension chooses the format (`.html`, `.pdf`,
  `.docx`), or `.Rmd` to write the source only.

- compare_to:

  Optional previous `qpm_round` (or its name) to add a
  revision-decomposition section.

- store:

  Round store used to resolve `compare_to` by name.

- render:

  Render the document, or only write the source.

- engine:

  `"auto"` (Quarto if present, else rmarkdown), `"quarto"`, or
  `"rmarkdown"`.

- quiet:

  Suppress rendering progress output.

## Value

The path actually produced (the rendered document, or the `.Rmd` when
rendering was not possible), invisibly.

## Details

The report is always written as a self-contained `.Rmd` source, on the
principle that institutions replace the template's *text*, not its
plumbing: edit the file, re-render, keep the analysis. Rendering
additionally needs pandoc (via Quarto or RStudio/Positron); where none
is available — air-gapped forecasting machines, bare CI runners —
`qpm_report()` reports that and returns the `.Rmd` unrendered rather
than failing.

## Examples

``` r
m <- qpm_template("bkl")
obs <- simulate(qpm_solve(m), nsim = 40, seed = 1, burn = 20)
obs$period <- next_quarters("2016-Q1", 40)
r <- qpm_round("demo", m, obs[, c("period", "pi", "i", "q")], horizon = 8)
src <- qpm_report(r, file.path(tempdir(), "mpr.Rmd"), render = FALSE)
```
