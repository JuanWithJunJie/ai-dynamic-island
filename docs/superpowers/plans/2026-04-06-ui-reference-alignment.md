# MacIrland UI 参考图改造说明

## 背景
当前项目已经具备菜单栏入口、浮动面板、session 列表、详情面板和基础诊断信息，但整体视觉更偏“开发中工具面板”，与 `example/` 目录中的两张参考图还有明显差距。

本文件用于明确：如果后续要把 MacIrland 的 UI 呈现形式往参考图方向推进，当前代码里主要需要修改哪些内容、每一部分应该朝什么方向改，以及建议的实施顺序。

参考图：
- `example/macirland1.png`
- `example/macirland2.png`

---

## 参考图传达出的目标风格

### 1. `macirland1.png` 对应的方向
这是一个非常紧凑的顶部状态入口：
- 深色、短宽比很小的胶囊形外观
- 左侧是高识别度的小图标
- 右侧是非常克制的数字/状态提示
- 整体感觉不是普通菜单栏文字，而是一个“状态小岛”

它更适合作为：
- 菜单栏入口的视觉参考
- 折叠态 / 极简态的品牌识别参考

### 2. `macirland2.png` 对应的方向
这是一个更完整的展开面板：
- 深色、高圆角、强悬浮感容器
- 顶部有清晰品牌区 `macirland`
- 中间内容不是传统表格，而是更像 activity feed / session feed
- 大量使用 chips/tag 展示模型、终端、时长、状态
- 卡片层级清晰，信息密度高但不乱

它更适合作为：
- 主浮动面板的整体视觉壳子参考
- session 列表与详情内容的排版参考

---

## 当前代码中需要重点修改的区域

## 一、菜单栏入口

### 当前状态
当前菜单栏入口定义在：
- `MacIrlandApp/App/MacIrlandApp.swift`

目前是 `MenuBarExtra`，label 已压缩为 icon-only，大致像这样：

```swift
MenuBarExtra {
    ...
} label: {
    Image(systemName: "terminal.fill")
        .accessibilityLabel("MacIrland")
}
```

### 如果要参考 `macirland1.png`，需要修改什么

#### 需要改的点
1. 修改 `MenuBarExtra` 的 label 呈现方式
2. 让入口视觉更接近“胶囊状态块”而不是单个 SF Symbol
3. 为入口增加一个小型数字/状态表达（如果当前数据层支持）
4. 保持宽度足够克制，避免再次加大刘海屏遮挡概率

#### 实现方向
可以尝试把 label 改成一个更小的自定义 SwiftUI view，例如：
- 深色背景
- 圆角 capsule
- 左侧小图标
- 右侧小数字

但这里有一个现实约束：
- `MenuBarExtra` 在 macOS 菜单栏中的最终摆放位置由系统控制
- 即使视觉上做成 capsule，也不能精确控制它避开刘海
- 所以这里能做的是“更像参考图的入口视觉”，不是“精确复刻参考图位置”

#### 涉及文件
- `MacIrlandApp/App/MacIrlandApp.swift`
- 如果需要抽组件，可新增或修改：`MacIrlandKit` / `MacIrlandApp` 下与菜单栏 label 对应的小型 SwiftUI view

#### 修改优先级
高。因为它是用户首先看到的部分，也是参考图 1 最直观能落地的一刀。

---

## 二、浮动面板外层视觉壳

### 当前状态
浮动面板的窗口由这里创建：
- `MacIrlandApp/App/PanelCoordinator.swift`

其中定义了：
- `NSPanel` 尺寸
- 标题栏风格
- 浮动级别
- 内容 root view

当前内容 view 是：

```swift
panel.contentView = NSHostingView(rootView: PanelView(viewModel: store))
```

这意味着真正需要做视觉升级的核心通常在：
- `PanelCoordinator.swift`（窗口壳和尺寸）
- `PanelView` 及其内部子视图（视觉结构）

### 如果要参考 `macirland2.png`，需要修改什么

#### 需要改的点
1. 调整 panel 的整体尺寸与边距感
2. 弱化传统窗口感，增强“悬浮卡片 / 岛屿”感
3. 让内容容器拥有更强的深色背景、圆角和层次
4. 在顶部加入明确的品牌头部区域

#### 可能涉及的代码层面
- 调整 `NSPanel` 的尺寸比例，让它更接近参考图的纵向信息面板
- 检查当前 `PanelView` 是否使用系统默认背景，如果是，需要改成自定义深色背景
- 在 `PanelView` 顶部增加 header：
  - 品牌标题 `macirland`
  - 辅助说明或状态摘要
- 统一外层 padding、圆角、分组间距

#### 涉及文件
至少会碰：
- `MacIrlandApp/App/PanelCoordinator.swift`
- `MacIrlandKit` 中定义 `PanelView` 的文件
- `MacIrlandKit` 中 `PanelView` 依赖的容器、section、row 视图文件

#### 修改优先级
最高。因为这是参考图 2 最核心的视觉差异来源，而且不一定需要先动业务逻辑，只改外层结构就能先明显提升观感。

---

## 三、Session 列表样式

### 当前状态
现在 session 列表已经能展示基础信息和选中详情，但从已有项目状态看，当前更像“功能列表”，还不像参考图中的产品化 feed。

### 如果要参考 `macirland2.png`，需要修改什么

#### 需要改的点
1. 把普通行样式升级为更像卡片或信息块的 row
2. 引入 chips/tag 来展示：
   - CLI 类型（Claude / Codex / Gemini）
   - 终端来源（Terminal / iTerm）
   - 最近活跃时间
   - 状态标签
3. 增强状态颜色、层级和节奏感
4. 让列表从“表格式扫描”变成“feed 式浏览”

#### 需要检查的内容
- 当前 session row 是在哪个文件定义的
- 当前 view model 是否已经提供：
  - CLI 类型
  - session 来源
  - 最近更新时间
  - 状态文本/枚举
- 如果数据还不够，需要在 `TaskStateStore` 或对应 view model 暴露更多 UI 所需字段

#### 涉及文件
大概率包括：
- `MacIrlandKit/Core/State/TaskStateStore.swift`
- `MacIrlandKit` 下 session list / row 对应 SwiftUI 文件
- 状态枚举或展示映射文件

#### 修改优先级
中高。它决定产品是不是像参考图 2 那样“有活力、有信息组织感”。

---

## 四、详情区 / 任务卡片区

### 当前状态
当前详情区已支持展示选中 session 的更多内容，但从项目描述和已有结构看，应该还偏工程化/诊断化。

### 如果要参考 `macirland2.png`，需要修改什么

#### 需要改的点
1. 把详情区域拆成多个清晰卡片
2. 把任务内容、摘要、reply、diagnostics 做层级区分
3. 减少“原始调试信息直接铺开”的感觉
4. 更强调当前任务、最近进度、是否需要用户输入

#### 推荐方向
- 用卡片分组：
  - 当前任务摘要卡
  - 对话 / 事件卡
  - 回复输入卡
  - 诊断信息卡（弱化视觉优先级）
- 在“需要用户处理”的状态上提高对比度

#### 涉及文件
- `PanelView` 详情区相关文件
- `MacIrlandKit/Features/Diagnostics/DiagnosticsSectionView.swift`
- reply 输入区域相关文件

#### 修改优先级
中。它很重要，但适合在外层壳和列表风格基本稳定后再推进。

---

## 五、视觉语言统一（颜色、圆角、字体层级、图标）

### 当前状态
目前项目更多是功能先行，视觉 token 可能还没有被系统化。

### 如果要参考两张图，需要补什么

#### 需要统一的内容
1. 深色背景体系
2. 面板/卡片/标签三层表面颜色
3. 圆角体系（大圆角、中圆角、胶囊）
4. 字号层级
5. 状态颜色体系
6. 图标风格统一

#### 推荐做法
不要一开始把这些散落在各个 view 里硬写，最好抽出一层轻量 UI token：
- `Color` 扩展
- `Spacing` 常量
- `CornerRadius` 常量
- `Tag` / `Chip` 公共组件
- `PanelCard` 公共容器组件

#### 涉及文件
- `MacIrlandKit` 下的共享 UI 组件与样式文件

#### 修改优先级
中。适合在第一轮外观改造之后收敛，不建议一开始就大范围抽象。

---

## 不建议本轮同时修改的内容
为了保持改造范围可控，这一轮不建议把下面这些一起重做：

1. **不要先重写 observation / state 逻辑**
   - 参考图主要是视觉表达变化，不是底层能力变化

2. **不要先做真实 reply bridge**
   - 这属于功能扩展，不属于参考图落地核心

3. **不要一开始就全量自定义 AppKit 菜单栏 item**
   - 当前 `MenuBarExtra` 已经解决了菜单栏生命周期问题
   - 如果直接切回深度自定义 `NSStatusItem`，范围会突然扩大

4. **不要一开始就做复杂动画**
   - 先把静态结构和视觉层级做对

---

## 建议的实施顺序

### 第一刀：先改主面板外层骨架
目标：让当前 panel 一眼看上去先接近 `macirland2.png`

建议只做：
- 深色背景
- 大圆角容器
- 顶部品牌 header
- 分区间距重排
- 基础阴影 / 层级调整

这一刀的特点：
- 视觉收益大
- 风险相对可控
- 对底层状态逻辑影响最小

### 第二刀：改 session 列表 row
目标：让列表更像 feed / activity stream

建议只做：
- row 卡片化
- chip 化元信息
- 状态色和时间信息重排

### 第三刀：改详情区卡片结构
目标：让详情区不再像工程调试页，而是像任务工作台

建议只做：
- 摘要卡
- 事件卡
- reply 区块
- diagnostics 弱化为次级区域

### 第四刀：再评估菜单栏入口是否要更像 `macirland1.png`
目标：在不显著增加宽度的前提下，尽量靠近参考图 1 的胶囊状态感

这一刀要注意：
- 刘海屏遮挡问题不能靠“移动位置”解决
- 只能通过更紧凑的视觉组件与更合理的信息密度来缓解

---

## 最小可执行版本建议
如果只允许先做一小刀，最值得先改的是：

**把当前浮动面板的外层视觉壳改成接近 `macirland2.png`。**

理由：
- 最能体现产品成熟度提升
- 不需要先改变真实数据流
- 用户一打开就能感知差异
- 比菜单栏入口做复杂胶囊样式更稳定

---

## 对后续实现的落地建议
后续正式开工时，建议先从这些文件入手排查：

- `MacIrlandApp/App/PanelCoordinator.swift`
- `MacIrlandApp/App/MacIrlandApp.swift`
- `MacIrlandKit/Core/State/TaskStateStore.swift`
- `MacIrlandKit/Features/Diagnostics/DiagnosticsSectionView.swift`
- `MacIrlandKit` 中承载 `PanelView`、session list、session row、detail section 的 SwiftUI 文件

实施时建议继续保持当前节奏：
- 一次只改一个窄切片
- 每一刀结束后更新 `CLAUDE.md`
- 每一刀都跑 `swift build` / `swift test`

---

## 结论
如果要让 MacIrland 的 UI 呈现形式参考这两张图片，当前最主要需要改的是：

1. `MacIrlandApp.swift` 中的菜单栏入口样式
2. `PanelCoordinator.swift` 与 `PanelView` 的外层浮动面板视觉骨架
3. session 列表的 row 呈现方式
4. 详情区的信息卡片结构
5. 一套轻量但统一的深色视觉语言

其中最推荐先落地的是：

**先把主浮动面板的外层壳子做成接近 `macirland2.png` 的样子。**
