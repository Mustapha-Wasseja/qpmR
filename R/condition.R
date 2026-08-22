# Conditional forecasting machinery.
#
# The solved model gives x_h = P x_{h-1} + Q e_h for surprise shocks. For
# shocks ANNOUNCED at the start of the forecast, the perfect-foresight
# response to a shock j quarters ahead follows the recursion
#     F_j = N^j Q,   N = -(A P + B)^{-1} A,
# derived by substituting x_t = P x_{t-1} + sum_j F_j e_{t+j} into the
# structural form A x_{t+1} + B x_t + C x_{t-1} + D e_t = 0. Both
# expectation modes therefore reduce to one linear map G from the stacked
# shock path to the stacked forecast path:
#     dG(h, s) = P dG(h-1, s) + term(h, s)
#     term = N^{s-h} Q for s >= h (anticipated), Q for s == h (unanticipated).
# Conditions are linear restrictions on the path; the implied shocks are
# the minimum-norm solution in standard-deviation units (the "most
# plausible" shock configuration), optionally restricted to a set of
# instrument shocks.

build_G <- function(sol, H, anticipated) {
  N <- length(sol$vars_all)
  k <- length(sol$shocks)
  P <- unname(sol$P); Q <- unname(sol$Q)
  NQ <- NULL
  if (anticipated) {
    st <- sol$structural
    if (is.null(st))
      stop("this solution predates qpmR 0.3; re-run qpm_solve()", call. = FALSE)
    Nm <- -solve(st$A %*% P + st$B, st$A)
    NQ <- vector("list", H)
    NQ[[1]] <- Q
    for (j in seq_len(H - 1L)) NQ[[j + 1L]] <- Nm %*% NQ[[j]]
  }
  G <- matrix(0, H * N, H * k)
  rows <- function(h) (h - 1L) * N + seq_len(N)
  cols <- function(s) (s - 1L) * k + seq_len(k)
  for (s in seq_len(H)) {
    prev <- matrix(0, N, k)
    for (h in seq_len(H)) {
      cur <- P %*% prev
      if (anticipated) {
        if (s >= h) cur <- cur + NQ[[s - h + 1L]]
      } else if (s == h) cur <- cur + Q
      G[rows(h), cols(s)] <- cur
      prev <- cur
    }
  }
  G
}

# shared core: re-solve a forecast under its accumulated conditions
recondition <- function(fc, anticipated, instruments) {
  sol <- fc$solution
  if (is.null(sol))
    stop("this forecast predates qpmR 0.3; re-run qpm_forecast()", call. = FALSE)
  H <- fc$horizon
  N <- length(sol$vars_all)
  k <- length(sol$shocks)
  cn <- fc$conditions
  if (is.null(cn) || nrow(cn) == 0L) stop("no conditions to apply", call. = FALSE)
  if (anyDuplicated(cn[, c("variable", "h")]))
    stop("conflicting conditions: the same variable is conditioned twice at one period",
         call. = FALSE)

  instruments <- instruments %||% sol$shocks
  bad <- setdiff(instruments, sol$shocks)
  if (length(bad))
    stop(sprintf("unknown instrument shock(s): %s", paste(bad, collapse = ", ")),
         call. = FALSE)

  sig <- fc$sigma
  G <- build_G(sol, H, anticipated)
  sig_stack <- rep(sig, times = H)
  Gs <- sweep(G, 2L, sig_stack, "*")          # standardized-shock units

  # constraint selection over the stacked path
  vidx <- match(cn$variable, sol$vars_all)
  rsel <- (cn$h - 1L) * N + vidx
  base_dev <- as.vector(t(fc$baseline_dev))   # stacked h-major
  c_target <- (cn$value - sol$ss[vidx]) - base_dev[rsel]

  icol <- as.vector(outer(match(instruments, sol$shocks), (seq_len(H) - 1L) * k, "+"))
  icol <- sort(icol)
  Mi <- Gs[rsel, icol, drop = FALSE]
  u_i <- pinv(Mi) %*% c_target
  resid <- max(abs(Mi %*% u_i - c_target))
  if (resid > 1e-6 * (1 + max(abs(c_target))))
    stop(errorCondition(sprintf(paste0(
      "conditions cannot be met with the chosen instruments ",
      "(residual %.3g): the instrument shocks do not move the conditioned ",
      "variables independently. Add instruments or drop a condition."), resid),
      class = c("qpm_unattainable", "qpm_error", "error", "condition")))

  u <- rep(0, H * k)
  u[icol] <- as.numeric(u_i)
  eps <- matrix(u * sig_stack, H, k, byrow = TRUE,
                dimnames = list(NULL, sol$shocks))
  ustd <- matrix(u, H, k, byrow = TRUE, dimnames = list(NULL, sol$shocks))

  dev_new <- fc$baseline_dev + matrix(G %*% (u * sig_stack), H, N, byrow = TRUE)
  colnames(dev_new) <- sol$vars_all

  # conditional uncertainty: Gaussian conditioning over ALL shocks
  sd_new <- fc$sd_uncond
  if (H * N <= 4000) {
    Sx <- Gs %*% t(Gs)
    SxS <- Sx[, rsel, drop = FALSE]
    ridge <- 1e-12 * max(mean(diag(Sx)), .Machine$double.xmin)
    W <- tryCatch(solve(Sx[rsel, rsel, drop = FALSE] +
                          diag(ridge, length(rsel)), t(SxS)),
                  error = function(cnd) NULL)
    if (!is.null(W)) {
      Vc_diag <- pmax(diag(Sx) - rowSums(SxS * t(W)), 0)
      sd_new <- matrix(sqrt(Vc_diag), H, N, byrow = TRUE)
      colnames(sd_new) <- sol$vars_all
    }
  }

  fc$dev <- dev_new
  fc$anticipated <- anticipated
  fc$instruments <- instruments
  fc$shocks_implied <- eps
  fc$shocks_implied_std <- ustd
  fc$paths <- assemble_paths(sol, dev_new, sd_new, fc$bands, H)
  fc
}

#' Conditional forecasts: impose paths, back out the shocks
#'
#' Imposes hard conditions on future values of model variables and finds
#' the minimum-norm structural shocks (in standard-deviation units,
#' optionally restricted to `instruments`) that deliver them. This is how
#' a policy question becomes a forecast: "what if the policy rate is held
#' at 3.5 for four quarters?" or "what paths are consistent with
#' inflation back at target by 2027?".
#'
#' The `anticipated` switch is the economics: `TRUE` means the whole
#' conditioned path is announced at the start of the forecast, so
#' expectations react immediately (forward-looking variables move before
#' the conditioning bites); `FALSE` means the implied shocks arrive as
#' period-by-period surprises. The two produce materially different
#' paths in any forward-looking model, and practitioners frequently do
#' not know which one their tools assume.
#'
#' Fan bands are recomputed as the Gaussian conditional distribution of
#' the path given the conditions (using all shocks), so conditioned
#' points have (near) zero width. The mean path uses only the chosen
#' instruments; when `instruments` is restricted, mean and bands answer
#' slightly different questions -- see Antolin-Diaz, Petrella and
#' Rubio-Ramirez (2021) for the full treatment, which is on the qpmR
#' roadmap.
#'
#' @param fc A `qpm_forecast` from [qpm_forecast()], or a `qpm_round`
#'   (its forecast is conditioned and the round returned).
#' @param ... Named conditions: one argument per variable, each a named
#'   vector of levels by period, e.g.
#'   `i = c("2026-Q4" = 3.5, "2027-Q1" = 3.5)` or `pi4 = c(h4 = 2)`.
#' @param anticipated Logical; announced-at-start (`TRUE`) vs
#'   period-by-period surprises (`FALSE`, default).
#' @param instruments Character vector of shocks allowed to move;
#'   default all shocks.
#' @return The conditioned `qpm_forecast`, with `$shocks_implied` (raw
#'   units), `$shocks_implied_std` (standard deviations), and the
#'   conditions recorded. Printing summarizes the implied shocks and
#'   flags any larger than two standard deviations.
#' @examples
#' sol <- qpm_solve(qpm_template("bkl"))
#' fc <- qpm_forecast(sol, horizon = 8)
#' hold <- qpm_condition(fc, i = c(h1 = 9.5, h2 = 9.5, h3 = 9.5, h4 = 9.5),
#'                       anticipated = TRUE, instruments = "eps_i")
#' hold
#' @export
qpm_condition <- function(fc, ..., anticipated = FALSE, instruments = NULL) {
  if (inherits(fc, "qpm_round")) {
    fc$forecast <- qpm_condition(fc$forecast, ..., anticipated = anticipated,
                                 instruments = instruments)
    return(fc)
  }
  stopifnot(inherits(fc, "qpm_forecast"))
  sol <- fc$solution
  spec <- list(...)
  if (length(spec) == 0L) stop("no conditions given", call. = FALSE)
  if (is.null(names(spec)) || any(names(spec) == ""))
    stop("conditions must be named by variable", call. = FALSE)
  badv <- setdiff(names(spec), sol$vars)
  if (length(badv))
    stop(sprintf("unknown variable(s): %s", paste(badv, collapse = ", ")), call. = FALSE)

  rows <- lapply(names(spec), function(v) {
    x <- spec[[v]]
    h <- resolve_horizons(names(x), fc$periods)
    data.frame(variable = v, period = fc$periods[h], h = h,
               value = as.numeric(x), source = "condition",
               stringsAsFactors = FALSE)
  })
  new <- do.call(rbind, rows)

  if (is.null(fc$baseline_dev)) fc$baseline_dev <- fc$dev
  fc$conditions <- rbind(fc$conditions, new)
  recondition(fc, anticipated = anticipated, instruments = instruments)
}

#' Shock-based alternative scenarios
#'
#' Adds a specified path of structural shocks to a forecast -- "what if
#' oil pushes the exchange rate 10 percent weaker next quarter?" --
#' without any inversion. Under `anticipated = TRUE` the shock path is
#' announced at the start of the forecast and expectations react ahead
#' of it.
#'
#' @param fc A `qpm_forecast`.
#' @param shocks Named list: one entry per shock, each a named vector of
#'   shock sizes (raw equation units) by period, e.g.
#'   `list(eps_q = c(h1 = 1.5))`.
#' @param anticipated Announced at start (`TRUE`) or surprises (`FALSE`).
#' @param label Optional scenario label for printing.
#' @return The shifted `qpm_forecast` (bands unchanged: a deterministic
#'   scenario shifts the mean, not the uncertainty).
#' @examples
#' sol <- qpm_solve(qpm_template("bkl"))
#' fc <- qpm_forecast(sol, horizon = 8)
#' dep <- qpm_scenario(fc, shocks = list(eps_q = c(h1 = 3)),
#'                     label = "10pct depreciation")
#' @export
qpm_scenario <- function(fc, shocks, anticipated = FALSE, label = NULL) {
  if (inherits(fc, "qpm_round")) {
    fc$forecast <- qpm_scenario(fc$forecast, shocks, anticipated = anticipated,
                                label = label)
    return(fc)
  }
  stopifnot(inherits(fc, "qpm_forecast"), is.list(shocks))
  sol <- fc$solution
  if (is.null(sol))
    stop("this forecast predates qpmR 0.3; re-run qpm_forecast()", call. = FALSE)
  bad <- setdiff(names(shocks), sol$shocks)
  if (length(bad))
    stop(sprintf("unknown shock(s): %s", paste(bad, collapse = ", ")), call. = FALSE)

  H <- fc$horizon; N <- length(sol$vars_all); k <- length(sol$shocks)
  eps <- matrix(0, H, k, dimnames = list(NULL, sol$shocks))
  for (s in names(shocks)) {
    x <- shocks[[s]]
    h <- resolve_horizons(names(x), fc$periods)
    eps[cbind(h, match(s, sol$shocks))] <- as.numeric(x)
  }
  G <- build_G(sol, H, anticipated)
  shift <- matrix(G %*% as.vector(t(eps)), H, N, byrow = TRUE)
  colnames(shift) <- sol$vars_all

  fc$dev <- fc$dev + shift
  fc$scenario <- list(label = label %||% "scenario", shocks = eps,
                      anticipated = anticipated)
  fc$paths <- assemble_paths(sol, fc$dev, fc$sd_uncond, fc$bands, H)
  fc
}
