#' Write (and optionally render) a monetary policy report
#'
#' Turns a forecast round into the document a policy meeting is run
#' from: an executive summary with the numbers filled in, the forecast
#' table and fan charts, the filtered gaps, the shock decomposition,
#' the judgment ledger, an optional revision decomposition against the
#' previous round, and a reproducibility appendix.
#'
#' The report is always written as a self-contained `.Rmd` source, on
#' the principle that institutions replace the template's *text*, not
#' its plumbing: edit the file, re-render, keep the analysis. Rendering
#' additionally needs pandoc (via Quarto or RStudio/Positron); where
#' none is available — air-gapped forecasting machines, bare CI
#' runners — `qpm_report()` reports that and returns the `.Rmd`
#' unrendered rather than failing.
#'
#' @param round A `qpm_round`.
#' @param file Output path. The extension chooses the format
#'   (`.html`, `.pdf`, `.docx`), or `.Rmd` to write the source only.
#' @param compare_to Optional previous `qpm_round` (or its name) to add
#'   a revision-decomposition section.
#' @param store Round store used to resolve `compare_to` by name.
#' @param render Render the document, or only write the source.
#' @param engine `"auto"` (Quarto if present, else rmarkdown),
#'   `"quarto"`, or `"rmarkdown"`.
#' @param quiet Suppress rendering progress output.
#' @return The path actually produced (the rendered document, or the
#'   `.Rmd` when rendering was not possible), invisibly.
#' @examples
#' m <- qpm_template("bkl")
#' obs <- simulate(qpm_solve(m), nsim = 40, seed = 1, burn = 20)
#' obs$period <- next_quarters("2016-Q1", 40)
#' r <- qpm_round("demo", m, obs[, c("period", "pi", "i", "q")], horizon = 8)
#' src <- qpm_report(r, file.path(tempdir(), "mpr.Rmd"), render = FALSE)
#' @export
qpm_report <- function(round, file = "mpr.html", compare_to = NULL,
                       store = "rounds", render = TRUE,
                       engine = c("auto", "quarto", "rmarkdown"),
                       quiet = TRUE) {
  stopifnot(inherits(round, "qpm_round"))
  engine <- match.arg(engine)
  if (is.character(compare_to)) compare_to <- load_round(compare_to, store)
  if (!is.null(compare_to) && !inherits(compare_to, "qpm_round"))
    stop("compare_to must be a qpm_round or a round name", call. = FALSE)

  ext <- tolower(tools::file_ext(file))
  if (!nzchar(ext)) { file <- paste0(file, ".html"); ext <- "html" }
  if (!(ext %in% c("html", "pdf", "docx", "rmd")))
    stop("file must end in .html, .pdf, .docx or .Rmd", call. = FALSE)
  if (ext == "rmd") render <- FALSE

  outdir <- dirname(normalizePath(file, mustWork = FALSE))
  dir.create(outdir, recursive = TRUE, showWarnings = FALSE)
  stem <- sub("\\.[^.]+$", "", basename(file))
  rmd_path <- file.path(outdir, paste0(stem, ".Rmd"))

  # data the template reads, next to the source so the .Rmd is portable
  bundle <- file.path(outdir, paste0(stem, "-round.rds"))
  saveRDS(list(round = round, compare_to = compare_to), bundle)

  tpl <- system.file("report", "mpr.Rmd", package = "qpmR")
  if (!nzchar(tpl)) stop("the report template is missing from the installation",
                         call. = FALSE)
  src <- readLines(tpl, warn = FALSE)
  src <- gsub("@BUNDLE@", basename(bundle), src, fixed = TRUE)
  src <- gsub("@TITLE@", round$name, src, fixed = TRUE)
  src <- gsub("@SUBTITLE@", sprintf("Forecast round - prepared %s", round$created),
              src, fixed = TRUE)
  writeLines(src, rmd_path)

  if (!render) return(invisible(rmd_path))

  fmt <- switch(ext, html = "html_document", pdf = "pdf_document",
                docx = "word_document")
  have_quarto <- nzchar(Sys.which("quarto")) ||
    (requireNamespace("quarto", quietly = TRUE) &&
       !is.null(tryCatch(quarto::quarto_path(), error = function(e) NULL)))
  have_pandoc <- requireNamespace("rmarkdown", quietly = TRUE) &&
    rmarkdown::pandoc_available()

  use <- switch(engine,
                auto = if (have_pandoc) "rmarkdown" else if (have_quarto) "quarto" else "none",
                quarto = if (have_quarto) "quarto" else "none",
                rmarkdown = if (have_pandoc) "rmarkdown" else "none")

  if (use == "none") {
    message("No pandoc/Quarto found, so the report was not rendered.\n",
            "  The source is written and ready: ", rmd_path, "\n",
            "  Render it from RStudio/Positron, or with: quarto render \"",
            basename(rmd_path), "\"")
    return(invisible(rmd_path))
  }

  out <- tryCatch({
    if (use == "rmarkdown") {
      rmarkdown::render(rmd_path, output_format = fmt,
                        output_file = basename(file), quiet = quiet)
    } else {
      quarto::quarto_render(rmd_path, output_format = switch(ext, html = "html",
                                                             pdf = "pdf",
                                                             docx = "docx"),
                            quiet = quiet)
      file
    }
  }, error = function(cnd) {
    message("Rendering failed (", conditionMessage(cnd), ").\n",
            "  The source is written and ready: ", rmd_path)
    rmd_path
  })
  invisible(out)
}
