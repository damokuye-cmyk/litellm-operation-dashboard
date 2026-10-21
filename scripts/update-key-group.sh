#!/usr/bin/env bash
# update-key-group.sh — manage the "key_group" variable (allowed api_key hashes)
# across all six LiteLLM SpendLogs dashboards (5 core + MaaS customer) in one command.
#
# Usage:
#   ./update-key-group.sh <hash1>[,hash2,...]        # set the member list (comma-separated, no spaces)
#   ./update-key-group.sh --list                     # show current members per dashboard
#
# Env (all optional):
#   GRAFANA_URL   default http://127.0.0.1:3000
#   GRAFANA_USER  default admin
#   GRAFANA_PASS  default admin
#
# The key list lives ONLY in the dashboard variable "key_group"
# (Dashboard settings -> Variables -> key_group). Every panel SQL uses
#   api_key IN (${key_group:sqlstring})
# so editing the variable instantly re-scopes all panels — no SQL edits.
# "All" (allValue empty) expands to the full member list.

set -euo pipefail

GRAFANA_URL="${GRAFANA_URL:-http://127.0.0.1:3000}"
GRAFANA_USER="${GRAFANA_USER:-admin}"
GRAFANA_PASS="${GRAFANA_PASS:-admin}"

UIDS=(
  litellm-spendlogs
  litellm-spendlogs-grouped
  litellm-token-analysis
  litellm-spendlogs-grouped-bars
  litellm-spendlogs-bars-search-agent
  wsd6bgm3e74k
)

auth=(-u "${GRAFANA_USER}:${GRAFANA_PASS}")

list_current() {
  for uid in "${UIDS[@]}"; do
    curl -s --max-time 15 "${auth[@]}" \
      "${GRAFANA_URL}/api/dashboards/uid/${uid}" \
    | python3 -c '
import json, sys
d = json.load(sys.stdin)["dashboard"]
var_list = (d.get("templating") or {}).get("list") or []
v = next((v for v in var_list if v.get("name") == "key_group"), None)
if not v:
    print("key_group variable MISSING from templating.list"); sys.exit(1)
members = v["query"].split(",")
print(d["uid"].ljust(38), "v%-3d" % d["version"], "members=%d" % len(members))
'
  done
}

if [[ "${1:-}" == "--list" ]]; then
  list_current
  exit 0
fi

if [[ $# -lt 1 ]]; then
  echo "usage: $0 <hash1>[,hash2,...] | --list" >&2
  exit 1
fi

KEYS="$1"

# normalize: strip whitespace, dedupe, require 64-hex members
QUERY=$(python3 -c '
import sys, re
raw = sys.argv[1]
keys = [k.strip() for k in raw.split(",") if k.strip()]
seen, out = set(), []
for k in keys:
    if k in seen: continue
    if not re.fullmatch(r"[0-9a-fA-F]{64}", k):
        print(f"ERROR: \"{k}\" is not a 64-char hex key hash", file=sys.stderr); sys.exit(1)
    seen.add(k); out.append(k)
print(",".join(out))
' "$KEYS")

N_MEMBERS=$(python3 -c 'import sys; print(len(sys.argv[1].split(",")))' "$QUERY")
echo "Setting key_group to ${N_MEMBERS} members (dashboard variable on all dashboards):"

for uid in "${UIDS[@]}"; do
  curl -s --max-time 15 "${auth[@]}" \
    "${GRAFANA_URL}/api/dashboards/uid/${uid}" -o "/tmp/kg-${uid}.json"
  python3 - "$uid" "$QUERY" <<'PYEOF'
import json, sys
uid, query = sys.argv[1], sys.argv[2]
doc = json.load(open(f"/tmp/kg-{uid}.json"))
d = doc["dashboard"]
d.pop("id", None)
var_list = (d.get("templating") or {}).get("list") or []
var = next((v for v in var_list if v.get("name") == "key_group"), None)
if var is None:
    sys.exit(f"key_group variable missing on {uid}")
var["query"] = query
var["current"] = {"selected": True, "text": ["All"], "value": ["$__all"]}
var["options"] = [{"selected": True, "text": "All", "value": "$__all"}]
json.dump({"dashboard": d, "overwrite": True,
           "message": f"key_group updated to {len(query.split(','))} members"},
          open(f"/tmp/kg-{uid}-save.json", "w"))
PYEOF
  curl -s --max-time 15 "${auth[@]}" -H 'Content-Type: application/json' \
    -X POST "${GRAFANA_URL}/api/dashboards/db" -d @"/tmp/kg-${uid}-save.json" \
  | python3 -c '
import json, sys
r = json.load(sys.stdin)
print("  " + str(r.get("slug", "?")).ljust(45), "->", r.get("status", "FAILED"), "v%s" % r.get("version", "?"))
if r.get("status") != "success": sys.exit(1)
'
done

echo "Done. Verify:"
list_current
