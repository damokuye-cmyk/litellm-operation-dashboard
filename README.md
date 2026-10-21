# LiteLLM Operation Dashboard

A six-dashboard Grafana pack over the LiteLLM proxy's PostgreSQL table `"LiteLLM_SpendLogs"` — usage overview, token analysis, streaming latency (TTFT/E2E/TPOT), and per-key drilldown. One command imports the whole set onto a fresh Grafana. Chinese version: [README_zh.md](README_zh.md).

## Features

- Six dashboards: usage overview, merged model-group rollups, token analysis, bucketed bar/line charts, a per-key "Search Agent" variant with a failed-request table, and a customer-facing "MaaS Operation Dashboard".
- Streaming latency metrics: TTFT, E2E, TPOT, plus non-stream prompt-processing throughput.
- One-command import that reproduces the full set on a fresh Grafana.
- Fully offline; credentials come from a mode-600 env file, never inline.
- Written conclusions follow the caller's language (`output_locale: auto | en | zh-CN`); metrics and SQL stay language-independent.

## Requirements

- Grafana 11.x reachable over HTTP, with admin credentials (basic auth).
- A PostgreSQL datasource pointing at the LiteLLM database (`litellm_db`, SELECT user); note its `uid`.
- `pg8000` for direct database verification.

## Layout

```
SKILL.md                                Working instruction set (English)
README.md                               This file
README_zh.md                            Chinese version
references/schema-and-metrics.md        SQL reference, validity filters, observed ranges
assets/dashboards/                      6 dashboard JSONs
scripts/import-dashboards.sh            One-command import into a target Grafana
scripts/update-key-group.sh             Update api_key membership across all 6 dashboards
scripts/render-dashboard.sh             Headless-Chrome dashboard screenshot -> PNG (env-driven)
```

## Quick Start

```bash
# Import all six dashboards into a target Grafana
GRAFANA_URL=http://<host>:3000 GRAFANA_USER=admin GRAFANA_PASS=<pw> \
DATASOURCE_UID=<uid> scripts/import-dashboards.sh
```

See `SKILL.md` for the full procedure: migration steps, metric definitions, scheduling, rendering, error analysis, pitfalls, and verification.

## License

MIT
