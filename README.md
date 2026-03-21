# LoopProfit (Qt/QML + SQLite)

LoopProfit 是一个面向移动端的 Qt6 + QML 项目，提供可审计的 AI 循环投资模拟系统。

## 工程标准（国际化实践）

- **分层架构**：UI（QML）/ 应用层（AppController）/ 领域层（LoopEngine）/ 数据层（DatabaseManager）。
- **事务一致性**：循环执行过程中的投资、轮次、日志、通知、资产更新在事务中完成，失败即回滚。
- **可观测性**：日志与通知均入库，可追溯每轮执行。
- **非阻塞 UI**：循环执行由 `QtConcurrent` 异步运行，避免阻塞主线程。
- **自动化测试**：QtTest + CTest，包含输入校验、交易记录、资产更新、审计统计等场景。
- **可复现环境**：提供 Ubuntu 依赖安装脚本和标准构建命令。

## Ubuntu 依赖安装

```bash
./scripts/setup_ubuntu_qt6.sh
```

或手动执行：

```bash
sudo apt-get update
sudo apt-get install -y cmake build-essential ninja-build qt6-base-dev qt6-base-dev-tools qt6-declarative-dev
```


## 合并冲突快速检查

在继续开发前可先执行：

```bash
./scripts/check_merge_conflicts.sh
```

该脚本会执行三类检查：
- `git ls-files -u`（检测是否存在未合并索引条目）
- 核心文件中的 `<<<<<<<` / `=======` / `>>>>>>>` 冲突标记
- `git diff --check` 空白/冲突样式问题

## 构建与测试

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

> 收益逻辑 `LoopEngine::executeBlackBoxProfit` 为可插拔黑箱函数，后续可替换为真实 AI 执行器。


## 利益冲突 #2 处理

系统新增 `conflict_disclosures` 审计表，并提供 UI 入口用于登记/解决冲突事件（如共享 AI 池收益归属冲突）。
当 `ISSUE_2` 存在未解决记录时，LoopEngine 会拒绝执行循环，必须先解决冲突后才能继续。
登记后可追溯用户、冲突类型、详情、状态与时间戳。

