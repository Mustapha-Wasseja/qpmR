# Disaggregated CPI: food and core inflation

Splits headline inflation into food and core. Food is 30-50 percent of
the consumption basket across most of sub-Saharan Africa and South Asia,
and a single-inflation model is unusable there: supply shocks to food
dominate headline, but monetary policy should look through the
relative-price component. Practically every technical-assistance
engagement rebuilds this split by hand.

## Usage

``` r
block_food_cpi(
  weight = 0.35,
  persistence = 0.5,
  demand = 0.2,
  passthrough = 0.25,
  correction = 0.1,
  sd = 3
)
```

## Arguments

- weight:

  Food share of the CPI basket (`w_food`).

- persistence:

  Food inflation persistence (`f1`).

- demand:

  Output-gap coefficient in food inflation (`f2`).

- passthrough:

  Real-exchange-rate coefficient in food inflation (`f3`); normally
  larger than core's, food being more tradable.

- correction:

  Error-correction speed on the relative food price (`f4`); must be
  positive for the relative price to be pinned down.

- sd:

  Standard deviation of the food supply shock.

## Value

A
[`qpm_block()`](https://mustapha-wasseja.github.io/qpmR/reference/qpm_block.md).

## Details

The block replaces headline inflation with an identity and adds:

- `pi_core` — the Phillips curve, now for core inflation (it keeps the
  template's `b1`, `b2`, `b3` and the `eps_pi` shock);

- `pi_food` — food inflation: its own persistence, expectations of
  headline, demand, a stronger exchange-rate pass-through than core, and
  error correction on the relative food price;

- `rp_food` — the relative food price gap, which accumulates the
  food-core inflation differential and mean-reverts through `f4`.

Headline is `pi = w_food * pi_food + (1 - w_food) * pi_core`, so
everything downstream (the 4-quarter average, the Fisher equation, the
policy rule) continues to use headline. To target core instead, replace
the policy rule with another block.

## Examples

``` r
m <- add_block(qpm_template("bkl"), block_food_cpi(weight = 0.45))
sol <- qpm_solve(m)
plot(irf(sol, shock = "eps_pifood"), vars = c("pi_food", "pi", "pi_core", "i"))
```
