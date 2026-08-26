## Submission

This is a new submission: qpmR 1.0.0.

qpmR implements the semi-structural quarterly projection models used in
central-bank forecasting and policy analysis systems, from model
declaration and solution through filtering, conditional forecasting,
Bayesian estimation and reporting.

## Test environments

* local Windows 11, R 4.5.2
* GitHub Actions: Ubuntu 24.04 (R-devel, R-release, R-oldrel),
  Windows Server (R-release), macOS (R-release)

## R CMD check results

0 errors | 0 warnings | 1 note

The one NOTE is the expected

    Maintainer: 'Mustapha Mohammed <muswaseja@gmail.com>'
    New submission

from CRAN's incoming feasibility check.

## Notes for the reviewer

* All examples run in a few seconds. The longer statistical procedures
  (Markov chain Monte Carlo estimation, marginal likelihoods, posterior
  forecasts) are wrapped in `\donttest{}` and are exercised by the test
  suite instead.
* `qpm_report()` writes an R Markdown document and renders it when
  pandoc or Quarto is available. Where neither is present it returns the
  unrendered source with a message rather than failing, so the examples
  and tests do not require pandoc.
* The `quarto` package is used conditionally (guarded by
  `requireNamespace()`) and is listed in Suggests.
* Files are written only to `tempdir()` in examples, tests and vignettes.
* The bundled `czechia` dataset is compiled from public statistical
  sources (Eurostat and OECD series distributed via FRED, and the
  European Central Bank reference exchange rate); the script that builds
  it is included in `data-raw/`.
