# Shipped model templates

`"bkl"` is the canonical semi-structural small-open-economy quarterly
projection model in the tradition of Berg, Karam and Laxton (2006, IMF
WP/06/80-81): an IS curve, a hybrid Phillips curve, a forward-looking
inflation-targeting policy rule, and a dampened (hybrid) UIP block, plus
equilibrium-trend and foreign processes, and an observation block for
real GDP growth (`dy_obs = dy_bar + 4 * (y_gap - y_gap[-1])`), so the
model can be filtered on actual national-accounts data without modelling
the level of potential output. The default calibration is illustrative,
for a higher-inflation emerging economy ("Meridia"); it is not any
actual country. See
[czechia](https://mustapha-wasseja.github.io/qpmR/reference/czechia.md)
for a real dataset and a matching recalibration example.

## Usage

``` r
qpm_template(
  name = c("bkl", "bkl_food", "managed_fx"),
  trends = c("stationary", "rw")
)
```

## Arguments

- name:

  Template name: `"bkl"`, `"bkl_food"`, or `"managed_fx"`.

- trends:

  `"stationary"` or `"rw"`; see Details.

## Value

A calibrated `qpm_model`.

## Details

`trends` selects the equilibrium processes:

- `"stationary"` (default): AR(1) trends anchored at steady-state
  parameters; the model is fully stationary.

- `"rw"`: driftless random walks for the equilibrium real exchange rate
  and potential growth (whose levels are pure normalizations); the
  neutral rate stays anchored by real interest parity (`rstar + prem`),
  since a free random walk there would leave steady-state gaps
  indeterminate. The model then has unit roots: free trend levels are
  normalized to minimum norm in the steady state, and
  [`qpm_filter()`](https://mustapha-wasseja.github.io/qpmR/reference/qpm_filter.md)
  switches to diffuse initialization automatically. This is the
  configuration for real data, where trends drift.

Conventions: gaps in percentage points; inflation QoQ annualised;
interest rates in percent per annum; `q` is 100 times the log real
exchange rate, an increase is a real depreciation; `dy_obs` is QoQ
annualised real GDP growth.

Country-shaped variants are shipped as shortcuts for the canonical model
plus an extension block (see
[`add_block()`](https://mustapha-wasseja.github.io/qpmR/reference/add_block.md)):

- `"bkl_food"` — headline CPI split into food and core
  ([`block_food_cpi()`](https://mustapha-wasseja.github.io/qpmR/reference/block_food_cpi.md)),
  the configuration for economies where food is a large share of the
  basket.

- `"managed_fx"` — a leaning-against-the-wind intervention rule entering
  the UIP block
  ([`block_fx_intervention()`](https://mustapha-wasseja.github.io/qpmR/reference/block_fx_intervention.md)).

## References

Berg, A., Karam, P., and Laxton, D. (2006). A Practical Model-Based
Approach to Monetary Policy Analysis - Overview. IMF Working Paper
06/80; and the companion How-To guide, IMF WP 06/81.

## Examples

``` r
m <- qpm_template("bkl")
summary(m)
#> <qpm_model> Canonical small open economy QPM (BKL, stationary trends)
#>   17 endogenous variables - 12 shocks - 25 parameters
#>   dynamics: max lag 3, max lead 4 (auxiliary states added automatically at solve time)
#>   calibration:
#>     a1 = 0.7, a2 = 0.1, a3 = 0.2, a4 = 0.1, a5 = 0.25, b1 = 0.7, b2 = 0.25,
#>     b3 = 0.1, c1 = 0.7, c2 = 1.5, c3 = 0.5, e1 = 0.7, pi_tar = 5, istar_ss
#>     = 3, pistar_ss = 2, prem_ss = 3, qbar_ss = 0, g_ss = 3.5, rho_qbar =
#>     0.9, rho_rbar = 0.9, rho_g = 0.85, rho_ystar = 0.8, rho_istar = 0.85,
#>     rho_pistar = 0.7, rho_prem = 0.85
#>   variables: y_gap, pi, pi4, i, r, r_gap, q, q_gap, ... (see summary())
#> 
#> Variables:
#>  name      label                                          unit  
#>  y_gap     Output gap                                     pp    
#>  pi        CPI inflation, QoQ annualised                  pct   
#>  pi4       CPI inflation, 4-quarter average               pct   
#>  i         Policy rate                                    pct pa
#>  r         Real interest rate                             pct pa
#>  r_gap     Real rate gap                                  pp    
#>  q         Real exchange rate, 100*log (+ = depreciation) index 
#>  q_gap     Real exchange rate gap                         pp    
#>  q_bar     Equilibrium real exchange rate                 index 
#>  r_bar     Neutral real interest rate                     pct pa
#>  dy_obs    Real GDP growth, QoQ annualised                pct   
#>  dy_bar    Potential output growth, annualised            pct   
#>  ystar_gap Foreign output gap                             pp    
#>  istar     Foreign nominal interest rate                  pct pa
#>  pistar    Foreign inflation                              pct   
#>  rstar     Foreign real interest rate                     pct pa
#>  prem      Country risk premium                           pp    
#> 
#> Equations:
#>    1. y_gap ~ a1 * y_gap[-1] + a2 * E(y_gap[+1]) - a3 * r_gap + a4 * q_gap + a5 * ystar_gap + eps_y
#>    2. pi ~ b1 * pi[-1] + (1 - b1) * E(pi[+1]) + b2 * y_gap + b3 * q_gap + eps_pi
#>    3. pi4 ~ (pi + pi[-1] + pi[-2] + pi[-3])/4
#>    4. i ~ c1 * i[-1] + (1 - c1) * (r_bar + pi4 + c2 * (E(pi4[+4]) - pi_tar) + c3 * y_gap) + eps_i
#>    5. r ~ i - E(pi[+1])
#>    6. r_gap ~ r - r_bar
#>    7. q ~ e1 * E(q[+1]) + (1 - e1) * q[-1] - (r - rstar - prem)/4 + eps_q
#>    8. q_gap ~ q - q_bar
#>    9. dy_obs ~ dy_bar + 4 * (y_gap - y_gap[-1]) + eps_dy
#>   10. ystar_gap ~ rho_ystar * ystar_gap[-1] + eps_ystar
#>   11. istar ~ rho_istar * istar[-1] + (1 - rho_istar) * istar_ss + eps_istar
#>   12. pistar ~ rho_pistar * pistar[-1] + (1 - rho_pistar) * pistar_ss + eps_pistar
#>   13. rstar ~ istar - E(pistar[+1])
#>   14. prem ~ rho_prem * prem[-1] + (1 - rho_prem) * prem_ss + eps_prem
#>   15. q_bar ~ rho_qbar * q_bar[-1] + (1 - rho_qbar) * qbar_ss + eps_qbar
#>   16. r_bar ~ rho_rbar * r_bar[-1] + (1 - rho_rbar) * (istar_ss - pistar_ss + prem_ss) + eps_rbar
#>   17. dy_bar ~ rho_g * dy_bar[-1] + (1 - rho_g) * g_ss + eps_g
#> 
#> Shock standard deviations:
#>   eps_y = 0.5, eps_pi = 1, eps_i = 0.5, eps_q = 1.5, eps_qbar = 0.3,
#>   eps_rbar = 0.2, eps_g = 0.2, eps_dy = 1, eps_ystar = 0.3, eps_istar =
#>   0.3, eps_pistar = 0.5, eps_prem = 0.5
m_rw <- qpm_template("bkl", trends = "rw")
```
