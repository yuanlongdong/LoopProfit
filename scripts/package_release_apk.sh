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
#   LOOPPROFIT_REMOTE_ONLY=1   # Skip local build; trigger GitHub workflow and return URL
#   LOOPPROFIT_REMOTE_FALLBACK=1 # If local build fails, fallback to remote workflow (default: 1)

if [[ $# -lt 3 || $# -gt 4 ]]; then
  echo "Usage: GITHUB_TOKEN=... $0 <owner> <repo> <tag> [install_dir]"
  exit 1
fi

OWNER="$1"
REPO="$2"
TAG="$3"
INSTALL_DIR="${4:-$HOME/.loopprofit-android}"
REMOTE_ONLY="${LOOPPROFIT_REMOTE_ONLY:-0}"
REMOTE_FALLBACK="${LOOPPROFIT_REMOTE_FALLBACK:-1}"

# Accept either GITHUB_TOKEN or GH_TOKEN.
if [[ -z "${GITHUB_TOKEN:-}" && -n "${GH_TOKEN:-}" ]]; then
  export GITHUB_TOKEN="$GH_TOKEN"
fi
: "${GITHUB_TOKEN:?GITHUB_TOKEN is required (or set GH_TOKEN)}"

if [[ "$REMOTE_ONLY" == "1" ]]; then
  ./scripts/trigger_android_release.sh "$OWNER" "$REPO" "$TAG"
  exit 0
fi

set +e
./scripts/bootstrap_android_env.sh "$INSTALL_DIR"
BOOTSTRAP_RC=$?
set -e
if [[ $BOOTSTRAP_RC -ne 0 ]]; then
  if [[ "$REMOTE_FALLBACK" == "1" ]]; then
    echo "local Android/Qt bootstrap failed; fallback to remote workflow dispatch..."
    ./scripts/trigger_android_release.sh "$OWNER" "$REPO" "$TAG"
    exit 0
  fi
  exit $BOOTSTRAP_RC
fi

# shellcheck disable=SC1090
source <(./scripts/bootstrap_android_env.sh "$INSTALL_DIR")

export ANDROID_SDK_ROOT
export ANDROID_NDK_ROOT
export QT_ANDROID_DIR
export QT_HOST_PATH

set +e
./scripts/build_android_apk.sh release
BUILD_RC=$?
set -e
if [[ $BUILD_RC -ne 0 ]]; then
  if [[ "$REMOTE_FALLBACK" == "1" ]]; then
    echo "local APK build failed; fallback to remote workflow dispatch..."
    ./scripts/trigger_android_release.sh "$OWNER" "$REPO" "$TAG"
    exit 0
  fi
  exit $BUILD_RC
fi

FINAL_APK="${APK_PATH:-}"
if [[ -z "$FINAL_APK" ]]; then
  FINAL_APK=$(find build-android/android-build/build/outputs/apk/release -name '*.apk' | head -n1 || true)
fi

if [[ -z "$FINAL_APK" || ! -f "$FINAL_APK" ]]; then
  echo "release APK not found; expected under build-android/android-build/build/outputs/apk/release"
  exit 1
fi

./scripts/publish_release_apk.sh "$OWNER" "$REPO" "$TAG" "$FINAL_APK"
