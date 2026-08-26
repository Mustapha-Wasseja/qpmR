# Save, load, and list forecast rounds

A round store is a plain directory: each round lives in `store/<slug>/`
as a self-contained `round.rds` plus human-readable sidecars
(`forecast.csv`, `data.csv`, `calibration.csv`, and `judgment.csv` when
judgment was applied) so that a round can be audited without R.

## Usage

``` r
save_round(round, store = "rounds", overwrite = FALSE)

load_round(name, store = "rounds")

list_rounds(store = "rounds")
```

## Arguments

- round:

  A `qpm_round`.

- store:

  Directory of the round store (created if missing).

- overwrite:

  Allow replacing an existing round of the same name.

- name:

  Round name (or its slug), or a direct path to a round directory or
  `round.rds`.

## Value

`save_round()` returns the round directory invisibly; `load_round()`
returns the `qpm_round`; `list_rounds()` returns a data frame of the
store's contents.

## Examples

``` r
m <- qpm_template("bkl")
obs <- simulate(qpm_solve(m), nsim = 40, seed = 1, burn = 20)
obs$period <- next_quarters("2016-Q1", 40)
r <- qpm_round("demo", m, obs[, c("period", "pi", "i", "q")], horizon = 8)
store <- file.path(tempdir(), "rounds")
save_round(r, store)
list_rounds(store)
#>   name          created data_to horizon n_judgment
#> 1 demo 2026-08-26 07:32 2026-Q1       8          0
r2 <- load_round("demo", store)
```
