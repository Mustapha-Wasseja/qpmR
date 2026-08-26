# qpmR (development version)

The 1.0 reporting and audit layer, plus country-adaptation blocks.

## Reporting and audit

* `qpm_report()`: turns a round into the document a policy meeting is
  run from — executive summary with the numbers filled in, forecast
  table and fan charts, filtered gaps, shock decomposition, the
  judgment ledger with its implied shocks, an optional revision
  decomposition against the previous round, and a reproducibility
  appendix. The `.Rmd` source is always written (institutions replace
  the template's text, not its plumbing) and rendered to HTML/PDF/Word
  when pandoc or Quarto is available; where neither is — air-gapped
  forecasting machines, bare CI runners — it says so and returns the
  source rather than failing.
* `chart_pack()`: the standard round chart set (forecast fans,
  filtered latent states, shock decomposition, monetary transmission)
  as a multi-page PDF or numbered PNGs.
* `verify_round()`: re-runs an archived round from its own contents and
  checks that the published numbers come back, reporting the largest
  deviation, the worst variables, and any qpmR version drift. When the
  round is loaded from a store it also checks the human-readable CSV
  sidecars against the object, so a hand-edited audit trail is
  detected.
* Stacked-bar decomposition and revision charts leave headroom for
  their legends.

## Country adaptation

* `qpm_block()` / `add_block()`: reusable bundles of variables, shocks,
  parameters and equations that adapt a template to a country without
  forking it. Equations whose left-hand side names an existing variable
  replace that variable's equation; equations for newly declared
  variables are appended. Blocks compose, and each one is recorded in
  the model's `meta$blocks`.
* `block_food_cpi()`: headline CPI split into food and core. The
  Phillips curve moves to core, food gets its own persistence, stronger
  exchange-rate pass-through, and error correction on the relative food
  price, and headline becomes the weighted identity. Food is 30-50
  percent of the basket across most of sub-Saharan Africa and South
  Asia, where a single-inflation model is unusable; a food supply shock
  in this block raises headline while leaving core essentially
  untouched, which is the relative-price story policy should look
  through.
* `block_fx_intervention()`: a leaning-against-the-wind intervention
  rule entering the UIP block, so one model spans a continuum of
  exchange-rate regimes — `intensity = 0` reproduces the free float
  exactly, moderate values a managed float, large values approach a peg
  (the peak exchange-rate response to a risk-premium shock falls from
  0.97 to 0.53 to 0.08 across those settings).
* `qpm_template()` gains the `"bkl_food"` and `"managed_fx"` shortcuts.
* `qpm_diff()`: structural comparison of two models — variables,
  shocks, parameters and equations added, removed or changed, plus
  recalibrations — so a country team's customization is reviewable as a
  diff rather than a fork.

# qpmR 0.4.0

The estimation layer is complete.

## Identification, marginal likelihood, vignette

* `qpm_identify()`: Iskrev-style local identification diagnostics
  before any sampling — numerical Jacobians of the solved model
  (solution level) and of the observables' population moments (moment
  level, stationary models) with respect to the chosen parameters.
  Reports parameters with no effect, rank-deficient combinations, and
  near-collinear pairs that are only jointly identified. Unit-root
  models get the solution-level check with an explanatory note.
* `marginal_likelihood()`: log marginal likelihood by the modified
  harmonic mean (Geweke 1999) across truncation probabilities with a
  stability spread, plus a Laplace approximation at the mode in
  transformed space as a cross-check. Differences across models on the
  same data are log Bayes factors. `truncate()` priors are now
  renormalized numerically at construction so they contribute proper
  densities.
* New vignette `qpmR-estimation`: priors, the AR(1) estimation
  laboratory, identification, Bayes factors, and the full Czech
  estimation with its results discussed (including the honestly
  weakly-identified policy-response coefficient).

* `priors()`: the prior mini-language. `normal()`, `beta()`, `gamma()`,
  `invgamma()`, `uniform()`, and `truncate()` exist only inside
  `priors()` (evaluated in a controlled environment), so base R's
  `beta()` and `gamma()` functions are never masked. Beta/gamma/
  inverse-gamma use the mean/sd parametrization economists write down.
* `qpm_estimate()`: Bayesian estimation of any subset of structural
  parameters and shock standard deviations over the Kalman-filter
  likelihood. Posterior mode in transformed (unconstrained) space,
  BFGS Hessian as the proposal seed, adaptive random-walk Metropolis
  (Haario-style covariance adaptation during burn-in, acceptance
  targeted at 0.25), multiple sequential chains, split R-hat and
  Geyer effective sample sizes. Draws violating Blanchard-Kahn get
  zero weight (the usual determinacy truncation). `method = "mle"`
  reuses the machinery with flat priors on the declared supports.
* Printing reports mode, posterior mean, 90% interval, R-hat, ESS,
  and a "learned" column comparing posterior to prior spread -- a
  cheap identification diagnostic. `plot()` overlays prior and
  posterior densities. `coef()` extracts point estimates;
  `apply_estimate()` recalibrates the model at them.
* `posterior_forecast()`: fan charts integrating over the posterior --
  each draw re-solves the model and re-filters the data, so the bands
  combine future-shock and parameter uncertainty.
* Internal: `kalman_loglik()`, a storage-free filter pass for
  estimation speed.

# qpmR 0.3.0

The policy-analysis layer is complete.

## Forecast rounds and revision decomposition

* `qpm_round()`: one replayable artifact per forecast -- model,
  calibration, data vintage, filtration, and the conditioned forecast
  together. [qpm_condition()], `qpm_scenario()`, and `add_judgment()`
  apply to rounds directly.
* `save_round()` / `load_round()` / `list_rounds()`: a plain-directory
  round store; each round is a self-contained `round.rds` plus
  human-readable CSV sidecars (forecast, data, calibration, judgment)
  for auditing without R.
* `compare_rounds()`: the revision decomposition. The forecast revision
  between two rounds is split into parameters, data revisions, new data
  (outturns), conditions, and judgment by re-running the full pipeline
  swapping one ingredient at a time. Contributions telescope (they sum
  to the total exactly); the endpoints are verified against the
  archived rounds, so a version drift is reported rather than silently
  absorbed. Judgment overtaken by data (a conditioned quarter that has
  become an outturn) is dropped and reported. Waterfall printing and
  stacked revision charts.
* `next_quarters()` exported for quarter-label arithmetic; formulas in
  models are stored without environments, keeping serialized rounds
  small.

## Conditional forecasts, scenarios, judgment

* `qpm_condition()`: hard conditional forecasts. Impose paths on any
  variables at any horizons; qpmR backs out the minimum-norm structural
  shocks (in standard-deviation units, optionally restricted to
  `instruments`) that deliver them. The `anticipated` switch is
  explicit: `TRUE` means the conditioned path is announced at the start
  of the forecast and expectations react ahead of it, `FALSE` means
  period-by-period surprises. Anticipated propagation uses the exact
  news recursion `F_j = N^j Q`, `N = -(AP+B)^{-1} A`, verified in the
  tests against a brute-force perfect-foresight solve. Fan bands are
  recomputed as the Gaussian conditional distribution given the
  conditions (zero width at conditioned points). Announced rate holds
  reproduce the Laseen-Svensson (2011) anticipated-path reversal, as
  they should.
* `qpm_scenario()`: shock-based alternative scenarios (announced or
  surprise), additive on any forecast.
* `add_judgment()` / `judgment_log()`: the judgment ledger. State the
  adjustment in percentage points; qpmR back-solves the supporting
  shocks, keeps the forecast model-consistent, records author,
  timestamp and rationale, and flags judgment requiring shocks above
  two standard deviations. Entries are stored as absolute targets and
  the full condition/judgment set is re-solved jointly, so the ledger
  is replayable.
* Forecasts carry quarter labels (`2026-Q3` style) inherited from the
  filtration; conditions and judgment can be addressed by label or by
  horizon (`h3`). Conditioned and judgment points are marked on fan
  charts.

# qpmR 0.2.0

The filtration layer is complete.

## Kalman filter, smoother, decompositions

* `qpm_filter()`: Kalman filter + RTS smoother over the solved model.
  Jointly infers every latent state (output gap, neutral rate,
  equilibrium exchange rate, trends) and the historical structural
  shocks from any subset of observed variables, with missing data and
  ragged edges handled naturally. Innovation diagnostics (Ljung-Box,
  outlier flags) are computed and printed. The likelihood is tested
  against the exact closed-form Gaussian likelihood.
* `qpm_decompose()`: exact historical shock decompositions of the
  smoothed history (additivity verified internally), with stacked-bar
  plots.
* `state_space()`: exports the exact `T`, `R`, `Z`, `H`, `Qc`, `P1`
  matrices used internally, so other estimators can build on qpmR.
* `qpm_forecast()` accepts a `qpm_filtration` as `from`, forecasting
  from the smoothed end-of-sample state with the smoothed history kept
  for fan charts.

## Diffuse initialization and unit-root trends

* Models with unit roots (random-walk trends) now solve: roots within
  `unit_tol` of the unit circle count as stable (the usual qz-criterium
  convention) and are reported separately. Steady states with free
  trend levels use a minimum-norm least-squares normalization; a
  drifted random walk (no fixed point) is a typed
  `qpm_no_steady_state` error explaining the balanced-growth
  limitation.
* `qpm_filter()`/`state_space()` switch automatically to an approximate
  diffuse initialization (damped-Lyapunov large-variance prior,
  `kappa = 1e6`) when the model has unit roots. Exact Durbin-Koopman
  diffuse recursions remain on the roadmap.
* `qpm_template("bkl", trends = "rw")`: equilibrium real exchange rate
  and potential growth as driftless random walks; the neutral rate
  stays anchored by real interest parity (a free random walk there
  would make steady-state gaps indeterminate).
* The template gains a GDP-growth observation block
  (`dy_obs = dy_bar + 4 * (y_gap - y_gap[-1])`), so the model filters
  on actual national-accounts data without modelling the level of
  potential output.

## Example country dataset

* `czechia`: quarterly Czech data 1996Q1 onward in model units (CPI
  inflation QoQ and YoY, 3M PRIBOR, real CZK/EUR, GDP growth, EURIBOR,
  euro-area HICP), compiled reproducibly by `data-raw/czechia.R` from
  FRED/OECD/Eurostat/ECB public endpoints. Filtering it with the rw
  template reproduces the known history: the pre-GFC boom, the 2009
  and 2013 recessions, the COVID crater, the koruna's trend real
  appreciation, and the post-GFC fall in potential growth (pinned in
  the test suite).

## Smaller improvements

* Filtration and decomposition charts label the time axis with period
  labels; `plot()` on decompositions gains a `periods` window argument.
* Extended qualitative palette (no more color recycling with many
  shocks).

# qpmR 0.1.0

* Initial release: model DSL (`qpm_model()`, `x[-1]` / `E(x[+1])`,
  automatic auxiliary states), Klein/QZ solver with Blanchard-Kahn
  diagnostics, steady states, `irf()`, `simulate()`, `qpm_forecast()`
  with fan bands, `qpm_lint()`, and the canonical Berg-Karam-Laxton
  small-open-economy template `qpm_template("bkl")`.
