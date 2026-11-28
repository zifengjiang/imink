# ExpandingDock 设计方案（UIKit 原生底导 · 真 Liquid Glass 精简并集版）

> **合规声明**：本实现 100% 独立编写，基于 Apple 官方公开框架（`UITabBarController`、`UINavigationController`、`UITabBarAppearance`、`UIVisualEffectView`、`UIGlassEffect`、`CAShapeLayer`、`UIViewPropertyAnimator`、`UISpringTimingParameters`）构建；**绝未复制任何 `AFK-surf/Comma`（AGPL-3.0）源码或引入其版权声明**。

---

## 1. 背景与为什么从 SwiftUI 重写为 UIKit

1. **底栏触控与液态光学透镜（`_UILiquidLensView` vs 静态胶囊位移）**：底栏直接使用真实系统 `UITabBar`（由 `UITabBarController` 驱动），原生激活 iOS 26 的 120Hz 光学折射透镜与系统级触控按压弹性。
2. **展开/收起的可打断物理连续性（`UIViewPropertyAnimator` vs 声明式 `Transition`）**：面板常驻于轻量 `UIView` 层级，从底导胶囊矩形 `bodyHeight = 0` 同源收腰生长（`scaleX: 0.80 -> 1.0`）与逐行错峰上浮全部由 `isInterruptible = true` 的 `UIViewPropertyAnimator` + `UISpringTimingParameters` 驱动，中途随时反点或下拉均可从当前插值平滑反向衔接。
3. **搜索框焦点、软键盘避让与零延迟 `UIControl` 响应**：`UITextField` 直接跟随 `keyboardAnimationCurve` 同频抬升面板，`UIScrollView(delaysContentTouches: false)` + 自定义 `UIControl` 实现触屏瞬时 `90ms` 微缩反馈。

---

## 2. 真机录屏 Bug 复盘与工程铁律

- **故障样本**：`/Users/jiangfeng/Documents/imink-design/dock-comma-glitch-record.mp4`（拼图见 `~/Documents/imink-design/comma-glitch-frames.png`，`#142 t=2.367s` 至 `#167 t=2.783s` 共 **`416.7ms`** 底栏其余 3 颗按钮消失）。
- **根因**：`experiment/comma-dock` 在展开与收起全程将 `systemBar.tabBar.alpha = 0` 并用离屏 `drawHierarchy` 静态快照替代，而离屏位图无法捕获 Liquid Glass 未选中按钮的 `CABackdropLayer` 混合层，再叠加双弹簧 `< 0.003` 长尾收敛阈值导致真栏被藏匿 `417ms`。
- **工程铁律**：实时 `UITabBar` 全程保持 `alpha = 1` 永不隐藏、**零静态快照**。

---

## 3. 真 Liquid Glass 材质升级与 `UIGlassEffect(.clear)` vs `.regular` 定量报告

### 3.1 为什么删除旧版毛玻璃标定层，以及如何用双层拓扑兼容 `UIGlassEffect` 并集轮廓

1. **彻底移除毛玻璃与白色系补救**：删除了旧版 `UIBlurEffect(.systemThickMaterial)`、`alpha = 0.038` 光学补偿层、白色 tint 以及全屏 `backdropBlurView`（`.systemUltraThinMaterial`），面板容器直接改用 iOS 26 原生 **`UIVisualEffectView` + `UIGlassEffect`**；`isInteractive = true` **仅开启在可点击控件**（标题栏放大镜按钮 `searchToggleGlassView` 与展开后的搜索框 `searchBoxGlassView`）上，面板背景玻璃 `platterGlassView` 保持 `isInteractive = false`。
2. **解决 `UIGlassEffect` 忽略 `UIView.mask` 的双层 Z 轴拓扑**：
   - 实测发现 iOS 26/27 的 `UIGlassEffect` 底层 SDF 渲染器忽略 `UIVisualEffectView.mask`（若把玻璃放在 `UITabBar` 前方延伸出血，会直接把底栏 4 颗图标一起模糊掉）。
   - 因此我们将面板拆为前后协同双层：
     - **Layer 2（玻璃物理层 `backgroundGlassContainerView`）**：严格插在 `backdropContainerView` 之上、**系统 `_UITabBarContainerView` 之下**。内部 `platterGlassView` 从面板顶沿一直延伸包住胶囊圆角（`height = bodyHeight + capsuleHeight`，`cornerRadius = capsuleR = 31.33pt`），并由 `platterHostView` 在胶囊赤道 `capsuleMidY` 做硬件矩形裁剪。这样面板左右外墙与圆肩三角区由同一块原生 `UIGlassEffect` 无缝填充，而实时 `UITabBar` 物理位于其前方，**4 颗按钮对比度留存率达 `100.0%~100.3%`（零模糊、零遮挡）**。
     - **Layer 4（交互内容层 `DockFilterPanelViewController.view`）**：仅承载标题栏、放大镜折叠搜索框、紧凑 `36pt` 列表行与上半拱微细连续描边，点击热区严格止于 `UITabBar` 顶沿。

### 3.2 `UIGlassEffect(.clear)` vs `UIGlassEffect(.regular)` 同坐标实测对比与选型结论

在 `iPhone 18 Pro`（`1206×2622`）真种子数据「全部对战」列表顶部（三次采样未遮挡区对齐误差 **`MAE = 0.000 RGB`**），将面板展开在高饱和橙色比分条（`真格区域 928计数`）与宝蓝色比分条（`真格区域 629计数`）正上方，对面板内纯玻璃无文字区（`x = 530..1020px, y = 1795..2340px`）逐像素取样（详见 `~/Documents/imink-design/uikit-dock-glass-blurcheck.png`）：

| 取样区域（同坐标像素数） | 面板外原色基准（Uncovered） | `UIGlassEffect(.clear)` 面板内 | `UIGlassEffect(.regular)` 面板内 |
| --- | --- | --- | --- |
| **高饱和橙色条**（`N = 1,726`） | `RGB(223.0, 102.1, 35.9)`<br>`HSV(21.2°, S=83.9%, V=87.4%)` | `RGB(241.2, 142.5, 88.6)`<br>`ΔRGB=(+18.3, +40.4, +52.6)`<br>`HSV(21.2°, S=63.3%)` **饱和度保留 `75.4%`** | `RGB(248.9, 238.0, 234.2)`<br>`ΔRGB=(+25.9, +135.9, +198.2)`<br>`HSV(15.8°, S=5.9%)` 饱和度仅剩 `7.1%` |
| **高饱和宝蓝条**（`N = 1,814`） | `RGB(52.4, 58.3, 195.3)`<br>`HSV(237.5°, S=73.2%, V=76.6%)` | `RGB(111.4, 116.1, 223.5)`<br>`ΔRGB=(+58.9, +57.8, +28.1)`<br>`HSV(237.5°, S=50.2%)` **饱和度保留 `68.6%`** | `RGB(237.2, 236.9, 249.1)`<br>`ΔRGB=(+184.7, +178.6, +53.8)`<br>`HSV(241.0°, S=4.9%)` 饱和度仅剩 `6.7%` |
| **白色卡片底面**（`N = 60,154`） | `RGB(251.7, 251.7, 252.9)` | `RGB(249.5, 248.8, 250.6)`（`ΔRGB ≈ -2.5`） | `RGB(245.3, 243.3, 246.4)`（`ΔRGB ≈ -7.1`） |
| **差分色差透过率 $\tau$**<br>（$\|\Delta\text{RGB}_{\text{glass}}\| / \|\Delta\text{RGB}_{\text{card}}\|$） | 基准橙蓝欧氏色差 `237.50` | **`τ = 79.6%`**（色差保留 `189.13`） | **`τ = 8.0%`**（色差仅剩 `19.06`，被严重漂白） |

- **最终选型与原因**：**最终选用 `UIGlassEffect(.clear)`**。原因在于 iOS 26 的 `.regular` 具有尺寸自适应雾度机制——在小尺寸胶囊（如 `62pt` 高的 `UITabBar`）上尚能透出柔和底色，但一旦扩展到 `361×280pt` 的面板尺寸，`.regular` 会自动叠加强烈白雾（透过率暴跌至 **`8.0%`**，饱和度丢失 `> 92%`，视觉上再次变成磨砂白塑料）；而 **`.clear`** 在完整面板尺寸下仍保持 **`79.6%` 的有效光学透过率**与 **`68.6%~75.4%` 的高饱和度保留率**（色相偏移 **`0.0°`**），边缘具备真实的液态透镜弯曲折射，与底部原生系统 `UITabBar` 属于同一透明玻璃族系（上下同屏对照见 `~/Documents/imink-design/uikit-dock-glass-native-vs-ours.png`）。

---

## 4. 面板信息架构瘦身（对齐首个参考视频量级）

1. **单一扁平列表，零分组标题**：彻底删除「对战模式 / 对战规则 / 打工规则」等全部分组标题；鲑鱼跑侧仅保留 5 行扁平项（`全部打工 / 鲑鱼跑 / 大型跑 / 团队打工竞赛 / 打工卡片`），对战侧同理一行一个模式/规则。
2. **删除「最近使用」整个分区**：消除与下方主列表的重复展示。
3. **删除底部「去筛选页设置更多条件…」入口行**：高阶筛选统一由各页面右上角导航栏筛选按钮承载，面板不再重复堆砌。
4. **搜索框收进标题栏放大镜按钮**：默认状态仅在标题栏右侧展示 `28×28pt` 放大镜图标（`expandingDock.searchToggleButton`，列表 `<= 6` 项及初始展开均默认折叠不占版面）；点击放大镜才弹簧展开 `36pt` 可交互玻璃输入框并唤起键盘。
5. **行高从 `40pt` 收紧至 `36pt`**：每行仅保留「`26pt` 圆角图标 + 加粗名称 +（选中态右侧 `✓`）」，彻底去掉 `›` 与数字角标等冗余装饰，面板展开总高度收敛至紧凑的 `242~284pt`。

---

## 5. 验收产物清单

- **展开态截图**：`~/Documents/imink-design/uikit-dock-glass-expanded.png`
- **搜索展开态截图**：`~/Documents/imink-design/uikit-dock-glass-search.png`
- **`.clear` vs `.regular` 透色取样核验图**：`~/Documents/imink-design/uikit-dock-glass-blurcheck.png`
- **同屏位置原生系统栏上下对照图**：`~/Documents/imink-design/uikit-dock-glass-native-vs-ours.png`
- **四阶段 60fps 演示录屏**：`~/Documents/imink-design/uikit-dock-glass.mp4`（`1206×2622`，`683` 帧 / `11.38s`：静止收起 → 展开精简 `.clear` 玻璃面板 → 点击标题栏放大镜展开搜索并过滤 `X比赛` → 点选自动回弹收起；非键盘遮挡段全部帧 4 颗底栏按钮对比度留存率 `95%~101%`，零快照、零闪烁）。
