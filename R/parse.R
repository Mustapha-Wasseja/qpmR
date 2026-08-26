# Internal parsing machinery.
#
# Equations are stored as residual expressions lhs - rhs in which every
# variable occurrence x[k] has been rewritten to a canonical symbol
# "x@k" and every shock to "eps@shk". Coefficients are then extracted
# numerically: for a linear equation, f(e_j) - f(0) is the exact
# coefficient on symbol j. A superposition check rejects nonlinear
# equations (qpmR 0.1 supports linear models only).

canon_var <- function(v, shift) paste0(v, CANON_SEP, shift)
canon_shk <- function(s) paste0(s, CANON_SEP, "shk")

parse_qpm_equation <- function(f, varnames, shknames, parnames, eq_label) {
  resid <- call("-", f[[2L]], f[[3L]])

  vkeys <- new.env(parent = emptyenv())
  skeys <- new.env(parent = emptyenv())
  bare_leads <- character(0)

  rec <- function(e, in_E = FALSE) {
    if (is.numeric(e) || is.logical(e)) return(e)
    if (is.symbol(e)) {
      nm <- as.character(e)
      if (nm %in% varnames) {
        assign(canon_var(nm, 0L), list(var = nm, shift = 0L), envir = vkeys)
        return(as.symbol(canon_var(nm, 0L)))
      }
      if (nm %in% shknames) {
        assign(canon_shk(nm), nm, envir = skeys)
        return(as.symbol(canon_shk(nm)))
      }
      if (nm %in% parnames) return(e)
      stop(sprintf(
        "unknown symbol '%s' in equation %s: not a declared variable, shock or parameter",
        nm, eq_label), call. = FALSE)
    }
    if (is.call(e)) {
      op <- e[[1L]]
      opname <- if (is.symbol(op)) as.character(op) else ""
      if (opname == "[") {
        if (length(e) != 3L || !is.symbol(e[[2L]]))
          stop(sprintf("bad lag/lead reference in equation %s: %s",
                       eq_label, deparse1(e)), call. = FALSE)
        nm <- as.character(e[[2L]])
        k <- tryCatch(eval(e[[3L]], envir = baseenv()), error = function(cnd) NULL)
        if (!is.numeric(k) || length(k) != 1L || !is.finite(k) || k != round(k))
          stop(sprintf("lag/lead index must be a fixed integer in equation %s: %s",
                       eq_label, deparse1(e)), call. = FALSE)
        k <- as.integer(k)
        if (nm %in% shknames)
          stop(sprintf(
            "shock '%s' appears with a lag/lead in equation %s: shocks enter contemporaneously in qpmR 0.1",
            nm, eq_label), call. = FALSE)
        if (!(nm %in% varnames))
          stop(sprintf("unknown variable '%s' in equation %s", nm, eq_label),
               call. = FALSE)
        if (k > 0L && !in_E)
          bare_leads <<- unique(c(bare_leads, sprintf("%s[+%d]", nm, k)))
        assign(canon_var(nm, k), list(var = nm, shift = k), envir = vkeys)
        return(as.symbol(canon_var(nm, k)))
      }
      if (opname == "E") {
        if (length(e) != 2L)
          stop(sprintf("E() takes exactly one argument (equation %s)", eq_label),
               call. = FALSE)
        return(rec(e[[2L]], in_E = TRUE))
      }
      out <- e
      for (i in seq_along(e)[-1L]) out[[i]] <- rec(e[[i]], in_E)
      return(out)
    }
    stop(sprintf("unsupported construct in equation %s: %s", eq_label, deparse1(e)),
         call. = FALSE)
  }

  expr <- rec(resid)

  vk <- mget(ls(vkeys), envir = vkeys)
  vdf <- if (length(vk)) {
    data.frame(canon = names(vk),
               var = vapply(vk, function(z) z$var, character(1)),
               shift = vapply(vk, function(z) z$shift, integer(1)),
               stringsAsFactors = FALSE, row.names = NULL)
  } else {
    data.frame(canon = character(0), var = character(0), shift = integer(0))
  }
  sk <- ls(skeys)
  sdf <- if (length(sk)) {
    data.frame(canon = sk,
               shock = vapply(mget(sk, envir = skeys), identity, character(1)),
               stringsAsFactors = FALSE, row.names = NULL)
  } else {
    data.frame(canon = character(0), shock = character(0))
  }

  list(expr = expr, vars = vdf, shocks = sdf,
       bare_leads = bare_leads, label = eq_label)
}

# Exact numeric coefficient extraction for one parsed equation, given the
# current parameter values.
eq_coefficients <- function(peq, params, parenv = NULL) {
  syms <- c(peq$vars$canon, peq$shocks$canon)
  # the parameter environment is built once per model and the evaluation
  # environment once per equation: coefficient extraction evaluates each
  # equation once per symbol, and qpm_solve() runs inside every MCMC draw
  if (is.null(parenv)) parenv <- list2env(as.list(params), parent = baseenv())
  ev <- new.env(parent = parenv)
  evalf <- function(vals) {
    list2env(as.list(vals), envir = ev)
    out <- eval(peq$expr, envir = ev)
    if (!is.numeric(out) || length(out) != 1L)
      stop(sprintf("equation %s does not evaluate to a scalar", peq$label),
           call. = FALSE)
    as.numeric(out)
  }
  # Coefficients come from evaluating the equation once per symbol, and this
  # runs inside every posterior draw, so the environment is built once and
  # each symbol is toggled in place rather than rebuilt from a named vector.
  for (s in syms) assign(s, 0, envir = ev)
  const <- eval(peq$expr, envir = ev)
  if (!is.numeric(const) || length(const) != 1L)
    stop(sprintf("equation %s does not evaluate to a scalar", peq$label),
         call. = FALSE)
  const <- as.numeric(const)
  if (!is.finite(const))
    stop(sprintf("equation %s evaluates to a non-finite value; check parameters",
                 peq$label), call. = FALSE)
  coefs <- numeric(length(syms))
  names(coefs) <- syms
  for (j in seq_along(syms)) {
    assign(syms[j], 1, envir = ev)
    coefs[j] <- as.numeric(eval(peq$expr, envir = ev)) - const
    assign(syms[j], 0, envir = ev)
  }

  if (length(syms)) {
    # deterministic pseudo-random test point (avoids touching the RNG)
    z <- stats::setNames(((seq_along(syms) * 0.6180339887) %% 1) + 0.5, syms)
    lin <- const + sum(coefs * z)
    got <- evalf(z)
    if (abs(got - lin) > 1e-8 * (1 + abs(got) + abs(lin)))
      stop(errorCondition(
        sprintf("equation %s is not linear in variables/shocks; qpmR 0.1 supports linear models only",
                peq$label),
        class = c("qpm_nonlinear", "qpm_error", "error", "condition")))
  }

  list(const = const,
       var_coefs = data.frame(var = peq$vars$var, shift = peq$vars$shift,
                              coef = unname(coefs[peq$vars$canon]),
                              stringsAsFactors = FALSE),
       shk_coefs = data.frame(shock = peq$shocks$shock,
                              coef = if (nrow(peq$shocks)) unname(coefs[peq$shocks$canon]) else numeric(0),
                              stringsAsFactors = FALSE))
}

# Coefficients only, in the canonical order variables-then-shocks that
# build_structure() indexes against. This runs once per equation per solve,
# and a solve runs once per posterior draw, so it does no more than
# evaluate the equation once per symbol: no data frames, no name lookups,
# and no linearity check (linearity is a property of the equations, so it
# is verified once when the structure is built).
eq_coefs_values <- function(peq, parenv) {
  syms <- c(peq$vars$canon, peq$shocks$canon)
  ev <- new.env(parent = parenv)
  for (s in syms) assign(s, 0, envir = ev)
  const <- eval(peq$expr, envir = ev)
  if (!is.numeric(const) || length(const) != 1L)
    stop(sprintf("equation %s does not evaluate to a scalar", peq$label),
         call. = FALSE)
  const <- as.numeric(const)
  if (!is.finite(const))
    stop(sprintf("equation %s evaluates to a non-finite value; check parameters",
                 peq$label), call. = FALSE)
  out <- numeric(length(syms))
  for (j in seq_along(syms)) {
    assign(syms[j], 1, envir = ev)
    out[j] <- as.numeric(eval(peq$expr, envir = ev)) - const
    assign(syms[j], 0, envir = ev)
  }
  list(const = const, coefs = out)
}
