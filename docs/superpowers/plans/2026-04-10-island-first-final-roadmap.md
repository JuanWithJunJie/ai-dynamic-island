# Island-First Final Roadmap

> **For agentic workers:** 这是 island-first 收尾阶段的路线图，不是单个 phase 的可执行计划。后续具体实现时，仍应为每一轮单独产出 implementation plan 和 execution report。

**Goal:** 评估 MacIrland 距离“可稳定演示、并逐步接近真实可用”的剩余工作量，并把后续 3 轮工作收成清晰路线图。

**Architecture:** 当前 island-first 体验的壳层已经基本建立完成，剩余工作重点从“UI 外形”转向“跨会话行为闭环”和“真实处理能力”。后续路线建议分成 3 轮：先完成 attention queue handoff，再打通真实 reply bridge，最后做边界行为与产品 polish。

**Tech Stack:** SwiftUI, AppKit `NSPanel`, `TaskStateStore`, `IslandCoordinator`, `PanelCoordinator`, observation services, reply bridge abstractions, XCTest

---

## 当前结论

如果“做完”的标准是：

### A. 可演示完成
- island-first 形态完整
- 多 session 行为基本合理
- 用户能理解产品如何工作
- 即使 reply 仍是 mock，也能稳定 demo

那么大约还需要 **2 轮**：
- Phase 7：attention queue / interruption handoff
- 最后一轮 polish

### B. 产品化完成
- island-first 形态完整
- 多 session 行为完整
- 能通过真实 reply bridge 对 CLI 会话做有效介入
- 主要边界行为已经收稳

那么更现实的估算是 **3 轮**：
- Phase 7：attention queue / interruption handoff
- Phase 8：真实 reply bridge
- Phase 9：polish + 稳定性闭环

**推荐按 3 轮推进。**

原因：
- Phase 1-6 已经把产品“长什么样、如何第一眼被看见”做出来了
- 当前最大缺口不再是 UI，而是“多个会话如何接力”和“用户的介入是否真的能落到 CLI”
- 如果不做真实 reply bridge，产品仍更接近 demo 而非可用工具

---

## 已完成到什么程度

### 已完成能力
- compact island / status strip
- expanded single-task card
- 1 个推荐 quick action
- 轻量动效 + auto-collapse
- panel 已降为二级详情层
- island 已具备多 session arbitration
- island -> panel handoff 已与当前焦点对齐

### 当前仍未完成的关键能力
- 当前 attention session 结束后，下一个待处理会话如何自然接力
- island 的“队列感”如何轻量表达
- reply 是否真的能打回真实 CLI
- 不同 CLI（尤其非 Claude Code）的真实写回链路是否成立
- 边界状态、文案与实机稳定性是否足够收口

---

## Recommended Remaining Rounds

### Round 1 — Phase 7: Attention Queue / Interruption Handoff

**目标：**
让 island 从“知道当前高亮谁”升级成“知道当前项和后续项如何接力”。

**这一轮要完成：**
- 建立 island attention queue helper
- dismiss 当前 highlighted 后，切到下一个 attention session
- transient auto-collapse 后，如果后面还有 attention session，继续 handoff
- compact / highlighted 增加轻量“后面还有待处理项”的提示

**这一轮完成后的收益：**
- 用户会明显感觉 island 是一个会“排队处理任务”的产品，而不是只会弹单卡
- 这是后面真实 reply bridge 之前最重要的体验闭环

**风险：**
- arbitration、dismiss 和记忆逻辑容易互相打架
- 需要重点看同级 session、被 dismiss session 和高 tier 抢占之间的关系

---

### Round 2 — Phase 8: Real Reply Bridge

**目标：**
让 island / panel 上的 quick action 或 reply 不再只是 mock，而是真正把动作写回 CLI 会话。

**这一轮要完成：**
- 审视现有 `ReplyBridging` 抽象与 mock 实现
- 先选一个最稳定的 CLI 目标作为首发路径
  - 推荐优先：Claude Code
- 支持最小真实写回能力：
  - quick action
  - 自定义回复至少二选一，建议先做 quick action
- 失败时保留明确错误反馈，不吞错
- 保持 runtime history 继续记录“已发送 / 被拒绝”

**建议范围控制：**
- 只先做一条真实 CLI 写回链路
- 不要同一轮同时做 Codex / Gemini 全量接入
- 不要顺手重写 observation

**这一轮完成后的收益：**
- 产品从“像产品”变成“开始真的能处理任务”
- 这一步是从 demo 到可用工具的分水岭

**风险：**
- Apple Events / Terminal automation / 不同终端元数据可靠性
- CLI prompt 结构不稳定
- 回写成功判定标准需要谨慎设计

---

### Round 3 — Phase 9: Product Polish / Stability Closure

**目标：**
把 island-first 的边界行为、文案、实机表现和状态收口，形成可长期演进的稳定基线。

**这一轮要完成：**
- 统一 compact / highlighted / panel 的状态词和产品 copy
- 梳理实机边界行为：
  - 无 session
  - 单 session
  - 多 session 同 tier
  - 高 tier 抢占
  - dismiss 后接力
  - auto-collapse 后接力
  - reply 发送成功 / 失败
- 收敛一些视觉和尺寸细节
- 补最终回归测试
- 更新 `CLAUDE.md` 和总体现状文档

**这一轮不要做：**
- 新产品形态
- 新交互模式
- 大规模架构重写

**这一轮完成后的收益：**
- 项目会从“还在快速试形态”进入“有稳定基线可以持续扩展”

---

## Sequencing Rationale

推荐顺序必须是：

1. `Phase 7`
2. `Phase 8`
3. `Phase 9`

原因：
- 如果先做真实 reply bridge，但 queue/handoff 还没收好，用户会觉得可写回了，但产品行为仍然跳
- 如果先做最终 polish，但 reply 仍是 mock，很多 polish 会被真实集成推翻
- 因此 Phase 7 是体验行为闭环，Phase 8 是能力闭环，Phase 9 是产品收尾

---

## Recommended Definition of Done

可以把“基本做完”的标准定成下面这些：

- island 在多 session 场景下不会乱跳
- 当前高亮项结束后，后续 attention session 会自然接上
- island 与 panel 的焦点一致
- 至少一条真实 reply bridge 可用
- quick action 或回复失败时有明确反馈
- compact / highlighted / panel 文案统一
- 主要边界行为有测试覆盖
- `swift test` / `swift build` 通过

如果这些都满足，就可以认为 island-first 第一阶段已经完成。

---

## What Not To Do Next

在后 3 轮里，不建议插入这些大项：
- 一次性把 Codex / Gemini 全量真实写回都做了
- 重写 observation 管线
- 把 panel 再抬回主工作台
- 给 island 增加多按钮密集交互
- 提前做复杂视觉炫技动画

这些都会把路线拉散。

---

## Suggested Next Action

最合理的下一步是直接执行：
- `Phase 7: Attention Queue / Interruption Handoff`

完成后再进入：
- `Phase 8: Real Reply Bridge`

最后收尾：
- `Phase 9: Product Polish / Stability Closure`

---

## Self-Review

### 1. Coverage
- 已覆盖“还要做几轮”的数量判断
- 已覆盖每一轮的目标、收益、风险和顺序
- 已给出为什么推荐按 3 轮推进

### 2. Placeholder Scan
- 无 TBD / TODO / implement later 占位
- 无“写测试”式空泛描述

### 3. Consistency
- 与现有 Phase 1-6 的完成状态一致
- 与最新的 Phase 7 方向保持一致
