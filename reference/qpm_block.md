# Model extension blocks

A block is a documented, reusable bundle of variables, shocks,
parameters and equations that adapts a template to a country. Blocks are
how a technical-assistance engagement customizes the canonical model
without forking it:
[`add_block()`](https://mustapha-wasseja.github.io/qpmR/reference/add_block.md)
applies one,
[`qpm_diff()`](https://mustapha-wasseja.github.io/qpmR/reference/qpm_diff.md)
shows exactly what changed, and the result is an ordinary `qpm_model`.

## Usage

``` r
qpm_block(
  name,
  variables = NULL,
  shocks = NULL,
  params = list(),
  sigma = NULL,
  equations = NULL,
  description = ""
)
```

## Arguments

- name:

  Block name, used in printing and in the model's history.

- variables:

  New variables, from
  [`vars()`](https://mustapha-wasseja.github.io/qpmR/reference/vars.md)
  (optional).

- shocks:

  New shocks, from
  [`shocks()`](https://mustapha-wasseja.github.io/qpmR/reference/shocks.md)
  (optional).

- params:

  Named list of new parameters (optional).

- sigma:

  Named vector of standard deviations for the new shocks (optional;
  default 1).

- equations:

  Equations, from
  [`eqs()`](https://mustapha-wasseja.github.io/qpmR/reference/eqs.md):
  replacements for existing variables and definitions for new ones.

- description:

  One-line description of what the block does.

## Value

An object of class `qpm_block`.

## Details

Equations whose left-hand side names a variable that already exists
**replace** that variable's equation; equations for newly declared
variables are appended. Left-hand sides must be bare variable names.

## See also

[`block_food_cpi()`](https://mustapha-wasseja.github.io/qpmR/reference/block_food_cpi.md),
[`block_fx_intervention()`](https://mustapha-wasseja.github.io/qpmR/reference/block_fx_intervention.md)

## Examples

``` r
b <- qpm_block(
  name = "risk premium shifter",
  params = list(prem_extra = 0),
  equations = eqs(prem ~ rho_prem * prem[-1] +
                    (1 - rho_prem) * (prem_ss + prem_extra) + eps_prem)
)
m <- add_block(qpm_template("bkl"), b)
```
