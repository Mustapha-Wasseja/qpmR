# qpmR (development version)

The start of the 0.2 filtration layer:

* `qpm_filter()`: Kalman filter + RTS smoother over the solved model.
  Jointly infers every latent state (output gap, neutral rate,
  equilibrium exchange rate, trends) and the historical structural
  shocks from any subset of observed variables, with missing data and
  ragged edges handled naturally. Innovation diagnostics (Ljung-Box,
  outlier flags) are computed and printed.
* `qpm_decompose()`: exact historical shock decompositions of the
  smoothed history, with stacked-bar plots.
* `state_space()`: exports the exact `T`, `R`, `Z`, `H`, `Qc`, `P1`
  matrices used internally, so other estimators can build on qpmR.
* `qpm_forecast()` now accepts a `qpm_filtration` as `from`, forecasting
  from the smoothed end-of-sample state with the smoothed history kept
  for fan charts.

# qpmR 0.1.0

* Initial release: model DSL (`qpm_model()`, `x[-1]` / `E(x[+1])`,
  automatic auxiliary states), Klein/QZ solver with Blanchard-Kahn
  diagnostics, steady states, `irf()`, `simulate()`, `qpm_forecast()`
  with fan bands, `qpm_lint()`, and the canonical Berg-Karam-Laxton
  small-open-economy template `qpm_template("bkl")`.
