#!/usr/bin/env bash
set -euo pipefail

# Fetch APK HTTP URL for an existing tag without triggering a new workflow.
# Usage:
#   GITHUB_TOKEN=... ./scripts/fetch_apk_url.sh <owner> <repo> <tag>
# If no release APK is found, tries latest successful workflow run artifact URL.

if [[ $# -ne 3 ]]; then
  echo "Usage: GITHUB_TOKEN=... $0 <owner> <repo> <tag>"
  exit 1
fi

OWNER="$1"
REPO="$2"
TAG="$3"
API="https://api.github.com/repos/${OWNER}/${REPO}"
WORKFLOW_FILE="android-apk.yml"

: "${GITHUB_TOKEN:?GITHUB_TOKEN is required}"

api() {
  local method="$1"; shift
  local url="$1"; shift
  curl -sS -X "$method" \
    -H "Authorization: Bearer ${GITHUB_TOKEN}" \
    -H "Accept: application/vnd.github+json" \
    "$url" "$@"
}

api_code() {
  local method="$1"; shift
  local url="$1"; shift
  curl -s -o /dev/null -w "%{http_code}" -X "$method" \
    -H "Authorization: Bearer ${GITHUB_TOKEN}" \
    -H "Accept: application/vnd.github+json" \
    "$url" "$@"
}

# 1) Release APK direct URL
REL_CODE=$(api_code GET "$API/releases/tags/${TAG}")
if [[ "$REL_CODE" == "200" ]]; then
  REL_JSON=$(api GET "$API/releases/tags/${TAG}")
  APK_URL=$(printf '%s' "$REL_JSON" | python -c 'import json,sys; d=json.load(sys.stdin); assets=d.get("assets",[]); apk=[a.get("browser_download_url","") for a in assets if str(a.get("name","")).endswith(".apk")]; print(apk[0] if apk else "")')
  if [[ -n "$APK_URL" ]]; then
    echo "$APK_URL"
    exit 0
  fi
fi

# 2) Latest successful workflow run artifact URL for this tag
RUNS_JSON=$(api GET "$API/actions/workflows/${WORKFLOW_FILE}/runs?per_page=30")
RUN_ID=$(printf '%s' "$RUNS_JSON" | python -c '
import json,sys
d=json.load(sys.stdin)
tag=sys.argv[1]
run_id=""
for r in d.get("workflow_runs",[]):
    if r.get("head_branch") != tag:
        continue
    if r.get("status") == "completed" and r.get("conclusion") == "success":
        run_id=str(r.get("id",""))
        break
print(run_id)
' "$TAG")

if [[ -n "$RUN_ID" ]]; then
  ARTIFACTS_JSON=$(api GET "$API/actions/runs/${RUN_ID}/artifacts")
  ARTIFACT_URL=$(printf '%s' "$ARTIFACTS_JSON" | python -c 'import json,sys; d=json.load(sys.stdin); arts=d.get("artifacts",[]); urls=[a.get("archive_download_url","") for a in arts if not a.get("expired",False) and str(a.get("name","")).startswith("loopprofit-apk")]; print(urls[0] if urls else "")')
  if [[ -n "$ARTIFACT_URL" ]]; then
    echo "$ARTIFACT_URL"
    exit 0
  fi
fi

echo "No APK URL found for ${OWNER}/${REPO} tag ${TAG}"
exit 1
