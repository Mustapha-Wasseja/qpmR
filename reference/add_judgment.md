# Add logged judgment to a forecast

Central-bank forecasts are never raw model output: the desk knows about
the announced electricity tariff, the tax change, the one-off the model
cannot see. `add_judgment()` makes that adjustment a first-class, logged
operation: you state the change you want (in percentage points, relative
to the current forecast), qpmR back-solves the structural shocks needed
to support it while keeping the whole forecast model-consistent, records
who imposed it and why, and flags judgment that requires implausibly
large shocks.

## Usage

``` r
add_judgment(
  fc,
  ...,
  author = "desk",
  rationale = "",
  anticipated = NULL,
  instruments = NULL
)
```

## Arguments

- fc:

  A `qpm_forecast` or a `qpm_round`.

- ...:

  Named adjustments: one argument per variable, each a named vector of
  *additions* (percentage points, relative to the current forecast) by
  period, e.g. `pi = c("2027-Q1" = 0.4)`.

- author:

  Who is imposing the judgment (logged).

- rationale:

  Why (logged; make it meaningful – the ledger is the audit trail read
  back before the policy meeting).

- anticipated:

  Expectation mode for the re-solve; defaults to the forecast's current
  mode, or unanticipated.

- instruments:

  Shocks allowed to move; defaults to the forecast's current
  instruments, or all shocks.

## Value

The adjusted `qpm_forecast` with the entry appended to its judgment
ledger.

## Details

Judgment entries are stored as absolute targets, so the ledger is
replayable; the full set of conditions and judgment is re-solved jointly
each time. Inspect the ledger with
[`judgment_log()`](https://mustapha-wasseja.github.io/qpmR/reference/judgment_log.md).

## Examples

``` r
sol <- qpm_solve(qpm_template("bkl"))
fc <- qpm_forecast(sol, horizon = 8)
fc2 <- add_judgment(fc, pi = c(h2 = 0.5),
                    author = "desk",
                    rationale = "announced electricity tariff increase")
judgment_log(fc2)
#> <judgment ledger> 1 entry
#>  id time             author variable period add   target
#>  1  2026-08-26 20:30 desk   pi       h2     +0.50 5.5   
#>  rationale                            
#>  announced electricity tariff increase
#>   implied shocks, max |sd|: eps_y 0.03, eps_pi 0.16, eps_i 0.03, eps_q 0.07, eps_qbar 0.01, eps_rbar 0.01, eps_ystar 0.00, eps_istar 0.02, eps_pistar 0.02, eps_prem 0.04
```
