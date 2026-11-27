# ExpandingDock 设计方案（imink 第一版）

## 1. 背景与「低改动高收益」架构拆分

### 1.1 为什么必须换掉系统浮动胶囊栏
iOS 26/27 的系统浮动胶囊 `TabView` 完全接管了底部标签栏绘制：`UITabBarItem`、`UITabBarAppearance` 与 `Tab` 自定义 `Label` 内的 `.font(...)` 均被系统忽略，且一旦构造新的 `UITabBarAppearance` 还会把全局 `AccentColor`（`#5639D6`）重置为系统蓝（详见 `Shared/Modifiers/AppTypography.swift` 顶部注释）。只有自绘底栏表面，才能拿回**全站游戏字体**（简中 `DFPZongYiW7` / 繁中 `DFP222` / 日文 `KurokaneStd-EB` / 韩文 `KoreanERIN-M` / 英文 `Splatfont 1`）、**`<= 49pt` 的轻薄高度**、圆角以及向上展开面板的控制权。

### 1.2 哪些用系统能力兜住 vs 哪些必须自绘（最小侵入原则）

为避免推倒重做整套根导航容器，我们采用**保留原生 `TabView` 容器 + 仅隐藏系统栏外观 + 叠放自绘 `ExpandingDock`** 的低改动高收益路径：

| 职责模块 | 实现归属 | 说明 |
| --- | --- | --- |
| **4 个根页面生命周期、懒加载与 `NavigationStack` 状态保持** | **系统能力兜住**（保留 `MainView` 原有 `TabView(selection: $tabSelection)`） | 不拆 `TabView`，通过 `.toolbar(useCustomDock ? .hidden : .visible, for: .tabBar)` 仅隐藏系统 `UITabBar` 视觉层；Tab 切换、状态保活、`.sheet` / `.fullScreenCover` 模态层级全部继续由系统托管。 |
| **兜底回退（`@AppStorage("imink.useCustomDock")`）** | **系统能力兜住** | 开关默认 `true`；切为 `false` 时恢复 `.toolbar(.visible, for: .tabBar)` 与 `.tabBarMinimizeBehavior(.onScrollDown)`，原系统 `TabView` 与顶部标题菜单零损可用。 |
| **完整多维筛选抽屉（`BattleFilterView` / `CoopFilterView`）** | **现有页面复用** | 继续使用原生 `.sheet` 承载场地、武器、时间滑杆、工友搜索、收藏/删除状态等重筛选，与 Dock 共用同一个 ViewModel 的 `@Published var filter: Filter`。 |
| **4-Tab 居中对称毛玻璃胶囊 + 二次点击同 Tab 向上展开模式快筛面板** | **必须自绘**（`ExpandingDock.swift`） | 保持「主页 / 对战 / 鲑鱼跑 / 我」**4 个等宽对称按钮**（无多余第 5 颗右圆钮）；首次点击未选中 Tab 切换页面，**在当前已选中 Tab 上再点一次**即向上原地形变为透明模式快筛面板，选完立即生效并自动回弹收起。 |
| **列表滚动自动退让与底部净空补齐** | **轻量适配**（`FloatingBarInsets.swift`） | 用 SwiftUI 原生 `.onScrollGeometryChange` 被动感知列表滚动方向，不挂额外手势；`FloatingBarInsets` 按新 Dock 实测顶沿（`68pt`）补齐 `8pt` 透明呼吸净空。 |

---

## 2. 参考实现的思路（未复制代码）

> **合规声明**：本节仅阅读并提炼架构与交互思路，**未复制任何源码，亦未引入任何第三方或 AGPL 代码与许可证文件**；所有代码均为针对 imink 业务与 SwiftUI 体系独立编写。

### 2.1 从 `afk-surf/comma` 学到的核心机制（仅借鉴思路，未复制代码）

精读了原视频对应的开源客户端 `afk-surf/comma` 中 `ShellTabBarController.swift`、`Design/Glass/GlassTabBar.swift`（`TabOverflowMenuView`）与 `Tasks/Dock/TaskDockViewController+Interaction.swift`，对照原视频逐帧图（`f001`～`f040`），提炼出 4 条关键机制：

1. **「左主胶囊 + 右独立圆钮」双体并列拓扑与底边锚定生长**：
   - 视频帧（`f001`、`f009`、`f014`、`f016`）与 `GlassTabBar.swift` 显示，底栏并非单一大长条，而是**左侧主胶囊 + `8~10pt` 间距 + 右侧等高独立正圆按钮**。
   - 展开时，左侧主胶囊**以底边 `maxY` 为不动锚点向上生长**为圆角卡片面板（`CGRect(x: bar.minX, y: bar.maxY - height, ...)`），右侧圆形按钮稳稳停留在原位（视觉上正好处于展开卡片的右下侧），再次点击该圆钮或点击外部遮罩即可原路折回胶囊，拇指无需移动位置。
2. **半高连续圆角（`thickness / 2`）与紧凑行高节奏**：
   - `TabOverflowMenuView` 将容器圆角固定为收起态厚度的一半（`.continuous` 连续曲率），使收起态天然是标准胶囊，展开态无需跳变圆角半径即可平滑过渡为大圆角面板；内部行高 `44~48pt`、外圈内边距 `8pt`，选中行带内嵌胶囊底块高亮。
3. **弹簧开合与逐行上浮微动效 + Reduce Motion 降级**：
   - 展开采用带轻微回弹的弹簧（时长约 `0.35s`、阻尼约 `0.72~0.78`），面板行带约 `10~14pt` 的自下而上微位移与淡入；收起采用更高阻尼（`~0.85+`）干脆落位，防止底边回弹穿模。
   - `TaskDockViewController+Interaction.swift` 显式检测 `UIAccessibility.isReduceMotionEnabled`，开启时放弃弹簧位移，降级为短促（`0.15~0.20s`）的 `.easeOut` 透明度过渡。
4. **手势隔离与滚动共存原则**：
   - 外部点击关闭手势仅在面板展开（`isOpen == true`）且触点落在面板 `frame` 之外时接收事件；收起态下容器空白区完全透传触摸，且绝不在 `UIScrollView` 内容区抢占纵向滚动手势；展开期间开启模态无障碍标记（`accessibilityViewIsModal`），收起瞬间立即释放。

#### 我们的实现为什么与 `afk-surf/comma` 截然不同

| 维度 | `afk-surf/comma`（原项目） | `imink`（我们的独立实现） |
| --- | --- | --- |
| **技术栈与复杂度** | 重度 UIKit：`ShellTabBarController`（1,200+ 行 `UITabBarController` 子类）+ `TabOverflowMenuView`（3,300+ 行基于 `CADisplayLink` 逐帧手算物理量的 `UIView`），目的是在静止态复用系统 `_UILiquidLensView` 并在折叠屏侧栏等 5 种姿态间做像素级接管。 | 纯声明式 SwiftUI（约 380 行）：保留 SwiftUI `TabView` 隐藏系统栏，叠加 `ExpandingDock` 视图，直接用 SwiftUI `spring` 动画、`.ultraThinMaterial` 与 `@Namespace` `matchedGeometryEffect`，零 `CADisplayLink`、零视图树遍历黑魔法。 |
| **底栏排版诉求** | 系统 SF Symbols 无文字图标栏（`home` / `inbox` / `people` + `more`）。 | 必须渲染 imink 专属 PDF 矢量图标（`TabBarHome` 等）+ **多语种游戏字体 11pt 标签**，且总高度压薄至 **`48pt`**（`<= 49pt`）。 |
| **主胶囊与右圆钮语义** | 左胶囊第 4 槽溢出二级导航页（`Apps` / `Drive` / `Plugins` / `Settings`），右圆钮打开 AI 对话路由层。 | 左胶囊完整承载 **4 个一级 Tab（主页 / 对战 / 鲑鱼跑 / 我）**；**右圆钮专职作为当前 Tab 的「模式快筛展开键」**，展开卡片承载数据库真实模式枚举与「去筛选页设置更多条件…」。 |

### 2.2 SwiftUI 社区近似实现对比（`mikonyaa/LiquidGlassTabBars`）

同时调研了社区纯 SwiftUI 实现 `mikonyaa/LiquidGlassTabBars`（`LiquidTabBar.swift` 与 `LiquidGlassSurfaceModifier.swift`）：

- **对方做法**：使用 `@Namespace` + `matchedGeometryEffect(id:in:)` 驱动选中胶囊在 Tab 间平滑横移（`.spring(response: 0.32, dampingFraction: 0.82)`）；通过 `LiquidGlassSurfaceModifier` 同时监听 `@Environment(\.accessibilityReduceMotion)` 与 `@Environment(\.accessibilityReduceTransparency)`（开启「降低透明度」时自动退化为实心底色 + `1pt` 描边）；支持重复点击当前 Tab 触发 `onReselect`。
- **我们借用的思路**：① 用 `@Namespace` + `matchedGeometryEffect` 实现 4 个 Tab 间的选中胶囊横移；② 同时尊重 `Reduce Motion` 与 `Reduce Transparency` 两项系统无障碍设置。
- **为什么不能直接引入该第三方依赖**：
  1. **缺少核心交互**：它只有水平胶囊切换，没有「右侧独立圆形按钮」与「向上弹开成筛选行列表面板」的状态机；
  2. **尺寸与字体不符**：其默认栏高 `60pt` 超过我们 `<= 49pt` 的硬指标，且写死了 `Image(systemName:)` 与系统 `.caption2` 字体，无法直接渲染 imink 矢量资源与游戏字体；
  3. **依赖与维护成本**：为百余行 UI 表层引入外部 SPM 包会增加构建供应链、Xcode 版本兼容与许可证审计负担，原生自写更轻、更可控。

---

## 3. 状态机设计（`DockState`）

```mermaid
stateDiagram-v2
    [*] --> collapsed
    collapsed --> expanded : 二次点击当前已选中的 Tab（或上拉胶囊）
    expanded --> collapsed : 再次点击当前 Tab / 点击模式行自动收起 / 点击外部遮罩 / 下滑面板
    collapsed --> scrollingHidden : 列表向下连续滚动 (y > 96pt 且累计下滑 > 28pt)
    scrollingHidden --> collapsed : 列表向上回滚 (> 12pt) / 回到顶部 / 触底 / 切换 Tab
```

| 状态 | 触发条件 | 视觉与交互表现 |
| --- | --- | --- |
| `collapsed`（收起常驻态） | 默认初始态；面板关闭后；列表在顶部（`y <= 24pt`）、向上回滚或滚到底部（距底 `<= 36pt`） | **居中对称 4-Tab 轻薄毛玻璃胶囊（`48pt` 高，无多余第 5 颗按钮）**，等宽排布「主页 / 对战 / 鲑鱼跑 / 我」；若对战或鲑鱼跑启用了筛选条件，对应 Tab 图标右上角显示 `6pt` 模式色圆点。首次点击未选中的 Tab 切换页面；**在当前已选中 Tab 上再点一次**即弹出该 Tab 的筛选面板。 |
| `expanded`（面板展开态） | 在当前已选中 Tab 上再点一次（或上拉胶囊） | 底层页面施加真实高斯模糊（`.blur(radius: 10)`）与极轻透点击层；4-Tab 胶囊通过 `GlassEffectContainer` + `glassEffectID` **连续向上生长形变**为透明毛玻璃面板，**原 4-Tab 胶囊常驻在面板最底部充当连续底座**（当前激活 Tab 图标翻转为 `chevron.down` 提示可再点收起）。点选任一单选模式行**立即同步 `Filter` 重筛列表，并在 80ms 视觉落定后带轻微回弹自动收起**；再次点击同 Tab、点外部遮罩或下滑面板亦可收起。 |
| `scrollingHidden`（滚动退让态） | 非展开态下，列表 `y > 96pt`、未触底且连续下滑 `> 28pt` | 像 iOS 26 一样自动退让：整组 Dock 向屏幕下方轻移并淡出（`offsetY: +68pt, scale: 0.94, opacity: 0`，关闭点击热区）；稍向上滑 `> 12pt` 或滑到底部立即回弹恢复 `collapsed`。滚动容器底部 `safeAreaInset` 保持恒定 `76pt` 不跳变。 |

---

## 4. 各状态尺寸、圆角、材质与阴影常量（4pt 栅格）

### 4.1 几何尺寸常量（`DockConfig`）

| 常量项 | 数值 | 设计说明 |
| --- | --- | --- |
| `collapsedHeight` | **`48pt`** | 严格 `<= 49pt`（比 iOS 26 系统浮动栏 `62pt` 薄 `14pt`），契合全站 `4pt` 栅格且满足 Apple HIG `>= 44pt` 触控高度；展开态下常驻于面板底部充当底座 |
| `cornerRadius` | **`24pt`**（`.continuous`） | `collapsedHeight / 2`，收起时为标准居中对称 4-Tab 胶囊，展开时通过 `glassEffectTransition(.matchedGeometry)` 同源形变为 `24pt` 连续曲率透明面板 |
| `tabPillHeight` / `tabPillInset` | **`40pt`** / **`4pt`** | 4 个按钮在 `HStack(spacing: 4)` 内等宽均分；内部选中滑块圆角 `20pt`（`24 - 4 = 20` 同心圆角）；图标 `18×18pt` + `11pt` 游戏字体单行文案 |
| `panelRowHeight` / `panelIconSize` | **`40pt`** / **`28×28pt`** | 紧凑单行高度 `40pt` + `28pt` 图标块，保证对战全部 7 个模式 + 更多条件行 + 底部 `48pt` 胶囊底座在单屏完整放下无需内滚；单选模式行仅在选中态显示右侧 `✓`（无多余 `›`），导航行显示 `›` |
| `horizontalMargin` / `maxDockWidth` | **`20pt`** / **`368pt`** | 去掉第 5 颗右圆钮后恢复左右完全对称边距 `20pt`；大屏总宽封顶 `368pt` 居中悬浮 |
| `bottomMargin` | Face ID 机型 **`20pt`**（`max(safeArea.bottom - 14, 16)`）；无安全区机型 **`12pt`** | 精准悬停在 Home Indicator 上方，不压系统手势条 |
| `tabBarTopFromScreenBottom` | Face ID 机型 **`68pt`**（`20 + 48`） | 实测值同步写入 `FloatingBarInsets.measuredCustomDockTop` / `measuredTabBarTop`，加上 `breathingSpacing = 8pt` 后列表底部总净空 **`76pt`** |

### 4.2 材质与背景虚化（原生 Liquid Glass）

- **统一毛玻璃材质**：居中对称 4-Tab 胶囊与展开面板置于同一个 `GlassEffectContainer(spacing: 0)` 内，直接调用 iOS 26 原生 `.glassEffect(.regular.interactive(), in: shape)` + `.glassEffectID("dock.primaryPlatter", in: glassNamespace)` + `.glassEffectTransition(.matchedGeometry)`，面板内部行采用全透明底（仅选中行叠 `Color.accentColor.opacity(0.13~0.22)` 轻透高亮胶囊），让底层折射色彩自然透出；当系统开启「降低透明度」（`accessibilityReduceTransparency`）时自动降级为 `.ultraThinMaterial` + `1pt` `.white.opacity(0.35)` 描边 + 柔和阴影。
- **展开背景景深虚化**：对 `MainView` 底层 `tabViewCore` 施加 `.blur(radius: 10 * (1 - dragDismissProgress))` 配合极轻遮罩（浅色 `0.08` / 深色 `0.22`），消除死板纯灰蒙层，拉出通透景深层次。

---

## 5. 动画参数与手感取舍

- **非对称开合弹簧（`DockMotion`）**：展开采用 **`.spring(response: 0.35, dampingFraction: 0.72)`**（带轻快开弹张力），收起采用 **`.spring(response: 0.28, dampingFraction: 0.94)`**（高阻尼干脆落位、绝不穿底），保留 `GlassEffectContainer` + `glassEffectID` + `glassEffectTransition(.matchedGeometry)` 连续形变，且底部 4-Tab 胶囊底边始终锁死在 `bottomMargin` 零跳位。
- **水平微收腰脉冲（SwiftUI `keyframeAnimator`）**：不缩放文字与圆角，直接通过 `KeyframeTrack(\.widthScale)` 驱动玻璃容器宽度——展开过程先在 `85ms` 内压至 **`0.80`** 再经弹簧回弹至 `1.0`；收起过程先在 `60ms` 内压至 **`0.82`** 再以 `0.94` 高阻尼归稳至 `1.0`，赋予玻璃液滴被向上拉扯与收回时的流体张力。
- **逐行错峰上浮与反序快收（`staggeredRowTransition`）**：面板行取消整体位移，每行独立应用 `AnyTransition.asymmetric`——展开自底向上按 `delay: index * 0.030s` 执行 `opacity 0→1` + `offset(y: +10→0)` + `blur(radius: 3→0)`；收起反序自顶向下按 `0.011s` 阶梯 + `0.088s` 单行时长（9 槽位总时长 `0.176s <= 0.18s`）快速收拢。
- **手势跟手与单选自动收起**：下拉面板时采用 `.interactiveSpring(response: 0.26, dampingFraction: 0.84)` 实时联动面板位移与背景模糊半径；点选单选模式行立刻刷新 `Filter` 重筛列表，停留 `80ms` 确认勾选后触发高阻尼收起曲线自动收回。
- **无障碍减弱动态效果（`UIAccessibility.isReduceMotionEnabled`）**：开启时关闭水平收腰、逐行位移与模糊，全面降级为纯淡入淡出（`.easeOut(duration: 0.18)`）。

---

## 6. 模式筛选进 Dock 后的信息架构与真实枚举覆盖

经核查 `Shared/Models/BattleMode.swift`、`Shared/Models/CoopRule.swift`、`Shared/Data/RecordListQueries.swift` 以及本地真实种子库 `seed-db.sqlite`（`SELECT DISTINCT mode FROM battle` 与 `SELECT DISTINCT rule FROM coop`）：

### 6.1 面板内快筛枚举、36pt 搜索框与「最近使用」分区

- **36pt 玻璃搜索框**：位于面板标题行下方、所有分组之前，采用 `magnifyingglass` 图标 + `TextField("搜索模式或规则", text: $searchText)` + `.textFieldStyle(.plain)`，高 `36pt`、圆角 `12pt`、轻透玻璃材质底；支持对**模式名 + 规则名**（如输入「涂地」匹配「涂地模式」、输入「X」匹配「X比赛」）进行大小写不敏感、忽略空白字符的实时过滤，无匹配结果时展示 40pt 占位行「没有匹配的筛选项」。
- **键盘避让与关闭时序**：监听 `UIResponder.keyboardWillChangeFrameNotification` 动态抬升 `effectiveBottomMargin = keyboardOverlap + 8`，保证软键盘弹出时整组面板与底部 4-Tab Dock 整体上移不被键盘遮住；点击遮罩或下滑面板时**先触发收起键盘，再收起面板**。
- **「最近使用」分区（`@AppStorage("imink.dock.recentModes")`）**：记录用户最近点选过的最多 **3** 个模式/规则，显示于搜索框正下方、常规分组上方；为空时自动隐藏该分区。

1. **对战 Tab（Tab 1，`BattleMode`，查询列 `battle.mode`）**：
   - `BattleMode.all`（`"ALL"` → **全部对战**，对应 `filter.modes = []`）
   - `BattleMode.regular`（`"REGULAR"` → **一般比赛** / 占地涂地）
   - `BattleMode.anarchy`（`"BANKARA"` → **蛮颓比赛** / 真格系列）
   - `BattleMode.xMatch`（`"XMATCH"` → **X比赛**）
   - `BattleMode.league`（`"LEAGUE"` → **活动比赛**）
   - `BattleMode.privateMatch`（`"PRIVATE"` → **私人比赛**）
   - `BattleMode.fest`（`"FEST"` → **祭典比赛**）
   - 底部固定入口：**「去筛选页设置更多条件…」**（右侧带剩余激活条件计数与 `›` chevron，点击收起 Dock 并弹出 `BattleFilterView`）。
2. **鲑鱼跑 Tab（Tab 2，`CoopRule`，查询列 `coop.rule`）**：
   - `CoopRule.ALL`（`"ALL_RULE"` → **全部打工**，对应 `filter.rules = []`）
   - `CoopRule.REGULAR`（`"REGULAR"` → **鲑鱼跑**）
   - `CoopRule.BIG_RUN`（`"BIG_RUN"` → **大型跑**）
   - `CoopRule.TEAM_CONTEST`（`"TEAM_CONTEST"` → **团队打工竞赛**）
   - 视图切换行：**打工卡片**（调用 `loadCards()` 按班次聚合浏览，对齐原顶部菜单能力）
   - 底部固定入口：**「去筛选页设置更多条件…」**（右侧带场地/武器/工友/时段等已启用条件数与 `›` chevron，点击收起 Dock 并弹出 `CoopFilterView`）。
3. **主页 Tab（Tab 0）与 我 Tab（Tab 3）**：
   - 主页展开面板提供「对战日程 / 鲑鱼跑日程」快切（双向绑定 `@AppStorage("home_page_selectedScheduleType")`）以及直达对战/打工筛选入口；
   - 「我」页展开面板提供「武器榜 / 场地榜 / 记录回收站 / 偏好设置」快捷跳转行（每行带 `›` chevron），保证在任意 Tab 点开右端圆钮都有实用一致的面板体验。

### 6.2 哪些留在筛选页 Sheet + 双向同步机制

- **留在 `BattleFilterView` / `CoopFilterView` 的重条件**：多模式并集勾选（如同时看蛮颓 + X比赛）、起止日期范围双滑杆、地图多选网格、配发武器 11 大类多选、同工玩家搜索与精确匹配、活跃/已删除记录范围、只显示收藏、一键重置。
- **双向同步**：
  - Dock 与 `BattleFilterView` 共同读写 `BattleListViewModel.shared.filter`；与 `CoopFilterView` 共同读写 `CoopListViewModel.shared.filter`（`CoopFilterView` 同步补齐打工规则筛选区块与概览标签展示，确保从 Dock 选完「大型跑」进 `CoopFilterView` 能直观看到并支持重置联动）。
  - 在 Dock 点选某模式时仅修改 `filter.modes` / `filter.rules`，完整保留收藏、地图、武器等其他已选条件，同时立即刷新 `navigationTitle` 与列表数据。

---

## 7. 风险清单与应对

1. **手势冲突（横向滚动 vs 拖拽展开 vs 系统上滑回桌面）**：
   - 第一版**不绑定底部边缘上滑拖拽展开手势**，严格采用「点右端圆钮展开、点遮罩或圆钮收起」，从根源上杜绝与 iOS Home Indicator 手势、首页轮播 `CarouselView` 横滑及列表纵滑抢事件。列表滚动隐藏采用纯被动的 `onScrollGeometryChange` 监听。
2. **安全区与 `FloatingBarInsets` 留白精度**：
   - 当 `useCustomDock == true` 时，`TabView` 系统栏隐藏后子容器 `safeAreaInsets.bottom` 变为 `34pt`（仅 Home Indicator）。`FloatingBarInsets` 区分新旧模式：自定义 Dock 模式下不再被 `34pt` 误覆盖 `measuredTabBarTop`，而是按实测 Dock 顶沿 `68pt` + `8pt` 呼吸间距补齐差额 `42pt`（总净空 `76pt`）；切回旧系统栏（`useCustomDock == false`）时自动恢复 `83pt + 8pt = 91pt`。
3. **iPad 与横屏适配**：
   - 限制 Dock 总宽上限 `392pt` 居中悬浮，避免在 iPad 上拉成横跨全屏的宽条；展开面板加 `ScrollView` 最大高度保护（`min(screenHeight * 0.62, 428pt)`），横屏矮视口下可顺滑滚动不顶穿导航栏。
4. **Live Activity 与顶部 Toast 并存**：
   - 灵动岛 `LiveActivityManager` 与居顶的 `SplatoonToastOverlay` 位于屏幕顶部；`.sheet` / `.fullScreenCover` 位于系统模态层高于 `MainView`，且从 Dock 打开筛选 Sheet 时先收起面板，视觉层级互不干扰。
5. **无障碍（VoiceOver / Reduce Motion / Reduce Transparency / Dynamic Type）**：
   - 完整支持 `UIAccessibility.isReduceMotionEnabled`（`0.2s easeOut` 无缩放）与 `accessibilityReduceTransparency`（实心高对比底色）；展开态为面板标记 `.accessibilityAddTraits(.isModal)` 并隐藏背景可访问性焦点；底栏胶囊限制 `.dynamicTypeSize(...DynamicTypeSize.xLarge)` 防止超大字号撑破 `48pt` 胶囊，同时为所有按钮标注清晰的中文 `accessibilityLabel` 与选中状态。
