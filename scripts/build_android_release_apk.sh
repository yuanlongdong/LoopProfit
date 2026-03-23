#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$ROOT_DIR/android-app"
SDK_ROOT="${ANDROID_SDK_ROOT:-/opt/android-sdk}"
KEYSTORE_PATH="${LOOPPROFIT_KEYSTORE_PATH:-$APP_DIR/release-keystore.jks}"
KEYSTORE_PASSWORD="${LOOPPROFIT_KEYSTORE_PASSWORD:-loopprofit123}"
KEY_ALIAS="${LOOPPROFIT_KEY_ALIAS:-loopprofit}"
KEY_PASSWORD="${LOOPPROFIT_KEY_PASSWORD:-$KEYSTORE_PASSWORD}"

if [[ ! -d "$SDK_ROOT" ]]; then
  echo "[ERROR] Android SDK not found at: $SDK_ROOT" >&2
  exit 1
fi

if [[ ! -f "$KEYSTORE_PATH" ]]; then
  keytool -genkeypair -v \
    -storetype PKCS12 \
    -keystore "$KEYSTORE_PATH" \
    -storepass "$KEYSTORE_PASSWORD" \
    -keypass "$KEY_PASSWORD" \
    -alias "$KEY_ALIAS" \
    -keyalg RSA \
    -keysize 2048 \
    -validity 3650 \
    -dname "CN=LoopProfit, OU=OpenAI, O=OpenAI, L=San Francisco, ST=CA, C=US"
fi

export ANDROID_SDK_ROOT="$SDK_ROOT"
export ANDROID_HOME="$SDK_ROOT"
export LOOPPROFIT_KEYSTORE_PASSWORD="$KEYSTORE_PASSWORD"
export LOOPPROFIT_KEY_ALIAS="$KEY_ALIAS"
export LOOPPROFIT_KEY_PASSWORD="$KEY_PASSWORD"

cd "$APP_DIR"
gradle :app:assembleRelease

APK_PATH="$APP_DIR/app/build/outputs/apk/release/app-release.apk"
"$SDK_ROOT/build-tools/35.0.0/apksigner" verify --print-certs "$APK_PATH"

echo "[OK] Release APK: $APK_PATH"
