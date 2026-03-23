#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${BUILD_DIR:-$ROOT_DIR/build-android-release}"
ANDROID_ABI="${ANDROID_ABI:-arm64-v8a}"

KEYSTORE_PATH="${KEYSTORE_PATH:-}"
KEY_ALIAS="${KEY_ALIAS:-}"
KEYSTORE_PASS="${KEYSTORE_PASS:-}"
KEY_PASS="${KEY_PASS:-$KEYSTORE_PASS}"

resolve_sdk_tool() {
  local tool="$1"
  if command -v "$tool" >/dev/null 2>&1; then
    command -v "$tool"
    return 0
  fi

  local sdk_root="${ANDROID_SDK_ROOT:-}"
  if [[ -z "$sdk_root" || ! -d "$sdk_root/build-tools" ]]; then
    return 1
  fi

  local candidate
  candidate="$(find "$sdk_root/build-tools" -type f -name "$tool" | sort -V | tail -n 1 || true)"
  [[ -n "$candidate" ]] || return 1
  echo "$candidate"
}

select_apk_target() {
  local targets_file="$1"
  local target

  for target in apk LoopProfitApp_make_apk; do
    if grep -q "^${target}:" "$targets_file"; then
      echo "$target"
      return 0
    fi
  done

  target="$(grep '_make_apk:' "$targets_file" | head -n 1 | cut -d: -f1 || true)"
  [[ -n "$target" ]] || return 1
  echo "$target"
}

if [[ -z "$KEYSTORE_PATH" || -z "$KEY_ALIAS" || -z "$KEYSTORE_PASS" ]]; then
  echo "[ERROR] 必须设置 KEYSTORE_PATH / KEY_ALIAS / KEYSTORE_PASS 环境变量。" >&2
  exit 1
fi
if [[ ! -f "$KEYSTORE_PATH" ]]; then
  echo "[ERROR] KEYSTORE_PATH 文件不存在: $KEYSTORE_PATH" >&2
  exit 1
fi

"$ROOT_DIR/scripts/check_android_env.sh"

cmake -S "$ROOT_DIR" -B "$BUILD_DIR" -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DQT_HOST_PATH="$QT_HOST_PATH" \
  -DCMAKE_TOOLCHAIN_FILE="$QT_ANDROID_TOOLCHAIN_FILE" \
  -DQT_NO_GLOBAL_APK_TARGET_PART_OF_ALL=ON \
  -DANDROID_ABI="$ANDROID_ABI" \
  -DCMAKE_PREFIX_PATH="$QT_ANDROID_CMAKE_PREFIX"

TARGETS_FILE="$BUILD_DIR/.ninja_targets.txt"
ninja -C "$BUILD_DIR" -t targets all > "$TARGETS_FILE"
APK_TARGET="$(select_apk_target "$TARGETS_FILE")"
if [[ -z "$APK_TARGET" ]]; then
  echo "[ERROR] 未找到 APK 构建 target（例如 apk / *_make_apk）。" >&2
  exit 1
fi

cmake --build "$BUILD_DIR" --target "$APK_TARGET"

APK_UNSIGNED="$(find "$BUILD_DIR" -type f -name '*unsigned.apk' | head -n 1)"
if [[ -z "$APK_UNSIGNED" ]]; then
  echo "[ERROR] 未找到 unsigned.apk，请检查上面的构建日志。" >&2
  exit 1
fi

ZIPALIGN_BIN="$(resolve_sdk_tool zipalign)"
APKSIGNER_BIN="$(resolve_sdk_tool apksigner)"
APK_ALIGNED="${APK_UNSIGNED/unsigned.apk/aligned.apk}"
APK_SIGNED="${APK_UNSIGNED/unsigned.apk/release-signed.apk}"

"$ZIPALIGN_BIN" -f -p 4 "$APK_UNSIGNED" "$APK_ALIGNED"

"$APKSIGNER_BIN" sign \
  --ks "$KEYSTORE_PATH" \
  --ks-key-alias "$KEY_ALIAS" \
  --ks-pass "pass:$KEYSTORE_PASS" \
  --key-pass "pass:$KEY_PASS" \
  --out "$APK_SIGNED" \
  "$APK_ALIGNED"

"$APKSIGNER_BIN" verify "$APK_SIGNED"

echo "[OK] Release APK 已生成: $APK_SIGNED"
