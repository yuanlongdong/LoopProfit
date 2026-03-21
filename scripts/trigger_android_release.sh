#!/usr/bin/env bash
set -euo pipefail

# Trigger GitHub Actions android-apk workflow for a tag and print APK release URL.
# Usage:
#   GITHUB_TOKEN=... ./scripts/trigger_android_release.sh <owner> <repo> <tag> [timeout_seconds]

if [[ $# -lt 3 || $# -gt 4 ]]; then
  echo "Usage: GITHUB_TOKEN=... $0 <owner> <repo> <tag> [timeout_seconds]"
  exit 1
fi

OWNER="$1"
REPO="$2"
TAG="$3"
TIMEOUT="${4:-3600}"
WORKFLOW_FILE="android-apk.yml"
API="https://api.github.com/repos/${OWNER}/${REPO}"

: "${GITHUB_TOKEN:?GITHUB_TOKEN is required}"

api() {
  local method="$1"; shift
  local url="$1"; shift
  curl -sS -X "$method" \
    -H "Authorization: Bearer ${GITHUB_TOKEN}" \
    -H "Accept: application/vnd.github+json" \
    "$url" "$@"
}

# Ensure tag exists remotely by creating refs/tags/<tag> from default branch HEAD when missing.
DEFAULT_BRANCH=$(api GET "$API" | python -c 'import json,sys; print(json.load(sys.stdin)["default_branch"])')
HEAD_SHA=$(api GET "$API/git/ref/heads/${DEFAULT_BRANCH}" | python -c 'import json,sys; print(json.load(sys.stdin)["object"]["sha"])')

TAG_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
  -H "Authorization: Bearer ${GITHUB_TOKEN}" \
  -H "Accept: application/vnd.github+json" \
  "$API/git/ref/tags/${TAG}")
if [[ "$TAG_STATUS" == "404" ]]; then
  api POST "$API/git/refs" \
    -d "$(printf '{"ref":"refs/tags/%s","sha":"%s"}' "$TAG" "$HEAD_SHA")" >/dev/null
fi

# Dispatch workflow on tag.
DISPATCH_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
  -H "Authorization: Bearer ${GITHUB_TOKEN}" \
  -H "Accept: application/vnd.github+json" \
  "$API/actions/workflows/${WORKFLOW_FILE}/dispatches" \
  -d "$(printf '{"ref":"%s"}' "$TAG")")
if [[ "$DISPATCH_CODE" != "204" ]]; then
  echo "failed to dispatch workflow (${DISPATCH_CODE})"
  exit 1
fi

echo "Workflow dispatched for ${TAG}; waiting..."

START=$(date +%s)
RUN_ID=""
while true; do
  NOW=$(date +%s)
  if (( NOW - START > TIMEOUT )); then
    echo "timeout waiting for workflow completion"
    exit 1
  fi

  RUN_JSON=$(api GET "$API/actions/workflows/${WORKFLOW_FILE}/runs?event=push&branch=${TAG}&per_page=1")
  RUN_ID=$(printf '%s' "$RUN_JSON" | python -c 'import json,sys; d=json.load(sys.stdin); print(d["workflow_runs"][0]["id"] if d.get("workflow_runs") else "")')
  STATUS=$(printf '%s' "$RUN_JSON" | python -c 'import json,sys; d=json.load(sys.stdin); print(d["workflow_runs"][0]["status"] if d.get("workflow_runs") else "")')
  CONCLUSION=$(printf '%s' "$RUN_JSON" | python -c 'import json,sys; d=json.load(sys.stdin); print(d["workflow_runs"][0].get("conclusion","") if d.get("workflow_runs") else "")')

  if [[ -n "$RUN_ID" && "$STATUS" == "completed" ]]; then
    if [[ "$CONCLUSION" != "success" ]]; then
      echo "workflow completed with conclusion=${CONCLUSION}"
      exit 1
    fi
    break
  fi
  sleep 10

done

# Fetch release asset URL for APK
REL_JSON=$(api GET "$API/releases/tags/${TAG}")
APK_URL=$(printf '%s' "$REL_JSON" | python -c 'import json,sys; d=json.load(sys.stdin); assets=d.get("assets",[]); apk=[a.get("browser_download_url","") for a in assets if str(a.get("name","")) .endswith(".apk")]; print(apk[0] if apk else "")')

if [[ -z "$APK_URL" ]]; then
  REL_URL=$(printf '%s' "$REL_JSON" | python -c 'import json,sys; d=json.load(sys.stdin); print(d.get("html_url",""))')
  if [[ -n "$REL_URL" ]]; then
    echo "$REL_URL"
    exit 0
  fi
  echo "release found but no apk asset"
  exit 1
fi

echo "$APK_URL"
