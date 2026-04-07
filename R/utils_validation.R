normalize_symbol <- function(symbol) {
  x <- toupper(gsub("\\s+", "", symbol))
  x <- gsub("\\.(SH|SZ)$", "", x)
  x
}

validate_symbol <- function(symbol) {
  s <- normalize_symbol(symbol)
  if (!grepl("^[0-9]{6}$", s)) {
    stop("symbol 必须是 6 位数字，例如 600519 或 000300")
  }
  s
}

validate_adjust <- function(adjust) {
  if (!is.numeric(adjust) || length(adjust) != 1 || !adjust %in% c(0, 1, 2)) {
    stop("adjust 必须是 0（不复权）、1（前复权）或 2（后复权）")
  }
  as.integer(adjust)
}

normalize_yyyymmdd <- function(x, arg_name) {
  if (inherits(x, "Date")) {
    return(format(x, "%Y%m%d"))
  }

  if (!is.character(x) || length(x) != 1) {
    stop(arg_name, " 必须是 Date 或 YYYYMMDD / YYYY-MM-DD 字符串")
  }

  x <- trimws(x)
  if (grepl("^[0-9]{8}$", x)) {
    return(x)
  }

  if (grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}$", x)) {
    return(gsub("-", "", x))
  }

  stop(arg_name, " 必须是 Date 或 YYYYMMDD / YYYY-MM-DD 字符串")
}

validate_date_range <- function(start, end) {
  start8 <- normalize_yyyymmdd(start, "start")
  end8 <- normalize_yyyymmdd(end, "end")

  if (start8 > end8) {
    stop("start 不能晚于 end")
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

  stop("无法从 symbol 推断交易所：", symbol)
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
