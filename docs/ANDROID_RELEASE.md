# Android Release APK 构建说明

当前仓库已经补充了一个 **可直接产出安装包的原生 Android 工程**，目录在 `android-app/`。

## 已验证的产物

执行下面命令后，会生成并签名：

```bash
./scripts/build_android_release_apk.sh
```

输出 APK 路径：

```text
android-app/app/build/outputs/apk/release/app-release.apk
```

## 环境要求

- JDK 17+
- Gradle 8.14.3+
- Android SDK
  - `platforms;android-35`
  - `build-tools;35.0.0`
  - `platform-tools`

默认会读取：

- `ANDROID_SDK_ROOT`，未设置时回退到 `/opt/android-sdk`
- `LOOPPROFIT_KEYSTORE_PATH`
- `LOOPPROFIT_KEYSTORE_PASSWORD`
- `LOOPPROFIT_KEY_ALIAS`
- `LOOPPROFIT_KEY_PASSWORD`

如果 keystore 不存在，脚本会自动生成一个 release keystore，再执行 `assembleRelease` 和 `apksigner verify`。

## App 内容

- 提供一个可安装的 release APK
- 在 Android 原生页面中复刻仓库 `LoopEngine` 的核心循环收益规则
- 支持输入钱包余额、投入金额、AI 数量、轮次、尝试次数、目标倍数、止损和扩 AI 步长
- 直接在手机端显示累计收益、最终余额和每轮结果

## 手动构建

```bash
cd android-app
export ANDROID_SDK_ROOT=/opt/android-sdk
export ANDROID_HOME=/opt/android-sdk
gradle :app:assembleRelease
```

## 签名校验

```bash
/opt/android-sdk/build-tools/35.0.0/apksigner verify --print-certs \
  android-app/app/build/outputs/apk/release/app-release.apk
```
