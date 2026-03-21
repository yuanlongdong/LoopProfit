#!/usr/bin/env bash
set -euo pipefail

# Bootstraps Android + Qt Android toolchains for local APK builds.
# Usage:
#   ./scripts/bootstrap_android_env.sh [install_dir]

INSTALL_DIR="${1:-$HOME/.loopprofit-android}"
SDK_DIR="$INSTALL_DIR/android-sdk"
QT_DIR="$INSTALL_DIR/qt"

mkdir -p "$INSTALL_DIR" "$SDK_DIR" "$QT_DIR"

if [[ ! -x "$SDK_DIR/cmdline-tools/latest/bin/sdkmanager" ]]; then
  echo "Installing Android commandline-tools..."
  TMP_ZIP="$INSTALL_DIR/cmdline-tools.zip"
  curl -L "https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip" -o "$TMP_ZIP"
  mkdir -p "$SDK_DIR/cmdline-tools"
  unzip -q -o "$TMP_ZIP" -d "$SDK_DIR/cmdline-tools"
  rm -rf "$SDK_DIR/cmdline-tools/latest"
  mv "$SDK_DIR/cmdline-tools/cmdline-tools" "$SDK_DIR/cmdline-tools/latest"
fi

export ANDROID_SDK_ROOT="$SDK_DIR"
export PATH="$ANDROID_SDK_ROOT/cmdline-tools/latest/bin:$ANDROID_SDK_ROOT/platform-tools:$PATH"

# sdkmanager closes stdin when done; with pipefail this can return 141 from `yes`.
# Accept that condition and continue.
set +o pipefail
yes | sdkmanager --licenses >/dev/null || true
set -o pipefail
sdkmanager "platform-tools" "platforms;android-34" "build-tools;34.0.0" "ndk;26.1.10909125"

if ! python -c "import aqt" >/dev/null 2>&1; then
  pip install aqtinstall
fi

QT_MIRROR="${QT_MIRROR:-}"

if [[ ! -d "$QT_DIR/6.7.2/android_arm64_v8a" ]]; then
  qt_args=(install-qt linux android 6.7.2 android_arm64_v8a --outputdir "$QT_DIR")
  if [[ -n "$QT_MIRROR" ]]; then
    qt_args+=(--base "$QT_MIRROR")
  fi
  python -m aqt "${qt_args[@]}"
fi

# Android Qt SDK usually requires matching desktop Qt host tools.
if [[ ! -d "$QT_DIR/6.7.2/gcc_64" ]]; then
  host_args=(install-qt linux desktop 6.7.2 gcc_64 --outputdir "$QT_DIR")
  if [[ -n "$QT_MIRROR" ]]; then
    host_args+=(--base "$QT_MIRROR")
  fi
  python -m aqt "${host_args[@]}"
fi

cat <<ENV
export ANDROID_SDK_ROOT="$SDK_DIR"
export ANDROID_NDK_ROOT="$SDK_DIR/ndk/26.1.10909125"
export QT_ANDROID_DIR="$QT_DIR/6.7.2/android_arm64_v8a"
export QT_HOST_PATH="$QT_DIR/6.7.2/gcc_64"
# Optional:
# export JAVA_HOME="$(dirname "$(dirname "$(readlink -f "$(command -v javac)")")")"
ENV
