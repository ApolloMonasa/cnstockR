test_that("cn_get_status returns source/request summary", {
  old_source <- getOption("cnstockR.source_config")
  old_req <- getOption("cnstockR.request_config")
  old_fail <- getOption("cnstockR.last_failure")
  on.exit(options(cnstockR.source_config = old_source, cnstockR.request_config = old_req, cnstockR.last_failure = old_fail), add = TRUE)

  cnstockR:::cn_set_source("auto", fallback_sources = c("eastmoney", "sina", "netease"))
  cnstockR:::cn_set_request_config(
    user_agents = c("ua1", "ua2"),
    referer = "https://example.com/",
    cookie = "a=b",
    proxy_pool = c("http://127.0.0.1:7890"),
    headers = list("X-Test" = "1")
  )
  cnstockR:::cn_set_last_failure("sina", "600519", "mock fail", kind = "error")

  st <- cnstockR::cn_get_status()
  expect_equal(st$default_source, "auto")
  expect_true("sina" %in% st$fallback_sources)
  expect_equal(st$request$user_agent_count, 2)
  expect_true(st$request$has_cookie)
  expect_equal(st$last_failure$source, "sina")
})

test_that("cn_ping_sources returns summary and recommendation", {
  testthat::local_mocked_bindings(
    cn_get_daily = function(symbol, start, end, adjust, source, max_retry, timeout_sec) {
      if (source == "eastmoney") {
        return(tibble::tibble(symbol = symbol, date = as.Date("2024-01-02"), open = 1, close = 1, high = 1, low = 1, volume = 1, amount = 1, amplitude = 0, pct_chg = 0, chg = 0, turnover = 0))
      }
      if (source == "sina") {
        return(tibble::tibble(symbol = symbol, date = as.Date("2024-01-03"), open = 1, close = 1, high = 1, low = 1, volume = 1, amount = 1, amplitude = 0, pct_chg = 0, chg = 0, turnover = 0))
      }
      stop("mock unavailable")
    },
    .package = "cnstockR"
  )

  old_source <- getOption("cnstockR.source_config")
  on.exit(options(cnstockR.source_config = old_source), add = TRUE)
  cnstockR:::cn_set_source("auto", fallback_sources = c("eastmoney", "sina", "netease"))

  res <- cnstockR::cn_ping_sources("600519", adjust = 1, max_retry = 0, timeout_sec = 1)
  expect_s3_class(res$summary, "tbl_df")
  expect_true(any(res$summary$available))
  expect_equal(res$recommendation$suggested_default, "eastmoney")
})
