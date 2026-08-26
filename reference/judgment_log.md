# Print a forecast's judgment ledger

Print a forecast's judgment ledger

## Usage

``` r
judgment_log(fc)
```

## Arguments

- fc:

  A `qpm_forecast` with judgment applied.

## Value

The ledger data frame, invisibly.

## Examples

``` r
sol <- qpm_solve(qpm_template("bkl"))
fc <- add_judgment(qpm_forecast(sol, horizon = 8), pi = c(h2 = 0.5),
                   author = "desk", rationale = "tariff")
judgment_log(fc)
#> <judgment ledger> 1 entry
#>  id time             author variable period add   target rationale
#>  1  2026-08-26 13:44 desk   pi       h2     +0.50 5.5    tariff   
#>   implied shocks, max |sd|: eps_y 0.03, eps_pi 0.16, eps_i 0.03, eps_q 0.07, eps_qbar 0.01, eps_rbar 0.01, eps_ystar 0.00, eps_istar 0.02, eps_pistar 0.02, eps_prem 0.04
```
