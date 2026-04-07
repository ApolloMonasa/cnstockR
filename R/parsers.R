parse_netease_rows <- function(text, symbol) {
  if (!nzchar(text)) {
    return(tibble::tibble())
  }

  rows <- tryCatch(
    utils::read.csv(
      text = text,
      stringsAsFactors = FALSE,
      fileEncoding = "UTF-8",
      check.names = FALSE
    ),
    error = function(e) NULL
  )

  if (is.null(rows) || nrow(rows) == 0) {
    converted_text <- tryCatch(iconv(text, from = "GB18030", to = "UTF-8"), error = function(e) text)
    rows <- utils::read.csv(
      text = converted_text,
      stringsAsFactors = FALSE,
      fileEncoding = "UTF-8",
      check.names = FALSE
    )
  }

  if (nrow(rows) == 0) {
    return(tibble::tibble())
  }

  names(rows) <- trimws(names(rows))
  rows <- rows[order(as.character(rows[[1]])), , drop = FALSE]

  date_col <- intersect(c("\u65e5\u671f", "date"), names(rows))[1]
  if (is.na(date_col)) {
    stop("netease response does not contain a date column")
  }

  pick_column <- function(candidates) {
    matched <- intersect(candidates, names(rows))
    if (length(matched) == 0) {
      return(rep(NA, nrow(rows)))
    }
    rows[[matched[1]]]
  }

  out <- tibble::tibble(
    symbol = normalize_symbol(symbol),
    date = as.Date(rows[[date_col]]),
    open = suppressWarnings(as.numeric(pick_column(c("\u5f00\u76d8\u4ef7", "\u5f00\u76d8", "open")))),
    close = suppressWarnings(as.numeric(pick_column(c("\u6536\u76d8\u4ef7", "\u6536\u76d8", "close", "TCLOSE")))),
    high = suppressWarnings(as.numeric(pick_column(c("\u6700\u9ad8\u4ef7", "\u6700\u9ad8", "high", "HIGH")))),
    low = suppressWarnings(as.numeric(pick_column(c("\u6700\u4f4e\u4ef7", "\u6700\u4f4e", "low", "LOW")))),
    volume = suppressWarnings(as.numeric(pick_column(c("\u6210\u4ea4\u91cf", "VOTURNOVER", "volume")))),
    amount = suppressWarnings(as.numeric(pick_column(c("\u6210\u4ea4\u91d1\u989d", "VATURNOVER", "amount")))),
    amplitude = NA_real_,
    pct_chg = suppressWarnings(as.numeric(pick_column(c("\u6da8\u8dcc\u5e45", "pct_chg", "PCHG")))),
    chg = suppressWarnings(as.numeric(pick_column(c("\u6da8\u8dcc\u989d", "chg", "CHG")))),
    turnover = suppressWarnings(as.numeric(pick_column(c("\u6362\u624b\u7387", "turnover", "TURNOVER"))))
  )

  out[order(out$date), , drop = FALSE]
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
