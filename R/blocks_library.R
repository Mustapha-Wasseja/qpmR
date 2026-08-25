#' Disaggregated CPI: food and core inflation
#'
#' Splits headline inflation into food and core. Food is 30-50 percent of
#' the consumption basket across most of sub-Saharan Africa and South
#' Asia, and a single-inflation model is unusable there: supply shocks to
#' food dominate headline, but monetary policy should look through the
#' relative-price component. Practically every technical-assistance
#' engagement rebuilds this split by hand.
#'
#' The block replaces headline inflation with an identity and adds:
#'
#' * `pi_core` — the Phillips curve, now for core inflation (it keeps the
#'   template's `b1`, `b2`, `b3` and the `eps_pi` shock);
#' * `pi_food` — food inflation: its own persistence, expectations of
#'   headline, demand, a stronger exchange-rate pass-through than core,
#'   and error correction on the relative food price;
#' * `rp_food` — the relative food price gap, which accumulates the
#'   food-core inflation differential and mean-reverts through `f4`.
#'
#' Headline is `pi = w_food * pi_food + (1 - w_food) * pi_core`, so
#' everything downstream (the 4-quarter average, the Fisher equation, the
#' policy rule) continues to use headline. To target core instead,
#' replace the policy rule with another block.
#'
#' @param weight Food share of the CPI basket (`w_food`).
#' @param persistence Food inflation persistence (`f1`).
#' @param demand Output-gap coefficient in food inflation (`f2`).
#' @param passthrough Real-exchange-rate coefficient in food inflation
#'   (`f3`); normally larger than core's, food being more tradable.
#' @param correction Error-correction speed on the relative food price
#'   (`f4`); must be positive for the relative price to be pinned down.
#' @param sd Standard deviation of the food supply shock.
#' @return A [qpm_block()].
#' @examples
#' m <- add_block(qpm_template("bkl"), block_food_cpi(weight = 0.45))
#' sol <- qpm_solve(m)
#' plot(irf(sol, shock = "eps_pifood"), vars = c("pi_food", "pi", "pi_core", "i"))
#' @export
block_food_cpi <- function(weight = 0.35, persistence = 0.50, demand = 0.20,
                           passthrough = 0.25, correction = 0.10, sd = 3) {
  stopifnot(weight > 0, weight < 1, persistence >= 0, persistence < 1,
            correction > 0)
  qpm_block(
    name = "food CPI",
    description = sprintf("headline = %.0f%% food + %.0f%% core, with relative-price error correction",
                          100 * weight, 100 * (1 - weight)),
    variables = vars(
      pi_core = var("Core CPI inflation, QoQ annualised", unit = "pct"),
      pi_food = var("Food CPI inflation, QoQ annualised", unit = "pct"),
      rp_food = var("Relative food price gap", unit = "pp")
    ),
    shocks = shocks(eps_pifood),
    params = list(w_food = weight, f1 = persistence, f2 = demand,
                  f3 = passthrough, f4 = correction),
    sigma = c(eps_pifood = sd),
    equations = eqs(
      # headline identity (replaces the template's Phillips curve slot)
      pi ~ w_food * pi_food + (1 - w_food) * pi_core,
      # the Phillips curve now determines core
      pi_core ~ b1 * pi_core[-1] + (1 - b1) * E(pi_core[+1]) +
        b2 * y_gap + b3 * q_gap + eps_pi,
      # food: supply-driven, tradable, error-correcting in relative price
      pi_food ~ f1 * pi_food[-1] + (1 - f1) * E(pi[+1]) + f2 * y_gap +
        f3 * q_gap - f4 * rp_food[-1] + eps_pifood,
      # relative price accumulates the inflation differential
      rp_food ~ rp_food[-1] + (pi_food - pi_core) / 4
    )
  )
}

#' Foreign-exchange intervention (managed float)
#'
#' Turns the template's floating exchange rate into a managed one. A
#' leaning-against-the-wind rule responds to the real exchange rate gap,
#' and intervention enters the UIP block directly, so the same model
#' spans a continuum of regimes: `intensity = 0` is a free float,
#' moderate values a managed float, and large values approach a peg.
#' Program countries — where reserves, not just the policy rate, are the
#' operative instrument — live in the middle of that range.
#'
#' `fx_int` is intervention intensity, positive meaning sales of foreign
#' exchange in support of the domestic currency (which appreciates the
#' real exchange rate, lowering `q`).
#'
#' @param intensity Scales both the intervention response to the RER gap
#'   and its effect on the exchange rate. `0` reproduces a free float.
#' @param persistence Persistence of intervention (`h1`).
#' @param sd Standard deviation of the discretionary intervention shock.
#' @return A [qpm_block()].
#' @examples
#' float <- qpm_solve(qpm_template("bkl"))
#' managed <- qpm_solve(add_block(qpm_template("bkl"),
#'                                block_fx_intervention(intensity = 1)))
#' # the same risk-premium shock moves the exchange rate less under management
#' @export
block_fx_intervention <- function(intensity = 1, persistence = 0.60, sd = 1) {
  stopifnot(intensity >= 0, persistence >= 0, persistence < 1)
  qpm_block(
    name = sprintf("FX intervention (intensity %s)", trimws(fmt_num(intensity))),
    description = "managed float: leaning-against-the-wind rule entering the UIP block",
    variables = vars(
      fx_int = var("FX intervention (+ = selling FX, supporting the currency)",
                   unit = "index")
    ),
    shocks = shocks(eps_fx),
    params = list(h1 = persistence, h2 = 0.30 * intensity, h3 = 0.50 * intensity),
    sigma = c(eps_fx = sd),
    equations = eqs(
      # lean against the wind: sell FX when the currency is weak (q_gap > 0)
      fx_int ~ h1 * fx_int[-1] + h2 * q_gap + eps_fx,
      # intervention appreciates the real exchange rate
      q ~ e1 * E(q[+1]) + (1 - e1) * q[-1] - (r - rstar - prem) / 4 -
        h3 * fx_int + eps_q
    )
  )
}
