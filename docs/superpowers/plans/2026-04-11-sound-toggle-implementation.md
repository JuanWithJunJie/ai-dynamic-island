# 2026-04-11 Sound Toggle Implementation Plan

## 1. Objective

在 hover expand 面板中添加声音开关按钮（UI 基于确认的 mockup）：
- 按钮位于 status strip 右侧
- 鼠标悬停面板时按钮淡入，离开后淡出
- 点击切换声音开关状态（`.all` ↔ `.mute`）
- 默认声音开启（`.all`）

## 2. Architecture

现有基础设施：
- `TaskStateStore.soundMode: SoundMode` - 已存在，支持 `.all` / `.criticalOnly` / `.mute`
- `LocalStore` 协议 - 已有 `save/loadSoundMode` 方法
- `ChiptuneSoundPlayer.playIfAllowed(cue:mode:)` - 根据 SoundMode 决定是否播放

实现方案：
- 简化为 2 档：`.all`（开）和 `.mute`（关）
- 声音开关状态通过 `store.soundMode` 读写
- `LocalStore` 持久化（已有接口，但当前 `InMemoryLocalStore` 仅内存存储 - 需要 UserDefaults 支持）

## 3. Implementation Tasks

### Task 1: 添加 UserDefaults 持久化支持
- 修改 `LocalStore.swift` 或添加 `UserDefaultsLocalStore`
- 替换 app 中 `InMemoryLocalStore` 为持久化版本

### Task 2: 添加声音开关按钮到 `IslandHoverExpandView`
- 在 `HoverExpandStatusStrip` 中添加 `SoundToggleButton`
- 按钮通过 `@State` hover 检测控制透明度动画
- 点击时切换 `store.soundMode`（`.all` ↔ `.mute`）

### Task 3: 验证
- Build 成功
- 214 tests pass

## 4. File Changes

| File | Change |
|------|--------|
| `MacIrlandKit/Services/Persistence/LocalStore.swift` | 添加 `UserDefaults` 持久化支持 |
| `MacIrlandKit/Features/Island/IslandHoverExpandView.swift` | 添加 `SoundToggleButton` 和 hover 透明度逻辑 |

## 5. Out of Scope
- 修改 `SoundMode` enum（已有 `.all` / `.criticalOnly` / `.mute`）
- 修改 `FeedbackService` 或 `ChiptuneSoundPlayer`
- 修改 `IslandCoordinator` hover 逻辑（已有）
