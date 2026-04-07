build_request <- function(url, timeout_sec = 20) {
  config <- cn_get_request_config()
  req <- httr2::request(url) |>
    httr2::req_timeout(timeout_sec)

  headers <- config$headers
  if (!is.null(config$referer)) {
    headers$Referer <- config$referer
  }
  if (!is.null(config$cookie)) {
    headers$Cookie <- config$cookie
  }

  user_agent <- pick_one(config$user_agents)
  if (!is.null(user_agent)) {
    req <- httr2::req_user_agent(req, user_agent)
  }

  if (length(headers) > 0) {
    req <- do.call(httr2::req_headers, c(list(req), headers))
  }

  proxy_url <- pick_one(config$proxy_pool)
  if (!is.null(proxy_url)) {
    req <- tryCatch(
      do.call(httr2::req_proxy, c(list(req), list(url = proxy_url))),
      error = function(e) req
    )
  }

  req
}

request_text <- function(url, query = list(), max_retry = 2, timeout_sec = 20) {
  last_err <- NULL

  if (!is.numeric(max_retry) || length(max_retry) != 1 || max_retry < 0) {
    stop("max_retry must be a non-negative number")
  }
  if (!is.numeric(timeout_sec) || length(timeout_sec) != 1 || timeout_sec <= 0) {
    stop("timeout_sec must be a positive number")
  }

  for (i in seq_len(max_retry + 1)) {
    req <- build_request(url, timeout_sec = timeout_sec)
    if (length(query) > 0) {
      req <- do.call(httr2::req_url_query, c(list(req), query))
    }

    resp <- tryCatch(httr2::req_perform(req), error = function(e) e)

    if (!inherits(resp, "error")) {
      return(httr2::resp_body_string(resp))
    }

    last_err <- resp
    Sys.sleep(0.5 * i)
  }

  stop("request failed: ", conditionMessage(last_err))
}

request_json <- function(url, query, max_retry = 2, timeout_sec = 20) {
  jsonlite::fromJSON(request_text(url, query = query, max_retry = max_retry, timeout_sec = timeout_sec))
}
