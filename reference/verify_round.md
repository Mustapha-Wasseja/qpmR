# Verify that an archived round still reproduces

Re-runs a saved forecast round from its own contents — model,
calibration, data vintage, conditions and judgment — and checks that the
published numbers come back. This is the audit an institution needs and
that a folder of scripts cannot provide: a round that no longer
reproduces is a finding, not a mystery.

## Usage

``` r
verify_round(round, store = "rounds", tol = 1e-06)
```

## Arguments

- round:

  A `qpm_round`, or a round name/path to load from `store`.

- store:

  Round store used when `round` is a name.

- tol:

  Absolute tolerance on the forecast paths.

## Value

An object of class `qpm_verification`: `$ok`, the largest deviation, the
worst variables, sidecar checks, and the qpmR versions involved.

## Details

When the round is loaded from a store, the human-readable CSV sidecars
are checked against the object too, so a hand-edited audit trail is
detected.

## Examples

``` r
m <- qpm_template("bkl")
obs <- simulate(qpm_solve(m), nsim = 40, seed = 1, burn = 20)
obs$period <- next_quarters("2016-Q1", 40)
r <- qpm_round("demo", m, obs[, c("period", "pi", "i", "q")], horizon = 8)
verify_round(r)
#> <qpm_verification> demo
#>   archived under qpmR 1.0.0.9000, verified under 1.0.0.9000
#>   re-ran the pipeline with 0 conditions and 0 judgment entries
#>   v forecast reproduces exactly (largest deviation 0)
```
