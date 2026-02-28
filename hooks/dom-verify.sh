#!/bin/bash
# dom-verify.sh — agent-browser DOM 応答性検証
#
# L10 (UI Responsiveness) の Layer 2 として、実際のブラウザで
# インタラクティブ要素のクリック後に accessibility snapshot が変化するか検証する。
#
# 成功時: "READY:<json_report_path>" を stdout へ出力
# 失敗時: "UNAVAILABLE:<reason>" を stdout へ出力 (exit 0 — 非ブロッキング)
#
# Protocol: lm-studio-ensure.sh と同じ READY/UNAVAILABLE パターン
#
# Usage:
#   RESULT=$(bash hooks/dom-verify.sh <base-url>)
#   case "$RESULT" in
#     READY:*) REPORT="${RESULT#READY:}" ;;
#     *)       echo "grep-only mode (no browser verification)" ;;
#   esac
#
# Dependencies: npx agent-browser (Vercel agent-browser)
# Lazy startup: grep 候補あり + アプリ起動中のときのみ実行

set -uo pipefail

# --- Configuration ---
BASE_URL="${1:-}"
HEALTH_TIMEOUT=1          # seconds — health check timeout
WAIT_AFTER_CLICK=500      # ms — DOM 変化を待つ時間
REPORT_FILE="/tmp/dom-verify-$(date +%s).json"

# --- Helper ---
log() { echo "[dom-verify] $*" >&2; }

# --- Step 0: Argument check ---
if [ -z "$BASE_URL" ]; then
  echo "UNAVAILABLE:no_base_url"
  exit 0
fi

# --- Step 1: Health check (app running?) ---
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout "$HEALTH_TIMEOUT" "$BASE_URL" 2>/dev/null || echo "000")

if [ "$HTTP_CODE" = "000" ] || [ "$HTTP_CODE" -ge 500 ] 2>/dev/null; then
  log "App not reachable at ${BASE_URL} (HTTP ${HTTP_CODE})"
  echo "UNAVAILABLE:app_not_running"
  exit 0
fi
log "App reachable (HTTP ${HTTP_CODE})"

# --- Step 2: agent-browser existence check ---
if ! command -v npx >/dev/null 2>&1; then
  echo "UNAVAILABLE:npx_not_found"
  exit 0
fi

# Quick check if agent-browser is available
if ! npx agent-browser --version >/dev/null 2>&1; then
  log "agent-browser not installed"
  echo "UNAVAILABLE:agent_browser_not_found"
  exit 0
fi
log "agent-browser available"

# --- Step 3: Navigate and snapshot ---
log "Navigating to ${BASE_URL}..."
SNAPSHOT_BEFORE=$(npx agent-browser snapshot --url "$BASE_URL" 2>/dev/null)

if [ -z "$SNAPSHOT_BEFORE" ]; then
  log "Failed to capture initial snapshot"
  echo "UNAVAILABLE:snapshot_failed"
  exit 0
fi

# --- Step 4: Extract interactive elements from accessibility tree ---
# Parse refs for interactive elements (buttons, links, forms)
INTERACTIVE_REFS=$(echo "$SNAPSHOT_BEFORE" \
  | grep -oE 'ref="[^"]*"' \
  | grep -iE 'button|link|submit|checkbox|tab' \
  | sed 's/ref="//;s/"//' \
  | head -20)

TOTAL=0
RESPONSIVE=0
UNRESPONSIVE=0
DETAILS="[]"

if [ -z "$INTERACTIVE_REFS" ]; then
  log "No interactive elements found in accessibility tree"
  # Still report success with 0 elements
  cat > "$REPORT_FILE" <<EOF
{"tested":0,"responsive":0,"unresponsive":0,"details":[],"status":"no_interactive_elements"}
EOF
  echo "READY:${REPORT_FILE}"
  exit 0
fi

# --- Step 5: Click each element and check for DOM changes ---
DETAILS_JSON="["
FIRST=true

while IFS= read -r ref; do
  [ -z "$ref" ] && continue
  TOTAL=$((TOTAL + 1))

  # Snapshot before click
  SNAP_PRE=$(npx agent-browser snapshot 2>/dev/null | md5 2>/dev/null || echo "pre")

  # Click the element
  npx agent-browser click --ref "$ref" 2>/dev/null

  # Wait for DOM changes
  sleep "0.$(printf '%03d' $WAIT_AFTER_CLICK)"

  # Snapshot after click
  SNAP_POST=$(npx agent-browser snapshot 2>/dev/null | md5 2>/dev/null || echo "post")

  # Compare
  if [ "$SNAP_PRE" = "$SNAP_POST" ]; then
    UNRESPONSIVE=$((UNRESPONSIVE + 1))
    STATUS="unresponsive"
  else
    RESPONSIVE=$((RESPONSIVE + 1))
    STATUS="responsive"
  fi

  # Append to details JSON
  if [ "$FIRST" = true ]; then
    FIRST=false
  else
    DETAILS_JSON="${DETAILS_JSON},"
  fi
  DETAILS_JSON="${DETAILS_JSON}{\"ref\":\"${ref}\",\"status\":\"${STATUS}\"}"

  log "  ref=${ref} -> ${STATUS}"
done <<< "$INTERACTIVE_REFS"

DETAILS_JSON="${DETAILS_JSON}]"

# --- Step 6: Write JSON report ---
cat > "$REPORT_FILE" <<EOF
{"tested":${TOTAL},"responsive":${RESPONSIVE},"unresponsive":${UNRESPONSIVE},"details":${DETAILS_JSON}}
EOF

log "Report: tested=${TOTAL} responsive=${RESPONSIVE} unresponsive=${UNRESPONSIVE}"
echo "READY:${REPORT_FILE}"
exit 0
