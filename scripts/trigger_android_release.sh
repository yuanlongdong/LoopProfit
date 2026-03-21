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
TIMEOUT="${4:-1200}"
POLL_INTERVAL=10
WORKFLOW_FILE="android-apk.yml"
API="https://api.github.com/repos/${OWNER}/${REPO}"
RUN_APPEAR_TIMEOUT=180

# Accept either GITHUB_TOKEN or GH_TOKEN.
if [[ -z "${GITHUB_TOKEN:-}" && -n "${GH_TOKEN:-}" ]]; then
  export GITHUB_TOKEN="$GH_TOKEN"
fi
: "${GITHUB_TOKEN:?GITHUB_TOKEN is required (or set GH_TOKEN)}"

if [[ "$GITHUB_TOKEN" == *"./scripts/"* ]]; then
  echo "detected malformed token value (it includes './scripts/...')."
  echo "please add a space before the script path:"
  echo "  GH_TOKEN=xxxxx ./scripts/trigger_android_release.sh <owner> <repo> <tag>"
  exit 1
fi

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

api_with_code() {
  local method="$1"; shift
  local url="$1"; shift
  local tmp
  tmp="$(mktemp)"
  local code
  code=$(curl -sS -o "$tmp" -w "%{http_code}" -X "$method" \
    -H "Authorization: Bearer ${GITHUB_TOKEN}" \
    -H "Accept: application/vnd.github+json" \
    "$url" "$@")
  printf '%s\n' "$code"
  cat "$tmp"
  rm -f "$tmp"
}

preflight_auth() {
  local repo_code
  repo_code=$(api_code GET "$API")
  case "$repo_code" in
    200) ;;
    401)
      echo "GitHub token authentication failed (401 Bad credentials)."
      exit 1
      ;;
    403)
      echo "GitHub token lacks permission for ${OWNER}/${REPO} (403 Forbidden)."
      exit 1
      ;;
    404)
      echo "Repository not found or token has no access: ${OWNER}/${REPO} (404)."
      exit 1
      ;;
    *)
      echo "Unexpected GitHub API status ${repo_code} while checking ${OWNER}/${REPO}."
      exit 1
      ;;
  esac

  local workflow_code
  workflow_code=$(api_code GET "$API/actions/workflows/${WORKFLOW_FILE}")
  if [[ "$workflow_code" != "200" ]]; then
    echo "Workflow file not accessible: ${WORKFLOW_FILE} (status ${workflow_code})"
    exit 1
  fi
}

preflight_auth

# Ensure tag exists remotely by creating refs/tags/<tag> from default branch HEAD when missing.
DEFAULT_BRANCH=$(api GET "$API" | python -c 'import json,sys; print(json.load(sys.stdin).get("default_branch",""))')
if [[ -z "$DEFAULT_BRANCH" ]]; then
  echo "failed to resolve default branch for ${OWNER}/${REPO}"
  exit 1
fi
HEAD_SHA=$(api GET "$API/git/ref/heads/${DEFAULT_BRANCH}" | python -c 'import json,sys; print(json.load(sys.stdin).get("object",{}).get("sha",""))')
if [[ -z "$HEAD_SHA" ]]; then
  echo "failed to resolve HEAD SHA for ${DEFAULT_BRANCH}"
  exit 1
fi

TAG_STATUS=$(api_code GET "$API/git/ref/tags/${TAG}")
if [[ "$TAG_STATUS" == "404" ]]; then
  api POST "$API/git/refs" \
    -d "$(printf '{"ref":"refs/tags/%s","sha":"%s"}' "$TAG" "$HEAD_SHA")" >/dev/null
fi

# Dispatch workflow on tag.
DISPATCH_TIME="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
DISPATCH_RESP=$(api_with_code POST "$API/actions/workflows/${WORKFLOW_FILE}/dispatches" \
  -d "$(printf '{"ref":"%s"}' "$TAG")")
DISPATCH_CODE=$(printf '%s' "$DISPATCH_RESP" | head -n1)
DISPATCH_BODY=$(printf '%s' "$DISPATCH_RESP" | tail -n +2)
if [[ "$DISPATCH_CODE" != "204" ]]; then
  echo "failed to dispatch workflow (${DISPATCH_CODE})"
  if [[ -n "$DISPATCH_BODY" ]]; then
    echo "$DISPATCH_BODY"
  fi
  exit 1
fi

echo "Workflow dispatched for ${TAG} at ${DISPATCH_TIME}; waiting..."

START=$(date +%s)
RUN_ID=""
RUN_URL=""
LAST_PROGRESS_EPOCH=0
while true; do
  NOW=$(date +%s)
  if (( NOW - START > TIMEOUT )); then
    echo "timeout waiting for workflow completion"
    exit 1
  fi

  RUN_JSON=$(api GET "$API/actions/workflows/${WORKFLOW_FILE}/runs?event=workflow_dispatch&per_page=20")
  RUN_FIELDS=$(printf '%s' "$RUN_JSON" | python -c '
import json,sys
d=json.load(sys.stdin)
tag=sys.argv[1]
since=sys.argv[2]
best=None
for r in d.get("workflow_runs",[]):
    if r.get("head_branch") != tag:
        continue
    created=r.get("created_at","")
    if created and created < since:
        continue
    rid=str(r.get("id","") or "")
    status=str(r.get("status","") or "")
    conclusion=str(r.get("conclusion","") or "")
    html=str(r.get("html_url","") or "")
    best=(rid,status,conclusion,html)
    break
if best:
    print("\t".join(best))
' "$TAG" "$DISPATCH_TIME")

  if [[ -z "$RUN_FIELDS" ]]; then
    if (( NOW - START > RUN_APPEAR_TIMEOUT )); then
      echo "workflow run for tag ${TAG} did not appear within ${RUN_APPEAR_TIMEOUT}s"
      echo "check Actions page: https://github.com/${OWNER}/${REPO}/actions/workflows/${WORKFLOW_FILE}"
      exit 1
    fi
    if (( NOW - LAST_PROGRESS_EPOCH >= 30 )); then
      echo "waiting for workflow run to appear... elapsed=$((NOW - START))s"
      LAST_PROGRESS_EPOCH=$NOW
    fi
    sleep "$POLL_INTERVAL"
    continue
  fi

  IFS=$'\t' read -r RUN_ID STATUS CONCLUSION RUN_URL <<< "$RUN_FIELDS"

  if (( NOW - LAST_PROGRESS_EPOCH >= 30 )); then
    echo "run=${RUN_ID:-n/a} status=${STATUS:-unknown} conclusion=${CONCLUSION:-n/a} elapsed=$((NOW - START))s"
    LAST_PROGRESS_EPOCH=$NOW
  fi

  if [[ -n "$RUN_ID" && "$STATUS" == "completed" ]]; then
    if [[ "$CONCLUSION" != "success" ]]; then
      echo "workflow completed with conclusion=${CONCLUSION}"
      [[ -n "$RUN_URL" ]] && echo "run: $RUN_URL"
      exit 1
    fi
    break
  fi
  sleep "$POLL_INTERVAL"

done

# Fetch release asset URL for APK
REL_CODE=$(api_code GET "$API/releases/tags/${TAG}")
if [[ "$REL_CODE" == "200" ]]; then
  REL_JSON=$(api GET "$API/releases/tags/${TAG}")
  APK_URL=$(printf '%s' "$REL_JSON" | python -c 'import json,sys; d=json.load(sys.stdin); assets=d.get("assets",[]); apk=[a.get("browser_download_url","") for a in assets if str(a.get("name","")) .endswith(".apk")]; print(apk[0] if apk else "")')
  if [[ -n "$APK_URL" ]]; then
    echo "$APK_URL"
    exit 0
  fi
  REL_URL=$(printf '%s' "$REL_JSON" | python -c 'import json,sys; d=json.load(sys.stdin); print(d.get("html_url",""))')
  if [[ -n "$REL_URL" ]]; then
    echo "$REL_URL"
    exit 0
  fi
fi

# Fallback: if release APK asset is not present yet, return artifact download URL.
if [[ -n "$RUN_ID" ]]; then
  ARTIFACTS_JSON=$(api GET "$API/actions/runs/${RUN_ID}/artifacts")
  ARTIFACT_URL=$(printf '%s' "$ARTIFACTS_JSON" | python -c 'import json,sys; d=json.load(sys.stdin); arts=d.get("artifacts",[]); urls=[a.get("archive_download_url","") for a in arts if not a.get("expired",False) and str(a.get("name","")).startswith("loopprofit-apk")]; print(urls[0] if urls else "")')
  if [[ -n "$ARTIFACT_URL" ]]; then
    echo "$ARTIFACT_URL"
    exit 0
  fi
fi

echo "workflow succeeded but no release apk asset/artifact URL could be resolved"
[[ -n "$RUN_URL" ]] && echo "run: $RUN_URL"
exit 1
