# Final Experience Hardening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把当前 island-first 体验最后一段不够扎实的链路补齐，让声音提示、tray 触发和轻告警表达真正进入“可长期体验”的状态。

**Architecture:** 当前代码已经具备可工作的 compact island、hover tray、完成提示音、图标状态语言和 1 秒自动刷新；全量测试/构建也为绿。但最新执行报告仍明确暴露出三个残留问题：transition-based 声音逻辑缺少真正可验证的测试支撑；tray 触发语义虽然进步了，但还没完全收成“多个相关 Claude Code 会话”；compact/tray 上的 alert 仍然存在“可见但不够稳定好懂”的风险。下一轮不新增新的 UI 层和交互层，只做体验硬化、语义收紧和验证补齐。

**Tech Stack:** Swift, SwiftUI, AppKit, Observation, XCTest

---

## Inputs

### Must review first
- `docs/superpowers/plans/2026-04-10-feedback-and-tray-hardening-implementation.md`
- `example/vibe-irland-2.mp4`
- `example/vibe-irland-3.mp4`

### Current gaps to close
- transition-based cue 逻辑已接入，但没有通过真正的多轮 refresh 测试把行为锁死
- tray eligibility 仍然偏“相关会话计数”，还没有收成一个可复用的“tray sessions”语义
- compact/tray 的 alert 已经不再 aggressive，但提示仍略显脆弱
- 最新执行报告的 runtime verification 仍偏 checklist，缺少代码/测试层的闭环

---

## File Structure

### Modify
- `MacIrlandKit/Services/Feedback/FeedbackService.swift`
- `MacIrlandApp/App/RefreshCoordinator.swift`
- `MacIrlandKit/Core/State/TaskStateStore.swift`
- `MacIrlandApp/App/IslandCoordinator.swift`
- `MacIrlandKit/Features/Island/IslandStatusStripView.swift`
- `MacIrlandKit/Features/Island/IslandMultiSessionTrayView.swift`
- `MacIrlandTests/TaskStateStoreTests.swift`
- `MacIrlandTests/AppLaunchSupportTests.swift`
- `MacIrlandTests/UIDisplayFormattingTests.swift`
- `CLAUDE.md`

### Create

---

## Task 1: Make transition-based feedback behavior testable and deterministic

**Files:**
- Modify: `MacIrlandKit/Services/Feedback/FeedbackService.swift`
- Modify: `MacIrlandApp/App/RefreshCoordinator.swift`
- Modify: `MacIrlandTests/AppLaunchSupportTests.swift`
- Modify: `MacIrlandTests/TaskStateStoreTests.swift`

- [ ] **Step 1: Keep cue generation transition-based, but make it directly testable**

Do not revert to presence-based sound logic.

Refactor only as needed so the transition rules can be tested without relying on a human watching the app refresh:
- `.taskStarted` only when a session newly enters `.running`
- `.waitingForReply` only when a session newly enters `.waitingInput` or `.replyAvailable`
- `.completed` only when a session newly enters `.completed`
- `.failed` only when a session newly enters `.alert` or `.failed`

- [ ] **Step 2: Add deterministic regression coverage for repeated refreshes**

Required coverage:
- same `running` session across multiple refresh cycles does not replay `.taskStarted`
- same `completed` session across multiple refresh cycles does not replay `.completed`
- state transition `running -> completed` emits completion once
- state transition `running -> waitingInput` emits waiting cue once

Use fake previous/current snapshots or a fake `SoundPlaying` sink if needed, but the tests must actually simulate multiple rounds.

- [ ] **Step 3: Keep current sound mode semantics intact**

Do not redesign `SoundMode` in this round.

The tests should validate transition behavior, not introduce a new audio policy.

- [ ] **Step 4: Run focused verification**

Run:
```bash
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland" --filter TaskStateStoreTests
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland" --filter AppLaunchSupportTests
```

---

## Task 2: Replace generic relevant-session counting with explicit tray-session semantics

**Files:**
- Modify: `MacIrlandKit/Core/State/TaskStateStore.swift`
- Modify: `MacIrlandApp/App/IslandCoordinator.swift`
- Modify: `MacIrlandKit/Features/Island/IslandMultiSessionTrayView.swift`
- Modify: `MacIrlandTests/TaskStateStoreTests.swift`
- Modify: `MacIrlandTests/AppLaunchSupportTests.swift`

- [ ] **Step 1: Introduce a single source of truth for tray sessions**

Do not continue scattering tray eligibility across:
- `sessions.count`
- implicit filters in coordinator
- view-layer assumptions

Create or refine one source of truth that answers:
- which sessions belong in the tray
- whether the tray should appear

The intended behavior is:
- multiple relevant Claude Code sessions should trigger tray
- unrelated or low-value sessions should not force tray
- tray rows should render from the same filtered session set used by eligibility

- [ ] **Step 2: Align coordinator and tray UI with the filtered tray session set**

Requirements:
- compact hover opens tray only when the filtered tray session set count is greater than 1
- tray header count and tray row list must use the same filtered session set
- `tray row click -> panel focus` behavior remains unchanged

- [ ] **Step 3: Add focused regression tests**

Required coverage:
- 2 Claude Code sessions -> tray sessions count is 2 and tray eligible
- 1 Claude Code + 1 unrelated/terminal session -> tray not eligible
- tray session set remains stable across refresh when underlying relevant sessions remain stable

- [ ] **Step 4: Run focused verification**

Run:
```bash
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland" --filter TaskStateStoreTests
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland" --filter AppLaunchSupportTests
```

---

## Task 3: Make alert signaling clearer without reintroducing interruption

**Files:**
- Modify: `MacIrlandKit/Features/Island/IslandStatusStripView.swift`
- Modify: `MacIrlandKit/Features/Island/IslandMultiSessionTrayView.swift`
- Modify: `MacIrlandTests/UIDisplayFormattingTests.swift`

- [ ] **Step 1: Tighten compact alert language**

Keep alert soft, but make it easier to scan.

Allowed directions:
- clearer secondary copy
- more explicit compact accent treatment
- more obvious but still restrained tray-row emphasis

Not allowed:
- reintroducing highlighted-card auto expansion for “still working” alert cases
- turning compact island into a warning banner

- [ ] **Step 2: Keep compact and tray semantics aligned**

If compact says “this needs attention but work continues,” tray rows should visually reinforce the same meaning.

Do not make compact say one thing while tray rows read like hard failures.

- [ ] **Step 3: Run focused verification**

Run:
```bash
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland" --filter UIDisplayFormattingTests
```

---

## Task 4: Full verification, runtime closure, and documentation

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: Run full automated verification**

Run:
```bash
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland"
swift build --package-path "/Users/lijunjie/Documents/AIproject/macirland"
```

- [ ] **Step 2: Run explicit runtime checks**

Required runtime checks:

1. keep a running Claude Code session alive across several refresh cycles and verify start sound does not replay
2. transition a session into waiting/reply state and verify waiting sound fires once
3. transition a session into completed state and verify completion sound fires once
4. keep 2 relevant Claude Code sessions alive and verify tray appears from the filtered tray session set, not from unrelated sessions
5. verify alert remains visible in compact/tray without incorrectly forcing large highlighted expansion

- [ ] **Step 3: Update docs**

Update `CLAUDE.md` so it only reflects behavior that is both implemented and verified:
- transition-based cue semantics
- filtered tray-session semantics
- lightweight alert signaling summary

- [ ] **Step 4: Write execution report**

Create:

Report must include:
1. objective recap
2. previous risks addressed
3. file changes
4. task execution details
5. verification matrix
6. deviations from plan
7. remaining risks

---

## Definition of Done

DoD:
- transition-based sound behavior is covered by real multi-refresh regression tests
- tray eligibility is driven by a filtered tray-session source of truth, not loose counting
- compact/tray alert signaling is clearer but still non-interruptive
- `swift test` passes
- `swift build` passes
- `CLAUDE.md` updated
- execution report written to the fixed path
