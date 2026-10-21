# LiteLLM Operation Dashboard

A six-dashboard Grafana pack over the LiteLLM proxy's PostgreSQL table `"LiteLLM_SpendLogs"` — usage overview, token analysis, streaming latency (TTFT/E2E/TPOT), and per-key drilldown. One command imports the whole set onto a fresh Grafana. Chinese version: [README_zh.md](README_zh.md).

## Contents

- [Dashboards](#dashboards)
- [Features](#features)
- [Requirements](#requirements)
- [Quick Start](#quick-start)
- [Layout](#layout)
- [Known Pitfalls](#known-pitfalls)
- [Documentation](#documentation)
- [License](#license)

## Dashboards

| Dashboard | What it shows |
|---|---|
| litellm-dashboard.json | Per-model overview and request-tag matrix. |
| litellm-dashboard-grouped.json | `key_group` scope, merged model groups, streaming metrics (TTFT/E2E/TPOT). |
| litellm-dashboard-tokens.json | Token distributions, percentiles, output/input ratio. |
| litellm-dashboard-grouped-bars.json | Adjustable time buckets (5m–7d): volume as bars, latency as lines. |
| litellm-dashboard-bars-search-agent.json | Same as above, with api_key relabeled as **Search Agent** plus a failed-requests table. |
| maas-operation-dashboard-customer.json | Customer-facing "MaaS Operation Dashboard" (N1–N20 layout), same `key_group` variable. |

All grouped charts share one series palette: glm-text = green, deepseek-v4-flash = blue, glm53-flash = orange, Search Agent = purple, `<none>` = gray.

## Features

- Streaming latency metrics: TTFT, E2E, TPOT, plus non-stream prompt-processing throughput.
- One-command import that reproduces the full set on a fresh Grafana.
- Fully offline; credentials come from a mode-600 env file, never inline.
- Written conclusions follow the caller's language (`output_locale: auto | en | zh-CN`); metrics and SQL stay language-independent.
- A schema and metric reference with validity filters and observed value ranges ships alongside the dashboards.

## Requirements

| Component | Requirement |
|---|---|
| Grafana | 11.x, reachable over HTTP, admin credentials (basic auth) |
| PostgreSQL datasource | Points at the LiteLLM database (`litellm_db`); SELECT-only user is enough |
| Python | `pg8000` for direct database verification (no psql client needed) |

## Quick Start

```bash
# Import all six dashboards into a target Grafana
GRAFANA_URL=http://<host>:3000 GRAFANA_USER=admin GRAFANA_PASS=<pw> \
DATASOURCE_UID=<uid> scripts/import-dashboards.sh
```

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

## Known Pitfalls

A few things worth knowing before you build on this pack; the full list is in `SKILL.md`:

- Identifiers are case-sensitive — `"LiteLLM_SpendLogs"`, `"startTime"`, `"endTime"` must be double-quoted.
- Dashboard variables must live under `templating.list`, not `templating.var`; wrong placement makes every panel 500.
- `spend` is 0.0 everywhere when LiteLLM cost tracking is off.

## Documentation

| Document | Purpose |
|---|---|
| [SKILL.md](SKILL.md) | Full working procedure: migration steps, metric definitions, scheduling, rendering, error analysis, verification |
| [references/schema-and-metrics.md](references/schema-and-metrics.md) | SpendLogs schema, metric formulas, validity filters, observed ranges |
| [README_zh.md](README_zh.md) | Chinese version of this README |

## License

MIT
