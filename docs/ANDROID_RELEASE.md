# Android Release APK 故障排查与构建指南

> 适用于本项目 Qt6 + CMake 构建。

## 为什么你目前会“无法生成 release apk”

结合本仓库现状，主要有 4 类高频原因：

1. **项目没有 Android 构建入口脚本**，环境变量容易漏配。
2. **Qt6 Android 工具链路径缺失**（`Qt6Config.cmake`、toolchain file 找不到）。
3. **构建目标名不一致**（Qt 版本不同，APK target 可能叫 `apk` 或 `*_make_apk`）。
4. **签名参数缺失或错误**（release 必须签名）。

## 一次性环境准备

至少要准备以下变量：

- `ANDROID_SDK_ROOT`
- `ANDROID_NDK_ROOT`
- `QT_HOST_PATH`
- `QT_ANDROID_CMAKE_PREFIX`
- `QT_ANDROID_TOOLCHAIN_FILE`

示例（请改成你本机路径）：

```bash
export ANDROID_SDK_ROOT=$HOME/Android/Sdk
export ANDROID_NDK_ROOT=$ANDROID_SDK_ROOT/ndk/26.3.11579264
export QT_HOST_PATH=$HOME/Qt/6.7.3/gcc_64
export QT_ANDROID_CMAKE_PREFIX=$HOME/Qt/6.7.3/android_arm64_v8a
export QT_ANDROID_TOOLCHAIN_FILE=$QT_ANDROID_CMAKE_PREFIX/lib/cmake/Qt6/qt.toolchain.cmake
```

## 快速自检

```bash
./scripts/check_android_env.sh
```

## 生成 Release APK

先准备签名信息：

```bash
export KEYSTORE_PATH=/abs/path/release.jks
export KEY_ALIAS=loopprofit
export KEYSTORE_PASS='******'
# 可选，默认跟 KEYSTORE_PASS 相同
export KEY_PASS='******'
```

然后执行：

```bash
./scripts/build_android_release_apk.sh
```

成功后会自动 `zipalign + apksigner`，并输出 `release-signed.apk` 路径。

## 常见报错定位

### 报错：`Could not find Qt6Config.cmake`

- 说明 `QT_ANDROID_CMAKE_PREFIX` 或 `QT_ANDROID_TOOLCHAIN_FILE` 配错，
- 或者你安装的是桌面 Qt，不是 Android 套件。

### 报错：`未找到 APK 构建 target`

- 脚本会自动识别 `apk` 或 `*_make_apk`。
- 若仍失败，通常是 Qt Android 套件不完整或 CMake 未走 Android toolchain。

### 报错：签名失败

- 检查 alias、keystore 密码、key 密码是否一致。
- 使用 `keytool -list -keystore <jks>` 校验 alias。

## 建议升级项

- Qt Android 套件统一到同一小版本（如 6.7.x）。
- Android Build Tools / Platform-Tools / NDK 使用同一套 CI 可复现版本。
- 把上述脚本纳入 CI（至少跑 `check_android_env.sh`）。
