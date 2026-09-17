# Suggested packages are used conditionally, so the package still checks
# where testthat is not installed.
if (requireNamespace("testthat", quietly = TRUE)) {
  library(testthat)
  library(qpmR)

  test_check("qpmR")
}
