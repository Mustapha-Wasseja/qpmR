# qpmR (development version)

The start of the 0.3 policy-analysis layer.

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
