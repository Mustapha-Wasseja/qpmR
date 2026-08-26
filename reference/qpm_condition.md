# Conditional forecasts: impose paths, back out the shocks

Imposes hard conditions on future values of model variables and finds
the minimum-norm structural shocks (in standard-deviation units,
optionally restricted to `instruments`) that deliver them. This is how a
policy question becomes a forecast: "what if the policy rate is held at
3.5 for four quarters?" or "what paths are consistent with inflation
back at target by 2027?".

## Usage

``` r
qpm_condition(fc, ..., anticipated = FALSE, instruments = NULL)
```

## Arguments

- fc:

  A `qpm_forecast` from
  [`qpm_forecast()`](https://mustapha-wasseja.github.io/qpmR/reference/qpm_forecast.md),
  or a `qpm_round` (its forecast is conditioned and the round returned).

- ...:

  Named conditions: one argument per variable, each a named vector of
  levels by period, e.g. `i = c("2026-Q4" = 3.5, "2027-Q1" = 3.5)` or
  `pi4 = c(h4 = 2)`.

- anticipated:

  Logical; announced-at-start (`TRUE`) vs period-by-period surprises
  (`FALSE`, default).

- instruments:

  Character vector of shocks allowed to move; default all shocks.

## Value

The conditioned `qpm_forecast`, with `$shocks_implied` (raw units),
`$shocks_implied_std` (standard deviations), and the conditions
recorded. Printing summarizes the implied shocks and flags any larger
than two standard deviations.

## Details

The `anticipated` switch is the economics: `TRUE` means the whole
conditioned path is announced at the start of the forecast, so
expectations react immediately (forward-looking variables move before
the conditioning bites); `FALSE` means the implied shocks arrive as
period-by-period surprises. The two produce materially different paths
in any forward-looking model, and practitioners frequently do not know
which one their tools assume.

Fan bands are recomputed as the Gaussian conditional distribution of the
path given the conditions (using all shocks), so conditioned points have
(near) zero width. The mean path uses only the chosen instruments; when
`instruments` is restricted, mean and bands answer slightly different
questions – see Antolin-Diaz, Petrella and Rubio-Ramirez (2021) for the
full treatment, which is on the qpmR roadmap.

## Examples

``` r
sol <- qpm_solve(qpm_template("bkl"))
fc <- qpm_forecast(sol, horizon = 8)
hold <- qpm_condition(fc, i = c(h1 = 9.5, h2 = 9.5, h3 = 9.5, h4 = 9.5),
                      anticipated = TRUE, instruments = "eps_i")
hold
#> <qpm_forecast> Canonical small open economy QPM (BKL, stationary trends) - 8 quarters ahead (h1 ... h8)
#>   conditions: 4 on i (anticipated; instruments: eps_i)
#>   implied shocks, max |sd|: eps_i 1.31
#>   mean (90% band) at h = 1, 4, 8:
#>     y_gap      -0.04 (-1.19, 1.11)  0.23 (-1.51, 1.98)  0.16 (-1.48, 1.81)
#>     pi         5.07 (3.03, 7.11)  5.66 (3.72, 7.61)  5.89 (2.51, 9.28)
#>     pi4        5.02 (4.51, 5.53)  5.34 (3.92, 6.76)  5.97 (   4, 7.94)
#>     i           9.5 ( 9.5,  9.5)   9.5 ( 9.5,  9.5)  9.62 (6.72, 12.5)
#>     r          4.29 (1.84, 6.75)   3.6 (1.32, 5.87)  4.01 (2.46, 5.55)
#>     r_gap      0.29 (-2.16, 2.75)  -0.4 (-2.69, 1.88)  0.01 (-1.56, 1.57)
#>     q          0.17 (-4.51, 4.85)  0.44 (-4.76, 5.64)  -0.68 (-5.02, 3.65)
#>     q_gap      0.17 (-4.5, 4.84)  0.44 (-4.72,  5.6)  -0.68 (-4.97,  3.6)
#>     q_bar      0 (-0.49, 0.49)  0 (-0.85, 0.85)  0 (-1.02, 1.02)
#>     r_bar         4 (3.67, 4.33)     4 (3.43, 4.57)     4 (3.32, 4.68)
#>     dy_obs     3.33 (-1.57, 8.24)  4.03 (-1.32, 9.39)  2.78 (-2.12, 7.69)
#>     dy_bar      3.5 (3.17, 3.83)   3.5 (2.97, 4.03)   3.5 ( 2.9,  4.1)
#>     ystar_gap  0 (-0.49, 0.49)  0 (-0.75, 0.75)  0 (-0.81, 0.81)
#>     istar         3 (2.51, 3.49)     3 (2.21, 3.79)     3 (2.11, 3.89)
#>     pistar        2 (1.18, 2.82)     2 (0.89, 3.11)     2 (0.87, 3.13)
#>     rstar         1 (-0.11, 2.11)     1 (-0.36, 2.36)     1 (-0.18, 2.18)
#>     prem          3 (2.18, 3.82)     3 (1.71, 4.29)     3 (1.55, 4.45)
```
