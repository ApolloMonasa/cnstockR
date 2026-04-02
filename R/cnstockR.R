normalize_symbol <- function(symbol) {
  x <- toupper(gsub("\\s+", "", symbol))
  x <- gsub("\\.(SH|SZ)$", "", x)
  x
}

validate_symbol <- function(symbol) {
  s <- normalize_symbol(symbol)
  if (!grepl("^[0-9]{6}$", s)) {
    stop("symbol must be 6 digits, e.g. 600519 or 000300")
  }
  s
}

validate_adjust <- function(adjust) {
  if (!is.numeric(adjust) || length(adjust) != 1 || !adjust %in% c(0, 1, 2)) {
    stop("adjust must be one of 0 (none), 1 (forward), 2 (backward)")
  }
  as.integer(adjust)
}

normalize_yyyymmdd <- function(x, arg_name) {
  if (inherits(x, "Date")) {
    return(format(x, "%Y%m%d"))
  }

  if (!is.character(x) || length(x) != 1) {
    stop(arg_name, " must be Date or character in YYYYMMDD / YYYY-MM-DD")
  }

  x <- trimws(x)
  if (grepl("^[0-9]{8}$", x)) {
    return(x)
  }

  if (grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}$", x)) {
    return(gsub("-", "", x))
  }

  stop(arg_name, " must be Date or character in YYYYMMDD / YYYY-MM-DD")
}

validate_date_range <- function(start, end) {
  start8 <- normalize_yyyymmdd(start, "start")
  end8 <- normalize_yyyymmdd(end, "end")

  if (start8 > end8) {
    stop("start must be earlier than or equal to end")
  }

  list(start = start8, end = end8)
}

symbol_to_secid <- function(symbol) {
  s <- validate_symbol(symbol)

  if (grepl("^(6|9)", s)) {
    return(paste0("1.", s))
  }

  if (grepl("^(0|2|3)", s)) {
    return(paste0("0.", s))
  }

  stop("cannot infer exchange from symbol: ", symbol)
}

symbol_to_secid_candidates <- function(symbol) {
  s <- validate_symbol(symbol)

  if (grepl("^(6|9)", s)) {
    return(c(paste0("1.", s), paste0("0.", s)))
  }

  if (grepl("^(0|2|3)", s)) {
    # 某些指数型代码（如 000300）在该接口可能走上证路由返回数据。
    return(c(paste0("1.", s), paste0("0.", s)))
  }

  c(paste0("1.", s), paste0("0.", s))
}

request_json <- function(url, query, max_retry = 2, timeout_sec = 20) {
  last_err <- NULL

  if (!is.numeric(max_retry) || length(max_retry) != 1 || max_retry < 0) {
    stop("max_retry must be a non-negative number")
  }
  if (!is.numeric(timeout_sec) || length(timeout_sec) != 1 || timeout_sec <= 0) {
    stop("timeout_sec must be a positive number")
  }

  for (i in seq_len(max_retry + 1)) {
    req <- httr2::request(url) |>
      httr2::req_url_query(!!!query) |>
      httr2::req_user_agent("cnstockR/0.1.0") |>
      httr2::req_timeout(timeout_sec)

    resp <- tryCatch(httr2::req_perform(req), error = function(e) e)

    if (!inherits(resp, "error")) {
      txt <- httr2::resp_body_string(resp)
      return(jsonlite::fromJSON(txt))
    }

    last_err <- resp
    Sys.sleep(0.5 * i)
  }

  stop("request failed: ", conditionMessage(last_err))
}

parse_kline_rows <- function(rows, symbol) {
  if (length(rows) == 0) {
    return(tibble::tibble())
  }

  mat <- do.call(rbind, strsplit(rows, ",", fixed = TRUE))

  out <- tibble::tibble(
    symbol = symbol,
    date = as.Date(mat[, 1]),
    open = as.numeric(mat[, 2]),
    close = as.numeric(mat[, 3]),
    high = as.numeric(mat[, 4]),
    low = as.numeric(mat[, 5]),
    volume = as.numeric(mat[, 6]),
    amount = as.numeric(mat[, 7]),
    amplitude = as.numeric(mat[, 8]),
    pct_chg = as.numeric(mat[, 9]),
    chg = as.numeric(mat[, 10]),
    turnover = as.numeric(mat[, 11])
  )

  out[order(out$date), , drop = FALSE]
}

#' 获取单个A股/指数的日线OHLCV数据
#'
#' @param symbol 字符串，6位股票/指数代码，例如 "600519"。
#' @param start 开始日期，支持 Date 或字符串（YYYYMMDD / YYYY-MM-DD）。
#' @param end 结束日期，支持 Date 或字符串（YYYYMMDD / YYYY-MM-DD）。
#' @param adjust 整数，复权方式：0 不复权，1 前复权，2 后复权。
#' @param max_retry 非负数，单次请求失败时最大重试次数。
#' @param timeout_sec 正数，请求超时时间（秒）。
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
                         max_retry = 2,
                         timeout_sec = 20) {
  dr <- validate_date_range(start, end)
  adjust <- validate_adjust(adjust)
  secid_candidates <- symbol_to_secid_candidates(symbol)

  url <- "https://push2his.eastmoney.com/api/qt/stock/kline/get"
  for (secid in secid_candidates) {
    query <- list(
      fields1 = "f1,f2,f3,f4,f5,f6",
      fields2 = "f51,f52,f53,f54,f55,f56,f57,f58,f59,f60,f61",
      ut = "fa5fd1943c7b386f172d6893dbfba10b",
      klt = "101",
      fqt = as.character(adjust),
      secid = secid,
      beg = dr$start,
      end = dr$end
    )

    json <- request_json(url, query, max_retry = max_retry, timeout_sec = timeout_sec)

    if (!is.null(json$data) && !is.null(json$data$klines) && length(json$data$klines) > 0) {
      return(parse_kline_rows(json$data$klines, symbol = normalize_symbol(symbol)))
    }
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
#' @return 返回合并后的行情数据 tibble。若全部失败则返回空 tibble。
#' @export
cn_get_daily_batch <- function(symbols,
                               start = "20221201",
                               end = format(Sys.Date(), "%Y%m%d"),
                               adjust = 1,
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
