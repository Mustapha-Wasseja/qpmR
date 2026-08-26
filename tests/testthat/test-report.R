m <- qpm_template("bkl")
obs <- simulate(qpm_solve(m), nsim = 44, seed = 3, burn = 20)
obs$period <- next_quarters("2015-Q4", 44)
cols <- c("period", "pi", "i", "q")
rA <- qpm_round("June round", m, obs[1:40, cols], horizon = 8)
rB0 <- qpm_round("September round", m, obs[, cols], horizon = 8)
rB <- add_judgment(rB0, pi = stats::setNames(0.4, rB0$forecast$periods[2]),
                   author = "desk", rationale = "tariff")

test_that("a clean round verifies exactly", {
  v <- verify_round(rA)
  expect_true(v$ok)
  expect_lt(v$max_dev, 1e-8)
  expect_output(print(v), "reproduces exactly")
})

test_that("verification survives judgment and conditions", {
  rc <- qpm_condition(rB, i = stats::setNames(9.5, rB$forecast$periods[1]),
                      instruments = "eps_i")
  v <- verify_round(rc)
  expect_true(v$ok)
  expect_equal(v$n_judgment, 1L)
  expect_equal(v$n_conditions, 1L)
})

test_that("a doctored forecast is caught", {
  bad <- rA
  bad$forecast$paths$mean[5] <- bad$forecast$paths$mean[5] + 0.25
  v <- verify_round(bad)
  expect_false(v$ok)
  expect_gt(v$max_dev, 0.2)
  expect_output(print(v), "does NOT reproduce")
})

test_that("store round-trip verifies and detects edited sidecars", {
  store <- file.path(tempdir(), "qpmr-verify-store")
  unlink(store, recursive = TRUE)
  d <- save_round(rB, store)
  v <- verify_round("September round", store)
  expect_true(v$ok)
  expect_true(all(unlist(v$sidecars)))
  expect_output(print(v), "sidecar files match")

  csv <- file.path(d, "forecast.csv")
  x <- utils::read.csv(csv); x$mean[1] <- x$mean[1] + 0.5
  utils::write.csv(x, csv, row.names = FALSE)
  v2 <- verify_round("September round", store)
  expect_false(v2$ok)
  expect_false(v2$sidecars$forecast)
  expect_lt(v2$max_dev, 1e-8)     # the object itself is still fine
  expect_output(print(v2), "do not match")
  unlink(store, recursive = TRUE)
})

test_that("chart_pack writes a multi-page pdf and png sets", {
  pdf_file <- file.path(tempdir(), "pack.pdf")
  unlink(pdf_file)
  expect_silent(chart_pack(rB, pdf_file))
  expect_true(file.exists(pdf_file))
  expect_gt(file.size(pdf_file), 5000)

  png_stem <- file.path(tempdir(), "pack.png")
  unlink(list.files(tempdir(), "^pack-[0-9]+\\.png$", full.names = TRUE))
  chart_pack(rB, png_stem, charts = c("forecast", "transmission"))
  pngs <- list.files(tempdir(), "^pack-[0-9]+\\.png$", full.names = TRUE)
  expect_gte(length(pngs), 2L)
  unlink(c(pdf_file, pngs))

  expect_error(chart_pack(rB, file.path(tempdir(), "pack.txt")), "\\.pdf or \\.png")
})

test_that("qpm_report writes a self-contained source with its data bundle", {
  outdir <- file.path(tempdir(), "qpmr-report"); unlink(outdir, recursive = TRUE)
  dir.create(outdir)
  src <- qpm_report(rB, file.path(outdir, "mpr.Rmd"), compare_to = rA,
                    render = FALSE)
  expect_true(file.exists(src))
  txt <- readLines(src)
  expect_false(any(grepl("@BUNDLE@|@TITLE@|@SUBTITLE@", txt)))  # all substituted
  expect_true(any(grepl("September round", txt, fixed = TRUE)))
  bundle <- file.path(outdir, "mpr-round.rds")
  expect_true(file.exists(bundle))
  b <- readRDS(bundle)
  expect_s3_class(b$round, "qpm_round")
  expect_s3_class(b$compare_to, "qpm_round")
  unlink(outdir, recursive = TRUE)
})

test_that("report rendering degrades gracefully without pandoc", {
  outdir <- file.path(tempdir(), "qpmr-report2"); unlink(outdir, recursive = TRUE)
  dir.create(outdir)
  target <- file.path(outdir, "mpr.html")
  # engine = "quarto" with no quarto present must message, not fail
  out <- suppressMessages(qpm_report(rB, target, render = TRUE,
                                     engine = if (nzchar(Sys.which("quarto")) ||
                                                  rmarkdown::pandoc_available())
                                       "auto" else "rmarkdown"))
  expect_true(file.exists(out))          # either the html or the .Rmd fallback
  expect_true(grepl("\\.(html|Rmd)$", out))
  unlink(outdir, recursive = TRUE)
})

test_that("bad report targets are rejected", {
  expect_error(qpm_report(rB, file.path(tempdir(), "x.txt")), "must end in")
  expect_error(qpm_report(rB, file.path(tempdir(), "x.Rmd"), compare_to = "nope",
                          store = tempdir()),
               "not found")
})
