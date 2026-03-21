#!/usr/bin/env bash
set -euo pipefail

# One-command helper for local release packaging + GitHub Release upload.
#
# Usage:
#   GITHUB_TOKEN=... ./scripts/package_release_apk.sh <owner> <repo> <tag> [install_dir]
#
# Optional env:
#   QT_MIRROR=...              # Qt mirror for bootstrap script
#   APK_PATH=/path/to/app.apk  # Skip auto-detect and publish this APK path

if [[ $# -lt 3 || $# -gt 4 ]]; then
  echo "Usage: GITHUB_TOKEN=... $0 <owner> <repo> <tag> [install_dir]"
  exit 1
fi

OWNER="$1"
REPO="$2"
TAG="$3"
INSTALL_DIR="${4:-$HOME/.loopprofit-android}"

: "${GITHUB_TOKEN:?GITHUB_TOKEN is required}"

./scripts/bootstrap_android_env.sh "$INSTALL_DIR"

# shellcheck disable=SC1090
source <(./scripts/bootstrap_android_env.sh "$INSTALL_DIR")

export ANDROID_SDK_ROOT
export ANDROID_NDK_ROOT
export QT_ANDROID_DIR
export QT_HOST_PATH

./scripts/build_android_apk.sh release

FINAL_APK="${APK_PATH:-}"
if [[ -z "$FINAL_APK" ]]; then
  FINAL_APK=$(find build-android/android-build/build/outputs/apk/release -name '*.apk' | head -n1 || true)
fi

if [[ -z "$FINAL_APK" || ! -f "$FINAL_APK" ]]; then
  echo "release APK not found; expected under build-android/android-build/build/outputs/apk/release"
  exit 1
fi

./scripts/publish_release_apk.sh "$OWNER" "$REPO" "$TAG" "$FINAL_APK"
