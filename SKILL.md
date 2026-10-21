---
name: litellm-operation-dashboard
description: "Maintain the LiteLLM SpendLogs Grafana dashboard pack."
version: 1.3.0
author: Hermes Agent
license: MIT
platforms: [linux, macos]
metadata:
  hermes:
    editorial_name: LiteLLM Operation Dashboard
    editorial_description: >-
      Migratable six-dashboard Grafana pack + schema & metric reference for
      LiteLLM proxy spend logs - TTFT, E2E, TPOT, model groups, error tables,
      one-command import, bilingual (EN/CN).
    tags: [litellm, grafana, postgres, observability, llm-analytics]
    related_skills: [grafana-dashboards]
---

# LiteLLM Operation Dashboard / LiteLLM 运维看板

Deploys, maintains, and migrates a six-dashboard Grafana analytics pack over the LiteLLM proxy's PostgreSQL table `"LiteLLM_SpendLogs"`. 部署、维护并在不同 Grafana 实例间迁移基于 LiteLLM 代理 PostgreSQL 表 `"LiteLLM_SpendLogs"` 的六看板 Grafana 分析包。

Consolidated from the former `litellm-spendlogs-dashboards-en` / `-cn` pair into one bilingual skill: shared assets/scripts/schema stay identical, only the documentation is unified and bilingual. 本技能由原 `litellm-spendlogs-dashboards-en` / `-cn` 两个 skill 整合而来：assets、scripts、表结构参考完全一致，仅文档统一为中英双语。

## Required Output-Locale Parameter / 必需的 output_locale 参数

This skill produces analysis output for a human audience. Verbal conclusions adapt to the caller's language; metrics and SQL stay language-independent. 本技能面向人类产出分析结论。文字结论适配调用者语言；指标与 SQL 保持语言无关。

```json
"output_locale": {
  "type": "string",
  "enum": ["auto", "en", "zh-CN"],
  "default": "auto",
  "description": "### English\nOutput language for the verbal analysis. auto = follow the input query language; en / zh-CN force that language. Fallback to English if detection fails.\n### 中文\n输出语言控制。auto 跟随输入查询语言；en / zh-CN 强制该语言；检测失败回退英文。"
}
```

## When to Use / 何时使用

- Import/rebuild this dashboard set on another Grafana instance (migration). 在其他 Grafana 实例上导入/复现本看板套件（迁移）。
- Add or modify panels over `"LiteLLM_SpendLogs"` — schema, quoting rules, metric guards. 新增或修改基于 `"LiteLLM_SpendLogs"` 的面板——表结构、引号规则、指标守卫。
- Investigate streaming latency (TTFT / E2E / TPOT) or non-stream prompt-processing throughput. 排查流式延迟（TTFT/E2E/TPOT）或非流式提示词处理吞吐。
- Analyze usage, token distribution, model-group merge, concurrency, or failure patterns. 分析用量、token 分布、模型组合并、并发或失败模式。
- Answer with a bilingual (EN/CN) written summary while keeping metrics in the original form. 用中英双语回答文字结论，同时保持指标原文。

**Don't use for:** general Grafana setup, auth resets, or API mechanics — that is `grafana-dashboards`. 不适用于：Grafana 通用安装、密码重置、API 机制（那是 `grafana-dashboards` 的事）。

## Prerequisites / 前置条件

- Grafana 11.x reachable over HTTP; admin credentials (basic auth). Grafana 11.x 可经 HTTP 访问；管理员凭据（basic auth）。
- A PostgreSQL datasource pointing at the LiteLLM database (`litellm_db`, user with SELECT). Record its **uid**. 指向 LiteLLM 数据库（`litellm_db`，SELECT 权限用户）的 PostgreSQL 数据源，记下其 **uid**。
- `pg8000` for direct DB verification: `pip install pg8000` (no psql client needed). 直连验证用 `pg8000`：`pip install pg8000`（无需 psql 客户端）。
- Credentials come from a mode-600 env file, never from literals. 凭据来自权限 600 的环境变量文件，绝不写死。
- Pack contents: dashboards in `assets/dashboards/`, importer `scripts/import-dashboards.sh`. 包内容：看板在 `assets/dashboards/`，导入脚本 `scripts/import-dashboards.sh`。

## The Dashboard Pack / 看板清单 (assets/dashboards/)

| File / 文件 | uid | What it shows / 内容 |
|---|---|---|
| litellm-dashboard.json | litellm-spendlogs | Per-model overview, request-tag matrix. 按模型的总览与请求标签矩阵。 |
| litellm-dashboard-grouped.json | litellm-spendlogs-grouped | `key_group` scope, merged model groups, streaming metrics (TTFT/E2E/TPOT). `key_group` 过滤 + 模型组合并 + 流式指标。 |
| litellm-dashboard-tokens.json | litellm-token-analysis | Token distributions, percentiles, output/input ratio. token 分布、分位数、输出/输入比。 |
| litellm-dashboard-grouped-bars.json | litellm-spendlogs-grouped-bars | `$bucket` charts (5m-7d), volumes as bars, latency as smooth lines. 可调时间桶图表，数量柱状/延迟折线。 |
| litellm-dashboard-bars-search-agent.json | litellm-spendlogs-bars-search-agent | Same + api_key relabeled as **Search Agent**, failed-requests table. 在上一块基础上将 api_key 重命名为 **Search Agent** 组并附失败请求明细表。 |
| maas-operation-dashboard-customer.json | efyuf9l9lvzswc | Customer-facing "MaaS Operation Dashboard" (N1–N20), same `key_group` scope. 客户侧 MaaS 运维看板（N1–N20 布局），同一 `key_group` 变量。 |

Unified series palette on all group charts: glm-text=green, deepseek-v4-flash=blue, glm53-flash=orange, Search Agent=purple, `<none>`=gray. 所有分组图统一配色：glm-text=绿、deepseek-v4-flash=蓝、glm53-flash=橙、Search Agent=紫、`<none>`=灰。

## Scheduling / 调度 (Hermes cron, not crontab)

The nightly/weekly PNG renders and the nightly error analysis run as Hermes cron jobs with `--no-agent --script <name>`: 夜间/每周 PNG 渲染与夜间错误分析以 Hermes cron 任务运行（`--no-agent --script <name>`，零 token、留持久记录）。

```bash
hermes cron create "30 1 * * *"    --name render-maas-daily   --script render-maas-daily.sh   --no-agent --deliver local
hermes cron create "0 1 * * 0"     --name render-maas-weekly  --script render-maas-weekly.sh  --no-agent --deliver local
hermes cron create "0 23 * * *"    --name error-analysis      --script error-analysis.py      --no-agent --deliver local
```

Scripts must be **copies** under `~/.hermes/scripts/` (symlinks are rejected). Verify each with `hermes cron run <id>` then `hermes cron runs <id>`. Never add new `crontab` lines. 脚本须为 `~/.hermes/scripts/` 下的**副本**（拒绝符号链接）；用 `hermes cron run` 验证。

## Rendering / 渲染 PNG

`scripts/render-dashboard.sh` screenshots any dashboard in the pack to a PNG via headless Chrome (anonymous Viewer auth). It is env-driven and reusable on any host — no secrets, no hard-coded paths. `渲染:` `scripts/render-dashboard.sh` 用无头 Chrome（匿名 Viewer 认证）把任意看板截图为 PNG；纯环境变量驱动、可迁移，无密钥、无写死路径。

```bash
CHROME_BIN=google-chrome OUT_DIR=... \
  scripts/render-dashboard.sh efyuf9l9lvzswc "$OUT_DIR/customer_$(date +%F).png" yesterday 10m
# window: yesterday | week | '<from_ms>-<to_ms>'; bucket optional (10m/30m/1d)
```

Key parameters / 关键参数:
- `?kiosk` removes the nav/breadcrumb chrome; `tz=Asia%2FRiyadh` forces the dashboard clock to Riyadh (UTC+3, no DST → epoch window math is exact) regardless of host TZ. `kiosk` 去导航，`tz=Asia/Riyadh` 强制利雅得时区（无 DST，时间窗可用毫秒戳精算）。
- `--virtual-time-budget=90000` lets async panel queries settle before the screenshot; too low → blank/partial panels. 给异步查询 90s 虚拟时间预算，太低会截出空面板。
- Sanity gate: output must be `PNG image data` AND > `MIN_SIZE` (default 100 KB). Login/blank pages are small — a tiny file means auth/failed render. 校验输出是真 PNG 且 >100KB，登录页/空白页通常很小。
- `from=now-1d%2Fd&to=now-1d%2Fd` = strict previous full day; `week` = last Sunday 00:00 → this Sunday 00:00. 昨天整天 / 上周日起止整 7 天。
- Logs: write to LOCAL disk, not an RDP-mapped drive (transient I/O errors on repeated appends). 日志写本地盘，勿写 RDP 映射盘（重复 append 会瞬时报错）。

> **Alternative — Grafana renderer plugin** `图形渲染插件`: if the target has the `grafana-image-renderer` plugin, use `GET /render/d/<uid>/<slug>?...&width=1600&height=1900&timeout=90&kiosk`. Pin the plugin to **v3.12.9** for Grafana 11.2.x — 4.x needs Grafana ≥ 11.3.8. `&kiosk` strips nav/breadcrumb; full-page render uses `/render/d/<uid>/<slug>` (the plain `/render` path truncates). 若目标已装 image-renderer 插件用其渲染；11.2.x 必须用 **v3.12.9**（4.x 需 ≥11.3.8）；`&kiosk` 去导航；整页用 `/render/d/<uid>/<slug>`。

## How to Run (migration) / 迁移步骤

1. Provision the PostgreSQL datasource in the target Grafana; note its uid. 在目标 Grafana 中配置 PostgreSQL 数据源，记下 uid。
2. Import all six dashboards / 执行导入:
   ```bash
   GRAFANA_URL=http://<host>:3000 GRAFANA_USER=admin GRAFANA_PASS=<pw> \
   DATASOURCE_UID=<uid> scripts/import-dashboards.sh
   ```
   `DATASOURCE_UID` rewrites the baked-in uid (`P98809E0A67B9D897`) before POSTing. Completion criterion: all six print HTTP 200. `DATASOURCE_UID` 会在导入前替换内置数据源 uid（`P98809E0A67B9D897`）；全部 HTTP 200 即成功。
3. Deployment-specific key edits happen ONLY in the `key_group` dashboard variable (hidden custom variable); every panel SQL references `api_key IN (${key_group:sqlstring})`. Change members via `scripts/update-key-group.sh <hash,...>` (updates ALL SIX at once) or Dashboard → Variables → key_group. Never edit the SQL literals. 部署相关密钥只写在 `key_group` 看板变量（隐藏自定义变量）；所有面板 SQL 引用 `api_key IN (${key_group:sqlstring})`。用 `scripts/update-key-group.sh <hash,...>` 一条命令更新全部六个看板，或在 Variables → key_group 手改；不要改 SQL。
4. Verify: `/api/health`, datasource health, one `/api/ds/query` spot-check, then each `/d/<uid>/...` URL. 验证：/api/health、数据源健康、任一 /api/ds/query 抽查，再逐个打开 /d/<uid>/... 页面。

## Metric Definitions / 指标定义

Full formulas, guards, and expected value ranges: `references/schema-and-metrics.md` (language-independent SQL reference). 完整公式、守卫与实测值范围见 `references/schema-and-metrics.md`（语言无关的 SQL 参考）。

- **TTFT** (streaming) = `completionStartTime - startTime`. TTFT（流式）= completionStartTime − startTime，首 token 延迟。
- **E2E** = `endTime - startTime`; equals `request_duration_ms` within 1ms — never show both. 平均延迟 = E2E；与 `request_duration_ms` 在 1ms 内相等，二者是同一指标，不要重复展示。
- **Stream vs non-stream**: use body field `proxy_server_request->>'stream'` ('true' = streamed), NOT a generation-window heuristic. 流式识别：用请求体 `proxy_server_request->>'stream'`，不要用生成窗口长短来猜。
- **TPOT** (ms/out token) = `(endTime - completionStartTime)*1000/completion_tokens`; guards: `status='success'` AND stream='true' AND `completionStartTime > startTime` AND window >= 1s AND `completion_tokens > 0`. TPOT（毫秒/输出 token）：`(endTime − completionStartTime) × 1000 / completion_tokens`，守卫见原文。
- **Non-stream TTFT** (ms/input token) = `(completionStartTime - startTime)*1000/prompt_tokens` on non-stream rows. 非流式 TTFT（毫秒/输入 token）衡量提示词处理吞吐。
- **Concurrency** (peak in-flight per group per `$bucket`): sweep-line over `[startTime, endTime)`. 并发（每组每 `$bucket` 峰值）：对 `[startTime, endTime)` 扫描线。
- **Token display = RAW values + Grafana `short` unit** (auto K/M/B) — SQL returns UNDIVIDED aggregates, do NOT append `(K)`/`(M)` to titles. token 显示 = 原始值 + Grafana `short` 单位（自动 K/M/B），SQL 返回不除的聚合值，勿在标题加 (K)/(M)。
- **Average-token metrics exclude tiny requests** (`prompt_tokens + completion_tokens >= 150`); in mixed-purpose tables use per-column `FILTER`, never WHERE. 平均类 token 指标排除极小请求（in+out >= 150）；多用途表格用逐列 FILTER，绝不放进 WHERE。
- **Image requests** (glm53-flash panel): identifiable only by parsing `proxy_server_request->'messages'` parts for `type='image_url'`. 图像请求只能解析 messages 内容分片识别；上游不报图像 token。
- **Error-type classification**: failure metrics EXCLUDE client parameter errors; failed lists add `error_type` CASE column. 失败指标排除客户端参数错误；失败清单加 error_type CASE 列。
- **Success rate caliber** = `success / (total − param errors)`. 成功率口径 = success / (total − 参数错误数)。
- **Hour-of-day timezone**: `"startTime"` is NAIVE UTC wall-clock; Riyadh hour = double `AT TIME ZONE` conversion; build on a `generate_series(0,23)` grid. 小时分布时区：startTime 为无时区 UTC 墙上时间；利雅得小时需双重 AT TIME ZONE 转换；建在 generate_series(0,23) 网格上。
- **Line-chart rendering**: `lineInterpolation: "smooth"` + `spanNulls: true`; time metrics use unit `ms`. 曲线渲染：smooth + spanNulls；时间指标用 ms 单位。

## Error Analysis / 错误分析 (nightly, 23:00)

A nightly 25h-window job classifies every new failure into **parameter error** (`参数错误`, client's fault) vs **other** (`其他`, service-side / undeterminable), then appends the day's section to a **MONTHLY** markdown archive. 每晚对最近 25 小时的失败调用分类为**参数错误（调用方原因）**或**其他（服务自身/无法定责）**，并按天追加到**按月归档**的 markdown。

- **Purpose / 目的**: failed-request rates and lists EXCLUDE parameter errors from the failure denominator — client bugs (bad model name, non-multimodal image call, unexpected params) are not the platform's problem. 失败率与失败清单都要把参数错误剔除出分母 —— 调用方 bug 不算平台问题。
- **Window**: `startTime >= now() - 25h` (covers a full overlap) with `status='failure'` AND `api_key IN (${key_group})`. 窗口 25 小时、status=failure、key_group 范围。
- **Classification / 分类口径** (the portable artifact is the **rules JSON** — class/code lists + message regex; the nightly driver `error-analysis.py` is your own, env-driven, reads that JSON). 分类的核心可迁移产物是**规则 JSON**（error_class/error_code 列表 + 消息正则）；每晚的驱动脚本 `error-analysis.py` 由你自备（env 驱动、读该 JSON）。
  - Parameter error flag = one of (`error_class` IN list) OR (`error_code` IN list) OR (`error_message` ~* regex). 命中 error_class / error_code 列表或 error_message 正则之一即参数错误。
  - Common parameter signatures: `ProxyModelNotFoundError` (bad model name), `AuthenticationError` on the caller side, `BadRequestError` / `UnsupportedParamsError` (e.g. `glm53 is not a multimodal model` = sending images to a non-multimodal model), or a `thinking` param the model doesn't accept. 常见参数错误特征见原文。
  - Everything not flagged is `其他`. Rows with no `error_code` / `error_class` rely on message-regex matching only. 未命中即其他；无 code 的靠消息正则。
- **Idempotent monthly append / 幂等按月追加**: one file per month `error-analysis_YYYY-MM.md`; rerunning the same day REPLACES that day's section (split on `^## ` day headers) — never one file per day. 每月一个文件；同一天重跑**替换**该日小节，绝不每天独立建文件。
- **Output sections / 输出结构**: `## YYYY-MM-DD` → failure total, param vs other counts, per `error_class/error_code` detail (tagged 参数错误/其他), then a "rules not covered" list (repeated `其他` message heads ≥2× → candidates to add to the rules JSON). 失败总数、参数/其他计数、按 error_class/error_code 明细、再加"规则未覆盖的重复模式"候选（≥2 次的其他类消息头，供扩充规则）。
- **Verify / 验证**: after a run, confirm the day's `## YYYY-MM-DD` section appeared and counts sum (`param + other == total`). 确认当日小节出现、参数+其他=总数。

## Pitfalls / 已知坑点

- Schema is case-sensitive: `"LiteLLM_SpendLogs"`, `"startTime"`, `"endTime"`, `"completionStartTime"` must be double-quoted. 表名与列名大小写敏感，必须双引号。
- Buffered rows poison TPOT without the >=1s guard. 缓冲行会污染 TPOT，无 ≥1 秒守卫时均值可达 10⁴–10⁵ token/s。
- Short completions (<50 output tokens) inflate average TPOT. 短输出会抬高平均 TPOT；可提供中位数或 `completion_tokens >= 100` 守卫。
- Failed requests never reach TPOT (`status='success'` filter). 失败请求永远进不了 TPOT。
- `spend` is 0.0 when LiteLLM cost tracking is off. LiteLLM 未配置成本追踪时 spend 全为 0.0。
- `barchart` legends are display-only in Grafana 11.x; use `timeseries` + `drawStyle: "bars"` for click-to-toggle. barchart 图例只能看；点击隐藏用 timeseries + drawStyle bars。
- Dashboard variables must live under `templating.list` — NOT `templating.var`; wrong placement 500s every panel. 看板变量必须放 `templating.list` 而非 `templating.var`；放错所有面板都 500。
- Table time columns: select raw `"startTime"`; a `to_char(...)` alias fails with HTTP 400. 表格时间列选原始 startTime；to_char 别名会 400。
- Save conflicts: re-export via `GET /api/dashboards/uid/<uid>` or save with `"overwrite": true`. 保存冲突：重导出或 overwrite 保存。
- Regex batch-edits are silent on no-match — always post-audit. 批量正则改 SQL 未匹配是静默的，务必事后审计。

## Verification / 验证

- Import script: all six dashboards return HTTP 200 (fails otherwise). 导入脚本要求六个看板全部 HTTP 200，否则退出非零。
- After import: `GET /api/dashboards/uid/<uid>` for each — assert panel count and title. 导入后逐个核对面板数量与标题。
- Spot-check one metric via direct pg8000 query; `references/schema-and-metrics.md` lists verified sane ranges. 用 pg8000 直连抽查指标；schema-and-metrics.md 列有实测合理范围。
