if (!requireNamespace("rcmdcheck", quietly = TRUE)) {
  install.packages("rcmdcheck", repos = "https://cloud.r-project.org")
}

rcmdcheck::rcmdcheck(
  args = c("--no-manual", "--as-cran"),
  error_on = "warning",
  check_dir = "check"
)
