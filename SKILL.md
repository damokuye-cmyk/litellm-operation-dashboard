---
name: litellm-operation-dashboard
description: "Maintain the LiteLLM SpendLogs Grafana dashboard pack."
version: 1.3.3
author: damokuye-ethanhuang
license: MIT
platforms: [linux, macos]
tags: [litellm, grafana, postgres, observability, llm-analytics]
related_skills: [grafana-dashboards]
---

# LiteLLM Operation Dashboard

A six-dashboard Grafana pack over the LiteLLM proxy's PostgreSQL table `"LiteLLM_SpendLogs"`. Use it to import the pack onto a new Grafana instance, extend its panels, and investigate usage, tokens, and streaming latency. Chinese documentation lives in [README_zh.md](README_zh.md); this file is the working instruction set and is English-only.

## The `output_locale` parameter

Analysis output is written for a human reader, so conclusions follow the caller's language; metrics and SQL never change.

```json
"output_locale": {
  "type": "string",
  "enum": ["auto", "en", "zh-CN"],
  "default": "auto",
  "description": "Language for the written analysis. auto follows the input query language, falling back to English if detection fails; en / zh-CN force that language."
}
```

## When to Use

- Import or rebuild this dashboard set on another Grafana instance (migration).
- Add or modify panels over `"LiteLLM_SpendLogs"` — the schema reference, quoting rules, and validity filters below apply.
- Investigate streaming latency (TTFT / E2E / TPOT) or non-stream prompt-processing throughput.
- Analyze usage, token distribution, model-group rollups, concurrency, or failure patterns.

**Not for:** general Grafana setup, auth resets, or API mechanics — that is `grafana-dashboards`.

## Prerequisites

- Grafana 11.x reachable over HTTP, with admin credentials (basic auth).
- A PostgreSQL datasource pointing at the LiteLLM database (`litellm_db`, SELECT-only user is enough). Note its **uid**.
- `pg8000` for direct database checks (`pip install pg8000`, no psql client needed).
- Credentials come from a mode-600 env file — never inline them in commands or scripts.
- Pack contents: dashboards in `assets/dashboards/`, importer at `scripts/import-dashboards.sh`.

## The Dashboard Pack (assets/dashboards/)

| File | uid | Shows |
|---|---|---|
| litellm-dashboard.json | litellm-spendlogs | Per-model overview and request-tag matrix. |
| litellm-dashboard-grouped.json | litellm-spendlogs-grouped | `key_group` scope, merged model groups, streaming metrics (TTFT/E2E/TPOT). |
| litellm-dashboard-tokens.json | litellm-token-analysis | Token distributions, percentiles, output/input ratio. |
| litellm-dashboard-grouped-bars.json | litellm-spendlogs-grouped-bars | Adjustable time buckets (5m–7d): volume as bars, latency as lines. |
| litellm-dashboard-bars-search-agent.json | litellm-spendlogs-bars-search-agent | Same as above, with api_key relabeled as **Search Agent** plus a failed-requests table. |
| maas-operation-dashboard-customer.json | wsd6bgm3e74k | Customer-facing "MaaS Operation Dashboard" (N1–N20 layout), same `key_group` variable. |

All grouped charts share one series palette: glm-text = green, deepseek-v4-flash = blue, glm53-flash = orange, Search Agent = purple, `<none>` = gray.

## Scheduling

The nightly/weekly PNG renders and the nightly error classification are plain scripts — wrap `scripts/render-dashboard.sh` (and your error-analysis driver) in small wrapper scripts and schedule them with cron or any scheduler:

```cron
30 1 * * *   /opt/dashboards/render-maas-daily.sh    # daily customer PNG
0 1 * * 0    /opt/dashboards/render-maas-weekly.sh   # weekly customer PNG
0 23 * * *   /opt/dashboards/error-analysis.py       # nightly failure classification
```

Run each job once by hand and check its output (PNG size, archive section) before trusting the schedule.

## Rendering PNGs

`scripts/render-dashboard.sh` screenshots any dashboard in the pack to a PNG via headless Chrome (anonymous Viewer auth). It is env-driven with safe defaults and reusable on any host — no secrets, no hard-coded paths.

```bash
CHROME_BIN=google-chrome OUT_DIR=... \
  scripts/render-dashboard.sh wsd6bgm3e74k "$OUT_DIR/customer_$(date +%F).png" yesterday 10m
# window: yesterday | week | '<from_ms>-<to_ms>'; bucket optional (10m/30m/1d)
```

Key parameters:

- `?kiosk` removes the nav and breadcrumb; `tz=Asia%2FRiyadh` pins the dashboard clock to Riyadh (UTC+3, no DST, so epoch window math is exact) regardless of host timezone.
- `--virtual-time-budget=90000` gives async panel queries time to settle. Too low and panels come back blank or partial.
- The output must be a real PNG larger than `MIN_SIZE` (default 100 KB). Login and blank pages are tiny — a small file means auth or render failed.
- `from=now-1d%2Fd&to=now-1d%2Fd` selects the previous full day; `week` runs from last Sunday 00:00 to this Sunday 00:00.
- Write logs to local disk, not an RDP-mapped drive (repeated appends there hit transient I/O errors).

> **Alternative — Grafana renderer plugin:** if the target has `grafana-image-renderer`, use `GET /render/d/<uid>/<slug>?...&width=1600&height=1900&timeout=90&kiosk`. Pin the plugin to **v3.12.9** on Grafana 11.2.x (4.x needs Grafana ≥ 11.3.8). The full-page render path is `/render/d/<uid>/<slug>`; the plain `/render` path truncates.

## Migration Steps

1. Provision the PostgreSQL datasource in the target Grafana and note its uid.
2. Import all six dashboards:
   ```bash
   GRAFANA_URL=http://<host>:3000 GRAFANA_USER=admin GRAFANA_PASS=<pw> \
   DATASOURCE_UID=<uid> scripts/import-dashboards.sh
   ```
   `DATASOURCE_UID` rewrites the baked-in uid (`GKFSMBOCFSBSO`) before POSTing. All six must return HTTP 200.
3. Per-deployment key membership lives only in the `key_group` dashboard variable (a hidden custom variable); every panel SQL references `api_key IN (${key_group:sqlstring})`. Update members with `scripts/update-key-group.sh <hash,...>` (covers all six at once) or via Dashboard → Variables → key_group. Never edit the SQL literals.
4. Verify: `/api/health`, datasource health, one `/api/ds/query` spot-check, then open each `/d/<uid>/...` page.

## Metric Definitions

Full formulas, validity filters ("guards"), and observed value ranges: `references/schema-and-metrics.md`.

- **TTFT** (streaming) = `completionStartTime - startTime`, the first-token delay.
- **E2E** = `endTime - startTime`. It equals `request_duration_ms` within 1 ms — same metric, never show both.
- **Stream vs non-stream**: use `proxy_server_request->>'stream'` ('true' = streamed). Do not infer it from generation-window length.
- **TPOT** (ms per output token) = `(endTime - completionStartTime)*1000/completion_tokens`. Require `status='success'`, stream='true', `completionStartTime > startTime`, a window of at least 1 s, and `completion_tokens > 0`.
- **Non-stream TTFT** (ms per input token) = `(completionStartTime - startTime)*1000/prompt_tokens` on non-stream rows; this is the prompt-processing throughput proxy.
- **Concurrency** (peak in-flight per group per `$bucket`): sweep-line over `[startTime, endTime)`.
- **Token display = raw values + Grafana `short` unit** (auto K/M/B). SQL returns undivided aggregates; do not append `(K)`/`(M)` to panel titles.
- **Average-token metrics exclude tiny requests** (`prompt_tokens + completion_tokens >= 150`). In mixed-purpose tables apply per-column `FILTER`, never a global WHERE.
- **Image requests** (glm53-flash panel): identifiable only by parsing `proxy_server_request->'messages'` parts for `type='image_url'`. The upstream does not report image tokens.
- **Error classification**: failure metrics exclude client-side parameter errors; failed-request lists add an `error_type` CASE column.
- **Success rate** = `success / (total - parameter errors)`.
- **Hour-of-day timezone**: `"startTime"` is naive UTC. Riyadh hour needs a double `AT TIME ZONE` conversion, built on a `generate_series(0,23)` grid.
- **Line charts**: `lineInterpolation: "smooth"` + `spanNulls: true`; time metrics use the `ms` unit.

## Error Analysis (nightly, 23:00)

A nightly job scans the last 25 hours of failures and splits each into **parameter error** (client's fault) vs **other** (service-side or undeterminable), then appends the day's section to a **monthly** markdown archive.

- **Why**: failed-request rates and lists exclude parameter errors from the denominator — client bugs (bad model name, image sent to a non-multimodal model, unexpected params) are not platform failures.
- **Window**: `startTime >= now() - 25h` (full overlap) with `status='failure'` AND `api_key IN (${key_group})`.
- **Classification rules**: the portable artifact is a **rules JSON** (error_class/error_code lists + message regexes); the nightly driver `error-analysis.py` is yours to provide (env-driven, reads that JSON).
  - A row is a parameter error if any of: `error_class` in list, `error_code` in list, or `error_message` matches the regex.
  - Typical signatures: `ProxyModelNotFoundError` (bad model name), caller-side `AuthenticationError`, `BadRequestError` / `UnsupportedParamsError` (e.g. `glm53 is not a multimodal model`), or a `thinking` param the model does not accept.
  - Anything not flagged is `其他`. Rows without `error_code`/`error_class` rely on the message regex alone.
- **Idempotent monthly append**: one file per month, `error-analysis_YYYY-MM.md`. Rerunning the same day replaces that day's section (split on `^## ` day headers) — never one file per day.
- **Output sections**: `## YYYY-MM-DD` → failure total, parameter vs other counts, per `error_class/error_code` detail, then a "rules not covered" list (repeated `其他` message heads, ≥2 occurrences, are candidates for the rules JSON).
- **Verify**: after a run, confirm the day's `## YYYY-MM-DD` section appeared and the counts sum (`param + other == total`).

## Known Pitfalls

- Identifiers are case-sensitive: `"LiteLLM_SpendLogs"`, `"startTime"`, `"endTime"`, `"completionStartTime"` must be double-quoted.
- Without the ≥1 s window guard, buffered rows poison TPOT (means can reach 10⁴–10⁵ tokens/s).
- Short completions (<50 output tokens) inflate average TPOT; offer a median or a `completion_tokens >= 100` filter.
- Failed requests never reach TPOT (the `status='success'` filter excludes them).
- `spend` is 0.0 everywhere when LiteLLM cost tracking is off.
- `barchart` legends are display-only in Grafana 11.x; use `timeseries` + `drawStyle: "bars"` for click-to-toggle.
- Dashboard variables must live under `templating.list`, not `templating.var`; wrong placement makes every panel 500.
- Table time columns: select raw `"startTime"`; a `to_char(...)` alias fails with HTTP 400.
- Save conflicts: re-export via `GET /api/dashboards/uid/<uid>`, or save with `"overwrite": true`.
- Regex batch-edits over SQL are silent on no-match — always audit afterwards.

## Verification

- Import script: all six dashboards return HTTP 200, else it exits non-zero.
- After import: `GET /api/dashboards/uid/<uid>` for each — assert panel count and title.
- Spot-check one metric via a direct pg8000 query; `references/schema-and-metrics.md` lists observed sane ranges.
