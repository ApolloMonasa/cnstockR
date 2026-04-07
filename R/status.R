null_coalesce <- function(x, y) {
  if (is.null(x)) {
    return(y)
  }
  x
}

cn_set_last_failure <- function(source, symbol, message, kind = c("error", "empty")) {
  kind <- match.arg(kind)
  options(cnstockR.last_failure = list(
    time = Sys.time(),
    source = as.character(source),
    symbol = as.character(symbol),
    kind = kind,
    message = as.character(message)
  ))
  invisible(getOption("cnstockR.last_failure"))
}

cn_get_last_failure <- function() {
  getOption("cnstockR.last_failure")
}

cn_clear_last_failure <- function() {
  options(cnstockR.last_failure = NULL)
  invisible(NULL)
}

#' 获取运行时状态摘要
#'
#' 汇总当前数据源配置、请求配置摘要以及最近一次失败信息，便于快速诊断拉取异常。
#'
#' @return 一个列表，包含：
#'   `default_source`（当前默认源）、`fallback_sources`（自动模式回退顺序）、
#'   `request`（请求配置摘要）以及 `last_failure`（最近失败元数据，若无则为 `NULL`）。
#'
#' @examples
#' st <- cn_get_status()
#' st$default_source
#' st$request
#' @export
cn_get_status <- function() {
  source_cfg <- cn_get_source_config()
  req_cfg <- cn_get_request_config()

  list(
    default_source = source_cfg$default_source,
    fallback_sources = source_cfg$fallback_sources,
    request = list(
      user_agent_count = length(null_coalesce(req_cfg$user_agents, character(0))),
      referer = null_coalesce(req_cfg$referer, NA_character_),
      has_cookie = !is.null(req_cfg$cookie) && nzchar(req_cfg$cookie),
      proxy_count = length(null_coalesce(req_cfg$proxy_pool, character(0))),
      extra_headers = names(null_coalesce(req_cfg$headers, list()))
    ),
    last_failure = cn_get_last_failure()
  )
}

#' 探测各数据源可用性并给出建议配置
#'
#' 对当前候选数据源逐一进行小范围抓取测试，返回每个源是否可用、返回行数、
#' 实际使用的复权参数与错误信息，并给出推荐的默认源与自动回退设置建议。
#'
#' @param symbol 6 位证券代码（股票或指数）。
#' @param start 开始日期，默认最近 30 天（`YYYYMMDD`）。
#' @param end 结束日期，默认当天（`YYYYMMDD`）。
#' @param adjust 复权方式：`0` 不复权，`1` 前复权，`2` 后复权。
#' @param max_retry 每个源探测请求的最大重试次数。
#' @param timeout_sec 每个源探测请求的超时时间（秒）。
#'
#' @return 一个列表：
#'   `summary` 为探测结果 `tibble`；`recommendation` 为建议配置列表（含推荐默认源）。
#'
#' @examples
#' \dontrun{
#' res <- cn_ping_sources("600519")
#' res$summary
#' res$recommendation
#' }
#' @export
cn_ping_sources <- function(symbol = "600519",
                            start = format(Sys.Date() - 30, "%Y%m%d"),
                            end = format(Sys.Date(), "%Y%m%d"),
                            adjust = 1,
                            max_retry = 1,
                            timeout_sec = 10) {
  validate_symbol(symbol)
  adjust <- validate_adjust(adjust)

  source_cfg <- cn_get_source_config()
  sources <- unique(c(source_cfg$fallback_sources, "eastmoney", "tencent", "sina", "netease"))

  parts <- lapply(sources, function(one_source) {
    one_adjust <- if (identical(one_source, "netease")) 0L else adjust

    out <- tryCatch(
      cn_get_daily(
        symbol = symbol,
        start = start,
        end = end,
        adjust = one_adjust,
        source = one_source,
        max_retry = max_retry,
        timeout_sec = timeout_sec
      ),
      error = function(e) e
    )

    if (inherits(out, "error")) {
      return(tibble::tibble(
        source = one_source,
        available = FALSE,
        rows = 0L,
        adjust_used = one_adjust,
        message = conditionMessage(out)
      ))
    }

    if (nrow(out) == 0) {
      return(tibble::tibble(
        source = one_source,
        available = FALSE,
        rows = 0L,
        adjust_used = one_adjust,
        message = "empty response"
      ))
    }

    tibble::tibble(
      source = one_source,
      available = TRUE,
      rows = as.integer(nrow(out)),
      adjust_used = one_adjust,
      message = "ok"
    )
  })

  summary_tbl <- dplyr::bind_rows(parts)
  ok_sources <- summary_tbl$source[summary_tbl$available]

  recommendation <- if (length(ok_sources) == 0) {
    list(
      suggested_default = NA_character_,
      suggested_auto_fallback = NA_character_,
      note = "no source is currently available"
    )
  } else {
    list(
      suggested_default = ok_sources[[1]],
      suggested_auto_fallback = sprintf(
        "cn_set_source(\"auto\", fallback_sources = c(%s))",
        paste(sprintf("\"%s\"", ok_sources), collapse = ", ")
      ),
      note = "choose the first available source as default"
    )
  }

  list(summary = summary_tbl, recommendation = recommendation)
}
