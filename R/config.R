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
  list(default_source = "auto", fallback_sources = c("eastmoney", "tencent", "sina", "netease"))
}

#' 获取当前请求配置
#'
#' 返回用于上游请求的运行时配置，包括 User-Agent 池、Referer、Cookie、代理池和
#' 额外请求头。若用户未设置，则返回包内默认配置。
#'
#' @return 一个列表，包含以下字段：
#'   `user_agents`, `referer`, `cookie`, `proxy_pool`, `headers`。
#'
#' @examples
#' cfg <- cn_get_request_config()
#' names(cfg)
#' @export
cn_get_request_config <- function() {
  config <- getOption("cnstockR.request_config")
  if (is.null(config)) {
    config <- cn_request_config_defaults()
  }
  config
}

#' 更新请求配置
#'
#' 按需更新请求行为配置。仅会覆盖传入的参数，其余字段保持当前值不变。
#' 可用于降低频繁请求被风控的概率，例如轮换 UA、设置 Referer/Cookie 或代理池。
#'
#' @param user_agents 可选字符向量。候选 User-Agent 列表。
#' @param referer 可选长度为 1 的字符串。Referer 请求头。
#' @param cookie 可选长度为 1 的字符串。Cookie 请求头。
#' @param proxy_pool 可选字符向量。代理地址列表（例如 `"http://127.0.0.1:7890"`）。
#' @param headers 可选命名列表。附加请求头。
#' @param reset 逻辑值。`TRUE` 时忽略其他参数并直接重置到默认配置。
#'
#' @return 不可见地返回更新后的配置列表。
#'
#' @examples
#' # 设置自定义请求头
#' cn_set_request_config(
#'   user_agents = c("ua-1", "ua-2"),
#'   referer = "https://finance.eastmoney.com/"
#' )
#'
#' # 仅重置配置
#' cn_set_request_config(reset = TRUE)
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

#' 重置请求配置
#'
#' 将请求配置恢复为包内默认值。
#'
#' @return 不可见地返回重置后的配置列表。
#'
#' @examples
#' cn_reset_request_config()
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

#' 设置默认数据源
#'
#' 配置全局默认数据源。若设为 `"auto"`，将按 `fallback_sources` 顺序自动回退。
#'
#' @param source 默认源，可选 `"auto"`、`"eastmoney"`、`"tencent"`、`"sina"`、`"netease"`。
#' @param fallback_sources 可选字符向量。仅在 `source = "auto"` 时生效，
#'   表示自动模式下的候选源顺序。
#'
#' @return 不可见地返回更新后的源配置列表。
#'
#' @examples
#' # 自动模式并指定回退顺序
#' cn_set_source("auto", fallback_sources = c("eastmoney", "tencent", "sina", "netease"))
#'
#' # 固定单一源
#' cn_set_source("sina")
#' @export
cn_set_source <- function(source = c("auto", "eastmoney", "tencent", "sina", "netease"), fallback_sources = NULL) {
  source <- match.arg(source)
  config <- cn_get_source_config()
  config$default_source <- source
  if (!is.null(fallback_sources)) {
    if (!is.character(fallback_sources) || length(fallback_sources) == 0) {
      stop("fallback_sources must be a non-empty character vector")
    }
    config$fallback_sources <- fallback_sources
  } else if (source == "auto") {
    config$fallback_sources <- c("eastmoney", "tencent", "sina", "netease")
  } else {
    config$fallback_sources <- character(0)
  }
  options(cnstockR.source_config = config)
  invisible(config)
}

#' 获取当前默认数据源
#'
#' 读取当前会话中的默认数据源设置。
#'
#' @return 长度为 1 的字符向量，取值为 `"auto"`、`"eastmoney"`、`"tencent"`、`"sina"` 或 `"netease"`。
#'
#' @examples
#' cn_get_source()
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
