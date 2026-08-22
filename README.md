# qpmR

**Quarterly Projection Models for Monetary Policy Analysis in R.**

qpmR builds, solves, and simulates the semi-structural quarterly
projection models (QPM) used in central-bank Forecasting and Policy
Analysis Systems (FPAS): output gap, Phillips curve, forward-looking
policy rule, and exchange-rate block, with model-consistent
expectations.

The goal is the workflow, not just the equations:

```
data -> filtering -> gaps -> model -> baseline -> judgment -> scenarios -> report
```

Version 0.1 delivers the model layer of that chain.

## What works today (0.1)

- **A native R model language.** Declare gap-form models with
  `qpm_model()`: lags/leads as `x[-1]` / `E(x[+1])`, labels and units on
  every variable, calibration with typo protection
  (`qpm_calibrate()`). Long lags and leads (e.g. `E(pi4[+4])` in the
  policy rule) are handled automatically via auxiliary states.
- **A generalized-Schur (QZ) solver** (Klein 2000) with honest
  Blanchard–Kahn diagnostics: indeterminacy and explosiveness are
  reported as typed errors that say *which economics* usually causes
  them (Taylor principle, pure-UIP unit roots).
- **The canonical Berg–Karam–Laxton small-open-economy QPM** as a
  calibrated template: `qpm_template("bkl")` — IS curve, hybrid Phillips
  curve, forward-looking inflation-targeting rule, dampened UIP, and
  stationary trend/foreign processes, for an illustrative
  emerging-economy calibration ("Meridia", 5% inflation target).
- **Model dynamics and forecasting:** `irf()` with peak-effect tables,
  `simulate()`, `qpm_forecast()` with analytic fan bands,
  `steady_state()`, `eigen_table()`, and `qpm_lint()` for
  specification checks.

## Quickstart

```r
library(qpmR)

m <- qpm_template("bkl")          # canonical small open economy QPM
summary(m)

sol <- qpm_solve(m)               # QZ solution + Blanchard-Kahn check
sol

ir <- irf(sol, shock = "eps_i")   # 100bp-style policy tightening
plot(ir, vars = c("pi", "y_gap", "i", "q"))

histq <- simulate(sol, nsim = 48, seed = 7, burn = 20)
fc <- qpm_forecast(sol, from = histq, horizon = 12)
plot(fc, vars = c("pi", "i", "y_gap", "q"))

# transmission experiment: double exchange-rate pass-through
m2 <- qpm_calibrate(m, b3 = 0.2)
plot(irf(qpm_solve(m2), shock = "eps_q"), vars = c("pi", "i"))
```

## Roadmap

| Version | Focus |
|---|---|
| 0.1 | Model DSL, QZ solver, BK diagnostics, IRFs, simulation, forecasts, BKL template |
| 0.2 | Kalman filter/smoother (`qpm_filter()`): gaps, `r*`, equilibrium RER, shock decompositions, random-walk trends |
| 0.3 | Conditional forecasts (`qpm_condition()`, anticipated vs unanticipated), judgment ledger (`add_judgment()`), forecast rounds |
| 0.4 | Bayesian estimation, identification diagnostics, posterior fans |
| 1.0 | Full FPAS workflow: round store, revision decomposition, Quarto report templates, chart packs |

## Design commitments

1. **Everything has an escape hatch.** `sol$P`, `sol$Q`, `eigen_table()`
   expose the actual matrices; nothing is hidden in closures.
2. **Errors teach.** A Blanchard–Kahn failure names the economics that
   usually causes it, not just the rank condition it violates.
3. **Verification is cheap.** The test suite pins the solver to analytic
   solutions; cross-checks against Dynare are planned for the shipped
   templates.

## References

- Berg, A., Karam, P., & Laxton, D. (2006). *A Practical Model-Based
  Approach to Monetary Policy Analysis — Overview* (IMF WP/06/80) and
  the companion how-to guide (IMF WP/06/81).
- Klein, P. (2000). Using the generalized Schur form to solve a
  multivariate linear rational expectations model. *JEDC* 24(10).

## License

MIT.
