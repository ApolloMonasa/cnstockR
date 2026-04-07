get_daily_by_source <- function(symbol, dr, adjust, source, max_retry, timeout_sec) {
  if (source == "eastmoney") {
    return(get_daily_eastmoney(symbol, dr, adjust, max_retry, timeout_sec))
  }
  if (source == "sina") {
    return(get_daily_sina(symbol, dr, adjust, max_retry, timeout_sec))
  }
  if (source == "netease") {
    return(get_daily_netease(symbol, dr, adjust, max_retry, timeout_sec))
  }
  stop("unsupported source: ", source)
}
