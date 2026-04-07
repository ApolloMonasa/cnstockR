test_that("sina source supports qfq adjust with factor", {
  testthat::local_mocked_bindings(
    request_text = function(url, query = list(), max_retry = 2, timeout_sec = 20) {
      if (grepl("qfq\\.js$", url)) {
        return('var data={"data":[["2024-01-01","2"],["2024-01-02","2"]]};')
      }
      '[{"day":"2024-01-01","open":"10","high":"12","low":"9","close":"11","volume":"100"}, {"day":"2024-01-02","open":"12","high":"14","low":"11","close":"13","volume":"120"}]'
    },
    .package = "cnstockR"
  )

  dr <- list(start = "20240101", end = "20240103")
  out <- cnstockR:::get_daily_sina("600519", dr = dr, adjust = 1L, max_retry = 0, timeout_sec = 1)

  expect_equal(nrow(out), 2)
  expect_equal(out$symbol[[1]], "600519")
  expect_equal(out$open[[1]], 5)
  expect_equal(out$close[[2]], 6.5)
})

test_that("sina source supports hfq adjust with factor", {
  testthat::local_mocked_bindings(
    request_text = function(url, query = list(), max_retry = 2, timeout_sec = 20) {
      if (grepl("hfq\\.js$", url)) {
        return('var data={"data":[["2024-01-01","2"],["2024-01-02","2"]]};')
      }
      '[{"day":"2024-01-01","open":"10","high":"12","low":"9","close":"11","volume":"100"}, {"day":"2024-01-02","open":"12","high":"14","low":"11","close":"13","volume":"120"}]'
    },
    .package = "cnstockR"
  )

  dr <- list(start = "20240101", end = "20240103")
  out <- cnstockR:::get_daily_sina("600519", dr = dr, adjust = 2L, max_retry = 0, timeout_sec = 1)

  expect_equal(nrow(out), 2)
  expect_equal(out$open[[1]], 20)
  expect_equal(out$close[[2]], 26)
})
