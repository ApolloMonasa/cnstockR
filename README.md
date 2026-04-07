# cnstockR

A 股/指数日线数据抓取与 parquet 导出工具。

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

默认情况下，`cn_get_daily()` 和 `cn_get_daily_batch()` 会先尝试东方财经，再自动降级到新浪和其他可用源，尽量减少单一源被封后的失败概率。

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

注意：`sina` 已支持前复权/后复权；`netease` 回退主要用于不复权数据。

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
- `eastmoney` 与 `sina` 支持前复权/后复权。
- `netease` 回退主要用于不复权数据（`adjust = 0`）。

3. 跨源差异
- 同一天数据在不同源可能存在细微差异（复权因子口径、更新时间、成交额单位等），严谨回测建议固定单一源。
