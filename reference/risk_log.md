# Print a forecast's balance-of-risks assessment

Print a forecast's balance-of-risks assessment

## Usage

``` r
risk_log(fc)
```

## Arguments

- fc:

  A `qpm_forecast` or `qpm_round` with risks applied.

## Value

The risk table, invisibly.

## Examples

``` r
sol <- qpm_solve(qpm_template("bkl"))
fc <- qpm_risk(qpm_forecast(sol, horizon = 8), pi = 0.4,
               rationale = "upside energy risk")
risk_log(fc)
#> <balance of risks> 8 entries
#>  author variable period skew  rationale         
#>  MPC    pi       h1     +0.40 upside energy risk
#>  MPC    pi       h2     +0.40 upside energy risk
#>  MPC    pi       h3     +0.40 upside energy risk
#>  MPC    pi       h4     +0.40 upside energy risk
#>  MPC    pi       h5     +0.40 upside energy risk
#>  MPC    pi       h6     +0.40 upside energy risk
#>  MPC    pi       h7     +0.40 upside energy risk
#>  MPC    pi       h8     +0.40 upside energy risk
#>   skew is mean minus mode, in the variable's own units; total variance is unchanged
```
