# Contributing

## Branch & PR policy

为降低类似“PR #2 冲突”问题，建议遵循以下流程：

1. 从最新主干创建分支：
   ```bash
   git fetch origin
   git switch main
   git pull --ff-only
   git switch -c feature/<topic>
   ```
2. 提交前先 rebase：
   ```bash
   git fetch origin
   git rebase origin/main
   ```
3. 如果发生冲突，按模块优先级处理：
   - `src/` 业务逻辑为准
   - `qml/` 保留最新交互文案
   - `README.md` 合并说明与命令
4. 冲突解决后必须本地验证：
   ```bash
   cmake -S . -B build
   cmake --build build -j4
   ctest --test-dir build --output-on-failure
   ```

## Coding standards

- 业务逻辑不得阻塞 UI 线程。
- 所有数据库写操作必须在事务语义下可回滚。
- 新增配置项必须同步补充测试。
- 提交信息采用 `type(scope): summary` 或清晰动宾句。

