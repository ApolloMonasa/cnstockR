# cnstockR

A 股/指数日线数据抓取与 parquet 导出工具，支持配置代理和UA头，目前支持以下数据源：
- eastmony（东方财富，全字段支持）
- sina(新浪，部分字段缺失)
- tencent(腾讯，部分字段缺失)
- netease(网易，目前有bug)
## 安装

```r
install.packages("remotes")
remotes::install_github("ApolloMonasa/cnstockR")
#如果希望下载vignettes,请使用以下命令安装
remotes::install_github("ApolloMonasa/cnstockR", build_vignettes = TRUE)
#这样安装后可以查看教学文章
browseVignettes("cnstockR")
```


## 函数

### 1) `cn_get_daily()`
抓取单个代码的日线行情。

```r
library(cnstockR)

df <- cn_get_daily(
  symbol = "600519",
  start = "2024-01-01",
  end = "2024-12-31",
  adjust = 1
)
```

参数说明：
- `adjust`: 复权方式，`0` 不复权，`1` 前复权，`2` 后复权。
- `max_retry`: 失败重试次数（非负数）。
返回列：
- `symbol`, `date`, `open`, `close`, `high`, `low`, `volume`, `amount`, `amplitude`, `pct_chg`, `chg`, `turnover`

注意事项：
- `symbol` 必须是 6 位数字，否则报错。
- `start` 不能晚于 `end`。
- 若接口无数据会报 `empty response for symbol`。

### 2) `cn_get_daily_batch()`
批量抓取多个代码并合并为一个数据框。

```r
library(cnstockR)

df_all <- cn_get_daily_batch(
  symbols = c("600519", "000001", "000300"),
  start = "2024-01-01",
  end = "2024-12-31",
  adjust = 1,
  pause_sec = 0.2,
  continue_on_error = TRUE
)
```

参数说明：
- `symbols`: 非空字符向量。
- `pause_sec`: 每次请求间隔秒数，防止请求过快。
- `continue_on_error`: `TRUE` 跳过失败代码并给 warning；`FALSE` 遇错即停止。
- 其余参数与 `cn_get_daily()` 一致。

注意事项：
- 默认会去重 `symbols`。
- 当 `continue_on_error = TRUE` 且全部代码都失败时，返回空 tibble。
- 大批量请求建议适当增大 `pause_sec` 和 `timeout_sec`。

### 2.1 稳定性与切源

默认情况下，`cn_get_daily()` 和 `cn_get_daily_batch()` 会先尝试东方财富，再自动回退到腾讯、新浪、网易等可用源，尽量减少单一源短时失效导致的抓取失败。

```r
library(cnstockR)

df <- cn_get_daily("600519", source = "auto")

cn_set_source("sina")
df2 <- cn_get_daily("600519")
```

如果你需要进一步降低被识别的概率，可以按需设置动态 UA、Referer、Cookie 和代理池：

```r
cn_set_request_config(
  user_agents = c("ua-1", "ua-2"),
  referer = "https://finance.eastmoney.com/",
  proxy_pool = c("http://127.0.0.1:7890")
)
```

说明：默认情况下，请求层会按数据源自动注入对应 Referer/Origin；
`cn_set_request_config(referer = ...)` 属于高级覆写选项，通常只在你明确需要固定来源头时使用。

注意：`eastmoney`、`tencent`、`sina` 支持前复权/后复权；`netease` 回退主要用于不复权数据。

### 3) `cn_to_parquet()`
将数据写出为 parquet 文件。

```r
library(cnstockR)

df <- cn_get_daily("600519", "2024-01-01", "2024-12-31")
cn_to_parquet(df, "data/600519_daily.parquet")
```

参数说明：
- `x`: data.frame / tibble。
- `file`: 输出 parquet 路径。

注意事项：
- 依赖 `arrow` 包；未安装会报错。
- 返回值是输出路径（invisible）。

### 4) `cn_set_source()` / `cn_get_source()`
设置或查看默认数据源。

```r
library(cnstockR)

cn_set_source("auto")
cn_get_source()
```

### 5) `cn_set_request_config()` / `cn_reset_request_config()`
设置或重置请求配置（动态 UA、Referer、Cookie、代理池）。

```r
library(cnstockR)

cn_set_request_config(
  user_agents = c("ua-1", "ua-2"),
  referer = "https://finance.eastmoney.com/"
)

cn_reset_request_config()
```

### 6) `cn_get_status()` / `cn_ping_sources()`

面向新手的诊断接口：

- `cn_get_status()`：查看当前默认源、回退顺序、请求配置摘要、最近失败源。
- `cn_ping_sources()`：快速探测各源可用性并返回建议配置。

```r
library(cnstockR)

cn_get_status()
ping <- cn_ping_sources("600519")
ping$summary
ping$recommendation
```

## 最简流程

```r
library(cnstockR)

x <- cn_get_daily_batch(
  symbols = c("600519", "000001"),
  start = "2024-01-01",
  end = "2024-12-31",
  continue_on_error = TRUE
)

cn_to_parquet(x, "data/cn_daily.parquet")
```

## 开发者检查

本地可运行与 CI 近似的检查流程：

```r
source("scripts/ci-check.R")
```

GitHub Actions 会自动在 Linux、Windows、macOS 上执行 `R CMD check`。

## 常见错误与排查

1. `empty response for symbol`
- 常见原因：日期区间过大、临时网络波动、单源短时不可用。
- 建议：先缩小日期区间，再用 `cn_ping_sources()` 查看可用源。

2. 请求报错或疑似 IP 封禁
- 常见原因：高频请求触发风控。
- 建议：增大 `pause_sec`、设置代理池和动态 UA，必要时切换默认源。

3. 编码或解析异常
- 常见原因：不同源返回编码差异（尤其 CSV/JSONP）。
- 建议：优先用 `source = "auto"`，若仍失败可先单独测试 `source = "sina"` 或 `source = "eastmoney"`。

## 数据一致性说明

1. 字段一致性
- 包会尽量统一输出字段：`symbol`, `date`, `open`, `close`, `high`, `low`, `volume`, `amount`, `amplitude`, `pct_chg`, `chg`, `turnover`。

2. 复权一致性
- `eastmoney`、`tencent` 与 `sina` 支持前复权/后复权。
- `netease` 回退主要用于不复权数据（`adjust = 0`）。

3. 跨源差异
- 同一天数据在不同源可能存在细微差异（复权因子口径、更新时间、成交额单位等），严谨回测建议固定单一源。

## For Devs

本节面向参与维护与扩展的开发者，介绍目录结构、抓取链路和关键实现策略。

### 1) 项目结构

- `R/cnstockR.R`：用户主入口（单标的、批量、parquet 导出）。
- `R/sources.R`：统一源分发层，按 source 路由到具体抓取实现。
- `R/sources_eastmoney.R`、`R/sources_tencent.R`、`R/sources_sina.R`、`R/sources_netease.R`：各源抓取与源内解析。
- `R/http.R`：统一请求执行层（重试、超时、头信息、代理）。
- `R/parsers.R`：通用解析辅助（CSV/K 线等）。
- `R/config.R`：请求配置与默认源配置。
- `R/status.R`：运行时状态与探测工具（`cn_get_status()` / `cn_ping_sources()`）。
- `tests/testthat/`：分源测试、回退测试、配置测试、状态测试。
- `man/`：由 roxygen2 生成的帮助文档。

### 2) 抓取链路

1. 用户调用 `cn_get_daily()` 或 `cn_get_daily_batch()`。
2. 参数先在校验层规范化（代码、日期、复权方式）。
3. 若 `source = "auto"`，按 fallback 顺序依次尝试。
4. 每个源通过 `get_daily_by_source()` 分发到对应抓取器。
5. 源实现返回统一字段，最终上层按统一 tibble 输出。

### 3) 反爬与稳定性策略

- 按源定制请求头：请求层会按目标域名自动注入对应 Referer/Origin，避免跨站头信息导致风控。
- 多端点回退：新浪实现采用多端点轮询（jsonp/json_v2/openapi），降低单端点失效概率。
- 参数分档回退：腾讯实现会按安全 datalen 分档请求，规避大参数导致的 `param error`。
- 失败隔离：单源失败不会污染其他源，`auto` 模式会继续尝试后续候选源。

### 4) 字段与语义约定

- 统一输出字段：`symbol`, `date`, `open`, `close`, `high`, `low`, `volume`, `amount`, `amplitude`, `pct_chg`, `chg`, `turnover`。
- `date` 为 `Date` 类型，`symbol` 为 6 位代码字符串。
- 非所有上游都提供完整字段，缺失字段使用 `NA` 补齐。

### 5) 开发与检查建议

- 快速检查：`source("scripts/ci-check.R")`
- 运行测试：`devtools::test()`
- 仅跑单文件测试：`devtools::test(filter = "tencent-source")`
- 更新文档：`devtools::document()`
- 本地联调：`devtools::load_all(reset = TRUE)` 后运行 `cn_ping_sources()` 验证各源可用性。

### 5.1) 注释与报错规范

- 导出函数使用 roxygen 中文文档（参数、返回值、示例完整）。
- 内部注释只解释复杂逻辑，不写“显而易见”的逐行注释。
- 错误信息优先中文、语义明确，并尽量包含关键上下文（如 symbol/source）。
- 新增逻辑时优先补充对应 `testthat` 用例，避免回归。

### 6) 扩展新数据源的推荐步骤

1. 新建 `R/sources_xxx.R`，实现 `get_daily_xxx()` 并输出标准字段。
2. 在 `R/sources.R` 的分发函数中注册该源。
3. 更新 `R/config.R` 的 source 枚举与默认 fallback。
4. 增加 `tests/testthat/test-xxx-source.R`，覆盖成功、空结果、结构漂移等场景。
5. 更新 roxygen 注释并重新生成帮助文档。
