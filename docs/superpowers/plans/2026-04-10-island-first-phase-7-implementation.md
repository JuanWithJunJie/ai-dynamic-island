# Island-First Phase 7 Implementation Plan

## Goal

在 Phase 6 完成多 session arbitration 之后，继续补足一个关键行为缺口：

- 当前 island 已经知道“谁最值得高亮”
- 但当用户 dismiss 当前高亮，或一个短暂停留的 highlighted card 自动收回时，其他仍待处理的 session 不一定会顺滑接上来

Phase 7 只做一件事：

让 island 具备更完整的 **attention queue / interruption handoff** 行为。

换句话说，当前最需要补的不是新 UI，而是让用户感受到：
- island 知道当前在关注谁
- 也知道后面还有谁在排队
- 当前任务被处理、dismiss 或自动收回后，系统能自然切到下一个应关注对象

---

## Why This Phase

Phase 1-6 已经完成：
- compact island
- expanded single-task card
- 1 个推荐 quick action
- 轻量动效 + auto-collapse
- panel 退为二级详情层
- 多 session arbitration + status copy

但当前仍有一个明显空档：
- `dismissedHighlightedSessionID` 还是单点记忆
- highlighted session 的退出逻辑仍偏“当前卡片结束后回 compact”
- 产品还没有真正建立“attention queue”

因此，Phase 7 应优先把“跨 session 切换和打断规则细化”落成更完整的用户体验。

---

## Scope

### In Scope
- 为 island 建立 attention queue 辅助表示
- 在 dismiss / auto-collapse 后切到下一个 attention session，而不是无脑回 compact
- 在 UI 上轻量提示“后面还有待处理会话”
- 继续保持 panel handoff 与当前 island 焦点对齐
- 补测试、更新 `CLAUDE.md`、写执行报告

### Out of Scope
- 真实 reply bridge
- 多 quick action 按钮
- 自由输入
- 新动画类型
- hover / 手势
- panel 再重构
- observation / adapter 重写

---

## Planned File Map

### Modify
- `MacIrlandKit/Core/State/TaskStateStore.swift`
- `MacIrlandKit/Features/Island/IslandPresentation.swift`
- `MacIrlandKit/Features/Island/IslandStatusStripView.swift`
- `MacIrlandKit/Features/Island/IslandExpandedCardView.swift`
- `MacIrlandApp/App/IslandCoordinator.swift`
- `MacIrlandTests/TaskStateStoreTests.swift`
- `MacIrlandTests/UIDisplayFormattingTests.swift`
- `MacIrlandTests/AppLaunchSupportTests.swift`
- `CLAUDE.md`

### Create

---

## Task 1 — Add attention queue helpers for island-facing sequencing

### Objective
让 store 层不只知道“最佳会话是谁”，还知道“后面还有哪些 attention session 正在排队”。

### Implementation

1. 在 `TaskStateStore` 中新增 island-facing 队列 helpers，例如：
   - `islandAttentionSessions`
   - `secondaryIslandAttentionCount`

2. `islandAttentionSessions` 规则：
   - 只包含 `status.needsAttention == true` 的 session
   - 排序沿用 Phase 6 的 tier + priority + lastActiveAt

3. `secondaryIslandAttentionCount` 含义：
   - 如果当前 island 已经聚焦某个 attention session，则统计剩余 attention session 数量
   - 没有 attention session 时返回 `0`

### Tests
```bash
swift test --filter TaskStateStoreTests
```

### Exit Criteria
- store 能提供稳定的 island attention queue
- secondary count 有测试覆盖

---

## Task 2 — Promote next attention session after dismiss or transient collapse

### Objective
让 island 在当前 highlighted session 被 dismiss 或自动收回后，优先切到队列中的下一个 attention session，而不是直接回 compact。

### Implementation

1. 在 `IslandCoordinator` 里把现有 arbitration 扩展成 queue-aware 逻辑：
   - 当前 active highlighted session 结束后，优先寻找下一个可显示的 attention candidate
   - 只有当 attention queue 已空，才回 compact

2. `dismissedHighlightedSessionID` 继续保留，但语义改成：
   - 被用户手动 dismiss 的 session 在本轮不应立即重新弹回
   - 但系统应继续尝试显示队列里的下一个 attention session

3. auto-collapse 的 handoff 规则：
   - `.alert` / `.replyAvailable` 自动收回后，如果仍有其他 attention session，切到下一个
   - 仅当没有下一项时，才回 compact

4. sticky arbitration 仍要保留：
   - 更高 tier 候选仍可抢占
   - 同级不频繁抖动

### Tests
```bash
swift test --filter AppLaunchSupportTests
```

### Exit Criteria
- dismiss 当前 highlighted 后，可顺滑切到下一个 attention session
- transient auto-collapse 后，若队列未空，不会直接掉回 compact
- sticky arbitration 与 queue handoff 不冲突

---

## Task 3 — Surface lightweight “more waiting” cues in compact and highlighted UI

### Objective
让用户知道当前 island 不只是在处理一个会话，后面还有排队项，但不要把 UI 做重。

### Implementation

1. 在 `CompactIslandPresentation` 增加轻量 overflow cue，例如：
   - `secondaryText`
   - 或等价命名

2. compact 态策略：
   - 如果有额外 attention session 排队，显示类似：
     - `另 2 个待处理`
   - 如果没有额外 attention session，则保持当前简洁布局

3. 在 `HighlightedIslandPresentation` 增加一个轻量 queue hint，例如：
   - `queueHintText`

4. expanded card 中仅允许加一行弱化提示，不新增新区域、不增加按钮：
   - 示例：`后面还有 2 个会话待处理`

### Tests
```bash
swift test --filter UIDisplayFormattingTests
```

### Exit Criteria
- compact / highlighted 都能在有排队项时表达“后面还有待处理”
- UI 保持轻量，不变成多卡工作台

---

## Task 4 — Verify queue handoff behavior and document it

### Objective
完成验证、文档收口和执行报告。

### Implementation

1. 更新 `CLAUDE.md`，补充：
   - island 已具备 attention queue handoff
   - dismiss / auto-collapse 后会继续尝试展示下一个待处理会话
   - compact / highlighted 已具备轻量的 pending cue

2. 写执行报告：

3. 报告中必须记录：
   - queue 排序规则
   - dismiss / auto-collapse handoff 规则
   - secondary pending cue 的展示规则

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

1. Task 1: attention queue helpers
2. Task 2: queue-aware handoff in coordinator
3. Task 3: lightweight pending cues
4. Task 4: verify + docs + execution report

Task 2 依赖 Task 1，不要并行。Task 3 要消费前两步的 presentation / coordinator 结果，也不要提前做。

---

## Success Criteria

Phase 7 完成后，应达到以下体验：

- island 不再只盯住一个 attention session，而是具备“当前项 + 后续项”意识
- dismiss 当前高亮后，系统会继续展示下一个待处理会话
- transient auto-collapse 后，如果后面还有 attention session，会自然接力
- 用户能从 compact / highlighted 里感知“还有其他会话在等”

---

## Not Doing Yet

Phase 7 完成后，仍然暂不做：
- 真实 reply bridge
- 多按钮 quick action 区
- 自由输入直达 island
- 更复杂的跨 CLI 打断/协作策略
- Codex / Gemini 全量真实 observation

这些应放到后续阶段再评估。
