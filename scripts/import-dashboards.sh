#!/usr/bin/env bash
# Import the six LiteLLM SpendLogs dashboards into a Grafana instance.
#
# Env:
#   GRAFANA_URL     default http://127.0.0.1:3000
#   GRAFANA_USER    default admin
#   GRAFANA_PASS    required - Grafana admin password
#   DATASOURCE_UID  optional - rewrite the baked-in postgres datasource uid
#                   (P98809E0A67B9D897) to this value before importing.
#
# Exits non-zero if any dashboard fails to import.
set -euo pipefail

GRAFANA_URL="${GRAFANA_URL:-http://127.0.0.1:3000}"
GRAFANA_USER="${GRAFANA_USER:-admin}"
GRAFANA_PASS="${GRAFANA_PASS:?Set GRAFANA_PASS to the Grafana admin password}"
DATASOURCE_UID="${DATASOURCE_UID:-}"
BUILTIN_UID="P98809E0A67B9D897"
DIR="$(cd "$(dirname "$0")/../assets/dashboards" && pwd)"

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

fail=0
for f in "$DIR"/*.json; do
  if [ -n "$DATASOURCE_UID" ]; then
    sed "s/$BUILTIN_UID/$DATASOURCE_UID/g" "$f" > "$tmp"
  else
    cp "$f" "$tmp"
  fi
  code="$(curl -s -u "$GRAFANA_USER:$GRAFANA_PASS" -H 'Content-Type: application/json' \
        -X POST "$GRAFANA_URL/api/dashboards/db" -d @"$tmp" -o /dev/null -w '%{http_code}')" || code="000"
  echo "$(basename "$f"): HTTP $code"
  [ "$code" = "200" ] || fail=1
done

if [ "$fail" = "1" ]; then
  echo "ERROR: one or more dashboards failed to import." >&2
  exit 1
fi
echo "All dashboards imported."
