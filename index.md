# qpmR

**Quarterly Projection Models for Monetary Policy Analysis in R.**

qpmR builds, solves, and simulates the semi-structural quarterly
projection models (QPM) used in central-bank Forecasting and Policy
Analysis Systems (FPAS): output gap, Phillips curve, forward-looking
policy rule, and exchange-rate block, with model-consistent
expectations.

The goal is the workflow, not just the equations:

    data -> filtering -> gaps -> model -> baseline -> judgment -> scenarios -> report

Version 0.1 delivers the model layer of that chain.

## What works today (0.1)

- **A native R model language.** Declare gap-form models with
  [`qpm_model()`](https://mustapha-wasseja.github.io/qpmR/reference/qpm_model.md):
  lags/leads as `x[-1]` / `E(x[+1])`, labels and units on every
  variable, calibration with typo protection
  ([`qpm_calibrate()`](https://mustapha-wasseja.github.io/qpmR/reference/qpm_calibrate.md)).
  Long lags and leads (e.g. `E(pi4[+4])` in the policy rule) are handled
  automatically via auxiliary states.
- **A generalized-Schur (QZ) solver** (Klein 2000) with honest
  Blanchard–Kahn diagnostics: indeterminacy and explosiveness are
  reported as typed errors that say *which economics* usually causes
  them (Taylor principle, pure-UIP unit roots).
- **The canonical Berg–Karam–Laxton small-open-economy QPM** as a
  calibrated template: `qpm_template("bkl")` — IS curve, hybrid Phillips
  curve, forward-looking inflation-targeting rule, dampened UIP, and
  stationary trend/foreign processes, for an illustrative
  emerging-economy calibration (“Meridia”, 5% inflation target).
- **Model dynamics and forecasting:**
  [`irf()`](https://mustapha-wasseja.github.io/qpmR/reference/irf.md)
  with peak-effect tables,
  [`simulate()`](https://rdrr.io/r/stats/simulate.html),
  [`qpm_forecast()`](https://mustapha-wasseja.github.io/qpmR/reference/qpm_forecast.md)
  with analytic fan bands,
  [`steady_state()`](https://mustapha-wasseja.github.io/qpmR/reference/steady_state.md),
  [`eigen_table()`](https://mustapha-wasseja.github.io/qpmR/reference/eigen_table.md),
  and
  [`qpm_lint()`](https://mustapha-wasseja.github.io/qpmR/reference/qpm_lint.md)
  for specification checks.

And since 0.2 — the filtration layer:

- **[`qpm_filter()`](https://mustapha-wasseja.github.io/qpmR/reference/qpm_filter.md)**
  — Kalman filter + RTS smoother over the solved model: jointly infers
  every latent state (output gap, neutral rate, equilibrium exchange
  rate, trends) and the historical structural shocks from whatever
  subset of variables you observe. Missing data and ragged edges
  handled; innovation diagnostics (Ljung–Box, outlier flags) printed.
  The likelihood is tested against the exact closed-form Gaussian
  likelihood.
- **[`qpm_decompose()`](https://mustapha-wasseja.github.io/qpmR/reference/qpm_decompose.md)**
  — exact historical shock decompositions of the smoothed history
  (contributions verified to sum to the states), with stacked-bar
  charts.
- **[`state_space()`](https://mustapha-wasseja.github.io/qpmR/reference/state_space.md)**
  — the exact `T`, `R`, `Z`, `H`, `Qc`, `P1` matrices used internally,
  exported so other estimators can build on qpmR.
- **`qpm_forecast(from = <filtration>)`** — forecast from the smoothed
  end-of-sample state, with the smoothed history on the fan chart.
- **Random-walk trends and diffuse initialization** —
  `qpm_template("bkl", trends = "rw")` makes the equilibrium exchange
  rate and potential growth unit-root processes; the solver counts unit
  roots explicitly and the filter switches to a diffuse prior
  automatically.
- **A real country dataset** — `czechia`, quarterly from 1996 in model
  units, compiled reproducibly from FRED/OECD/Eurostat/ECB public
  endpoints. Filtering it reproduces the known history: the pre-GFC
  boom, the 2009 and 2013 recessions, the COVID crater, the koruna’s
  trend real appreciation, and the post-GFC fall in potential growth —
  all pinned in the test suite.

``` r

mcz <- qpm_calibrate(qpm_template("bkl", trends = "rw"),
                     pi_tar = 2, istar_ss = 2, pistar_ss = 2, prem_ss = 1)
cz <- czechia[czechia$period >= "1999",
              c("period", "pi4", "i", "q", "dy_obs", "istar", "pistar")]
fit <- qpm_filter(mcz, cz)
plot(fit, vars = c("y_gap", "dy_bar", "r_bar", "q_gap"))
plot(qpm_decompose(fit), var = "pi4")
```

And since 0.3 — the policy-analysis layer:

- **[`qpm_condition()`](https://mustapha-wasseja.github.io/qpmR/reference/qpm_condition.md)**
  — hard conditional forecasts with the minimum-norm implied shocks
  reported in standard deviations, an explicit `anticipated` switch
  (announced-at-start vs period-by-period surprises — materially
  different in any forward-looking model), instrument restrictions, and
  conditional fan bands that collapse at conditioned points. The
  anticipation recursion is verified against brute-force perfect
  foresight in the test suite.
- **[`qpm_scenario()`](https://mustapha-wasseja.github.io/qpmR/reference/qpm_scenario.md)**
  — shock-based alternatives, announced or surprise.
- **[`add_judgment()`](https://mustapha-wasseja.github.io/qpmR/reference/add_judgment.md)
  /
  [`judgment_log()`](https://mustapha-wasseja.github.io/qpmR/reference/judgment_log.md)**
  — judgment as a first-class, logged operation: state the change, qpmR
  back-solves the supporting shocks, records author/time/rationale, and
  flags anything requiring more than two standard deviations.
- **Forecast rounds** —
  [`qpm_round()`](https://mustapha-wasseja.github.io/qpmR/reference/qpm_round.md)
  archives the whole pipeline (model + calibration + data vintage +
  filtration + conditioned forecast) as one replayable object;
  [`save_round()`](https://mustapha-wasseja.github.io/qpmR/reference/save_round.md)
  /
  [`load_round()`](https://mustapha-wasseja.github.io/qpmR/reference/save_round.md)
  /
  [`list_rounds()`](https://mustapha-wasseja.github.io/qpmR/reference/save_round.md)
  manage a plain-directory store with CSV sidecars for auditing without
  R.
- **[`compare_rounds()`](https://mustapha-wasseja.github.io/qpmR/reference/compare_rounds.md)
  — the revision decomposition.** “Inflation for 2027-Q1 is 0.55pp
  higher than we said in March: +0.15 new outturns, +0.40 judgment.”
  Computed by re-running the pipeline swapping one ingredient at a time
  (parameters → data revisions → new data → conditions → judgment); the
  contributions telescope exactly and the endpoints are verified against
  the archived rounds.

``` r

base <- qpm_forecast(qpm_solve(mcz), from = fit, horizon = 12)
hold <- qpm_condition(base, i = c("2026-Q3" = 3.5, "2026-Q4" = 3.5),
                      anticipated = TRUE, instruments = "eps_i")

rA <- qpm_round("2026-Q1 March", mcz, cz_to_2025Q4, horizon = 12)
rB <- add_judgment(qpm_round("2026-Q3 September", mcz, cz, horizon = 12),
                   pi4 = c("2027-Q1" = 0.4), author = "prices desk",
                   rationale = "announced energy-tariff increase")
compare_rounds(rA, rB)
```

And since 0.4 — the estimation layer:

- **[`priors()`](https://mustapha-wasseja.github.io/qpmR/reference/priors.md)**
  — a prior mini-language (`beta`, `gamma`, `invgamma`, `normal`,
  `uniform`, `truncate`) in the mean/sd parametrization economists write
  down, scoped inside
  [`priors()`](https://mustapha-wasseja.github.io/qpmR/reference/priors.md)
  so base R’s [`beta()`](https://rdrr.io/r/base/Special.html) and
  [`gamma()`](https://rdrr.io/r/base/Special.html) are never masked.
- **[`qpm_estimate()`](https://mustapha-wasseja.github.io/qpmR/reference/qpm_estimate.md)**
  — Bayesian estimation of any subset of parameters and shock sds over
  the Kalman-filter likelihood: posterior mode, adaptive random-walk
  Metropolis seeded by the BFGS Hessian, split R-hat / ESS diagnostics,
  and a “learned” column comparing posterior to prior spread.
  `method = "mle"` uses the same machinery.
- **[`posterior_forecast()`](https://mustapha-wasseja.github.io/qpmR/reference/posterior_forecast.md)**
  — fan charts that integrate over the posterior: every draw re-solves
  the model and re-filters the data.
- **[`qpm_identify()`](https://mustapha-wasseja.github.io/qpmR/reference/qpm_identify.md)**
  — Iskrev-style identification diagnostics *before* sampling: which
  parameters have no effect, which are only jointly identified, where
  the Jacobian loses rank.
- **[`marginal_likelihood()`](https://mustapha-wasseja.github.io/qpmR/reference/marginal_likelihood.md)**
  — modified harmonic mean with a Laplace cross-check; differences
  across models are log Bayes factors.

And in the development version (1.0 — reporting, audit, country
adaptation):

- **[`qpm_report()`](https://mustapha-wasseja.github.io/qpmR/reference/qpm_report.md)**
  — a round becomes the monetary policy report: an executive summary
  with the numbers filled in, fan charts, gaps, the shock decomposition,
  the judgment ledger, the revision against the previous round, and a
  reproducibility appendix. The `.Rmd` source is always written so teams
  edit the text, not the plumbing; rendering degrades gracefully where
  pandoc is unavailable.
- **[`chart_pack()`](https://mustapha-wasseja.github.io/qpmR/reference/chart_pack.md)**
  — the standard round chart set as a multi-page PDF.
- **[`verify_round()`](https://mustapha-wasseja.github.io/qpmR/reference/verify_round.md)**
  — re-runs an archived round and confirms the published numbers still
  come back, flagging version drift and hand-edited CSV sidecars.

``` r

verify_round(r)                       # does the archive still reproduce?
chart_pack(r, "chart_pack.pdf")
qpm_report(r, "mpr.html", compare_to = previous_round)
```

- **[`add_block()`](https://mustapha-wasseja.github.io/qpmR/reference/add_block.md)**
  — extension blocks that adapt a template to a country without forking
  it, composable and recorded in the model.
- **[`block_food_cpi()`](https://mustapha-wasseja.github.io/qpmR/reference/block_food_cpi.md)**
  — headline CPI split into food and core, the configuration every
  LIC/EM engagement needs and rebuilds by hand. A food supply shock
  moves headline while leaving core untouched.
- **[`block_fx_intervention()`](https://mustapha-wasseja.github.io/qpmR/reference/block_fx_intervention.md)**
  — a managed float: one model spanning free float through peg by a
  single `intensity` argument.
- **[`qpm_diff()`](https://mustapha-wasseja.github.io/qpmR/reference/qpm_diff.md)**
  — a country customization reviewed as a diff.

``` r

m <- add_block(qpm_template("bkl"), block_food_cpi(weight = 0.45))
plot(irf(qpm_solve(m), shock = "eps_pifood"),
     vars = c("pi_food", "pi", "pi_core", "i"))
qpm_diff(qpm_template("bkl"), m)
```

``` r

est <- qpm_estimate(mcz, cz, priors(
  b1 = beta(0.70, 0.10), b2 = gamma(0.25, 0.10), b3 = gamma(0.10, 0.05),
  c1 = beta(0.70, 0.10), c2 = truncate(normal(1.5, 0.25), lower = 1),
  eps_pi = invgamma(1, 0.5)
), iter = 4000, chains = 2)
est
plot(est)                                   # prior vs posterior
plot(posterior_forecast(est, horizon = 12)) # parameter-uncertainty fans
```

## Quickstart

``` r

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
|----|----|
| 0.1 | Model DSL, QZ solver, BK diagnostics, IRFs, simulation, forecasts, BKL template — done |
| 0.2 | Kalman filter/smoother, shock decompositions, unit-root trends with diffuse initialization, real country dataset (`czechia`) — done |
| 0.3 | Conditional forecasts (anticipated vs unanticipated), scenarios, judgment ledger, forecast rounds, round store, revision decomposition — done |
| 0.4 | Bayesian estimation (priors, adaptive RWM, R-hat/ESS), identification diagnostics, marginal likelihood, posterior fans, estimation vignette — done |
| 1.0 | Country adaptation (extension blocks, [`qpm_diff()`](https://mustapha-wasseja.github.io/qpmR/reference/qpm_diff.md)), reporting ([`qpm_report()`](https://mustapha-wasseja.github.io/qpmR/reference/qpm_report.md), [`chart_pack()`](https://mustapha-wasseja.github.io/qpmR/reference/chart_pack.md)) and audit ([`verify_round()`](https://mustapha-wasseja.github.io/qpmR/reference/verify_round.md)) — done; CRAN submission next |

## Does it agree with Dynare?

Yes — and you can check rather than take it on trust.
[`write_dynare()`](https://mustapha-wasseja.github.io/qpmR/reference/write_dynare.md)
exports any model as a `.mod` file, and the test suite pins qpmR’s
impulse responses to golden files produced by Dynare 6.0:

``` r

write_dynare(qpm_template("bkl"), "bkl.mod")
```

Across **4080 impulse-response points** (12 shocks x 17 variables x 20
quarters) the largest discrepancy is **1.4e-14**, with steady states
agreeing to 8e-14. The food-block model agrees to 1.7e-14, which also
validates
[`add_block()`](https://mustapha-wasseja.github.io/qpmR/reference/add_block.md)
independently — Dynare parses the original equations and builds its own
auxiliary variables, so the two implementations agree only if both
handle long leads and lags correctly. Regenerate the golden files with
`data-raw/dynare_golden.R`.

## Speed

The Kalman filter and the stationary-covariance solve are compiled
(RcppArmadillo). Both keep reference implementations in R, and the test
suite pins the compiled paths to them to machine precision — that
agreement is what makes the fast path trustworthy. Use
`options(qpmR.use_cpp = FALSE)` to fall back to R.

A posterior draw on the Czech model (22 states, 110 quarters) costs 73
ms, against 181 ms in pure R, so a 6000-draw estimate takes about seven
minutes rather than eighteen. The largest single gain was not the filter
but replacing the `O(N^6)` Kronecker solution of the Lyapunov equation
with `O(N^3)` squaring: 39x on that step alone, and it also speeds up
[`model_properties()`](https://mustapha-wasseja.github.io/qpmR/reference/model_properties.md),
[`qpm_rule_eval()`](https://mustapha-wasseja.github.io/qpmR/reference/qpm_rule_eval.md)
and
[`qpm_identify()`](https://mustapha-wasseja.github.io/qpmR/reference/qpm_identify.md).

## Testing

466 assertions across 18 files, at **87.7% line coverage** — measured on
every push by the `test-coverage` workflow. The suite pins the solver to
analytic solutions (AR(1), hybrid roots, brute-force perfect foresight),
the Kalman filter to the exact closed-form Gaussian likelihood, the
revision decomposition to exact telescoping, and the whole solver to
Dynare (above).

To publish the coverage percentage as a badge, add a `CODECOV_TOKEN`
repository secret from <https://app.codecov.io>; the workflow already
uploads to Codecov and only needs the token.

## Design commitments

1.  **Everything has an escape hatch.** `sol$P`, `sol$Q`,
    [`eigen_table()`](https://mustapha-wasseja.github.io/qpmR/reference/eigen_table.md)
    expose the actual matrices; nothing is hidden in closures.
2.  **Errors teach.** A Blanchard–Kahn failure names the economics that
    usually causes it, not just the rank condition it violates.
3.  **Verification is cheap.** The test suite pins the solver to
    analytic solutions; cross-checks against Dynare are planned for the
    shipped templates.

## References

- Berg, A., Karam, P., & Laxton, D. (2006). *A Practical Model-Based
  Approach to Monetary Policy Analysis — Overview* (IMF WP/06/80) and
  the companion how-to guide (IMF WP/06/81).
- Klein, P. (2000). Using the generalized Schur form to solve a
  multivariate linear rational expectations model. *JEDC* 24(10).

## License

MIT.
