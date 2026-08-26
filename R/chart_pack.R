#' The standard forecast-round chart pack
#'
#' Produces the chart set a forecast round is discussed from: the
#' forecast fans, the filtered latent states, the historical shock
#' decomposition of inflation, and the model's monetary transmission.
#' Output is a multi-page PDF by default, or numbered PNGs.
#'
#' @param round A `qpm_round`.
#' @param file Output file. A `.pdf` extension gives one multi-page
#'   document; a `.png` extension gives numbered files
#'   (`name-1.png`, ...). `NULL` draws to the current device.
#' @param charts Which charts to include, from `"forecast"`, `"gaps"`,
#'   `"decomposition"`, `"transmission"`. Default: all four.
#' @param vars Variables for the forecast page. Default: the model's
#'   headline set, whichever of `pi4`/`pi`, `i`, `y_gap`, `q` exist.
#' @param width,height Page size in inches.
#' @return The output path (invisibly), or `NULL` when drawing to the
#'   current device.
#' @examples
#' m <- qpm_template("bkl")
#' obs <- simulate(qpm_solve(m), nsim = 40, seed = 1, burn = 20)
#' obs$period <- next_quarters("2016-Q1", 40)
#' r <- qpm_round("demo", m, obs[, c("period", "pi", "i", "q")], horizon = 8)
#' pdf_path <- file.path(tempdir(), "pack.pdf")
#' chart_pack(r, pdf_path)
#' @export
chart_pack <- function(round, file = NULL, charts = NULL, vars = NULL,
                       width = 9, height = 6.5) {
  stopifnot(inherits(round, "qpm_round"))
  charts <- charts %||% c("forecast", "gaps", "decomposition", "transmission")
  charts <- match.arg(charts, c("forecast", "gaps", "decomposition", "transmission"),
                      several.ok = TRUE)
  sol <- round$solution
  vars <- vars %||% headline_vars(sol)

  dev_open <- FALSE
  if (!is.null(file)) {
    ext <- tolower(tools::file_ext(file))
    if (ext == "pdf") {
      grDevices::pdf(file, width = width, height = height, onefile = TRUE)
      dev_open <- TRUE
    } else if (ext == "png") {
      stem <- sub("\\.png$", "", file, ignore.case = TRUE)
      grDevices::png(sprintf("%s-%%d.png", stem),
                     width = width * 150, height = height * 150, res = 150)
      dev_open <- TRUE
    } else {
      stop("file must end in .pdf or .png", call. = FALSE)
    }
    on.exit(if (dev_open) grDevices::dev.off(), add = TRUE)
  }

  if ("forecast" %in% charts) {
    plot(round$forecast, vars = vars)
    page_title(sprintf("%s - forecast", round$name))
  }
  if ("gaps" %in% charts) {
    latent <- setdiff(sol$vars, round$observables)
    gv <- intersect(c("y_gap", "r_gap", "q_gap", "dy_bar", "r_bar", "q_bar"), latent)
    if (length(gv) == 0L) gv <- utils::head(latent, 4)
    if (length(gv)) {
      plot(round$fit, vars = utils::head(gv, 4))
      page_title(sprintf("%s - filtered latent states", round$name))
    }
  }
  if ("decomposition" %in% charts) {
    dec <- qpm_decompose(round$fit, vars = intersect(c("pi4", "pi"), sol$vars))
    dv <- if ("pi4" %in% sol$vars) "pi4" else "pi"
    n <- round$fit$n_obs
    plot(dec, var = dv, periods = max(1L, n - 39L):n)
    page_title(sprintf("%s - shock decomposition", round$name))
  }
  if ("transmission" %in% charts) {
    if ("eps_i" %in% sol$shocks) {
      plot(irf(sol, shock = "eps_i", horizon = 16), vars = vars)
      page_title(sprintf("%s - monetary transmission", round$name))
    }
  }
  invisible(file)
}

headline_vars <- function(sol) {
  cand <- c(if ("pi4" %in% sol$vars) "pi4" else "pi", "i", "y_gap", "q")
  out <- intersect(cand, sol$vars)
  if (length(out) == 0L) utils::head(sol$vars, 4) else out
}

# small footer stamp on a completed page
page_title <- function(txt) {
  graphics::mtext(txt, side = 1, line = -1, outer = TRUE, cex = 0.7,
                  col = "grey35", adj = 0.01)
}
