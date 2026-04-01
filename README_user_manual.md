# cnstockR User Manual

## 1. 目的

`cnstockR` 是一个轻量级 R 库，用于从国内公开行情接口抓取 A 股日线数据，并整理为可直接建模的数据框（tibble）。

## 2. 功能

- `cn_get_daily()`：抓取单个股票/指数的日线 OHLCV 数据
- `cn_get_daily_batch()`：批量抓取并合并多标的数据
- `cn_to_parquet()`：将结果保存为 parquet

返回字段：

- `symbol`：代码（6位）
- `date`：日期（Date）
- `open` `close` `high` `low`
- `volume` `amount`
- `amplitude` `pct_chg` `chg` `turnover`

## 3. 依赖安装

```r
install.packages(c("httr2", "jsonlite", "dplyr", "tibble", "stringr", "arrow", "devtools"))
```

## 4. 加载方式

推荐（有 `devtools` 时）：

```r
devtools::load_all("cnstockR")
```

免安装 `devtools` 的方式：

```r
source("cnstockR/R/cnstockR.R")
```

## 5. 参数说明

### `cn_get_daily(symbol, start, end, adjust)`

- `symbol`：6位代码，如 `"600519"`、`"000300"`
- `start`：开始日期，格式 `YYYYMMDD`
- `end`：结束日期，格式 `YYYYMMDD`
- `adjust`：复权方式
  - `0` 不复权
  - `1` 前复权
  - `2` 后复权

### `cn_get_daily_batch(symbols, start, end, adjust, pause_sec)`

- `symbols`：代码向量
- `pause_sec`：请求间隔秒数，默认 `0.15`

## 6. 示例

### 6.1 抓取单个标的

```r
library(dplyr)
devtools::load_all("cnstockR")

mz <- cn_get_daily("600519", start = "20221201", end = "20251201", adjust = 1)
head(mz)
```

### 6.2 批量抓取

```r
x <- cn_get_daily_batch(c("600519", "000300"), start = "20221201", end = "20251201")
count(x, symbol)
```

### 6.3 保存 parquet

```r
cn_to_parquet(x, "data/local_market_data.parquet")
```

## 7. 常见问题

- 报错 `empty response`：
  - 检查代码是否为 6 位数字
  - 检查网络是否可访问行情接口
  - 尝试减小时间范围后重试

- 报错 `cannot infer exchange`：
  - 目前仅支持 A 股常见代码前缀：`6/9`（上证）和 `0/2/3`（深证）

## 8. 合规与使用提醒

- 本库用于教学与研究，不构成任何投资建议。
- 数据接口来自公开网络源，接口字段和可用性可能随时间变化。
