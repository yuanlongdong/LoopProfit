#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./scripts/release_apk_link.sh <owner> <repo> <tag>
# Example:
#   ./scripts/release_apk_link.sh yuanlongdong LoopProfit v1.0.0

if [[ $# -ne 3 ]]; then
  echo "Usage: $0 <owner> <repo> <tag>"
  exit 1
fi

OWNER="$1"
REPO="$2"
TAG="$3"

if command -v gh >/dev/null 2>&1; then
  # Try to resolve real uploaded APK asset URL from GitHub Release API.
  if gh api "repos/${OWNER}/${REPO}/releases/tags/${TAG}" >/tmp/release.json 2>/dev/null; then
    apk_url=$(python - <<'PY'
import json
with open('/tmp/release.json','r',encoding='utf-8') as f:
    data=json.load(f)
for a in data.get('assets',[]):
    name=a.get('name','').lower()
    if name.endswith('.apk'):
        print(a.get('browser_download_url',''))
        break
PY
)
    if [[ -n "${apk_url}" ]]; then
      echo "${apk_url}"
      exit 0
    fi
  fi
fi

# Fallback canonical release page URL (user can click and copy direct APK asset link).
echo "https://github.com/${OWNER}/${REPO}/releases/tag/${TAG}"
