#!/usr/bin/env bash
# render-dashboard.sh — headless-Chrome screenshot of any dashboard in the pack into a PNG.
#
# Reusable across hosts: no secrets, no hard-coded customer paths. Everything is
# env-driven with safe defaults; point GRAFANA_URL / CHROME_BIN / OUT_DIR at the target.
#
# Auth model: the target Grafana must allow an ANONYMOUS Viewer role for the dashboard
# (Grafana -> Users & access -> Anonymous). The CLI cannot inject cookies, so the render
# URL must be viewable without login. Password-protected instances need a different path
# (renderer plugin + POST /api/render, see SKILL.md "Rendering").
#
# Usage:
#   render-dashboard.sh <uid> <out.png> [window-spec] [bucket]
#   window-spec: yesterday | week | '<from_ms>-<to_ms>'   (default: yesterday, Riyadh prev day)
#   bucket:      grafana $bucket to force, e.g. 10m / 30m / 1d  (empty = dashboard default)
#
# Timezone note: `tz=Asia%2FRiyadh` forces the dashboard clock to Riyadh regardless of
# host TZ. `from=now-1d%2Fd&to=now-1d%2Fd` = strict previous full day.
set -euo pipefail

DUID="${1:?usage: render-dashboard.sh <uid> <out.png> [yesterday|week|from-to] [bucket]}"
OUT="${2:?missing output path}"
WINDOW="${3:-yesterday}"
BUCKET="${4:-}"

# env with defaults
GRAFANA_URL="${GRAFANA_URL:-http://127.0.0.1:3000}"
CHROME_BIN="${CHROME_BIN:-google-chrome}"
PROFILE="${PROFILE:-/tmp/chrome-render-profile}"
WIDTH="${WIDTH:-1600}"
HEIGHT="${HEIGHT:-1900}"
MIN_SIZE="${MIN_SIZE:-100000}"       # under this = login/blank page, treat as failure
TIME_BUDGET="${TIME_BUDGET:-90000}"  # virtual-time-budget ms (let async panels settle)

# window -> URL fragment (Riyadh UTC+3, no DST -> epoch math is exact)
case "$WINDOW" in
  yesterday)
    FRAG="from=now-1d%2Fd&to=now-1d%2Fd"
    ;;
  week)
    TODAY_ZERO=$(date -d 'today 00:00' +%s)
    START_MS=$(( (TODAY_ZERO - 7*86400) * 1000 ))
    END_MS=$(( TODAY_ZERO * 1000 ))
    FRAG="from=${START_MS}&to=${END_MS}"
    ;;
  *)
    FRAG="from=${WINDOW%%-*}&to=${WINDOW##*-}"
    ;;
esac

BQ=""
[ -n "$BUCKET" ] && BQ="&var-bucket=${BUCKET}"

mkdir -p "$(dirname "$OUT")"

if ! curl -sf "$GRAFANA_URL/api/health" >/dev/null; then
  echo "FAIL grafana-down $GRAFANA_URL" >&2
  exit 1
fi

rm -f "${OUT}.tmp.png"
if timeout 180 "$CHROME_BIN" --headless=new --disable-gpu --no-sandbox --hide-scrollbars \
     --user-data-dir="$PROFILE" --window-size="${WIDTH},${HEIGHT}" \
     --virtual-time-budget="$TIME_BUDGET" --screenshot="${OUT}.tmp.png" \
     "$GRAFANA_URL/d/$DUID?kiosk&tz=Asia%2FRiyadh&$FRAG$BQ" 2>/dev/null; then
  SIZE=$(stat -c%s "${OUT}.tmp.png" 2>/dev/null || echo 0)
  if file "${OUT}.tmp.png" | grep -q "PNG image data" && [ "$SIZE" -gt "$MIN_SIZE" ]; then
    mv "${OUT}.tmp.png" "$OUT"
    echo "OK $OUT ($SIZE bytes, window=$WINDOW bucket=${BUCKET:-default})"
    exit 0
  fi
fi
RC=$?
echo "FAIL uid=$DUID (chrome rc=$RC, size=${SIZE:-n/a})" >&2
rm -f "${OUT}.tmp.png"
exit 1
