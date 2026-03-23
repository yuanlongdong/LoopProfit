#!/usr/bin/env bash
set -euo pipefail

err() { echo "[ERROR] $*" >&2; }
ok() { echo "[OK] $*"; }

check_cmd() {
  local cmd="$1"
  if command -v "$cmd" >/dev/null 2>&1; then
    ok "命令可用: $cmd"
  else
    err "缺少命令: $cmd"
    return 1
  fi
}

check_var_dir() {
  local name="$1"
  local value="${!name:-}"
  if [[ -z "$value" ]]; then
    err "未设置环境变量: $name"
    return 1
  fi
  if [[ ! -d "$value" ]]; then
    err "$name 目录不存在: $value"
    return 1
  fi
  ok "$name=$value"
}

check_var_file() {
  local name="$1"
  local value="${!name:-}"
  if [[ -z "$value" ]]; then
    err "未设置环境变量: $name"
    return 1
  fi
  if [[ ! -f "$value" ]]; then
    err "$name 文件不存在: $value"
    return 1
  fi
  ok "$name=$value"
}

resolve_apksigner() {
  if command -v apksigner >/dev/null 2>&1; then
    echo "$(command -v apksigner)"
    return 0
  fi

  local sdk_root="${ANDROID_SDK_ROOT:-}"
  if [[ -z "$sdk_root" || ! -d "$sdk_root/build-tools" ]]; then
    return 1
  fi

  local candidate
  candidate="$(find "$sdk_root/build-tools" -type f -name apksigner | sort -V | tail -n 1 || true)"
  if [[ -n "$candidate" ]]; then
    echo "$candidate"
    return 0
  fi

  return 1
}

main() {
  local failed=0

  check_cmd cmake || failed=1
  check_cmd ninja || failed=1
  check_cmd java || failed=1
  check_cmd jarsigner || failed=1

  check_var_dir ANDROID_SDK_ROOT || failed=1
  check_var_dir ANDROID_NDK_ROOT || failed=1
  check_var_dir QT_ANDROID_CMAKE_PREFIX || failed=1
  check_var_dir QT_HOST_PATH || failed=1
  check_var_file QT_ANDROID_TOOLCHAIN_FILE || failed=1

  local apksigner_bin=""
  if apksigner_bin="$(resolve_apksigner)"; then
    ok "apksigner=$apksigner_bin"
  else
    err "缺少 apksigner（可放入 PATH，或安装到 \$ANDROID_SDK_ROOT/build-tools/*/apksigner）"
    failed=1
  fi

  if [[ $failed -ne 0 ]]; then
    err "Android Release APK 环境检查失败，请按 docs/ANDROID_RELEASE.md 进行修复。"
    exit 1
  fi

  ok "Android Release APK 环境检查通过。"
}

main "$@"
