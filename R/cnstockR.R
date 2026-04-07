#' 获取单个A股/指数的日线 OHLCV 行情
#'
#' 从指定数据源抓取单个股票或指数在给定日期区间内的日线数据，并统一整理为
#' 标准字段（symbol/date/open/close/high/low/volume/amount 等）。
#' 当 `source = "auto"` 时，会按照当前回退顺序依次尝试多个上游源，尽量提高可用性。
#'
#' @param symbol 字符串，6 位证券代码（股票或指数），例如 `"600519"`、`"000300"`。
#' @param start 开始日期。支持 `Date` 或字符串（`YYYYMMDD` / `YYYY-MM-DD`）。
#' @param end 结束日期。支持 `Date` 或字符串（`YYYYMMDD` / `YYYY-MM-DD`）。
#' @param adjust 整数复权方式：`0` 不复权，`1` 前复权，`2` 后复权。
#' @param source 数据源：`"auto"`、`"eastmoney"`、`"sina"`、`"netease"`。
#'   其中 `"auto"` 会按配置的 fallback 顺序自动切换。
#' @param max_retry 非负整数。单个上游请求失败时的最大重试次数。
#' @param timeout_sec 正数。单次请求超时时间（秒）。
#'
#' @return 一个 `tibble`，通常包含以下字段：
#'   `symbol`, `date`, `open`, `close`, `high`, `low`, `volume`, `amount`,
#'   `amplitude`, `pct_chg`, `chg`, `turnover`。
#'   若指定源返回空数据会报错；`source = "auto"` 且全部源失败时会汇总失败信息后报错。
#'
#' @examples
#' \dontrun{
#' # 前复权抓取单个股票
#' cn_get_daily("600519", start = "20230101", end = "20231231", adjust = 1)
#'
#' # 自动切源（推荐默认）
#' cn_get_daily("000300", source = "auto")
#' }
#' @export
cn_get_daily <- function(symbol,
                         start = "20221201",
                         end = format(Sys.Date(), "%Y%m%d"),
                         adjust = 1,
                         source = cn_get_source(),
                         max_retry = 2,
                         timeout_sec = 20) {
  dr <- validate_date_range(start, end)
  adjust <- validate_adjust(adjust)

  source <- tolower(source)
  source <- match.arg(source, choices = c("auto", "eastmoney", "sina", "netease"))
  if (source == "auto") {
    source_config <- cn_get_source_config()
    candidate_sources <- unique(c(source_config$fallback_sources, "eastmoney", "sina", "netease"))
  } else {
    candidate_sources <- source
  }

  last_err <- NULL
  for (one_source in candidate_sources) {
    one <- tryCatch(
      get_daily_by_source(
        symbol = symbol,
        dr = dr,
        adjust = adjust,
        source = one_source,
        max_retry = max_retry,
        timeout_sec = timeout_sec
      ),
      error = function(e) e
    )

    if (!inherits(one, "error") && nrow(one) > 0) {
      return(one)
    }

    if (inherits(one, "error")) {
      cn_set_last_failure(
        source = one_source,
        symbol = symbol,
        message = conditionMessage(one),
        kind = "error"
      )
      last_err <- one
    } else {
      cn_set_last_failure(
        source = one_source,
        symbol = symbol,
        message = "empty response",
        kind = "empty"
      )
    }
  }

  if (source == "auto" && !is.null(last_err)) {
    stop("all data sources failed for symbol: ", symbol, ": ", conditionMessage(last_err))
  }

  stop("empty response for symbol: ", symbol)
}

#' 批量抓取多个代码的日线行情并按行合并
#'
#' 对输入代码向量逐个调用 [cn_get_daily()]，并将结果按行拼接为单个 `tibble`。
#' 函数会自动去重 `symbols`，并支持请求间隔控制、失败即停或失败跳过两种模式。
#'
#' @param symbols 非空字符向量，元素为 6 位证券代码。
#' @param start 开始日期。支持 `Date` 或字符串（`YYYYMMDD` / `YYYY-MM-DD`）。
#' @param end 结束日期。支持 `Date` 或字符串（`YYYYMMDD` / `YYYY-MM-DD`）。
#' @param adjust 整数复权方式：`0` 不复权，`1` 前复权，`2` 后复权。
#' @param source 数据源：`"auto"`、`"eastmoney"`、`"sina"`、`"netease"`。
#' @param pause_sec 非负数。相邻代码请求之间的暂停秒数，建议在批量场景中适当增大。
#' @param continue_on_error 逻辑值。`TRUE` 时跳过失败代码并给出 warning；
#'   `FALSE` 时遇到首个失败即终止并报错。
#' @param max_retry 非负整数。单个上游请求失败时的最大重试次数。
#' @param timeout_sec 正数。单次请求超时时间（秒）。
#'
#' @return 合并后的 `tibble`。当 `continue_on_error = TRUE` 且全部代码失败时，
#'   返回 0 行 `tibble`。
#'
#' @examples
#' \dontrun{
#' cn_get_daily_batch(
#'   symbols = c("600519", "000001", "000300"),
#'   start = "20240101",
#'   end = "20241231",
#'   adjust = 1,
#'   pause_sec = 0.2,
#'   continue_on_error = TRUE
#' )
#' }
#' @export
cn_get_daily_batch <- function(symbols,
                               start = "20221201",
                               end = format(Sys.Date(), "%Y%m%d"),
                               adjust = 1,
                               source = cn_get_source(),
                               pause_sec = 0.15,
                               continue_on_error = FALSE,
                               max_retry = 2,
                               timeout_sec = 20) {
  if (!is.character(symbols) || length(symbols) == 0) {
    stop("symbols must be a non-empty character vector")
  }
  if (!is.numeric(pause_sec) || length(pause_sec) != 1 || pause_sec < 0) {
    stop("pause_sec must be a non-negative number")
  }
  if (!is.logical(continue_on_error) || length(continue_on_error) != 1) {
    stop("continue_on_error must be TRUE or FALSE")
  }

  dr <- validate_date_range(start, end)
  adjust <- validate_adjust(adjust)
  symbols <- unique(symbols)
  parts <- vector("list", length(symbols))

  for (i in seq_along(symbols)) {
    one <- tryCatch(
      cn_get_daily(
        symbols[[i]],
        start = dr$start,
        end = dr$end,
        adjust = adjust,
        source = source,
        max_retry = max_retry,
        timeout_sec = timeout_sec
      ),
      error = function(e) e
    )

    if (inherits(one, "error")) {
      if (continue_on_error) {
        warning("failed symbol ", symbols[[i]], ": ", conditionMessage(one), call. = FALSE)
        parts[[i]] <- NULL
      } else {
        stop(one)
      }
    } else {
      parts[[i]] <- one
    }

    if (pause_sec > 0 && i < length(symbols)) {
      Sys.sleep(pause_sec)
    }
  }

  dplyr::bind_rows(parts)
}

#' 将行情数据写出为 parquet 文件
#'
#' 便捷封装 `arrow::write_parquet()`，用于将抓取结果高效落盘，便于后续分析与共享。
#'
#' @param x `data.frame` 或 `tibble`。
#' @param file 输出 parquet 文件路径（建议以 `.parquet` 结尾）。
#'
#' @return 不可见地返回输出路径 `file`。
#'
#' @details
#' 该函数依赖 `arrow` 包。若未安装会直接报错。
#'
#' @examples
#' \dontrun{
#' x <- cn_get_daily("600519", start = "20240101", end = "20241231")
#' cn_to_parquet(x, "data/600519_daily.parquet")
#' }
#' @export
cn_to_parquet <- function(x, file) {
  if (!requireNamespace("arrow", quietly = TRUE)) {
    stop("package 'arrow' is required for parquet output")
  }
  arrow::write_parquet(x, file)
  invisible(file)
}
