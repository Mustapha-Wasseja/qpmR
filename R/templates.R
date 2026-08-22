#' Shipped model templates
#'
#' `"bkl"` is the canonical semi-structural small-open-economy quarterly
#' projection model in the tradition of Berg, Karam and Laxton (2006, IMF
#' WP/06/80-81): an IS curve, a hybrid Phillips curve, a forward-looking
#' inflation-targeting policy rule, and a dampened (hybrid) UIP block,
#' plus equilibrium-trend and foreign processes, and an observation block
#' for real GDP growth (`dy_obs = dy_bar + 4 * (y_gap - y_gap[-1])`), so
#' the model can be filtered on actual national-accounts data without
#' modelling the level of potential output. The default calibration is
#' illustrative, for a higher-inflation emerging economy ("Meridia"); it
#' is not any actual country. See [czechia] for a real dataset and a
#' matching recalibration example.
#'
#' `trends` selects the equilibrium processes:
#' * `"stationary"` (default): AR(1) trends anchored at steady-state
#'   parameters; the model is fully stationary.
#' * `"rw"`: driftless random walks for the equilibrium real exchange
#'   rate and potential growth (whose levels are pure normalizations);
#'   the neutral rate stays anchored by real interest parity
#'   (`rstar + prem`), since a free random walk there would leave
#'   steady-state gaps indeterminate. The model then has unit roots:
#'   free trend levels are normalized to minimum norm in the steady
#'   state, and [qpm_filter()] switches to diffuse initialization
#'   automatically. This is the configuration for real data, where
#'   trends drift.
#'
#' Conventions: gaps in percentage points; inflation QoQ annualised;
#' interest rates in percent per annum; `q` is 100 times the log real
#' exchange rate, an increase is a real depreciation; `dy_obs` is QoQ
#' annualised real GDP growth.
#'
#' @param name Template name; currently `"bkl"`.
#' @param trends `"stationary"` or `"rw"`; see Details.
#' @return A calibrated `qpm_model`.
#' @references Berg, A., Karam, P., and Laxton, D. (2006). A Practical
#'   Model-Based Approach to Monetary Policy Analysis - Overview. IMF
#'   Working Paper 06/80; and the companion How-To guide, IMF WP 06/81.
#' @examples
#' m <- qpm_template("bkl")
#' summary(m)
#' m_rw <- qpm_template("bkl", trends = "rw")
#' @export
qpm_template <- function(name = c("bkl"), trends = c("stationary", "rw")) {
  name <- match.arg(name)
  trends <- match.arg(trends)
  bkl_template(trends)
}

bkl_template <- function(trends = "stationary") {
  trend_eqs <- if (trends == "rw") {
    # q_bar and dy_bar levels are pure normalizations, so driftless random
    # walks are safe. The neutral rate stays anchored by real interest
    # parity (rstar + prem): a free random walk in r_bar would leave
    # steady-state gaps indeterminate (a permanent r_bar shift implies
    # permanently nonzero gaps through UIP).
    eqs(
      q_bar ~ q_bar[-1] + eps_qbar,
      r_bar ~ rho_rbar * r_bar[-1] +
        (1 - rho_rbar) * (istar_ss - pistar_ss + prem_ss) + eps_rbar,
      dy_bar ~ dy_bar[-1] + eps_g
    )
  } else {
    eqs(
      q_bar ~ rho_qbar * q_bar[-1] + (1 - rho_qbar) * qbar_ss + eps_qbar,
      r_bar ~ rho_rbar * r_bar[-1] +
        (1 - rho_rbar) * (istar_ss - pistar_ss + prem_ss) + eps_rbar,
      dy_bar ~ rho_g * dy_bar[-1] + (1 - rho_g) * g_ss + eps_g
    )
  }

  qpm_model(
    name = sprintf("Canonical small open economy QPM (BKL, %s trends)", trends),
    variables = vars(
      y_gap     = var("Output gap", unit = "pp"),
      pi        = var("CPI inflation, QoQ annualised", unit = "pct"),
      pi4       = var("CPI inflation, 4-quarter average", unit = "pct"),
      i         = var("Policy rate", unit = "pct pa"),
      r         = var("Real interest rate", unit = "pct pa"),
      r_gap     = var("Real rate gap", unit = "pp"),
      q         = var("Real exchange rate, 100*log (+ = depreciation)", unit = "index"),
      q_gap     = var("Real exchange rate gap", unit = "pp"),
      q_bar     = var("Equilibrium real exchange rate", unit = "index"),
      r_bar     = var("Neutral real interest rate", unit = "pct pa"),
      dy_obs    = var("Real GDP growth, QoQ annualised", unit = "pct"),
      dy_bar    = var("Potential output growth, annualised", unit = "pct"),
      ystar_gap = var("Foreign output gap", unit = "pp"),
      istar     = var("Foreign nominal interest rate", unit = "pct pa"),
      pistar    = var("Foreign inflation", unit = "pct"),
      rstar     = var("Foreign real interest rate", unit = "pct pa"),
      prem      = var("Country risk premium", unit = "pp")
    ),
    shocks = shocks(eps_y, eps_pi, eps_i, eps_q, eps_qbar, eps_rbar,
                    eps_g, eps_dy, eps_ystar, eps_istar, eps_pistar, eps_prem),
    equations = c(eqs(
      # aggregate demand
      y_gap ~ a1 * y_gap[-1] + a2 * E(y_gap[+1]) - a3 * r_gap +
        a4 * q_gap + a5 * ystar_gap + eps_y,
      # Phillips curve (real marginal cost = output gap + RER gap)
      pi ~ b1 * pi[-1] + (1 - b1) * E(pi[+1]) + b2 * y_gap + b3 * q_gap + eps_pi,
      # 4-quarter inflation
      pi4 ~ (pi + pi[-1] + pi[-2] + pi[-3]) / 4,
      # forward-looking inflation-targeting rule
      i ~ c1 * i[-1] + (1 - c1) * (r_bar + pi4 +
        c2 * (E(pi4[+4]) - pi_tar) + c3 * y_gap) + eps_i,
      # Fisher equation
      r ~ i - E(pi[+1]),
      r_gap ~ r - r_bar,
      # dampened (hybrid) real UIP
      q ~ e1 * E(q[+1]) + (1 - e1) * q[-1] - (r - rstar - prem) / 4 + eps_q,
      q_gap ~ q - q_bar,
      # observed GDP growth: potential growth plus the change in the gap
      dy_obs ~ dy_bar + 4 * (y_gap - y_gap[-1]) + eps_dy,
      # foreign and premium processes
      ystar_gap ~ rho_ystar * ystar_gap[-1] + eps_ystar,
      istar ~ rho_istar * istar[-1] + (1 - rho_istar) * istar_ss + eps_istar,
      pistar ~ rho_pistar * pistar[-1] + (1 - rho_pistar) * pistar_ss + eps_pistar,
      rstar ~ istar - E(pistar[+1]),
      prem ~ rho_prem * prem[-1] + (1 - rho_prem) * prem_ss + eps_prem
    ), trend_eqs),
    params = list(
      a1 = 0.70, a2 = 0.10, a3 = 0.20, a4 = 0.10, a5 = 0.25,
      b1 = 0.70, b2 = 0.25, b3 = 0.10,
      c1 = 0.70, c2 = 1.50, c3 = 0.50,
      e1 = 0.70,
      pi_tar = 5, istar_ss = 3, pistar_ss = 2, prem_ss = 3, qbar_ss = 0,
      g_ss = 3.5,
      rho_qbar = 0.90, rho_rbar = 0.90, rho_g = 0.85, rho_ystar = 0.80,
      rho_istar = 0.85, rho_pistar = 0.70, rho_prem = 0.85
    ),
    sigma = c(eps_y = 0.5, eps_pi = 1.0, eps_i = 0.5, eps_q = 1.5,
              eps_qbar = 0.3, eps_rbar = 0.2, eps_g = 0.2, eps_dy = 1.0,
              eps_ystar = 0.3, eps_istar = 0.3, eps_pistar = 0.5,
              eps_prem = 0.5),
    meta = list(
      template = "bkl", trends = trends,
      ranges = list(
        a1 = c(0.40, 0.95), a2 = c(0.00, 0.30), a3 = c(0.05, 0.50),
        a4 = c(0.00, 0.30), a5 = c(0.00, 0.60),
        b1 = c(0.30, 0.90), b2 = c(0.05, 0.60), b3 = c(0.00, 0.40),
        c1 = c(0.30, 0.90), c2 = c(1.00, 3.00), c3 = c(0.00, 1.50),
        e1 = c(0.40, 0.95),
        rho_qbar = c(0, 0.98), rho_rbar = c(0, 0.98), rho_g = c(0, 0.98),
        rho_ystar = c(0, 0.98), rho_istar = c(0, 0.98),
        rho_pistar = c(0, 0.98), rho_prem = c(0, 0.98)
      )
    )
  )
}
