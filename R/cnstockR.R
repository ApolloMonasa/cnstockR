#' 获取单个A股/指数的日线OHLCV数据
#'
#' @param symbol 字符串，6位股票/指数代码，例如 "600519"。
#' @param start 开始日期，支持 Date 或字符串（YYYYMMDD / YYYY-MM-DD）。
#' @param end 结束日期，支持 Date 或字符串（YYYYMMDD / YYYY-MM-DD）。
#' @param adjust 整数，复权方式：0 不复权，1 前复权，2 后复权。
#' @param max_retry 非负数，单次请求失败时最大重试次数。
#' @param timeout_sec 正数，请求超时时间（秒）。
#' @param source 数据源，支持 `auto`、`eastmoney`、`sina`、`netease`。
#' @return 返回标准化后的日度行情 tibble。
#' @examples
#' \dontrun{
#' cn_get_daily("600519", start = "20230101", end = "20231231", adjust = 1)
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

#' 批量抓取多个代码并按行合并
#'
#' @param symbols 字符向量，元素为6位代码。
#' @param start 开始日期，支持 Date 或字符串（YYYYMMDD / YYYY-MM-DD）。
#' @param end 结束日期，支持 Date 或字符串（YYYYMMDD / YYYY-MM-DD）。
#' @param adjust 整数，复权方式。
#' @param pause_sec 数值型，请求之间的暂停秒数。
#' @param continue_on_error 逻辑值，TRUE 时跳过失败代码并记录 warning。
#' @param max_retry 非负数，单次请求失败时最大重试次数。
#' @param timeout_sec 正数，请求超时时间（秒）。
#' @param source 数据源，支持 `auto`、`eastmoney`、`sina`、`netease`。
#' @return 返回合并后的行情数据 tibble。若全部失败则返回空 tibble。
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

#' 将数据保存为 parquet 文件
#'
#' @param x 数据框或 tibble。
#' @param file 输出 parquet 文件路径。
#' @return 隐式返回输出文件路径。
#' @export
cn_to_parquet <- function(x, file) {
  if (!requireNamespace("arrow", quietly = TRUE)) {
    stop("package 'arrow' is required for parquet output")
  }
  arrow::write_parquet(x, file)
  invisible(file)
}
