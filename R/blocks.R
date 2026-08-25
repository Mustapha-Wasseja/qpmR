#' Model extension blocks
#'
#' A block is a documented, reusable bundle of variables, shocks,
#' parameters and equations that adapts a template to a country. Blocks
#' are how a technical-assistance engagement customizes the canonical
#' model without forking it: [add_block()] applies one, [qpm_diff()]
#' shows exactly what changed, and the result is an ordinary
#' `qpm_model`.
#'
#' Equations whose left-hand side names a variable that already exists
#' **replace** that variable's equation; equations for newly declared
#' variables are appended. Left-hand sides must be bare variable names.
#'
#' @param name Block name, used in printing and in the model's history.
#' @param variables New variables, from [vars()] (optional).
#' @param shocks New shocks, from [shocks()] (optional).
#' @param params Named list of new parameters (optional).
#' @param sigma Named vector of standard deviations for the new shocks
#'   (optional; default 1).
#' @param equations Equations, from [eqs()]: replacements for existing
#'   variables and definitions for new ones.
#' @param description One-line description of what the block does.
#' @return An object of class `qpm_block`.
#' @seealso [block_food_cpi()], [block_fx_intervention()]
#' @examples
#' b <- qpm_block(
#'   name = "risk premium shifter",
#'   params = list(prem_extra = 0),
#'   equations = eqs(prem ~ rho_prem * prem[-1] +
#'                     (1 - rho_prem) * (prem_ss + prem_extra) + eps_prem)
#' )
#' m <- add_block(qpm_template("bkl"), b)
#' @export
qpm_block <- function(name, variables = NULL, shocks = NULL, params = list(),
                      sigma = NULL, equations = NULL, description = "") {
  stopifnot(is.character(name), length(name) == 1L)
  if (is.null(equations) || length(equations) == 0L)
    stop("a block must supply at least one equation", call. = FALSE)
  structure(list(name = name, description = description,
                 variables = variables, shocks = shocks,
                 params = unlist(params), sigma = sigma,
                 equations = equations),
            class = "qpm_block")
}

#' @export
print.qpm_block <- function(x, ...) {
  cat(sprintf("<qpm_block> %s\n", x$name))
  if (nzchar(x$description)) cat(sprintf("  %s\n", x$description))
  if (!is.null(x$variables))
    cat(sprintf("  adds variables: %s\n", paste(x$variables$name, collapse = ", ")))
  if (!is.null(x$shocks))
    cat(sprintf("  adds shocks: %s\n", paste(x$shocks, collapse = ", ")))
  if (length(x$params))
    cat(strwrap(paste("adds parameters:",
                      paste(names(x$params), "=", fmt_num(x$params), collapse = ", ")),
                width = 76, indent = 2, exdent = 4), sep = "\n")
  cat(sprintf("  %d equation%s\n", length(x$equations),
              if (length(x$equations) == 1L) "" else "s"))
  invisible(x)
}

eq_lhs_name <- function(f) {
  lhs <- f[[2L]]
  if (!is.symbol(lhs))
    stop(sprintf("block equations must have a bare variable on the left-hand side, got: %s",
                 deparse1(lhs)), call. = FALSE)
  as.character(lhs)
}

#' Apply an extension block to a model
#'
#' @param model A `qpm_model`.
#' @param block A [qpm_block()], or a list of blocks applied in order.
#' @return The extended `qpm_model`, with the block recorded in
#'   `meta$blocks`.
#' @examples
#' m <- add_block(qpm_template("bkl"), block_food_cpi(weight = 0.4))
#' m
#' @export
add_block <- function(model, block) {
  stopifnot(inherits(model, "qpm_model"))
  if (is.list(block) && !inherits(block, "qpm_block")) {
    for (b in block) model <- add_block(model, b)
    return(model)
  }
  stopifnot(inherits(block, "qpm_block"))

  vars_new <- if (is.null(block$variables)) model$vars
              else rbind(model$vars, block$variables)
  dup <- vars_new$name[duplicated(vars_new$name)]
  if (length(dup))
    stop(sprintf("block '%s' declares variables that already exist: %s",
                 block$name, paste(dup, collapse = ", ")), call. = FALSE)

  shocks_new <- c(model$shocks, block$shocks)
  dup <- shocks_new[duplicated(shocks_new)]
  if (length(dup))
    stop(sprintf("block '%s' declares shocks that already exist: %s",
                 block$name, paste(dup, collapse = ", ")), call. = FALSE)

  params_new <- model$params
  if (length(block$params)) {
    clash <- intersect(names(block$params), names(model$params))
    if (length(clash))
      stop(sprintf("block '%s' declares parameters that already exist: %s",
                   block$name, paste(clash, collapse = ", ")), call. = FALSE)
    params_new <- c(params_new, block$params)
  }

  sigma_new <- model$sigma
  if (!is.null(block$shocks)) {
    add_sig <- stats::setNames(rep(1, length(block$shocks)), block$shocks)
    if (!is.null(block$sigma)) {
      unknown <- setdiff(names(block$sigma), block$shocks)
      if (length(unknown))
        stop(sprintf("block '%s': sigma names are not block shocks: %s",
                     block$name, paste(unknown, collapse = ", ")), call. = FALSE)
      add_sig[names(block$sigma)] <- block$sigma
    }
    sigma_new <- c(sigma_new, add_sig)
  }

  # replace by left-hand side where the variable already exists, else append
  existing_lhs <- vapply(model$equations, eq_lhs_name, character(1))
  eqs_new <- model$equations
  replaced <- character(0); added <- character(0)
  for (f in block$equations) {
    v <- eq_lhs_name(f)
    j <- match(v, existing_lhs)
    if (!is.na(j)) {
      eqs_new[[j]] <- f
      replaced <- c(replaced, v)
    } else {
      if (!(v %in% vars_new$name))
        stop(sprintf("block '%s' defines an equation for '%s', which is neither an existing variable nor declared by the block",
                     block$name, v), call. = FALSE)
      eqs_new <- c(eqs_new, list(f))
      added <- c(added, v)
    }
  }

  meta <- model$meta
  meta$blocks <- c(meta$blocks, list(list(name = block$name,
                                          description = block$description,
                                          replaced = replaced, added = added)))
  if (!is.null(block$params) && length(block$params))
    meta$ranges <- meta$ranges   # blocks may extend ranges via meta later

  qpm_model(name = sprintf("%s + %s", model$name, block$name),
            variables = vars_new, shocks = shocks_new, equations = eqs_new,
            params = params_new, sigma = sigma_new, meta = meta)
}

#' Compare two models structurally
#'
#' Shows what a customization actually changed: variables, shocks and
#' parameters added or removed, equations changed, and recalibrations.
#' This is how a model review works when country teams adapt a template.
#'
#' @param old,new `qpm_model` objects.
#' @param tol Relative tolerance for calling a parameter changed.
#' @return An object of class `qpm_model_diff`, printed as a report.
#' @examples
#' qpm_diff(qpm_template("bkl"),
#'          add_block(qpm_template("bkl"), block_food_cpi()))
#' @export
qpm_diff <- function(old, new, tol = 1e-10) {
  stopifnot(inherits(old, "qpm_model"), inherits(new, "qpm_model"))
  eq_txt <- function(m) {
    out <- vapply(m$equations, deparse1, character(1))
    names(out) <- vapply(m$equations, eq_lhs_name, character(1))
    out
  }
  eo <- eq_txt(old); en <- eq_txt(new)
  common <- intersect(names(eo), names(en))
  changed <- common[eo[common] != en[common]]

  shared_par <- intersect(names(old$params), names(new$params))
  recal <- shared_par[abs(new$params[shared_par] - old$params[shared_par]) >
                        tol * pmax(1, abs(old$params[shared_par]))]
  shared_sig <- intersect(names(old$sigma), names(new$sigma))
  resig <- shared_sig[abs(new$sigma[shared_sig] - old$sigma[shared_sig]) >
                        tol * pmax(1, abs(old$sigma[shared_sig]))]

  structure(list(
    vars_added = setdiff(new$vars$name, old$vars$name),
    vars_removed = setdiff(old$vars$name, new$vars$name),
    shocks_added = setdiff(new$shocks, old$shocks),
    shocks_removed = setdiff(old$shocks, new$shocks),
    params_added = setdiff(names(new$params), names(old$params)),
    params_removed = setdiff(names(old$params), names(new$params)),
    eqs_added = setdiff(names(en), names(eo)),
    eqs_removed = setdiff(names(eo), names(en)),
    eqs_changed = changed,
    old_eqs = eo, new_eqs = en,
    recalibrated = recal, resigma = resig,
    old_params = old$params, new_params = new$params,
    old_sigma = old$sigma, new_sigma = new$sigma,
    old_name = old$name, new_name = new$name
  ), class = "qpm_model_diff")
}

#' @export
print.qpm_model_diff <- function(x, ...) {
  cat(sprintf("<qpm_model_diff>\n  from: %s\n  to:   %s\n", x$old_name, x$new_name))
  line <- function(label, v) if (length(v))
    cat(strwrap(sprintf("%s: %s", label, paste(v, collapse = ", ")),
                width = 76, indent = 2, exdent = 4), sep = "\n")
  line("+ variables", x$vars_added)
  line("- variables", x$vars_removed)
  line("+ shocks", x$shocks_added)
  line("- shocks", x$shocks_removed)
  line("+ parameters", x$params_added)
  line("- parameters", x$params_removed)
  if (length(x$eqs_added)) {
    cat("  + equations:\n")
    for (v in x$eqs_added) cat(sprintf("      %s\n", x$new_eqs[[v]]))
  }
  if (length(x$eqs_removed)) {
    cat("  - equations:\n")
    for (v in x$eqs_removed) cat(sprintf("      %s\n", x$old_eqs[[v]]))
  }
  if (length(x$eqs_changed)) {
    cat("  ~ equations changed:\n")
    for (v in x$eqs_changed) {
      cat(sprintf("      - %s\n", x$old_eqs[[v]]))
      cat(sprintf("      + %s\n", x$new_eqs[[v]]))
    }
  }
  if (length(x$recalibrated)) {
    cat("  ~ recalibrated:\n")
    for (p in x$recalibrated)
      cat(sprintf("      %s: %s -> %s\n", p, fmt_num(x$old_params[[p]]),
                  fmt_num(x$new_params[[p]])))
  }
  if (length(x$resigma)) {
    cat("  ~ shock sds changed:\n")
    for (s in x$resigma)
      cat(sprintf("      %s: %s -> %s\n", s, fmt_num(x$old_sigma[[s]]),
                  fmt_num(x$new_sigma[[s]])))
  }
  if (!length(c(x$vars_added, x$vars_removed, x$shocks_added, x$shocks_removed,
                x$params_added, x$params_removed, x$eqs_added, x$eqs_removed,
                x$eqs_changed, x$recalibrated, x$resigma)))
    cat("  (identical)\n")
  invisible(x)
}
