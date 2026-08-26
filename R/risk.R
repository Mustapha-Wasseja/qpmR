# Two-piece (split) normal distribution, the standard device for
# expressing a skewed balance of risks around a modal forecast.
#
#   f(x) = A exp(-(x-mu)^2 / (2 s1^2))   x <  mu
#          A exp(-(x-mu)^2 / (2 s2^2))   x >= mu,   A = sqrt(2/pi)/(s1+s2)
#
#   mean = mu + sqrt(2/pi) (s2 - s1)
#   var  = (1 - 2/pi)(s2 - s1)^2 + s1 s2
#
# Given a target variance (from the model) and a skew (mean minus mode),
# the two scale parameters are pinned down exactly.

SQ2PI <- sqrt(2 / pi)

tpn_params <- function(variance, skew) {
  d <- skew / SQ2PI                       # s2 - s1
  p <- variance - (1 - 2 / pi) * d^2      # s1 * s2
  if (!is.finite(p) || p <= 0) return(c(NA_real_, NA_real_))
  s1 <- (-d + sqrt(d^2 + 4 * p)) / 2
  s2 <- s1 + d
  if (s1 <= 0 || s2 <= 0) return(c(NA_real_, NA_real_))
  c(s1, s2)
}

tpn_quantile <- function(p, mode, s1, s2) {
  cut <- s1 / (s1 + s2)
  ifelse(p < cut,
         mode + s1 * stats::qnorm(pmin(pmax(p * (s1 + s2) / (2 * s1), 0), 1)),
         mode + s2 * stats::qnorm(pmin(pmax(
           (p * (s1 + s2) - s1 + s2) / (2 * s2), 0), 1)))
}

tpn_mean <- function(mode, s1, s2) mode + SQ2PI * (s2 - s1)

#' Express a balance of risks (skewed fan charts)
#'
#' Central banks rarely believe their fan charts are symmetric: the
#' published judgement is usually "risks to inflation are tilted to the
#' upside". `qpm_risk()` applies that judgement, replacing the Gaussian
#' bands of a forecast with two-piece normal bands whose *mode* stays on
#' the model's projection while the *mean* shifts by the stated skew.
#' Total uncertainty is preserved: the variance implied by the model at
#' each horizon is held fixed, so a skew redistributes risk rather than
#' adding it.
#'
#' The skew is stated in the variable's own units as *mean minus mode* —
#' a value of `0.3` on inflation means the risks are worth 0.3
#' percentage points to the upside. Skews may be given for any subset of
#' variables and horizons; anything unstated keeps symmetric bands.
#'
#' Unlike [add_judgment()], which moves the projection itself and
#' back-solves the shocks that support it, this changes only the shape of
#' the distribution around an unchanged central path.
#'
#' @param fc A `qpm_forecast`, or a `qpm_round` (its forecast is used).
#' @param ... Named skews: one argument per variable, each a named vector
#'   of *mean minus mode* by period, e.g. `pi4 = c("2027-Q1" = 0.3)`.
#'   A single unnamed value applies to every horizon.
#' @param author,rationale Recorded with the risk assessment, as for
#'   judgement.
#' @return The forecast with skewed bands. `$risk` records the skews and
#'   `$paths` gains a `mode` column alongside `mean`.
#' @examples
#' sol <- qpm_solve(qpm_template("bkl"))
#' fc <- qpm_forecast(sol, horizon = 8)
#' risky <- qpm_risk(fc, pi = 0.4, author = "MPC",
#'                   rationale = "energy prices tilted to the upside")
#' risky
#' plot(risky, vars = c("pi", "i"))
#' @export
qpm_risk <- function(fc, ..., author = "MPC", rationale = "") {
  if (inherits(fc, "qpm_round")) {
    fc$forecast <- qpm_risk(fc$forecast, ..., author = author,
                            rationale = rationale)
    return(fc)
  }
  stopifnot(inherits(fc, "qpm_forecast"))
  sol <- fc$solution
  if (is.null(sol))
    stop("this forecast predates qpmR 1.1; re-run qpm_forecast()", call. = FALSE)
  spec <- list(...)
  if (length(spec) == 0L) stop("no risks given", call. = FALSE)
  if (is.null(names(spec)) || any(names(spec) == ""))
    stop("risks must be named by variable", call. = FALSE)
  bad <- setdiff(names(spec), sol$vars)
  if (length(bad))
    stop(sprintf("unknown variable(s): %s", paste(bad, collapse = ", ")),
         call. = FALSE)

  H <- fc$horizon
  rows <- lapply(names(spec), function(v) {
    x <- spec[[v]]
    if (is.null(names(x))) {
      if (length(x) != 1L)
        stop(sprintf("risk for '%s' must be named by period, or a single value for all horizons", v),
             call. = FALSE)
      h <- seq_len(H); val <- rep(as.numeric(x), H)
    } else {
      h <- resolve_horizons(names(x), fc$periods); val <- as.numeric(x)
    }
    data.frame(variable = v, period = fc$periods[h], h = h, skew = val,
               stringsAsFactors = FALSE)
  })
  risk <- do.call(rbind, rows)
  risk$author <- author
  risk$rationale <- rationale
  combined <- rbind(fc$risk, risk)
  if (anyDuplicated(combined[, c("variable", "h")]))
    stop("the same variable is given two risks at one period", call. = FALSE)
  fc$risk <- combined

  fc$paths <- assemble_paths_risk(sol, fc$dev, fc$sd_uncond %||% NULL,
                                  fc$bands, H, fc$risk, fc$paths)
  fc
}

# Rebuild the band columns, using two-piece normal quantiles wherever a
# skew has been stated and Gaussian ones elsewhere.
assemble_paths_risk <- function(sol, dev, sd_path, bands, H, risk, paths) {
  vs <- sol$vars
  ssv <- sol$ss[vs]
  if (is.null(sd_path)) {
    # derive the implied sd from the widest existing band (posterior fans)
    b <- max(bands)
    hi <- paths[[sprintf("hi_%.0f", 100 * b)]]
    sd_path <- matrix(NA_real_, H, length(vs), dimnames = list(NULL, vs))
    for (v in vs) {
      d <- paths[paths$variable == v, ]
      sd_path[, v] <- (d[[sprintf("hi_%.0f", 100 * b)]] - d$mean) /
        stats::qnorm(0.5 + b / 2)
    }
  }
  out <- vector("list", length(vs))
  for (j in seq_along(vs)) {
    v <- vs[j]
    mode <- dev[, v] + ssv[[v]]
    sk <- rep(0, H)
    rv <- risk[risk$variable == v, , drop = FALSE]
    if (nrow(rv)) sk[rv$h] <- rv$skew
    sd_v <- sd_path[, v]
    d <- data.frame(variable = v, h = seq_len(H), mode = mode, mean = mode)
    for (b in bands) {
      lo <- numeric(H); hi <- numeric(H)
      pl <- 0.5 - b / 2; ph <- 0.5 + b / 2
      for (h in seq_len(H)) {
        if (sk[h] == 0 || !is.finite(sd_v[h]) || sd_v[h] <= 0) {
          zq <- stats::qnorm(ph)
          lo[h] <- mode[h] - zq * sd_v[h]; hi[h] <- mode[h] + zq * sd_v[h]
        } else {
          s <- tpn_params(sd_v[h]^2, sk[h])
          if (anyNA(s)) {
            zq <- stats::qnorm(ph)
            lo[h] <- mode[h] - zq * sd_v[h]; hi[h] <- mode[h] + zq * sd_v[h]
          } else {
            lo[h] <- tpn_quantile(pl, mode[h], s[1], s[2])
            hi[h] <- tpn_quantile(ph, mode[h], s[1], s[2])
            d$mean[h] <- tpn_mean(mode[h], s[1], s[2])
          }
        }
      }
      d[[sprintf("lo_%.0f", 100 * b)]] <- lo
      d[[sprintf("hi_%.0f", 100 * b)]] <- hi
    }
    out[[j]] <- d
  }
  res <- do.call(rbind, out)
  rownames(res) <- NULL
  res
}

#' Print a forecast's balance-of-risks assessment
#'
#' @param fc A `qpm_forecast` or `qpm_round` with risks applied.
#' @return The risk table, invisibly.
#' @examples
#' sol <- qpm_solve(qpm_template("bkl"))
#' fc <- qpm_risk(qpm_forecast(sol, horizon = 8), pi = 0.4,
#'                rationale = "upside energy risk")
#' risk_log(fc)
#' @export
risk_log <- function(fc) {
  if (inherits(fc, "qpm_round")) fc <- fc$forecast
  stopifnot(inherits(fc, "qpm_forecast"))
  r <- fc$risk
  if (is.null(r) || nrow(r) == 0L) {
    cat("no balance-of-risks assessment on this forecast\n")
    return(invisible(NULL))
  }
  cat(sprintf("<balance of risks> %d entr%s\n", nrow(r),
              if (nrow(r) == 1L) "y" else "ies"))
  show <- r[, c("author", "variable", "period", "skew", "rationale")]
  show$skew <- sprintf("%+.2f", show$skew)
  print(show, row.names = FALSE, right = FALSE)
  cat("  skew is mean minus mode, in the variable's own units;",
      "total variance is unchanged\n")
  invisible(r)
}
