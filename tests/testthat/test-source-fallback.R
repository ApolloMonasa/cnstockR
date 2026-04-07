test_that("cn_get_daily auto source falls back when primary source is empty", {
  calls <- character(0)

  testthat::local_mocked_bindings(
    get_daily_by_source = function(symbol, dr, adjust, source, max_retry, timeout_sec) {
      calls <<- c(calls, source)
      if (identical(source, "eastmoney")) {
        return(tibble::tibble())
      }
      tibble::tibble(
        symbol = "600519",
        date = as.Date("2024-01-02"),
        open = 10,
        close = 11,
        high = 12,
        low = 9,
        volume = 100,
        amount = 1000,
        amplitude = NA_real_,
        pct_chg = 1,
        chg = 1,
        turnover = NA_real_
      )
    },
    .package = "cnstockR"
  )

  old_opt <- getOption("cnstockR.source_config")
  on.exit(options(cnstockR.source_config = old_opt), add = TRUE)
  cnstockR:::cn_set_source("auto", fallback_sources = c("eastmoney", "netease"))

  out <- cnstockR::cn_get_daily(
    symbol = "600519",
    start = "20240101",
    end = "20240103",
    adjust = 0,
    source = "auto",
    max_retry = 0,
    timeout_sec = 1
  )

  expect_s3_class(out, "tbl_df")
  expect_equal(nrow(out), 1)
  expect_equal(calls, c("eastmoney", "netease"))
})

test_that("cn_get_daily_batch passes source and can continue on error", {
  testthat::local_mocked_bindings(
    cn_get_daily = function(symbol, start, end, adjust, source, max_retry, timeout_sec) {
      if (symbol == "000001") {
        stop("mock failure")
      }
      tibble::tibble(
        symbol = symbol,
        date = as.Date("2024-01-02"),
        open = 1,
        close = 1,
        high = 1,
        low = 1,
        volume = 1,
        amount = 1,
        amplitude = 0,
        pct_chg = 0,
        chg = 0,
        turnover = 0
      )
    },
    .package = "cnstockR"
  )

  expect_warning(
    out <- cnstockR::cn_get_daily_batch(
      symbols = c("600519", "000001"),
      start = "20240101",
      end = "20240103",
      adjust = 0,
      source = "netease",
      continue_on_error = TRUE,
      pause_sec = 0,
      max_retry = 0,
      timeout_sec = 1
    ),
    "failed symbol"
  )

  expect_equal(unique(out$symbol), "600519")
  expect_equal(nrow(out), 1)
})
