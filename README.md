# LoopProfit (Qt/QML + SQLite)

LoopProfit 是一个面向移动端的 Qt6 + QML 项目，提供可审计的 AI 循环投资模拟系统。

## 工程标准（国际化实践）

- **分层架构**：UI（QML）/ 应用层（AppController）/ 领域层（LoopEngine）/ 数据层（DatabaseManager）。
- **事务一致性**：循环执行过程中的投资、轮次、日志、通知、资产更新在事务中完成，失败即回滚。
- **可观测性**：日志与通知均入库，可追溯每轮执行。
- **非阻塞 UI**：循环执行由 `QtConcurrent` 异步运行，避免阻塞主线程。
- **自动化测试**：QtTest + CTest，包含输入校验、交易记录、资产更新、审计统计等场景。
- **报表导出**：支持按用户导出轮次 CSV 报表，便于后续可视化分析。
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


可在 UI 中点击“导出轮次报表CSV”，默认导出到 `./round_report_user1.csv`。


## 10项规则达成情况（当前版本）

- ✅ 用户、投token、循环、收益审计、止损/复投、SQLite事务、日志通知：已实现基础闭环。  
- ✅ 报表统计：已支持成功率/失败率与轮次 CSV 导出。  
- ✅ 可视化图表：已提供收益柱状图（按轮次）基础展示。  
- ✅ 单元测试覆盖率门禁：新增 `scripts/run_coverage.sh` 与 `coverage.yml`（`--fail-under-line 80`）。  
- ⚠️ APK 一键发布直链：已支持 tag 自动上传 APK 到 Release（可生成直链），签名流程可按生产要求再加固。  



## 获取发行版 APK 直链

发布 `v*` tag 后，可用脚本获取 APK 直链：

```bash
./scripts/release_apk_link.sh <owner> <repo> <tag>
# 例：./scripts/release_apk_link.sh yuanlongdong LoopProfit v1.0.0
```

若 Release 已有 APK 资产，脚本会输出 `browser_download_url`；否则回退到 Release 页面 URL。


若你已有本地 APK，可一键发布并返回直链：

```bash
./scripts/publish_release_apk.sh <owner> <repo> <tag> <apk_path>
```


一条命令本地打包并发布（会输出 APK HTTP 直链）：

```bash
GITHUB_TOKEN=... ./scripts/package_release_apk.sh <owner> <repo> <tag> [install_dir]
```

说明：该命令会依次执行环境引导、release 打包、上传 Release 资产。
如本机 Android/Qt 环境受限导致失败，默认会自动回退到 GitHub 远程构建并返回链接。
也可强制只走远程构建：

```bash
LOOPPROFIT_REMOTE_ONLY=1 GITHUB_TOKEN=... ./scripts/package_release_apk.sh <owner> <repo> <tag>
# 或使用 GH_TOKEN（等效）：
LOOPPROFIT_REMOTE_ONLY=1 GH_TOKEN=... ./scripts/package_release_apk.sh <owner> <repo> <tag>
```


若你希望在 GitHub 端自动构建并直接拿到 release APK 链接，可用：

```bash
GITHUB_TOKEN=... ./scripts/trigger_android_release.sh <owner> <repo> <tag>
```

该脚本会：自动补 tag（若不存在）→ 触发 `android-apk.yml` → 等待成功 → 输出 APK 下载链接。

如果你已经手动跑过工作流，只想“直接取链接”而不重复触发，可用：

```bash
GITHUB_TOKEN=... ./scripts/fetch_apk_url.sh <owner> <repo> <tag>
```

脚本会优先返回 Release 的 APK 直链；若暂未挂载 Release 资产，会回退到成功 run 的 artifact 下载 URL。


若本机无 Android/Qt 环境，可先执行：

```bash
./scripts/bootstrap_android_env.sh
# 若官方 Qt 源不可达，可指定镜像：
QT_MIRROR=https://mirrors.tuna.tsinghua.edu.cn/qt ./scripts/bootstrap_android_env.sh
```
