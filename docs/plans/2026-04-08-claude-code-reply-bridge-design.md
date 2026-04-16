# Claude Code Real Reply Bridge MVP Design

## 背景
MacIrland 现在已经能通过 Terminal / iTerm observation 发现 Claude Code 会话，区分 running / waiting input / completed / alert / failed / contextLost，并把 session detail timeline 升级为当前 app 运行期内的正式历史流。

当前最大的断点已经不是“看不到会话”，而是“看到了会话，但不能真正回写 CLI”。现有 `ReplyBridgeService` 仍是 mock：它可以做本地校验与 UI 演示，但不会把回复真正送回 Claude Code 所在终端会话。

这份设计的目标，是把 reply bridge 推进到一个可用的 MVP：至少让用户能从 MacIrland 对 **Claude Code** 的等待输入会话发送真实回复，并在 UI 中看见成功或失败的闭环反馈。

## 目标
- 为 **Claude Code** 提供真实 reply bridge MVP
- 支持从当前 panel 对选中 session 执行：
  - quick action
  - 自由文本发送
- 发送语义等价于：**用户在目标终端会话里输入文本并按回车**
- 成功 / 失败都要回到：
  - UI explanation
  - runtime history
  - 轻量 diagnostics / reason

## 非目标
本轮不做：
- Codex / Gemini 的真实 reply bridge
- 直接写 TTY
- AppleScript 失败后的 tty fallback
- per-session draft（列为下一刀）
- 复杂 loading / retry / resend UI
- 持久化发送记录
- 完整端到端自动化 UI 回放测试

## 方案比较

### 方案 A：AppleScript 驱动终端注入（推荐）
通过 Terminal / iTerm 的 AppleScript 接口，定位目标会话并执行写入动作，再附带回车。

优点：
- 与当前 observation / 自动化权限链路一致
- 不需要引入更底层、更脆弱的 tty 直写
- 便于沿用现有 Terminal / iTerm 元数据与 bridge target

缺点：
- 依赖终端 app 的脚本能力与定位准确性
- 需要认真处理“会话已变化 / 已消失”

### 方案 B：直接写 TTY
根据 `ttyIdentifier` 直接向目标 tty 写入文本与换行。

优点：
- 更底层，更接近“直接写到会话”

缺点：
- 权限、有效性与转义问题更多
- 与当前项目结构不一致，MVP 风险更高

### 方案 C：混合策略
优先 AppleScript，失败再尝试 tty。

优点：
- 长期覆盖更全

缺点：
- MVP scope 明显变大
- 调试面太宽，不利于先交付首条真实闭环

## 最终选择
采用 **方案 A：AppleScript 驱动终端注入**。

原因：
- 最贴合当前项目已经建立好的 Terminal / iTerm observation 与权限模型
- 更容易在 MVP 范围内做出稳定、可解释的行为
- 能最快把“观察工具”推进成“可回复工作台”

## 架构设计
本轮 bridge 只拆到三层：

### 1. ReplyBridgeService
继续实现 `ReplyBridging`，但从纯 mock 升级为真实桥接入口。

职责：
- 校验 session 是否可发送
- 根据 terminal 类型选择具体 writer
- 返回统一 `ReplyValidationResult`

### 2. Terminal-specific writers
新增两个具体 writer：
- `TerminalReplyWriter`
- `ITermReplyWriter`

职责：
- 根据 `TaskSession` / `BridgeTarget` / terminal metadata 生成目标定位
- 执行 AppleScript 写入
- 对写入失败给出明确原因

### 3. TaskStateStore 集成
`performQuickAction` / `sendDraftReply` 保持现有调用入口，但底层不再停留在 mock。

职责：
- 继续调用 `replyBridge`
- 将发送成功 / 失败写入 runtime history
- 把 explanation 回给详情区

## 目标定位策略
发送前不能只信任旧的 `session.id`，必须做双重确认。

### 发送前必须检查
- `session.sourceCLI == .claudeCode`
- `bridgeTarget` 存在
- `replyCapability` 处于允许发送的状态
- 当前 session 仍与可定位终端目标匹配：
  - `terminalAppIdentifier`
  - `windowIdentifier` / terminal context
  - `ttyIdentifier`（如果存在）

### 会话失配处理
如果当前 session 元数据与 bridge target 不再匹配，则拒绝发送，并返回类似：
- “目标 Claude Code 会话已变化或不存在，请刷新后重试。”

这能避免把消息发到错误终端页签。

## 发送语义
本轮统一定义为：
- 把 message 当作一条完整输入
- 写入目标终端会话
- **立即附带回车**

这意味着 quick action 与 custom text 的区别只在 message 来源，不在发送协议。

### 文本处理策略
MVP 只做最小清洗：
- trim 尾部无意义空白
- 拒绝全空文本
- 保留用户原文
- 不做 shell command 拼装增强
- 不做多行脚本执行能力

产品语义是“像用户粘贴一句话并回车”，不是“远程执行脚本”。

## 失败模型
失败原因要对用户可解释，至少覆盖：
- 没有自动化权限 / Apple Events 被拒绝
- 目标 session 找不到
- terminal app 不可用
- AppleScript 执行失败
- 当前 bridge 仅支持 Claude Code
- 文本为空

这些失败都会反馈到：
- `ReplyValidationResult.explanation`
- runtime history
- `replyCapability.reason` 或 diagnostics 补充说明

## UI 设计
本轮 UI 不新增入口，只复用现有：
- quick action 按钮
- 自由输入框
- 发送按钮

### 成功时
- 详情区显示成功 explanation
- timeline 追加一条 user action / custom reply 记录

### 失败时
- explanation 显示失败原因
- timeline 追加 rejected / failed 记录

### 本轮不做
- loading spinner
- resend button
- per-session draft
- 更深的发送状态可视化

## 数据与状态设计
本轮尽量不新增复杂 public 状态机。

### 保持不变
- `ReplyValidationResult` 继续只包含：
  - `canSend`
  - `explanation`

### 内部语义增强
通过内部发送结果区分：
- validation failed
- send success
- send failed

这些区别通过以下方式反映：
- runtime history kind / detail
- diagnostics / capability reason
- UI explanation

## 测试策略

### 1. ReplyBridgeService 单元测试
覆盖：
- 空文本拒绝
- 非 Claude Code session 拒绝
- 缺失 bridge target 拒绝
- writer 成功时返回成功 explanation
- writer 失败时返回失败 explanation

### 2. TaskStateStore 集成测试
覆盖：
- quick action 成功后落 history
- custom text 成功后落 history
- session 失配 / 权限失败时落 rejected history
- 不破坏已有 refresh / history merge 行为

### 3. Writer 层测试
只做脚本生成 / 调用参数级测试：
- Terminal writer 是否生成正确 AppleScript 调用
- iTerm writer 是否生成正确目标定位

不做：
- 重型 GUI 自动化
- 完整端到端真实终端交互自动化

### 4. 手动 smoke test
本轮需要保留一轮实机验证：
- 打开真实 Claude Code 会话
- 让其进入 waiting input
- 在 MacIrland 中发送 quick action
- 在终端确认输入确实被写入并触发继续执行

## 风险与缓解

### 风险 1：目标会话漂移
缓解：
- 发送前双重校验
- 失配就拒绝，不冒险发送

### 风险 2：Apple Events 权限问题
缓解：
- 返回明确 explanation
- 引导用户到系统自动化权限里确认

### 风险 3：Terminal / iTerm 差异
缓解：
- writer 分 terminal app 拆开实现
- 不抽象成过早通用层

### 风险 4：全局 draft 串 session
缓解：
- 本轮先接受这个已知限制
- 下一刀优先改成 per-session draft

## 下一步建议
这个 MVP 落地后，最值得紧接着做的是：
1. 把 `draftReply` 改成 per-session
2. 在 diagnostics 中加入更明确的 bridge send result
3. 评估 Codex / Gemini 是否也有可行的真实回写路径
