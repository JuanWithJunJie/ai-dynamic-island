# Auto-Refresh Crash Regression Fix Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在不回退自动刷新 crash 修复主线的前提下，修复 `TaskStateStore` 当前留下的 island attention 回归，让全量测试重新回到绿色，并确保 `waitingInput` 会话不会因为 session 去重或优先级收敛而被意外吞掉。

**Architecture:** 当前 `1s` 自动刷新崩溃的主根因已经被收敛在 duplicate `TaskSession.id` 路径上，修复方向基本正确；但修复后留下了一条行为回归。`TaskStateStoreTests.testIslandAttentionSessionsFiltersNonAttentionSessions` 现在失败，说明在 `SessionResolver` 去重、`TaskStateStore.mergeHistory(...)` 防御式合并、或相关优先级收敛逻辑里，有一步让本应保留的 `waitingInput` 会话不再进入 `islandAttentionSessions`。下一步应该优先恢复语义正确性，而不是继续扩产品功能。

**Tech Stack:** Swift, SwiftUI, AppKit, `TaskStateStore`, `SessionResolver`, `BuiltInCLIAdapter`, XCTest

---

## Verified Current State

已确认：

- `swift build --package-path "/Users/lijunjie/Documents/AIproject/macirland"` 通过
- `swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland"` 未通过
- 失败测试：

```text
TaskStateStoreTests.testIslandAttentionSessionsFiltersNonAttentionSessions
XCTAssertEqual failed: ("0") is not equal to ("1")
XCTAssertEqual failed: ("nil") is not equal to ("Optional(MacIrlandKit.TaskStatus.waitingInput)")
```

这说明：

1. 崩溃修复报告不能算完全闭环
2. 当前 attention session 语义已发生回归
3. 还不适合继续向下推进新功能

---

## File Structure

### Modify
- `MacIrlandKit/Services/SessionRecognition/SessionResolver.swift`
- `MacIrlandKit/Core/State/TaskStateStore.swift`
- `MacIrlandKit/Adapters/BuiltIn/BuiltInCLIAdapter.swift`
- `MacIrlandTests/TaskStateStoreTests.swift`
- `CLAUDE.md`

### Create

---

### Task 1: Reproduce and localize the attention regression

**Files:**
- Modify: `MacIrlandTests/TaskStateStoreTests.swift`

- [ ] **Step 1: Add or refine focused regression coverage**

确保测试能明确区分以下三种情况：

- 两个不同 logical session：`waitingInput + running`，attention count 必须是 `1`
- 两个相同 logical session：duplicate IDs，最终只保留一个更强版本
- duplicate collapse 后，如果一条 session 的状态从 `running -> waitingInput`，最终 surviving session 必须仍是 `waitingInput`

建议新增 1-2 条 focused tests，而不是只依赖现有断言。

- [ ] **Step 2: Run focused tests**

Run:
```bash
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland" --filter testIslandAttentionSessionsFiltersNonAttentionSessions
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland" --filter TaskStateStoreTests
```

- [ ] **Step 3: Identify the exact regression point**

优先判断回归来自哪一层：

- `ClaudeStatusJudge` / adapter 状态判断错误
- `SessionResolver` 去重过头，误把不同 session 合成一个
- `mergeHistory(...)` 在 surviving session 选择上保留了错误状态

不要在没有定位前直接改一堆逻辑。

---

### Task 2: Fix deduplication semantics without reopening the crash

**Files:**
- Modify: `MacIrlandKit/Services/SessionRecognition/SessionResolver.swift`
- Modify: `MacIrlandKit/Adapters/BuiltIn/BuiltInCLIAdapter.swift`
- Modify: `MacIrlandTests/TaskStateStoreTests.swift`

- [ ] **Step 1: Preserve distinct logical sessions**

如果 regression 来自 `SessionResolver`，修复原则是：

- 只 collapse 真正相同 stable identity 的 session
- 不能把不同 tty / 不同窗口 / 不同 logical session 误合并
- 如果相同 stable identity 的两条候选状态不同，surviving candidate 不能只看 `lastActiveAt`；要保证 attention state 不会被较弱状态覆盖

推荐保守排序：

1. 更高 `TaskStatus.tier`
2. 更高 `priority`
3. 更新 `lastActiveAt`
4. 必要时再用 evidence/history 长度做 tiebreak

- [ ] **Step 2: If needed, fix stable identity generation**

如果问题其实来自 `stableSessionID(for:)` 过于粗糙，就做最小必要修复。

但要求：

- 只做最小 identity 修正
- 不要在这一轮重写整条 session identity 模型

- [ ] **Step 3: Re-run focused tests**

Run:
```bash
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland" --filter TaskStateStoreTests
```

Expected:
- island attention regression 消失
- duplicate-session crash coverage 仍然通过

---

### Task 3: Reconcile mergeHistory with surviving session semantics

**Files:**
- Modify: `MacIrlandKit/Core/State/TaskStateStore.swift`
- Modify: `MacIrlandTests/TaskStateStoreTests.swift`

- [ ] **Step 1: Audit mergeHistory survivor behavior**

当前 `mergeHistory(from:into:)` 防御式写法避免了 crash，但要确认：

- 不会把更弱状态的旧 session 语义带回新 session
- 不会在 history preserve 的同时丢掉当前 status
- 不会因为 duplicate folding 让 `waitingInput` / `replyAvailable` 失去 attention

- [ ] **Step 2: Keep defensive no-crash behavior**

本任务绝不能回退为 `Dictionary(uniqueKeysWithValues:)`。

要求：

- 保留 defensive merge
- 只修 survivor/status/history 的语义问题

- [ ] **Step 3: Re-run focused tests**

Run:
```bash
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland" --filter TaskStateStoreTests
```

---

### Task 4: Full verification and runtime confidence check

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: Run full verification**

Run:
```bash
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland"
swift build --package-path "/Users/lijunjie/Documents/AIproject/macirland"
```

Success criteria:
- 全量测试通过
- 构建通过

- [ ] **Step 2: Launch and soak briefly**

启动 app，确认：

- `1s` 自动刷新仍在
- 运行 `20-30s` 不闪退
- island / panel attention 行为仍正确

- [ ] **Step 3: Update docs**

更新 `CLAUDE.md`，记录：

- crash fix 已继续修到回归关闭
- 当前自动刷新已恢复到“构建绿 + 测试绿 + 短时运行稳定”

- [ ] **Step 4: Write execution report**

Create:

报告必须包含：

1. 目标回顾
2. 根因与回归点
3. 文件变更清单
4. Task 执行明细
5. 验证矩阵
6. 与 plan 的偏差说明
7. 剩余风险

---

## Definition of Done

DoD:

- `testIslandAttentionSessionsFiltersNonAttentionSessions` 通过
- 全量 `swift test` 通过
- `swift build` 通过
- 自动刷新 crash fix 仍然保留
- app 在 `20-30s` 自动刷新下不闪退
- `CLAUDE.md` 已更新
- 执行报告已写入固定路径
