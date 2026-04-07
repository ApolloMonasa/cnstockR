test_that("request config set and reset works", {
  old_opt <- getOption("cnstockR.request_config")
  on.exit(options(cnstockR.request_config = old_opt), add = TRUE)

  cnstockR:::cn_reset_request_config()
  default_cfg <- cnstockR:::cn_get_request_config()

  cnstockR:::cn_set_request_config(
    user_agents = c("ua-a", "ua-b"),
    referer = "https://example.com/",
    cookie = "foo=bar",
    proxy_pool = c("http://127.0.0.1:7890"),
    headers = list("X-Test" = "1")
  )

  cfg <- cnstockR:::cn_get_request_config()
  expect_equal(cfg$user_agents, c("ua-a", "ua-b"))
  expect_equal(cfg$referer, "https://example.com/")
  expect_equal(cfg$cookie, "foo=bar")
  expect_equal(cfg$proxy_pool, c("http://127.0.0.1:7890"))
  expect_equal(cfg$headers[["X-Test"]], "1")

  cnstockR:::cn_reset_request_config()
  reset_cfg <- cnstockR:::cn_get_request_config()
  expect_equal(reset_cfg$referer, default_cfg$referer)
  expect_equal(reset_cfg$cookie, default_cfg$cookie)
})

test_that("source config set/get works", {
  old_opt <- getOption("cnstockR.source_config")
  on.exit(options(cnstockR.source_config = old_opt), add = TRUE)

  cnstockR:::cn_set_source("auto", fallback_sources = c("eastmoney", "netease"))
  expect_equal(cnstockR:::cn_get_source(), "auto")

  cnstockR:::cn_set_source("netease")
  expect_equal(cnstockR:::cn_get_source(), "netease")
})
