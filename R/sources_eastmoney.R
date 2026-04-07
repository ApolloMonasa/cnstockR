get_daily_eastmoney <- function(symbol, dr, adjust, max_retry, timeout_sec) {
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

  tibble::tibble()
}
