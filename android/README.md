# Android APK 发布说明

当前仓库已提供 Android 构建脚本与 CI 工作流（含 tag 发布 Release 资产）：

- 本地脚本：`scripts/build_android_apk.sh [debug|release]`
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


可先使用 `debug` 产物验证安装，再切到 `release` 产物发布。

## 启动图标（封面）

已在 `android/package/res/` 提供矢量化启动图标资源（`ic_launcher` / `ic_launcher_round`），并在 `CMakeLists.txt` 中通过 `QT_ANDROID_PACKAGE_SOURCE_DIR` 接入 Android 打包流程。

如需替换图标，可修改以下文件：

- `android/package/res/drawable/ic_launcher_background.xml`
- `android/package/res/drawable/ic_launcher_foreground.xml`

> 该方案使用 XML 矢量资源，便于在 CI 中无设计工具环境时快速迭代。
