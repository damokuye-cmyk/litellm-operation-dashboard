# LiteLLM SpendLogs: Schema, Metrics, and Verified Values

## Table

`"LiteLLM_SpendLogs"` in the LiteLLM proxy's PostgreSQL database (case-sensitive, ORM-generated). 33 columns; key ones:

| Column | Type | Notes |
|---|---|---|
| `"startTime"`, `"endTime"` | timestamp | request window. Quote them. |
| `"completionStartTime"` | timestamp | **first-token time for streamed rows**; for buffered (non-stream) rows it is recorded at completion, i.e. ≈ endTime. |
| `model`, `model_group` | text | model_group is the deployment alias; can be '' (mostly failures). |
| `api_key` | text | SHA-256 hash of the virtual key - used for filtering and identity relabeling. |
| `request_tags` | jsonb | array; element 0 = `"User-Agent: <client>"` (python-httpx, AsyncOpenAI, GitHubCopilotChat, litellm, ...). Present on ~35k of 39k rows. |
| `prompt_tokens`, `completion_tokens`, `total_tokens` | int | populated on success. |
| `request_duration_ms` | int | E2E in ms. |
| `status` | text | 'success' / 'failure'. Failures carry empty model/call_type and no timestamps. |
| `spend` | double | 0.0 everywhere when cost tracking is off. |
| `metadata` | jsonb | ~2KB avg; failures carry `metadata->'error_information'` with `error_class`, `error_code`, `error_message`. |
| `proxy_server_request` | jsonb | ~35KB avg, up to 700KB - NEVER select it into a table panel. |

## Metric formulas (as shipped in the pack)

All with `status='success'` and the dashboard's api_key filter.

**Stream identification**: `proxy_server_request->>'stream'` - 'true' means streamed; a missing key means non-stream (default false). Present on 35,236 of 36,063 success rows all-time; the 827 missing rows default to non-stream. Buffered (non-stream) rows record completionStartTime AT COMPLETION (= endTime), streamed rows record it at the first token.

**request_duration_ms == E2E**: verified equal to `("endTime" - "startTime") * 1000` within 1ms rounding (9,105 of 18,326 exact, avg abs diff 0.5ms, max 1ms). "Avg latency" and "E2E" are the same metric.

```sql
-- TTFT (streaming rows only)
AVG(EXTRACT(EPOCH FROM ("completionStartTime" - "startTime")) * 1000)
-- E2E  (== AVG(request_duration_ms))
AVG(EXTRACT(EPOCH FROM ("endTime" - "startTime")) * 1000)
-- TPOT, ms per output token (streaming)
AVG(EXTRACT(EPOCH FROM ("endTime" - "completionStartTime")) * 1000
    / NULLIF(completion_tokens, 0))
-- guards: proxy_server_request->>'stream' = 'true'
--          AND "completionStartTime" > "startTime"
--          AND EXTRACT(EPOCH FROM ("endTime" - "completionStartTime")) >= 1
--          AND completion_tokens > 0
-- Non-stream TTFT, ms per input token (buffered)
AVG(EXTRACT(EPOCH FROM ("completionStartTime" - "startTime")) * 1000
    / NULLIF(prompt_tokens, 0))
-- guards: COALESCE(proxy_server_request->>'stream','false') <> 'true'
--          AND "completionStartTime" > "startTime" AND prompt_tokens > 0
```

Why the 1s guard remains on TPOT: 180 rows all-time have stream=true but a sub-50ms recorded generation window with real tokens (recording glitches) - the guard drops those, it does not define streaming.

## Group merge CASE (per-panel SQL)

```sql
CASE WHEN api_key = '<search-agent-key-hash>' THEN 'Search Agent'   -- identity rule FIRST
     WHEN model_group IN ('glm52','glm5.1-w8a8','glm53','glm5.1') THEN 'glm-text'
     WHEN model_group IN ('deepseek-v4-flash','deepseek-v4-flash0731') THEN 'deepseek-v4-flash'
     ELSE COALESCE(NULLIF(model_group,''),'<none>')
END
```

In count-matrix panels the identity gets its own FILTER column and every other column's FILTER adds `api_key <> '<hash>'` to avoid double counting.

## Verified values (source deployment, 7d window, 2026-09)

- Groups: glm-text 10,115 req / deepseek-v4-flash 5,589 / glm53-flash 1,691 / Search Agent 296 / `<none>` 73.
- TPOT avg: deepseek-v4-flash ~20.6 ms/tok, glm53-flash ~59.5, glm-text ~64.8 (glm-text inflated by short-output + litellm-UA probe traffic; long-output glm53 runs at ~22-26 ms/tok).
- Non-stream TTFT/input-token: Search Agent ~3.8 ms, deepseek-v4-flash ~5.6, glm-text ~45, glm53-flash ~1,121 (long queue / small prompts - normalization artifact, flag it).
- Tokens: deepseek-v4-flash input-heavy (avg 41.7k in / 315 out, RAG pattern); glm-text bimodal; global input median ~9.7k, p99 ~134k, output median 128.

## Palette

glm-text `green`, deepseek-v4-flash `blue`, glm53-flash `orange`, Search Agent `purple`, `<none>` `#8e8e8e` - as `fieldConfig.overrides` byName matchers on every series panel.

## Operational quick reference

```bash
# datasource health
curl -s -u admin:<pw> http://<host>:3000/api/datasources/uid/<uid>/health
# save dashboard
curl -s -u admin:<pw> -H 'Content-Type: application/json' \
  -X POST http://<host>:3000/api/dashboards/db -d @<file>.json
# direct PG check
python3 -c "import pg8000.native as n; c=n.Connection('readonly',password='<pw>',host='<host>',port=5432,database='litellm_db'); print(c.run('SELECT COUNT(*) FROM \"LiteLLM_SpendLogs\"'))"
```
