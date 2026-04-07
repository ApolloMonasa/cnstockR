symbol_to_sina_symbol <- function(symbol) {
  s <- validate_symbol(symbol)

  if (grepl("^(6|9)", s)) {
    return(paste0("sh", s))
  }

  if (grepl("^(0|2|3)", s)) {
    return(paste0("sz", s))
  }

  stop("cannot infer market for symbol: ", symbol)
}

unwrap_json_payload <- function(text) {
  txt <- trimws(text)
  if (!nzchar(txt)) {
    return(txt)
  }

  if (grepl("^[\\[{]", txt)) {
    return(sub(";\\s*$", "", txt))
  }

  # Sina may prepend anti-bot scripts/comments before JSONP payload.
  # Extract the last assignment payload instead of splitting at the first '='.
  txt <- sub("^\\s*/\\*.*?\\*/\\s*", "", txt, perl = TRUE)

  m_wrap <- regexec("=\\s*\\((\\s*[\\[{].*[\\]}]\\s*)\\)\\s*;?\\s*$", txt, perl = TRUE)
  hit_wrap <- regmatches(txt, m_wrap)[[1]]
  if (length(hit_wrap) >= 2) {
    return(trimws(hit_wrap[2]))
  }

  m_plain <- regexec("=\\s*([\\[{].*[\\]}])\\s*;?\\s*$", txt, perl = TRUE)
  hit_plain <- regmatches(txt, m_plain)[[1]]
  if (length(hit_plain) >= 2) {
    return(trimws(hit_plain[2]))
  }

  txt <- sub("^.*=", "", txt)
  txt <- sub(";\\s*$", "", txt)
  txt <- trimws(txt)
  if (grepl("^\\(", txt) && grepl("\\)$", txt)) {
    txt <- substr(txt, 2, nchar(txt) - 1)
    txt <- trimws(txt)
  }

  txt
}

as_num <- function(x) {
  suppressWarnings(as.numeric(gsub(",", "", as.character(x), fixed = TRUE)))
}

fill_factor <- function(x) {
  if (length(x) == 0) {
    return(x)
  }

  out <- as.numeric(x)
  non_na <- which(!is.na(out))
  if (length(non_na) == 0) {
    return(out)
  }

  out[seq_len(non_na[1] - 1)] <- out[non_na[1]]
  last <- out[non_na[1]]
  for (i in seq_along(out)) {
    if (!is.na(out[i])) {
      last <- out[i]
    } else {
      out[i] <- last
    }
  }

  out
}

parse_sina_adjust_factor <- function(text) {
  txt <- trimws(text)
  if (!nzchar(txt)) {
    return(tibble::tibble())
  }

  txt <- sub("^\\s*/\\*.*?\\*/\\s*", "", txt, perl = TRUE)
  txt <- sub("^\\s*var\\s+[^=]+\\s*=\\s*", "", txt, perl = TRUE)
  txt <- sub(";\\s*/\\*.*$", "", txt, perl = TRUE)
  txt <- sub(";\\s*$", "", txt)
  txt <- trimws(txt)

  parsed <- tryCatch(jsonlite::fromJSON(txt, simplifyVector = TRUE), error = function(e) NULL)
  if (is.null(parsed)) {
    legacy_hits <- regmatches(
      txt,
      gregexpr('\\["([0-9]{4}-[0-9]{2}-[0-9]{2})","?([0-9.]+)"?', txt, perl = TRUE)
    )[[1]]

    if (length(legacy_hits) == 0) {
      return(tibble::tibble())
    }

    dates <- sub('^\\["([0-9]{4}-[0-9]{2}-[0-9]{2})".*$', '\\1', legacy_hits)
    factors <- sub('^\\["[0-9]{4}-[0-9]{2}-[0-9]{2}","?([0-9.]+)"?.*$', '\\1', legacy_hits)

    return(tibble::tibble(
      date = as.Date(dates),
      factor = as_num(factors)
    ))
  }

  if (is.list(parsed) && !is.null(parsed$data)) {
    factor_tbl <- parsed$data
    if (is.data.frame(factor_tbl)) {
      date_col <- intersect(c("d", "day", "date"), names(factor_tbl))[1]
      factor_col <- intersect(c("f", "factor"), names(factor_tbl))[1]
      if (!is.na(date_col) && !is.na(factor_col)) {
        return(tibble::tibble(
          date = as.Date(factor_tbl[[date_col]]),
          factor = as_num(factor_tbl[[factor_col]])
        ))
      }
    }
  }

  if (is.data.frame(parsed)) {
    date_col <- intersect(c("d", "day", "date"), names(parsed))[1]
    factor_col <- intersect(c("f", "factor"), names(parsed))[1]
    if (!is.na(date_col) && !is.na(factor_col)) {
      return(tibble::tibble(
        date = as.Date(parsed[[date_col]]),
        factor = as_num(parsed[[factor_col]])
      ))
    }
  }

  tibble::tibble()
}

get_sina_adjust_factor <- function(symbol, method, max_retry, timeout_sec) {
  sina_symbol <- symbol_to_sina_symbol(symbol)
  url <- sprintf("https://finance.sina.com.cn/realstock/company/%s/%s.js", sina_symbol, method)
  txt <- request_text(url, query = list(), max_retry = max_retry, timeout_sec = timeout_sec)
  parse_sina_adjust_factor(txt)
}

standardize_sina_rows <- function(df, symbol, dr) {
  if (is.null(df) || nrow(df) == 0) {
    return(tibble::tibble())
  }

  pick <- function(candidates) {
    matched <- intersect(candidates, names(df))
    if (length(matched) == 0) {
      return(rep(NA, nrow(df)))
    }
    df[[matched[1]]]
  }

  out <- tibble::tibble(
    symbol = normalize_symbol(symbol),
    date = as.Date(pick(c("day", "date", "d"))),
    open = as_num(pick(c("open", "o"))),
    close = as_num(pick(c("close", "c"))),
    high = as_num(pick(c("high", "h"))),
    low = as_num(pick(c("low", "l"))),
    volume = as_num(pick(c("volume", "v"))),
    amount = as_num(pick(c("amount", "m"))),
    amplitude = NA_real_,
    pct_chg = NA_real_,
    chg = NA_real_,
    turnover = as_num(pick(c("turnover")))
  )

  out <- out[!is.na(out$date), , drop = FALSE]
  out <- out[out$date >= as.Date(dr$start, "%Y%m%d") & out$date <= as.Date(dr$end, "%Y%m%d"), , drop = FALSE]
  out <- out[order(out$date), , drop = FALSE]

  if (nrow(out) == 0) {
    return(out)
  }

  prev_close <- c(NA_real_, out$close[-nrow(out)])
  out$chg <- ifelse(is.na(prev_close), NA_real_, out$close - prev_close)
  out$pct_chg <- ifelse(is.na(prev_close) | prev_close == 0, NA_real_, out$chg / prev_close * 100)
  out$amplitude <- ifelse(is.na(prev_close) | prev_close == 0, NA_real_, (out$high - out$low) / prev_close * 100)

  out
}

apply_sina_adjust <- function(x, symbol, adjust, max_retry, timeout_sec) {
  if (nrow(x) == 0 || identical(adjust, 0L)) {
    return(x)
  }

  method <- if (identical(adjust, 1L)) "qfq" else "hfq"
  factors <- get_sina_adjust_factor(symbol, method, max_retry = max_retry, timeout_sec = timeout_sec)
  if (nrow(factors) == 0) {
    return(x)
  }

  # Current Sina factor feed is event-based rather than daily; keep factor rows
  # during merge so forward fill can propagate latest factor to trade dates.
  merged <- merge(x, factors, by = "date", all = TRUE, sort = TRUE)
  merged$factor <- fill_factor(merged$factor)
  merged <- merged[!is.na(merged$symbol), , drop = FALSE]
  merged <- merged[order(merged$date), , drop = FALSE]
  merged <- merged[!is.na(merged$factor) & merged$factor > 0, , drop = FALSE]

  if (nrow(merged) == 0) {
    return(tibble::tibble())
  }

  if (identical(method, "qfq")) {
    merged$open <- merged$open / merged$factor
    merged$high <- merged$high / merged$factor
    merged$low <- merged$low / merged$factor
    merged$close <- merged$close / merged$factor
  } else {
    merged$open <- merged$open * merged$factor
    merged$high <- merged$high * merged$factor
    merged$low <- merged$low * merged$factor
    merged$close <- merged$close * merged$factor
  }

  merged[, c("symbol", "date", "open", "close", "high", "low", "volume", "amount", "amplitude", "pct_chg", "chg", "turnover"), drop = FALSE]
}

get_daily_sina <- function(symbol, dr, adjust, max_retry, timeout_sec) {
  s <- symbol_to_sina_symbol(symbol)

  start_dt <- as.Date(dr$start, "%Y%m%d")
  end_dt <- as.Date(dr$end, "%Y%m%d")
  day_span <- as.integer(end_dt - start_dt) + 1L
  target_datalen <- max(200L, min(1500L, as.integer(ceiling(day_span * 1.5) + 60L)))
  datalen_candidates <- unique(c(target_datalen, 1000L, 500L, 300L, 200L))

  base_query <- list(
    symbol = s,
    scale = "240",
    ma = "no"
  )

  endpoint_candidates <- list(
    list(
      url = "https://money.finance.sina.com.cn/quotes_service/api/json_v2.php/CN_MarketData.getKLineData",
      parser = function(txt) {
        tryCatch(jsonlite::fromJSON(txt), error = function(e) NULL)
      }
    ),
    list(
      url = "https://quotes.sina.cn/cn/api/openapi.php/CN_MarketDataService.getKLineData",
      parser = function(txt) {
        dat <- tryCatch(jsonlite::fromJSON(txt), error = function(e) NULL)
        if (!is.null(dat) && is.list(dat) && !is.null(dat$result) && !is.null(dat$result$data)) {
          return(dat$result$data)
        }
        NULL
      }
    ),
    list(
      url = "https://quotes.sina.cn/cn/api/jsonp_v2.php/=/CN_MarketDataService.getKLineData",
      parser = function(txt) {
        payload <- unwrap_json_payload(txt)
        tryCatch(jsonlite::fromJSON(payload), error = function(e) NULL)
      }
    ),
    list(
      url = "https://quotes.sina.cn/cn/api/jsonp_v2.php/var%20_kline=/CN_MarketDataService.getKLineData",
      parser = function(txt) {
        payload <- unwrap_json_payload(txt)
        tryCatch(jsonlite::fromJSON(payload), error = function(e) NULL)
      }
    )
  )

  dat <- NULL
  for (ep in endpoint_candidates) {
    for (datalen in datalen_candidates) {
      query <- c(base_query, list(datalen = as.character(datalen)))
      txt <- tryCatch(
        request_text(ep$url, query = query, max_retry = max_retry, timeout_sec = timeout_sec),
        error = function(e) ""
      )

      if (!nzchar(txt)) {
        next
      }

      parsed <- ep$parser(txt)
      if (is.null(parsed)) {
        next
      }

      if (is.data.frame(parsed) && nrow(parsed) > 0) {
        dat <- parsed
        break
      }

      if (is.list(parsed) && length(parsed) > 0 && is.data.frame(parsed[[1]]) && nrow(parsed[[1]]) > 0) {
        dat <- parsed[[1]]
        break
      }
    }

    if (!is.null(dat)) {
      break
    }
  }

  if (is.null(dat)) {
    return(tibble::tibble())
  }

  standardized <- if (is.data.frame(dat)) {
    standardize_sina_rows(dat, symbol = symbol, dr = dr)
  } else if (is.list(dat) && length(dat) > 0 && is.data.frame(dat[[1]])) {
    standardize_sina_rows(dat[[1]], symbol = symbol, dr = dr)
  } else {
    tibble::tibble()
  }

  apply_sina_adjust(standardized, symbol = symbol, adjust = adjust, max_retry = max_retry, timeout_sec = timeout_sec)
}
