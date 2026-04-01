# cnstockR

A 股/指数日线数据抓取与 parquet 导出工具。

## 安装

```r
install.packages("remotes")
remotes::install_github("ApolloMonasa/cnstockR")
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
- `symbol`: 6 位代码（如 `600519`、`000300`）。
- `start` / `end`: 支持 `Date`、`YYYYMMDD`、`YYYY-MM-DD`。
- `adjust`: 复权方式，`0` 不复权，`1` 前复权，`2` 后复权。
- `max_retry`: 失败重试次数（非负数）。
- `timeout_sec`: 请求超时秒数（正数）。

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
