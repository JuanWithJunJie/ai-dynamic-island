# 2026-04-11 Island Hover Expand (Option B) Implementation

## 1. Objective

实现 island 鼠标悬停展开功能（Option B 布局）：
- 鼠标悬停 → island 展开显示上半部分（当前 attention session 详情）+ 下半部分（所有会话列表）
- 鼠标离开 → 200ms 延迟后自动折叠回 compact
- 点击会话行 → AppleScript 跳转到对应 Terminal tab（不改变上半部分展示内容）
- 上半部分始终展示当前 `preferredIslandSession`（最高优先级 session）的详情

## 2. Technical Background

### 当前 island 模式
- `IslandSurfaceMode`: `.compact` | `.tray` | `.highlighted`
- 当前 hover 行为（`IslandCoordinator`）：
  - `.compact` → hover → 200ms 延迟 → `.tray`（显示会话列表）
  - `.compact` → 点击 → `.highlighted`（显示完整详情卡片）
  - `.tray` → 点击某行 → 调用 `openPanelForSession(sessionID)` → 打开 panel

### 核心文件
- `MacIrlandApp/App/IslandCoordinator.swift` - island 窗口管理、hover 跟踪、模式切换
- `MacIrlandKit/Features/Island/IslandMultiSessionTrayView.swift` - 当前 tray view（会话列表）
- `MacIrlandKit/Features/Island/IslandStatusStripView.swift` - compact status strip
- `MacIrlandKit/Features/Island/IslandExpandedCardView.swift` - 当前 expanded card（单 session 详情）

### Option B 新布局结构
```
┌─────────────────────────────────┐
│  status strip (始终显示)         │  ← 36px
├─────────────────────────────────┤
│  session detail (attention)     │  ← 动态高度
│  - icon / title / subtitle      │
│  - chip / timestamp             │
│  - recent input bubble          │
│  - events timeline              │
│  - Continue button              │
├─────────────────────────────────┤
│  session list header            │  ← 32px
├─────────────────────────────────┤
│  row 1 (highlighted)            │
│  row 2                          │  ← 动态高度
│  row 3                          │
└─────────────────────────────────┘
```

总高度约 240-280px（compact 36px）。

## 3. Implementation Plan

### Task 1: 创建 `IslandHoverExpandView` — 新的 Option B 组合视图
- 新文件：`MacIrlandKit/Features/Island/IslandHoverExpandView.swift`
- 结构：
  - 上半部分：调用现有组件展示 `preferredIslandSession` 详情（复用 `IslandExpandedCardView` 或重新组合）
  - 下半部分：调用现有 `IslandMultiSessionTrayView` 列表
- 使用 SwiftUI `@ObservedObject` 或 `let` 接收数据
- 状态：`isExpanded: Bool` 控制展开/折叠动画

### Task 2: 修改 `IslandCoordinator` — 添加 `.hoverExpand` 模式
- 在 `IslandSurfaceMode` 中确认或新增 `.hoverExpand` 模式
- 修改 `handleMouseEntered()`：
  - 如果当前是 `.compact` 且有多个相关会话 → 进入 `.hoverExpand`
  - 如果当前是 `.compact` 且只有 1 个会话 → 可选进入简化展开（显示 detail + 无列表）
- 修改 `handleMouseExited()`：
  - 如果当前是 `.hoverExpand` → 200ms 延迟 → 回到 `.compact`
  - 使用 `DispatchWorkItem` 或 `Task.sleep` 实现延迟取消
- 确保 `.hoverExpand` 模式下 island 高度覆盖完整内容（预估 260px）

### Task 3: 修改 `IslandSurfaceView` — 支持 `.hoverExpand` 渲染
- `IslandSurfaceView` 当前处理 `.compact` / `.tray` / `.highlighted`
- 新增 `.hoverExpand` 分支：
  - 返回 `IslandHoverExpandView(isExpanded: true)`
- `.compact` 分支返回 `IslandStatusStripView`

### Task 4: 修改 `IslandMultiSessionTrayView` — 添加点击跳转回调
- 当前 `TraySessionRow` 有 `onSessionSelected` 回调
- 修改 `TraySessionRow` 的点击行为：
  - 点击 → 调用 `TerminalJumpService.jumpToTab(tty:)` 跳转到对应 Terminal tab
  - 跳转成功后 `NSWorkspace.shared.frontTerminal()` 激活 Terminal
  - 不改变 island 展开状态（保持在 `.hoverExpand`）
- 确保 `TerminalJumpService` 的 AppleScript 实现正确（已有 `jumpToSession` 方法）

### Task 5: 验证 compact 形态仍然正常
- `.compact` 模式：仅显示 `IslandStatusStripView`（36px）
- `.tray` 模式（多个会话 + hover）：显示 `IslandMultiSessionTrayView`（当前行为）
- `.highlighted` 模式（点击后）：显示 `IslandExpandedCardView`（当前行为）
- 确认各模式切换不会相互干扰

### Task 6: 添加单元测试
- `IslandCoordinatorTests.swift`（新文件）：
  - `testHoverExpandEntersFromCompact` - hover 后进入 `.hoverExpand`
  - `testHoverExpandFallsBackToCompactAfterDelay` - 离开后延迟回到 `.compact`
  - `testHoverExpandWithSingleSession` - 单会话时的行为
  - `testTrayRowClickDoesNotCloseExpand` - 点击列表行不关闭展开

### Task 7: 手动验证
- 启动 app，hover 到 island → 确认展开高度、内容正确
- hover 离开 → 确认 200ms 延迟后折叠
- 点击 session row → 确认跳转到对应 Terminal tab
- 确认 `.compact` / `.tray` / `.highlighted` 各模式仍然正常

## 4. File Changes

| File | Change |
|------|--------|
| `MacIrlandKit/Features/Island/IslandHoverExpandView.swift` | 新建 - Option B 组合视图 |
| `MacIrlandApp/App/IslandCoordinator.swift` | 修改 - 添加 `.hoverExpand` 模式切换逻辑 |
| `MacIrlandKit/Features/Island/IslandSurfaceView.swift` | 修改 - 新增 `.hoverExpand` 分支渲染 |
| `MacIrlandKit/Features/Island/IslandMultiSessionTrayView.swift` | 修改 - 点击行跳转 Terminal tab |
| `MacIrlandTests/IslandCoordinatorTests.swift` | 新建 - hover expand 测试 |

## 5. Dependencies

- `TerminalJumpService` - 已有 `jumpToSession(tty:)` 方法
- `IslandSurfaceMode` - 当前 enum
- `IslandStatusStripView` - 现有 compact 视图
- `IslandExpandedCardView` - 现有展开卡片视图
- `IslandMultiSessionTrayView` - 现有列表视图

## 6. Risks

1. **高度计算**：`.hoverExpand` 需要固定高度覆盖完整内容，但 macOS island 窗口高度由内容决定。需要验证 NSPanel 的 `setContentSize` 或 SwiftUI frame 修正。
2. **模式冲突**：`.hoverExpand` 和 `.tray` 都是 hover 触发，需要明确区分：
   - `.tray`：多会话 hover 时显示简洁列表（当前行为）
   - `.hoverExpand`：多会话 hover 时显示详情 + 列表（新行为）
   - 确认新设计是否替换 `.tray` 或作为独立模式
3. **点击穿透**：hover 展开后鼠标移动到列表区域，mouseExited 会被触发吗？需要 NSTrackingArea 配置正确。

## 7. Out of Scope

- 修改 panel 窗口本身的行为（panel 打开方式不变）
- 修改 `IslandExpandedCardView` 的内部布局（直接复用）
- 多语言 / 国际化
- 非 macOS 平台适配
