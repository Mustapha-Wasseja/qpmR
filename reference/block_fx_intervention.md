# Foreign-exchange intervention (managed float)

Turns the template's floating exchange rate into a managed one. A
leaning-against-the-wind rule responds to the real exchange rate gap,
and intervention enters the UIP block directly, so the same model spans
a continuum of regimes: `intensity = 0` is a free float, moderate values
a managed float, and large values approach a peg. Program countries —
where reserves, not just the policy rate, are the operative instrument —
live in the middle of that range.

## Usage

``` r
block_fx_intervention(intensity = 1, persistence = 0.6, sd = 1)
```

## Arguments

- intensity:

  Scales both the intervention response to the RER gap and its effect on
  the exchange rate. `0` reproduces a free float.

- persistence:

  Persistence of intervention (`h1`).

- sd:

  Standard deviation of the discretionary intervention shock.

## Value

A
[`qpm_block()`](https://mustapha-wasseja.github.io/qpmR/reference/qpm_block.md).

## Details

`fx_int` is intervention intensity, positive meaning sales of foreign
exchange in support of the domestic currency (which appreciates the real
exchange rate, lowering `q`).

## Examples

``` r
float <- qpm_solve(qpm_template("bkl"))
managed <- qpm_solve(add_block(qpm_template("bkl"),
                               block_fx_intervention(intensity = 1)))
# the same risk-premium shock moves the exchange rate less under management
```
