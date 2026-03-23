# LoopProfit (Qt/QML + SQLite)

基于“AI翻倍循环助手”规则搭建的 Qt6 移动端项目骨架，当前已实现：

- 多用户账户与配置（`users` / `config`）
- 投 token 审计（`token_invest`，唯一交易 ID）
- 循环轮次收益与达标判断（`rounds`）
- 自动扩 AI、自动复投、止损停止
- 事务化数据库更新（失败回滚）
- 日志与通知落库（`logs` / `notifications`）
- Qt Quick 移动端基础界面
- 单元测试（QtTest）

## Ubuntu 依赖安装

如果提示找不到 `Qt6Config.cmake`，先安装依赖：

```bash
./scripts/setup_ubuntu_qt6.sh
```

或手动执行：

```bash
sudo apt-get update
sudo apt-get install -y cmake build-essential ninja-build qt6-base-dev qt6-base-dev-tools qt6-declarative-dev
```

## 构建

```bash
cmake -S . -B build
cmake --build build
ctest --test-dir build --output-on-failure
```

## 运行

```bash
./build/LoopProfitApp
```

## 数据库表

- `users`
- `config`
- `token_invest`
- `rounds`
- `logs`
- `notifications`

> 注意：当前收益逻辑为可替换黑箱模拟函数（`LoopEngine::executeBlackBoxProfit`），后续可接入真实 AI 任务执行器。


## Android Release APK

仓库现在已经包含可直接构建的原生 Android 工程：`android-app/`，并且只保留纯文本源码文件，避免 PR 因二进制 wrapper 文件被拦截。

快速执行：

```bash
./scripts/build_android_release_apk.sh
```

生成结果：

```text
android-app/app/build/outputs/apk/release/app-release.apk
```

更多细节见：

- `docs/ANDROID_RELEASE.md`
