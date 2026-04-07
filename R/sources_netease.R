get_daily_netease <- function(symbol, dr, adjust, max_retry, timeout_sec) {
  if (!identical(adjust, 0L)) {
    return(tibble::tibble())
  }

  netease_code <- if (grepl("^(6|9)", normalize_symbol(symbol))) {
    paste0("0", normalize_symbol(symbol))
  } else {
    paste0("1", normalize_symbol(symbol))
  }

  url <- "http://quotes.money.163.com/service/chddata.html"
  query <- list(
    code = netease_code,
    start = dr$start,
    end = dr$end,
    fields = "TOPEN;HIGH;LOW;TCLOSE;CHG;PCHG;TURNOVER;VOTURNOVER;VATURNOVER"
  )

  txt <- request_text(url, query = query, max_retry = max_retry, timeout_sec = timeout_sec)
  parse_netease_rows(txt, symbol = symbol)
}
