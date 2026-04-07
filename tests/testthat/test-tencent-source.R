test_that("tencent source parses raw day kline", {
  testthat::local_mocked_bindings(
    request_json = function(url, query, max_retry = 2, timeout_sec = 20) {
      list(
        data = list(
          sh600519 = list(
            day = list(
              c("2024-01-01", "10", "11", "12", "9", "100"),
              c("2024-01-02", "11", "12", "13", "10", "120")
            )
          )
        )
      )
    },
    .package = "cnstockR"
  )

  dr <- list(start = "20240101", end = "20240103")
  out <- cnstockR:::get_daily_tencent("600519", dr = dr, adjust = 0L, max_retry = 0, timeout_sec = 1)

  expect_equal(nrow(out), 2)
  expect_equal(out$symbol[[1]], "600519")
  expect_equal(out$open[[1]], 10)
  expect_equal(out$close[[2]], 12)
})

test_that("tencent source parses qfq and hfq kline", {
  testthat::local_mocked_bindings(
    request_json = function(url, query, max_retry = 2, timeout_sec = 20) {
      if (grepl("fqkline", url)) {
        return(list(
          data = list(
            sh600519 = list(
              qfqday = list(
                c("2024-01-01", "5", "5.5", "6", "4.5", "100"),
                c("2024-01-02", "6", "6.5", "7", "5.5", "120")
              ),
              hfqday = list(
                c("2024-01-01", "20", "22", "24", "18", "100"),
                c("2024-01-02", "22", "24", "26", "20", "120")
              )
            )
          )
        ))
      }
      stop("unexpected url")
    },
    .package = "cnstockR"
  )

  dr <- list(start = "20240101", end = "20240103")
  qfq <- cnstockR:::get_daily_tencent("600519", dr = dr, adjust = 1L, max_retry = 0, timeout_sec = 1)
  hfq <- cnstockR:::get_daily_tencent("600519", dr = dr, adjust = 2L, max_retry = 0, timeout_sec = 1)

  expect_equal(qfq$open[[1]], 5)
  expect_equal(hfq$close[[2]], 24)
})

test_that("tencent source retries candidate prefixes for index codes", {
  calls <- character(0)

  testthat::local_mocked_bindings(
    request_json = function(url, query, max_retry = 2, timeout_sec = 20) {
      calls <<- c(calls, query$param)
      if (startsWith(query$param, "sh000300")) {
        return(list(
          data = list(
            sh000300 = list(
              day = list(
                c("2024-01-01", "10", "11", "12", "9", "100")
              )
            )
          )
        ))
      }
      list(data = list(sz000300 = list(day = list())))
    },
    .package = "cnstockR"
  )

  dr <- list(start = "20240101", end = "20240103")
  out <- cnstockR:::get_daily_tencent("000300", dr = dr, adjust = 0L, max_retry = 0, timeout_sec = 1)

  expect_match(calls[[1]], "^sh000300,day,,,\\d+$")
  expect_equal(nrow(out), 1)
  expect_equal(out$symbol[[1]], "000300")
})