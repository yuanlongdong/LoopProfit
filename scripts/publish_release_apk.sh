#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   GITHUB_TOKEN=xxx ./scripts/publish_release_apk.sh <owner> <repo> <tag> <apk_path>
# Example:
#   ./scripts/publish_release_apk.sh yuanlongdong LoopProfit v1.0.0 dist/app-release.apk

if [[ $# -ne 4 ]]; then
  echo "Usage: $0 <owner> <repo> <tag> <apk_path>"
  exit 1
fi

OWNER="$1"
REPO="$2"
TAG="$3"
APK_PATH="$4"

if [[ ! -f "$APK_PATH" ]]; then
  echo "APK not found: $APK_PATH"
  exit 1
fi

if ! command -v gh >/dev/null 2>&1; then
  echo "gh CLI is required"
  exit 1
fi

if ! gh release view "$TAG" --repo "${OWNER}/${REPO}" >/dev/null 2>&1; then
  gh release create "$TAG" "$APK_PATH" \
    --repo "${OWNER}/${REPO}" \
    --title "$TAG" \
    --notes "Automated APK release for $TAG"
else
  gh release upload "$TAG" "$APK_PATH" --repo "${OWNER}/${REPO}" --clobber
fi

release_json=$(gh api "repos/${OWNER}/${REPO}/releases/tags/${TAG}")
apk_url=$(python - <<'PY'
import json,sys
obj=json.loads(sys.stdin.read())
for a in obj.get('assets',[]):
    name=a.get('name','').lower()
    if name.endswith('.apk'):
        print(a.get('browser_download_url',''))
        break
PY
<<< "$release_json")

if [[ -z "$apk_url" ]]; then
  echo "Release created but APK URL not found"
  exit 1
fi

echo "$apk_url"
