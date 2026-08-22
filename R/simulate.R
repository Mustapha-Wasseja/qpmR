#' Simulate a solved model
#'
#' Draws Gaussian shocks with the model's standard deviations and iterates
#' the solved transition. Returns variables in levels (steady state plus
#' simulated deviations). The final full state is stored as an attribute
#' so a simulation can be handed straight to [qpm_forecast()].
#'
#' @param object A `qpm_solution`.
#' @param nsim Number of quarters to simulate.
#' @param seed Optional seed for reproducibility.
#' @param sigma Optional named vector of shock standard deviations
#'   overriding the model's.
#' @param burn Burn-in quarters discarded from the start.
#' @param ... Unused.
#' @return A data frame of class `qpm_sim` (period plus one column per
#'   declared variable), with attributes `state` (final expanded state,
#'   deviations) and `shocks` (the drawn shocks).
#' @examples
#' sol <- qpm_solve(qpm_template("bkl"))
#' hist <- simulate(sol, nsim = 60, seed = 42, burn = 20)
#' head(hist)
#' @importFrom stats simulate
#' @export
simulate.qpm_solution <- function(object, nsim = 40, seed = NULL,
                                  sigma = NULL, burn = 0, ...) {
  if (!is.null(seed)) set.seed(seed)
  sig <- object$sigma
  if (!is.null(sigma)) {
    unknown <- setdiff(names(sigma), object$shocks)
    if (length(unknown))
      stop(sprintf("sigma names are not shocks: %s", paste(unknown, collapse = ", ")),
           call. = FALSE)
    sig[names(sigma)] <- sigma
  }

  N <- length(object$vars_all)
  k <- length(object$shocks)
  Tt <- nsim + burn
  eps <- matrix(stats::rnorm(Tt * k), Tt, k) %*% diag(sig, k, k)
  colnames(eps) <- object$shocks

  x <- matrix(0, Tt + 1L, N)
  for (t in seq_len(Tt))
    x[t + 1L, ] <- object$P %*% x[t, ] + object$Q %*% eps[t, ]
  x <- x[-1L, , drop = FALSE]
  colnames(x) <- object$vars_all

  keep <- (burn + 1L):Tt
  dev <- x[keep, , drop = FALSE]
  lev <- sweep(dev[, object$vars, drop = FALSE], 2L,
               -object$ss[object$vars])

  out <- data.frame(period = seq_len(nsim), lev, check.names = FALSE)
  structure(out, class = c("qpm_sim", "data.frame"),
            state = dev[nrow(dev), ],
            shocks = eps[keep, , drop = FALSE],
            ss = object$ss[object$vars])
}
