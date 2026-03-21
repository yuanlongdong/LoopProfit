#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ANDROID_NDK_ROOT=/path/to/ndk \
#   ANDROID_SDK_ROOT=/path/to/sdk \
#   QT_ANDROID_DIR=/path/to/Qt/6.x/android_arm64_v8a \
#   ./scripts/build_android_apk.sh [debug|release]

BUILD_TYPE="${1:-release}"
if [[ "$BUILD_TYPE" != "debug" && "$BUILD_TYPE" != "release" ]]; then
  echo "build type must be debug or release"
  exit 1
fi

: "${ANDROID_SDK_ROOT:?ANDROID_SDK_ROOT is required}"
: "${ANDROID_NDK_ROOT:?ANDROID_NDK_ROOT is required}"
: "${QT_ANDROID_DIR:?QT_ANDROID_DIR is required}"

if [[ -z "${JAVA_HOME:-}" ]]; then
  JAVA_BIN=$(command -v javac || true)
  if [[ -n "$JAVA_BIN" ]]; then
    JAVA_HOME=$(dirname "$(dirname "$(readlink -f "$JAVA_BIN")")")
    export JAVA_HOME
  fi
fi

BUILD_DIR="build-android"
INSTALL_DIR="${BUILD_DIR}/install"

cmake -S . -B "${BUILD_DIR}" -G Ninja \
  -DQT_HOST_PATH="${QT_ANDROID_DIR}/.." \
  -DCMAKE_TOOLCHAIN_FILE="${QT_ANDROID_DIR}/lib/cmake/Qt6/qt.toolchain.cmake" \
  -DANDROID_ABI=arm64-v8a \
  -DANDROID_PLATFORM=android-24 \
  -DCMAKE_BUILD_TYPE=Release

cmake --build "${BUILD_DIR}" -j
cmake --install "${BUILD_DIR}" --prefix "${INSTALL_DIR}"

if ! command -v androiddeployqt >/dev/null 2>&1; then
  echo "androiddeployqt not found in PATH"
  exit 1
fi

ANDROIDDEPLOYQT_JSON=$(find "${BUILD_DIR}" -name android-*.json | head -n1)
if [[ -z "${ANDROIDDEPLOYQT_JSON}" ]]; then
  echo "androiddeployqt json not found"
  exit 1
fi

args=(
  --input "${ANDROIDDEPLOYQT_JSON}"
  --output "${BUILD_DIR}/android-build"
  --android-platform android-34
  --gradle
)

if [[ "$BUILD_TYPE" == "release" ]]; then
  args+=(--release)
else
  args+=(--debug)
fi

if [[ -n "${JAVA_HOME:-}" ]]; then
  args+=(--jdk "$JAVA_HOME")
fi

androiddeployqt "${args[@]}"

echo "APK output directory: ${BUILD_DIR}/android-build/build/outputs/apk/${BUILD_TYPE}"
