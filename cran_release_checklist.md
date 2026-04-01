# CRAN 发布清单（cnstockR）

## 1. 发布前必须修改

- 把 DESCRIPTION 中作者信息改成你的真实姓名和可用邮箱。
- 确保包名、Title、Description 不包含夸大或营销表述。
- 检查 LICENSE 与版权归属。

## 2. 代码质量与兼容性

- 所有导出函数都要有 roxygen 注释。
- 避免使用三冒号访问外部包非导出函数。
- 避免在示例中发起大量网络请求。
- 网络请求建议可选跳过（如 `if (interactive())` 或条件检查）。

## 3. 本地检查命令

在 `cnstockR` 目录执行：

```r
install.packages(c("devtools", "roxygen2", "rcmdcheck", "testthat"))

roxygen2::roxygenise()
devtools::document()
devtools::test()
devtools::check(manual = TRUE)
rcmdcheck::rcmdcheck(args = c("--as-cran"), error_on = "warning")
```

目标：`R CMD check --as-cran` 无 ERROR / WARNING / NOTE（至少无关键 NOTE）。

## 4. 常见 CRAN 拒稿点

- NOTE/WARNING 未处理（尤其是未声明全局变量、未使用导入、URL 失效）。
- 例子执行太慢或依赖外网且不稳定。
- 文档与函数签名不一致。
- 作者邮箱不可用。

## 5. 提交流程

1. 在 CRAN 账号页面准备 maintainer 邮箱。
2. 生成源码包：

```r
devtools::build()
```

3. 打开 CRAN 提交页并上传 `.tar.gz`。
4. 填写变更说明（尤其是首次提交的包目的与数据来源）。
5. 收到 CRAN 邮件后按要求修复并重新提交。

## 6. 针对本包的建议

- 你当前依赖外部行情接口，建议加一个 `quiet` 与 `verbose` 控制，并在示例中使用较短日期区间。
- 后续可补充单元测试：
  - 代码格式校验
  - 日期格式校验
  - 失败重试逻辑
  - 批量抓取在 `continue_on_error = TRUE` 时不崩溃
