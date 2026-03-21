# Android APK 发布说明

当前仓库已提供 Android 构建脚本与 CI 工作流（含 tag 发布 Release 资产）：

- 本地脚本：`scripts/build_android_apk.sh`
- CI 工作流：`.github/workflows/android-apk.yml`

## 仍需你配置的内容

1. Qt Android 套件路径（`QT_ANDROID_DIR`）
2. Android SDK / NDK 路径（`ANDROID_SDK_ROOT`, `ANDROID_NDK_ROOT`）
3. 签名配置（keystore + gradle signing）

## 产物路径

构建成功后，APK 典型路径：

`build-android/android-build/build/outputs/apk/release/`

## 直链发布建议

1. 在 GitHub Release 中上传 APK
2. 使用 Release asset URL 作为 HTTP 直链


触发方式：手动 `workflow_dispatch` 或推送 `v*` tag。
