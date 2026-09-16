## Submission

This is a new submission: qpmR 1.1.0.

qpmR implements the semi-structural quarterly projection models used in
central-bank forecasting and policy analysis systems, from model
declaration and solution through filtering, conditional forecasting,
Bayesian estimation and reporting.

## Test environments

* local Windows 11, R 4.5.2 (`R CMD check --as-cran`, including the
  PDF manual)
* GitHub Actions: Ubuntu 24.04 (R-devel, R-release, R-oldrel),
  Windows Server (R-release), macOS (R-release)

## R CMD check results

0 errors | 0 warnings | 1 note

The one NOTE is the expected

    Maintainer: 'Mustapha Mohammed <mustapha.wasseja.mohammed@gmail.com>'
    New submission

from CRAN's incoming feasibility check.

## Notes for the reviewer

* The package contains compiled code: a Kalman filter and a Lyapunov
  solver in C++ via RcppArmadillo. Reference implementations in R are
  kept, and the test suite checks that the compiled and R paths agree
  to machine precision.
* All examples run in a few seconds. The procedures that sample from a
  posterior (Markov chain Monte Carlo estimation, marginal likelihoods,
  posterior forecasts) are wrapped in `\donttest{}` and sized to run
  quickly; the test suite exercises them more thoroughly.
* `qpm_report()` writes an R Markdown document and renders it when
  pandoc or Quarto is available. Where neither is present it returns the
  unrendered source with a message rather than failing, so the examples
  and tests do not require pandoc. The `quarto` package is used
  conditionally (guarded by `requireNamespace()`) and is listed in
  Suggests.
* No function writes to the file system unless the user supplies a
  path; examples, tests and vignettes write only to `tempdir()`.
* The bundled `czechia` dataset is compiled from public statistical
  sources (Eurostat and OECD series distributed via FRED, and the
  European Central Bank reference exchange rate); the script that builds
  it is included in `data-raw/`.
