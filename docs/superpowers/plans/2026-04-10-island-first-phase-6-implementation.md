# Island-First Phase 6 Implementation Plan

## Goal

在 Phase 1-5 已完成的前提下，继续收口 island-first 体验，但仍然避免跳进真实 reply bridge 或更大集成。  
Phase 6 只做两件事：

1. 让 island 在多 session 并存时，能更稳定地决定“当前应该高亮哪一个会话”。
2. 让 compact island / highlighted card 的状态文案更像产品语言，而不是纯计数或内部状态名。

这一步的目标不是增加更多功能，而是让现有 island 作为“第一层状态界面”在真实多任务场景下更可信、更稳定。

---

## Why This Phase

Phase 1-5 已经完成了：
- compact island
- expanded single-task card
- 1 个推荐 quick action
- 轻量动效 + auto-collapse
- panel 退为二级详情层

当前最明显的剩余缺口不是视觉，而是行为：
- `IslandCoordinator` 仍主要围绕 `store.topSession` 工作
- `CompactIslandPresentation` 的状态词仍是偏 summary count 驱动
- 当多个 session 同时存在时，产品尚未明确回答：
  - island 应该先展示谁
  - 什么时候切换到另一个 session
  - 什么时候保持当前会话不跳动
  - 顶部状态词应该如何表达“当前最重要的事情”

因此，Phase 6 应该优先建立稳定的 island arbitration 和状态文案策略。

---

## Scope

### In Scope
- 为 island 引入独立于 `topSession` 的 focus / arbitration 规则
- 为 highlighted card 引入“同等级不抖动、遇到更高等级可抢占”的切换策略
- 让 compact strip 的状态词由“当前 island 关注对象”驱动，而不只是摘要计数
- 打通 island -> panel 的 session handoff，使 panel 打开时跟随 island 当前焦点
- 补测试、更新 `CLAUDE.md`、写执行报告

### Out of Scope
- 真实 reply bridge
- 多 quick action
- 自由输入
- 新动画类型
- 新 hover / 手势
- observation / adapter / session matching 重写
- panel 信息架构再重构

---

## Planned File Map

### Modify
- `MacIrlandKit/Core/State/TaskStateStore.swift`
- `MacIrlandKit/Features/Island/IslandPresentation.swift`
- `MacIrlandKit/Features/Island/IslandStatusStripView.swift`
- `MacIrlandApp/App/IslandCoordinator.swift`
- `MacIrlandApp/App/PanelCoordinator.swift`
- `MacIrlandTests/TaskStateStoreTests.swift`
- `MacIrlandTests/UIDisplayFormattingTests.swift`
- `MacIrlandTests/AppLaunchSupportTests.swift`
- `CLAUDE.md`

### Create

---

## Task 1 — Add island-focused session ranking and user-facing status copy

### Objective
在数据/展示层先定义“当前 island 应该关注哪个 session”以及“应该对用户说什么状态词”。

### Implementation

1. 在 `TaskStateStore` 中新增独立的 island focus 读取口，例如：
   - `preferredIslandSession`
   - 或等价命名，但不要替换掉现有 `topSession`

2. `preferredIslandSession` 的排序规则先收成明确的 attention tier：
   - Tier 4: `.waitingInput`, `.failed`, `.contextLost`
   - Tier 3: `.alert`
   - Tier 2: `.replyAvailable`
   - Tier 1: `.running`
   - Tier 0: `.completed`

3. 同 tier 内继续沿用现有排序信号：
   - `priority`
   - `lastActiveAt`

4. 更新 `CompactIslandPresentation`，让它根据 `preferredIslandSession` 产出更明确的 statusText：
   - `.waitingInput` → `等待回复`
   - `.failed` / `.contextLost` → `需要处理`
   - `.alert` → `发现异常`
   - `.replyAvailable` → `可直接回复`
   - `.running` → `运行中`
   - `.completed` → `已完成`
   - 无 session → `空闲`

5. `countText` 仍保留总会话数表达，不要改成复杂统计句。

### Tests
```bash
swift test --filter TaskStateStoreTests
swift test --filter UIDisplayFormattingTests
```

### Exit Criteria
- `preferredIslandSession` 可用
- compact 状态词由 island focus 驱动
- 排序与文案映射都有测试覆盖

---

## Task 2 — Add sticky highlighted arbitration in IslandCoordinator

### Objective
避免 expanded island 在多个 attention session 之间频繁抖动；让当前高亮对象只有在真正值得切换时才切换。

### Implementation

1. 在 `IslandCoordinator` 中引入当前高亮会话记忆，例如：
   - `activeHighlightedSessionID`

2. 新增一个集中 helper，用于根据 `store.sessions` 和当前 active session 决定下一次 highlighted session：
   - 如果当前 active session 仍存在，且仍属于 attention 范围：
     - 当新候选只是相同 tier 或更低 tier 时，保持当前 active session
     - 只有出现更高 tier 候选时，才允许立即切换
   - 如果当前 active session 消失、降级到非 attention，或被 dismiss：
     - 再切到下一个 `preferredIslandSession`

3. `dismissedHighlightedSessionID` 继续保留，但语义要与新的 arbitration 配合：
   - 被 dismiss 的 session 不应立刻重新展开
   - 但更高 tier 的新 session 仍然可以抢占

4. `recomputeMode()` 改为围绕 arbitration helper 工作，而不是直接吃 `store.topSession`

### Tests
```bash
swift test --filter AppLaunchSupportTests
```

### Exit Criteria
- 同级 attention session 不会频繁来回跳
- 更高等级 attention session 能正确抢占
- dismiss 记忆与 arbitration 不冲突

---

## Task 3 — Keep panel handoff aligned with island focus

### Objective
让用户从 island 打开的 panel，默认聚焦的就是 island 此刻正在表达的那一个 session。

### Implementation

1. 在 `PanelCoordinator` 增加显式入口，例如：
   - `showPanelSelectingSession(id:)`
   - 或等价 API

2. `IslandCoordinator.openPanel()` 不再只调用泛化的 panel open，而是把“当前 island 实际聚焦的 session id”传过去。

3. compact 态点击 panel 时：
   - 优先选择 `preferredIslandSession`
   - 如果没有，再退回当前 `topSession`

4. highlighted 态点击 panel 时：
   - 必须优先选择当前 active highlighted session

### Tests
```bash
swift test --filter AppLaunchSupportTests
```

### Exit Criteria
- island -> panel handoff 与当前 island 焦点一致
- 不会出现 island 显示 A，但 panel 打开后落到 B 的情况

---

## Task 4 — Verify the calmer arbitration behavior and document it

### Objective
完成验证、文档收口和执行报告。

### Implementation

1. 更新 `CLAUDE.md`，补充：
   - island 已具备多 session arbitration
   - compact 状态词已改为 focus-driven copy
   - panel handoff 已与 island focus 对齐

2. 写执行报告：

3. 报告中必须记录：
   - 状态分级规则
   - sticky arbitration 规则
   - island -> panel handoff 规则

### Verification
```bash
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland"
swift build --package-path "/Users/lijunjie/Documents/AIproject/macirland"
```

### Exit Criteria
- 全量测试通过
- 构建通过
- `CLAUDE.md` 已更新
- 执行报告已落盘

---

## Suggested Execution Order

1. Task 1: focus ranking + status copy
2. Task 2: sticky highlighted arbitration
3. Task 3: panel handoff alignment
4. Task 4: verify + docs + execution report

不要把 Task 2 和 Task 3 并行做，因为它们都依赖“当前 island 焦点是谁”这件事。

---

## Success Criteria

Phase 6 完成后，应达到以下体验：

- 当多个 session 同时存在时，island 不会因为同等级事件频繁抖动
- 只有更高优先级、真正更值得关注的 session 才会抢占当前高亮
- compact strip 的状态词能表达“当前最重要的事情”
- 用户从 island 进入 panel 时，不会感受到上下文跳变

---

## Not Doing Yet

Phase 6 完成后，仍然暂不做：
- 真实 reply bridge
- Codex / Gemini 全量真实 observation
- 多按钮 card
- 自由输入直达 island
- 更复杂的 cross-session interrupt workflow

这些都应放到 Phase 7 及之后再评估。
