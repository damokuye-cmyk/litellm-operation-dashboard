# LiteLLM Operation Dashboard

Deploy, maintain, and migrate a six-dashboard Grafana analytics pack over the LiteLLM proxy's PostgreSQL table `"LiteLLM_SpendLogs"`. Bilingual (EN/CN). Chinese version: [README_zh.md](README_zh.md).

Consolidated from the former `litellm-spendlogs-dashboards-en` / `-cn` skill pair into a single bilingual skill. Shared dashboards, scripts, and schema reference are byte-identical to the originals.

## Features

- Six dashboards: usage overview, merged model-group rollups, token analysis, bucketed bar/line charts, per-key "Search Agent" variant with failed-request table, and a customer-facing "MaaS Operation Dashboard".
- Streaming latency metrics: TTFT, E2E, TPOT and non-stream prompt-processing throughput.
- One-command import script that reproduces the whole set on a fresh Grafana.
- Language-adaptive output via the `output_locale` parameter (`auto | en | zh-CN`).
- Fully offline; credentials come from a mode-600 env file, never from literals.

## Requirements

- Grafana 11.x over HTTP; admin credentials (basic auth).
- PostgreSQL datasource pointing at the LiteLLM database (`litellm_db`, SELECT user); note its `uid`.
- `pg8000` for direct DB verification.

## Layout

```
SKILL.md                                Bilingual usage guide (EN primary + CN inline)
README.md                               This file (English primary)
README_zh.md                            Chinese translation
references/schema-and-metrics.md        SQL reference, metric guards, safe ranges (language-independent)
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

See `SKILL.md` for the full procedure, metric definitions, scheduling, rendering, error analysis, pitfalls, and verification.

## License

MIT
