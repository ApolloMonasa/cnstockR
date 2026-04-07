cn_request_config_defaults <- function() {
  list(
    user_agents = c(
      "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36",
      "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15",
      "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36"
    ),
    referer = "https://finance.eastmoney.com/",
    cookie = NULL,
    proxy_pool = NULL,
    headers = list()
  )
}

cn_source_defaults <- function() {
  list(default_source = "auto", fallback_sources = c("eastmoney", "sina", "netease"))
}

#' Get request behavior for upstream calls
#'
#' @return A list with request config fields: user_agents, referer, cookie,
#'   proxy_pool, and headers.
#' @export
cn_get_request_config <- function() {
  config <- getOption("cnstockR.request_config")
  if (is.null(config)) {
    config <- cn_request_config_defaults()
  }
  config
}

#' Update request configuration
#'
#' @param user_agents Optional character vector of User-Agent candidates.
#' @param referer Optional single string Referer header.
#' @param cookie Optional single string Cookie header.
#' @param proxy_pool Optional character vector of proxy URLs.
#' @param headers Optional named list of extra headers.
#' @param reset Logical flag. If TRUE, reset to defaults.
#' @return Invisible request config list.
#' @export
cn_set_request_config <- function(user_agents = NULL,
                                  referer = NULL,
                                  cookie = NULL,
                                  proxy_pool = NULL,
                                  headers = list(),
                                  reset = FALSE) {
  if (reset) {
    options(cnstockR.request_config = cn_request_config_defaults())
    return(invisible(cn_get_request_config()))
  }

  config <- cn_get_request_config()
  if (!is.null(user_agents)) {
    if (!is.character(user_agents) || length(user_agents) == 0) {
      stop("user_agents must be a non-empty character vector")
    }
    config$user_agents <- user_agents
  }
  if (!is.null(referer)) {
    if (!is.character(referer) || length(referer) != 1) {
      stop("referer must be a single character string")
    }
    config$referer <- referer
  }
  if (!is.null(cookie)) {
    if (!is.character(cookie) || length(cookie) != 1) {
      stop("cookie must be a single character string")
    }
    config$cookie <- cookie
  }
  if (!is.null(proxy_pool)) {
    if (!is.character(proxy_pool) || length(proxy_pool) == 0) {
      stop("proxy_pool must be a non-empty character vector")
    }
    config$proxy_pool <- proxy_pool
  }
  if (length(headers) > 0 && !is.list(headers)) {
    stop("headers must be a named list")
  }
  if (length(headers) > 0) {
    config$headers <- headers
  }

  options(cnstockR.request_config = config)
  invisible(config)
}

#' Reset request configuration
#'
#' @return Invisible request config list.
#' @export
cn_reset_request_config <- function() {
  options(cnstockR.request_config = cn_request_config_defaults())
  invisible(cn_get_request_config())
}

cn_get_source_config <- function() {
  config <- getOption("cnstockR.source_config")
  if (is.null(config)) {
    config <- cn_source_defaults()
  }
  config
}

#' Set default data source
#'
#' @param source One of auto, eastmoney, sina, netease.
#' @param fallback_sources Optional source vector used when source is auto.
#' @return Invisible source config list.
#' @export
cn_set_source <- function(source = c("auto", "eastmoney", "sina", "netease"), fallback_sources = NULL) {
  source <- match.arg(source)
  config <- cn_get_source_config()
  config$default_source <- source
  if (!is.null(fallback_sources)) {
    if (!is.character(fallback_sources) || length(fallback_sources) == 0) {
      stop("fallback_sources must be a non-empty character vector")
    }
    config$fallback_sources <- fallback_sources
  } else if (source == "auto") {
    config$fallback_sources <- c("eastmoney", "sina", "netease")
  } else {
    config$fallback_sources <- character(0)
  }
  options(cnstockR.source_config = config)
  invisible(config)
}

#' Get current default data source
#'
#' @return Character scalar source name.
#' @export
cn_get_source <- function() {
  cn_get_source_config()$default_source
}

pick_one <- function(x) {
  if (is.null(x) || length(x) == 0) {
    return(NULL)
  }
  x[[sample.int(length(x), 1)]]
}
