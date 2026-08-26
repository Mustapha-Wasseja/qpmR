# Package index

## Specifying a model

Declare a model in R, or start from the canonical small open economy
template and check it before you use it.

- [`qpm_model()`](https://mustapha-wasseja.github.io/qpmR/reference/qpm_model.md)
  : Define a quarterly projection model
- [`vars()`](https://mustapha-wasseja.github.io/qpmR/reference/vars.md)
  : Declare the endogenous variables of a model
- [`var()`](https://mustapha-wasseja.github.io/qpmR/reference/var.md) :
  Declare a model variable with a label and unit
- [`shocks()`](https://mustapha-wasseja.github.io/qpmR/reference/shocks.md)
  : Declare the structural shocks of a model
- [`eqs()`](https://mustapha-wasseja.github.io/qpmR/reference/eqs.md) :
  Declare model equations
- [`E()`](https://mustapha-wasseja.github.io/qpmR/reference/E.md) :
  Expectations operator (equation syntax only)
- [`qpm_calibrate()`](https://mustapha-wasseja.github.io/qpmR/reference/qpm_calibrate.md)
  : Update a model's calibration
- [`qpm_template()`](https://mustapha-wasseja.github.io/qpmR/reference/qpm_template.md)
  : Shipped model templates
- [`qpm_lint()`](https://mustapha-wasseja.github.io/qpmR/reference/qpm_lint.md)
  : Check a model for common specification problems

## Adapting a model to a country

Extension blocks bundle the changes a country needs — disaggregated food
inflation, a managed exchange rate — so an adaptation is reviewable as a
diff rather than a fork.

- [`qpm_block()`](https://mustapha-wasseja.github.io/qpmR/reference/qpm_block.md)
  : Model extension blocks
- [`add_block()`](https://mustapha-wasseja.github.io/qpmR/reference/add_block.md)
  : Apply an extension block to a model
- [`block_food_cpi()`](https://mustapha-wasseja.github.io/qpmR/reference/block_food_cpi.md)
  : Disaggregated CPI: food and core inflation
- [`block_fx_intervention()`](https://mustapha-wasseja.github.io/qpmR/reference/block_fx_intervention.md)
  : Foreign-exchange intervention (managed float)
- [`qpm_diff()`](https://mustapha-wasseja.github.io/qpmR/reference/qpm_diff.md)
  : Compare two models structurally

## Solving and model properties

The generalized Schur solution, its diagnostics, and what the model
implies about transmission.

- [`qpm_solve()`](https://mustapha-wasseja.github.io/qpmR/reference/qpm_solve.md)
  : Solve a model under model-consistent expectations
- [`steady_state()`](https://mustapha-wasseja.github.io/qpmR/reference/steady_state.md)
  : Steady state of a model or solution
- [`eigen_table()`](https://mustapha-wasseja.github.io/qpmR/reference/eigen_table.md)
  : Generalized eigenvalues of a solved model
- [`irf()`](https://mustapha-wasseja.github.io/qpmR/reference/irf.md) :
  Impulse response functions
- [`simulate(`*`<qpm_solution>`*`)`](https://mustapha-wasseja.github.io/qpmR/reference/simulate.qpm_solution.md)
  : Simulate a solved model
- [`state_space()`](https://mustapha-wasseja.github.io/qpmR/reference/state_space.md)
  : State-space representation of a solved model

## Filtering the data

Infer the latent states — output gap, neutral rate, equilibrium exchange
rate — and the historical shocks behind them.

- [`qpm_filter()`](https://mustapha-wasseja.github.io/qpmR/reference/qpm_filter.md)
  : Estimate latent states from data (Kalman filter/smoother)
- [`qpm_decompose()`](https://mustapha-wasseja.github.io/qpmR/reference/qpm_decompose.md)
  [`plot(`*`<qpm_decomposition>`*`)`](https://mustapha-wasseja.github.io/qpmR/reference/qpm_decompose.md)
  : Historical shock decomposition

## Forecasting and policy analysis

The baseline projection, assumed paths, alternative scenarios, and
judgment as a logged and auditable operation.

- [`qpm_forecast()`](https://mustapha-wasseja.github.io/qpmR/reference/qpm_forecast.md)
  : Model forecast with uncertainty bands
- [`qpm_condition()`](https://mustapha-wasseja.github.io/qpmR/reference/qpm_condition.md)
  : Conditional forecasts: impose paths, back out the shocks
- [`qpm_scenario()`](https://mustapha-wasseja.github.io/qpmR/reference/qpm_scenario.md)
  : Shock-based alternative scenarios
- [`add_judgment()`](https://mustapha-wasseja.github.io/qpmR/reference/add_judgment.md)
  : Add logged judgment to a forecast
- [`judgment_log()`](https://mustapha-wasseja.github.io/qpmR/reference/judgment_log.md)
  : Print a forecast's judgment ledger
- [`posterior_forecast()`](https://mustapha-wasseja.github.io/qpmR/reference/posterior_forecast.md)
  : Forecast with parameter uncertainty (posterior fan)

## Forecast rounds

A round binds model, calibration, data vintage and forecast into one
replayable artefact — then answers why the forecast moved, and whether
the archive still reproduces.

- [`qpm_round()`](https://mustapha-wasseja.github.io/qpmR/reference/qpm_round.md)
  : Forecast rounds: one replayable artifact per forecast
- [`save_round()`](https://mustapha-wasseja.github.io/qpmR/reference/save_round.md)
  [`load_round()`](https://mustapha-wasseja.github.io/qpmR/reference/save_round.md)
  [`list_rounds()`](https://mustapha-wasseja.github.io/qpmR/reference/save_round.md)
  : Save, load, and list forecast rounds
- [`compare_rounds()`](https://mustapha-wasseja.github.io/qpmR/reference/compare_rounds.md)
  [`plot(`*`<qpm_revision>`*`)`](https://mustapha-wasseja.github.io/qpmR/reference/compare_rounds.md)
  : Compare two forecast rounds: the revision decomposition
- [`verify_round()`](https://mustapha-wasseja.github.io/qpmR/reference/verify_round.md)
  : Verify that an archived round still reproduces

## Estimation

Priors, posterior sampling over the Kalman-filter likelihood,
identification diagnostics and marginal likelihoods.

- [`priors()`](https://mustapha-wasseja.github.io/qpmR/reference/priors.md)
  : Declare priors for Bayesian estimation
- [`qpm_estimate()`](https://mustapha-wasseja.github.io/qpmR/reference/qpm_estimate.md)
  [`coef(`*`<qpm_estimate>`*`)`](https://mustapha-wasseja.github.io/qpmR/reference/qpm_estimate.md)
  : Estimate model parameters (Bayesian or maximum likelihood)
- [`apply_estimate()`](https://mustapha-wasseja.github.io/qpmR/reference/apply_estimate.md)
  : Recalibrate a model at an estimate's point values
- [`qpm_identify()`](https://mustapha-wasseja.github.io/qpmR/reference/qpm_identify.md)
  : Identification diagnostics (Iskrev-style Jacobian analysis)
- [`marginal_likelihood()`](https://mustapha-wasseja.github.io/qpmR/reference/marginal_likelihood.md)
  : Marginal likelihood of an estimated model

## Reporting

The deliverables a policy round is discussed from.

- [`qpm_report()`](https://mustapha-wasseja.github.io/qpmR/reference/qpm_report.md)
  : Write (and optionally render) a monetary policy report
- [`chart_pack()`](https://mustapha-wasseja.github.io/qpmR/reference/chart_pack.md)
  : The standard forecast-round chart pack

## Interoperability and data

- [`write_dynare()`](https://mustapha-wasseja.github.io/qpmR/reference/write_dynare.md)
  : Export a model to a Dynare .mod file
- [`czechia`](https://mustapha-wasseja.github.io/qpmR/reference/czechia.md)
  : Czech quarterly macroeconomic dataset
- [`next_quarters()`](https://mustapha-wasseja.github.io/qpmR/reference/next_quarters.md)
  : Generate consecutive quarter labels
