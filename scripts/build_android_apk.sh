#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ANDROID_NDK_ROOT=/path/to/ndk \
#   ANDROID_SDK_ROOT=/path/to/sdk \
#   QT_ANDROID_DIR=/path/to/Qt/6.x/android_arm64_v8a \
#   ./scripts/build_android_apk.sh

: "${ANDROID_SDK_ROOT:?ANDROID_SDK_ROOT is required}"
: "${ANDROID_NDK_ROOT:?ANDROID_NDK_ROOT is required}"
: "${QT_ANDROID_DIR:?QT_ANDROID_DIR is required}"

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

androiddeployqt \
  --input "${ANDROIDDEPLOYQT_JSON}" \
  --output "${BUILD_DIR}/android-build" \
  --android-platform android-34 \
  --jdk "$JAVA_HOME" \
  --gradle \
  --release

echo "APK output directory: ${BUILD_DIR}/android-build/build/outputs/apk/release"
