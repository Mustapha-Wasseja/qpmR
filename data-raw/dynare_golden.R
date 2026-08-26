# Regenerate tests/testthat/golden/dynare.rds — the Dynare cross-check.
#
# Requires MATLAB (or Octave) with Dynare on the path. Run from the
# package root after any change to the shipped templates or the solver:
#
#   Rscript data-raw/dynare_golden.R
#
# Verified with Dynare 6.0 + MATLAB R2023b on Windows.

MATLAB <- Sys.getenv("QPMR_MATLAB", "C:/Program Files/MATLAB/R2023b/bin/matlab.exe")
DYNARE <- Sys.getenv("QPMR_DYNARE", "C:/dynare/6.0/matlab")
stopifnot(file.exists(MATLAB), dir.exists(DYNARE))

pkgload::load_all(".", quiet = TRUE)
work <- file.path(tempdir(), "qpmr-dynare")
dir.create(work, recursive = TRUE, showWarnings = FALSE)

templates <- c("bkl", "bkl_food")

run_one <- function(tpl) {
  mod <- file.path(work, paste0(tpl, ".mod"))
  write_dynare(qpm_template(tpl), file = mod, irf = 20)

  driver <- file.path(work, paste0("run_", tpl, ".m"))
  writeLines(c(
    sprintf("addpath('%s');", DYNARE),
    sprintf("cd('%s');", gsub("\\\\", "/", work)),
    sprintf("dynare %s.mod noclearall nolog", tpl),
    sprintf("fid = fopen('irfs_%s.csv', 'w');", tpl),
    "fprintf(fid, '%s\\n', 'name,h,value');",
    "nm = fieldnames(oo_.irfs);",
    "for k = 1:numel(nm)",
    "    v = oo_.irfs.(nm{k});",
    "    for h = 1:numel(v)",
    "        fprintf(fid, '%s,%d,%.15e\\n', nm{k}, h, v(h));",
    "    end",
    "end",
    "fclose(fid);",
    sprintf("fid2 = fopen('steady_%s.csv', 'w');", tpl),
    "fprintf(fid2, '%s\\n', 'name,value');",
    "for k = 1:numel(M_.endo_names)",
    "    fprintf(fid2, '%s,%.15e\\n', M_.endo_names{k}, oo_.steady_state(k));",
    "end",
    "fclose(fid2);"
  ), driver)

  st <- system2(MATLAB, c("-batch", shQuote(sprintf("run('%s')",
                                                    gsub("\\\\", "/", driver)))),
                stdout = TRUE, stderr = TRUE)
  irf_csv <- file.path(work, sprintf("irfs_%s.csv", tpl))
  if (!file.exists(irf_csv)) {
    cat(tail(st, 20), sep = "\n")
    stop("Dynare did not produce IRFs for ", tpl)
  }
  list(template = tpl,
       irfs = utils::read.csv(irf_csv, stringsAsFactors = FALSE),
       steady = utils::read.csv(file.path(work, sprintf("steady_%s.csv", tpl)),
                                stringsAsFactors = FALSE),
       dynare_version = basename(dirname(DYNARE)),
       generated = as.character(Sys.Date()))
}

golden <- stats::setNames(lapply(templates, run_one), templates)

# report agreement before overwriting the stored file
for (g in golden) {
  sol <- qpm_solve(qpm_template(g$template))
  worst <- 0
  for (s in sol$shocks) {
    ir <- irf(sol, shock = s, horizon = 21)
    for (v in sol$vars) {
      d <- g$irfs[g$irfs$name == paste0(v, "_", s), , drop = FALSE]
      if (!nrow(d)) next
      d <- d[order(d$h), ]
      worst <- max(worst, max(abs(d$value -
                                    ir$value[ir$variable == v][seq_len(nrow(d))])))
    }
  }
  cat(sprintf("%-10s max |qpmR - Dynare| over %d IRF points: %.3e\n",
              g$template, nrow(g$irfs), worst))
}

saveRDS(golden, "tests/testthat/golden/dynare.rds", compress = "xz")
cat("written tests/testthat/golden/dynare.rds\n")
