symbol_to_tencent_symbol_candidates <- function(symbol) {
  s <- validate_symbol(symbol)

  if (grepl("^(6|9)", s)) {
    return(paste0("sh", s))
  }

  if (grepl("^(0|2|3)", s)) {
    return(c(paste0("sh", s), paste0("sz", s)))
  }

  stop("cannot infer market for symbol: ", symbol)
}

parse_tencent_rows <- function(rows, symbol, dr) {
  if (is.null(rows) || length(rows) == 0) {
    return(tibble::tibble())
  }

  rows_df <- NULL
  if (is.data.frame(rows)) {
    rows_df <- rows
  } else if (is.matrix(rows)) {
    rows_df <- as.data.frame(rows, stringsAsFactors = FALSE)
  } else {
    row_list <- Filter(function(one) {
      is.atomic(one) && length(one) >= 6 && grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}$", as.character(one[[1]]))
    }, rows)

    if (length(row_list) > 0) {
      row_list <- lapply(row_list, function(one) as.character(one)[seq_len(6)])
      rows_df <- tryCatch(
        as.data.frame(do.call(rbind, row_list), stringsAsFactors = FALSE),
        error = function(e) NULL
      )
    }
  }

  if (is.null(rows_df) || ncol(rows_df) < 6) {
    return(tibble::tibble())
  }

  out <- tibble::tibble(
    symbol = normalize_symbol(symbol),
    date = as.Date(rows_df[[1]]),
    open = as_num(rows_df[[2]]),
    close = as_num(rows_df[[3]]),
    high = as_num(rows_df[[4]]),
    low = as_num(rows_df[[5]]),
    volume = as_num(rows_df[[6]]),
    amount = NA_real_,
    amplitude = NA_real_,
    pct_chg = NA_real_,
    chg = NA_real_,
    turnover = NA_real_
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

get_daily_tencent <- function(symbol, dr, adjust, max_retry, timeout_sec) {
  candidates <- symbol_to_tencent_symbol_candidates(symbol)
  datalen_candidates <- c(1000L, 800L, 500L, 300L, 200L)

  for (tencent_symbol in candidates) {
    pick_rows <- function(payload, key, day_key) {
      if (!is.null(payload$data[[key]]) && !is.null(payload$data[[key]][[day_key]])) {
        return(payload$data[[key]][[day_key]])
      }

      find_day_rows <- function(x, target, depth = 0L) {
        if (is.null(x) || depth > 4L) {
          return(NULL)
        }

        if (is.list(x) && !is.null(x[[target]])) {
          return(x[[target]])
        }

        if (!is.list(x) || length(x) == 0) {
          return(NULL)
        }

        for (i in seq_along(x)) {
          hit <- find_day_rows(x[[i]], target = target, depth = depth + 1L)
          if (!is.null(hit)) {
            return(hit)
          }
        }

        NULL
      }

      find_day_rows(payload$data, target = day_key)
    }

    if (identical(adjust, 0L)) {
      url <- "https://web.ifzq.gtimg.cn/appstock/app/kline/kline"
      for (datalen in datalen_candidates) {
        query <- list(param = sprintf("%s,day,,,%s", tencent_symbol, datalen))
        json <- request_json(url, query, max_retry = max_retry, timeout_sec = timeout_sec)
        rows <- pick_rows(json, key = tencent_symbol, day_key = "day")
        out <- parse_tencent_rows(rows, symbol = symbol, dr = dr)
        if (nrow(out) > 0) {
          return(out)
        }
      }
      next
    }

    fq_mode <- if (identical(adjust, 1L)) "qfq" else "hfq"
    url <- "https://web.ifzq.gtimg.cn/appstock/app/fqkline/get"
    for (datalen in datalen_candidates) {
      query <- list(param = sprintf("%s,day,,,%s,%s", tencent_symbol, datalen, fq_mode))
      json <- request_json(url, query, max_retry = max_retry, timeout_sec = timeout_sec)
      rows <- pick_rows(json, key = tencent_symbol, day_key = paste0(fq_mode, "day"))
      if (is.null(rows)) {
        rows <- pick_rows(json, key = tencent_symbol, day_key = "day")
      }
      out <- parse_tencent_rows(rows, symbol = symbol, dr = dr)
      if (nrow(out) > 0) {
        return(out)
      }
    }
  }

  tibble::tibble()
}