# PRD: 共享 Indicator 管理系统

## 1. 背景与问题

### 1.1 当前问题
- **独立调用问题**：每个业务函数（如 `fetchBattles()`、`fetchCoops()`、`fetchRecord()` 等）都独立创建和管理自己的 Indicator，使用 `UUID().uuidString` 作为唯一标识
- **重叠显示问题**：当多个任务同时执行时（如后台刷新时同时获取对战和鲑鱼跑记录），会显示多个重叠的 Indicator，用户体验不佳
- **缺乏统一管理**：没有统一的机制来协调多个相关任务的 Indicator 显示

### 1.2 典型场景
1. **后台数据刷新**：`BackgroundTaskManager` 中同时调用 `fetchBattles()` 和 `fetchCoops()`
2. **手动刷新**：用户同时触发多个数据获取任务
3. **登录流程**：登录过程中涉及多个步骤（获取 token、下载头像、保存账户信息等）
4. **数据导入/导出**：批量操作时可能有多个子任务
5. **实时任务**：用户启动数据刷新后切换到后台，任务应继续执行并在灵动岛显示进度

## 2. 目标

### 2.1 核心目标
- **统一管理**：提供业务专属的 API，让相关任务能够共享同一个 Indicator
- **避免重叠**：同时出现的任务显示在同一个 Indicator 中，而不是多个重叠的 Indicator
- **向后兼容**：保持现有 API 的兼容性，不影响现有代码
- **实时任务支持**：任务可以在应用进入后台后继续执行，不因应用切换而暂停
- **灵动岛支持**：使用 Live Activities 在灵动岛和锁屏显示任务进度

### 2.2 用户体验目标
- 用户看到统一的加载状态，而不是多个重叠的提示
- 能够清楚地看到当前正在执行的所有任务
- 任务完成后有清晰的反馈
- **后台执行**：应用切换到后台时，任务继续执行，用户可以在灵动岛看到进度
- **无缝体验**：应用返回前台时，任务状态无缝同步，Indicator 自动更新

## 3. 功能需求

### 3.1 核心功能

#### 3.1.1 任务组（Task Group）概念
- 引入"任务组"概念，将相关的异步任务归类到同一个组
- 每个任务组对应一个共享的 Indicator ID
- 任务组可以动态添加和移除子任务

#### 3.1.2 共享 Indicator API
提供以下业务专属的 API：

```swift
// 1. 创建或获取任务组的共享 Indicator
func acquireSharedIndicator(
    groupId: String,  // 任务组ID，如 "data-refresh", "login-flow"
    title: String,
    icon: Indicator.Icon = .progressIndicator,
    supportsLiveActivity: Bool = false,  // 是否支持 Live Activity
    allowBackgroundExecution: Bool = false  // 是否允许后台执行
) -> String  // 返回共享的 Indicator ID

// 2. 在任务组中注册子任务
func registerSubTask(
    groupId: String,
    taskName: String  // 子任务名称，如 "获取对战记录", "获取鲑鱼跑记录"
)

// 3. 完成子任务
func completeSubTask(
    groupId: String,
    taskName: String
)

// 4. 更新任务组 Indicator 的标题（自动聚合所有子任务状态）
func updateGroupTitle(groupId: String)

// 5. 更新任务进度
func updateTaskProgress(
    groupId: String,
    progress: Double  // 0.0 - 1.0
)

// 6. 完成整个任务组
func completeTaskGroup(
    groupId: String,
    success: Bool,
    message: String?
)

// 7. 启动实时任务（后台执行 + Live Activity）
func startRealtimeTask(
    groupId: String,
    title: String,
    icon: Indicator.Icon = .progressIndicator
) async throws -> String

// 8. 停止实时任务
func stopRealtimeTask(groupId: String)
```

#### 3.1.3 Indicator 显示逻辑
- **标题显示**：显示任务组名称和当前活跃的子任务列表
  - 示例："正在加载数据 (获取对战记录、获取鲑鱼跑记录)"
  - 当子任务完成时，从列表中移除
- **进度显示**：如果有多个子任务，可以显示整体进度
- **状态更新**：所有子任务完成后，自动更新为成功状态

#### 3.1.4 实时任务与 Live Activity 支持
- **后台执行**：标记为实时任务的任务组，在应用进入后台后继续执行
- **Live Activity 显示**：
  - 在 iPhone 14 Pro 及更新机型的灵动岛显示任务进度
  - 在锁屏界面显示任务状态
  - 支持动态更新进度和状态
- **状态同步**：应用返回前台时，自动同步 Live Activity 状态到应用内 Indicator
- **自动切换**：应用在前台时显示应用内 Indicator，进入后台时自动切换到 Live Activity

### 3.2 业务场景适配

#### 3.2.1 数据刷新场景
```swift
// 后台刷新时
let groupId = "background-refresh-\(UUID().uuidString)"
let indicatorId = Indicators.shared.acquireSharedIndicator(
    groupId: groupId,
    title: "正在刷新数据"
)

// fetchBattles 和 fetchCoops 都使用同一个 groupId
Indicators.shared.registerSubTask(groupId: groupId, taskName: "获取对战记录")
await SN3Client.shared.fetchBattles(groupId: groupId)
Indicators.shared.completeSubTask(groupId: groupId, taskName: "获取对战记录")

Indicators.shared.registerSubTask(groupId: groupId, taskName: "获取鲑鱼跑记录")
await SN3Client.shared.fetchCoops(groupId: groupId)
Indicators.shared.completeSubTask(groupId: groupId, taskName: "获取鲑鱼跑记录")

Indicators.shared.completeTaskGroup(groupId: groupId, success: true, message: nil)
```

#### 3.2.2 登录流程场景
```swift
let groupId = "login-flow-\(UUID().uuidString)"
let indicatorId = Indicators.shared.acquireSharedIndicator(
    groupId: groupId,
    title: "登录中"
)

// 各个步骤注册为子任务
Indicators.shared.registerSubTask(groupId: groupId, taskName: "获取sessionToken")
// ... 执行登录步骤 ...
Indicators.shared.completeSubTask(groupId: groupId, taskName: "获取sessionToken")

Indicators.shared.registerSubTask(groupId: groupId, taskName: "设置游戏服务令牌")
// ... 执行步骤 ...
Indicators.shared.completeSubTask(groupId: groupId, taskName: "设置游戏服务令牌")
```

#### 3.2.3 实时任务场景（支持后台执行和 Live Activity）
```swift
// 用户手动触发数据刷新
let groupId = "realtime-refresh-\(UUID().uuidString)"

// 启动实时任务（自动启用后台执行和 Live Activity）
let indicatorId = try await Indicators.shared.startRealtimeTask(
    groupId: groupId,
    title: "正在刷新数据",
    icon: .progressIndicator
)

// 注册子任务（会自动同步到 Live Activity）
Indicators.shared.registerSubTask(groupId: groupId, taskName: "获取对战记录")
await SN3Client.shared.fetchBattles(groupId: groupId)
Indicators.shared.completeSubTask(groupId: groupId, taskName: "获取对战记录")
Indicators.shared.updateTaskProgress(groupId: groupId, progress: 0.5)

Indicators.shared.registerSubTask(groupId: groupId, taskName: "获取鲑鱼跑记录")
await SN3Client.shared.fetchCoops(groupId: groupId)
Indicators.shared.completeSubTask(groupId: groupId, taskName: "获取鲑鱼跑记录")
Indicators.shared.updateTaskProgress(groupId: groupId, progress: 1.0)

// 完成任务（Live Activity 会自动更新并延迟关闭）
Indicators.shared.completeTaskGroup(
    groupId: groupId,
    success: true,
    message: "成功加载 15 个对战记录、8 个鲑鱼跑记录"
)
```

### 3.3 技术实现要点

#### 3.3.1 数据结构
```swift
class TaskGroup {
    let id: String
    var indicatorId: String
    var activeTasks: Set<String>  // 当前活跃的子任务名称
    var completedTasks: Set<String>  // 已完成的子任务名称
    var title: String
    var icon: Indicator.Icon
    var createdAt: Date
    var progress: Double?  // 整体进度 0.0 - 1.0
    var supportsLiveActivity: Bool  // 是否支持 Live Activity
    var allowBackgroundExecution: Bool  // 是否允许后台执行
    var liveActivityToken: String?  // Live Activity 的 token
    var backgroundTaskIdentifier: UIBackgroundTaskIdentifier?  // 后台任务标识符
}
```

#### 3.3.2 Indicators 扩展
在 `Indicators` 类中添加：
- `taskGroups: [String: TaskGroup]` - 存储所有任务组
- `liveActivityManager: LiveActivityManager?` - Live Activity 管理器
- 上述的业务专属 API 方法
- 自动更新 Indicator 标题的逻辑
- 应用生命周期监听（前台/后台切换）

#### 3.3.3 Live Activity 管理器
创建 `LiveActivityManager` 类：
- 管理 Live Activity 的创建、更新和结束
- 处理应用前后台切换时的状态同步
- 使用 ActivityKit 框架（iOS 16+）

#### 3.3.4 后台任务管理
- 使用 `UIApplication.beginBackgroundTask()` 申请后台执行时间
- 监听应用生命周期事件（`willResignActive`、`didEnterBackground`、`didBecomeActive`）
- 应用进入后台时，自动切换到 Live Activity 显示
- 应用返回前台时，同步 Live Activity 状态到应用内 Indicator

#### 3.3.5 向后兼容
- 现有的 `display()`、`dismiss()` 等方法保持不变
- 如果调用方不提供 `groupId`，则使用原有的独立 Indicator 逻辑
- 通过可选参数的方式引入新功能
- Live Activity 功能需要 iOS 16+，低版本自动降级到普通 Indicator

## 4. 设计方案

### 4.1 架构设计

```
Indicators (单例)
├── 现有方法（保持不变）
│   ├── display(_ indicator: Indicator)
│   ├── dismiss(with id: String)
│   └── updateTitle/Icon/Subtitle...
│
├── 新增：任务组管理
│   ├── taskGroups: [String: TaskGroup]
│   ├── acquireSharedIndicator(...)
│   ├── registerSubTask(...)
│   ├── completeSubTask(...)
│   ├── updateGroupTitle(...)
│   ├── updateTaskProgress(...)
│   └── completeTaskGroup(...)
│
├── 新增：实时任务支持
│   ├── startRealtimeTask(...)
│   ├── stopRealtimeTask(...)
│   ├── handleAppWillResignActive()
│   ├── handleAppDidEnterBackground()
│   └── handleAppDidBecomeActive()
│
└── 新增：Live Activity 管理器
    └── LiveActivityManager
        ├── startActivity(for: TaskGroup)
        ├── updateActivity(for: TaskGroup)
        ├── endActivity(for: TaskGroup)
        └── syncFromActivity(to: Indicator)
```

### 4.2 工作流程

1. **创建任务组**
   - 调用 `acquireSharedIndicator()` 创建或获取任务组的 Indicator
   - 如果任务组已存在，返回现有的 Indicator ID

2. **注册子任务**
   - 调用 `registerSubTask()` 添加子任务
   - 自动更新 Indicator 标题，显示当前活跃的子任务

3. **更新进度**
   - 子任务执行过程中可以调用 `updateTitle()` 更新详细状态
   - 系统自动聚合多个子任务的状态

4. **完成子任务**
   - 调用 `completeSubTask()` 标记子任务完成
   - 自动从活跃任务列表中移除

5. **更新进度**
   - 调用 `updateTaskProgress()` 更新任务进度
   - 如果启用了 Live Activity，同步更新 Live Activity

6. **完成任务组**
   - 调用 `completeTaskGroup()` 完成整个任务组
   - 更新 Indicator 为成功/失败状态
   - 如果启用了 Live Activity，更新 Live Activity 状态
   - 延迟后自动关闭 Indicator 和 Live Activity

7. **应用生命周期处理**
   - **进入后台**：如果任务组支持后台执行，申请后台任务时间；如果支持 Live Activity，启动 Live Activity
   - **返回前台**：同步 Live Activity 状态到应用内 Indicator，关闭 Live Activity
   - **任务完成**：释放后台任务资源

### 4.3 UI 显示示例

**场景1：单个任务**
```
标题：正在加载对战记录
图标：进度指示器
```

**场景2：多个任务**
```
标题：正在加载数据
副标题：获取对战记录、获取鲑鱼跑记录
图标：进度指示器
```

**场景3：部分完成**
```
标题：正在加载数据
副标题：获取对战记录（已完成）、获取鲑鱼跑记录
图标：进度指示器
```

**场景4：全部完成**
```
标题：数据加载完成
副标题：成功加载 15 个对战记录、8 个鲑鱼跑记录
图标：成功图标
```

**场景5：实时任务（应用在前台）**
```
标题：正在刷新数据
副标题：获取对战记录、获取鲑鱼跑记录
图标：进度指示器
进度条：50%
```

**场景6：实时任务（应用在后台，Live Activity）**
```
灵动岛/锁屏显示：
┌─────────────────────────┐
│ 🔄 正在刷新数据          │
│ 获取对战记录 ✓           │
│ 获取鲑鱼跑记录...        │
│ ▓▓▓▓▓▓░░░░ 50%          │
└─────────────────────────┘
```

## 5. 实施计划

### 5.1 阶段一：核心功能开发
1. 在 `Indicators` 类中添加 `TaskGroup` 数据结构
2. 实现 `acquireSharedIndicator()` 方法
3. 实现 `registerSubTask()` 和 `completeSubTask()` 方法
4. 实现自动更新标题的逻辑
5. 实现 `updateTaskProgress()` 方法

### 5.2 阶段二：实时任务支持
1. 实现后台任务管理（`UIApplication.beginBackgroundTask`）
2. 监听应用生命周期事件
3. 实现应用前后台切换时的状态管理
4. 测试后台任务执行

### 5.3 阶段三：Live Activity 集成
1. 创建 `LiveActivityManager` 类
2. 定义 Live Activity 的数据模型（使用 ActivityKit）
3. 实现 Live Activity 的创建、更新和结束
4. 实现应用前后台切换时的 Live Activity 同步
5. 创建 Live Activity Widget Extension（用于显示 UI）

### 5.4 阶段四：业务适配
1. 修改 `runPipeline()` 方法，支持可选的 `groupId` 参数
2. 修改 `fetchBattles()` 和 `fetchCoops()`，支持任务组和实时任务
3. 修改 `BackgroundTaskManager`，使用共享 Indicator
4. 修改 `LoginViewModel`，使用共享 Indicator
5. 在用户手动刷新时启用实时任务支持

### 5.5 阶段五：测试与优化
1. 测试多个任务同时执行的情况
2. 测试任务取消的情况
3. 测试错误处理
4. 测试应用前后台切换的场景
5. 测试 Live Activity 在不同设备上的显示效果
6. 优化 UI 显示效果和性能

## 6. 边界情况处理

### 6.1 任务取消
- 如果任务被取消，自动从任务组中移除
- 如果任务组为空，自动关闭 Indicator

### 6.2 错误处理
- 子任务失败时，在 Indicator 中显示错误信息
- 任务组可以标记为部分成功

### 6.3 并发安全
- 所有对 `taskGroups` 的访问都需要线程安全
- 使用 `@MainActor` 或锁机制保证线程安全

### 6.4 内存管理
- 任务组完成后，延迟清理（避免频繁创建/销毁）
- 设置最大任务组数量限制
- Live Activity 结束后及时释放资源

### 6.5 后台执行限制
- iOS 系统对后台执行时间有限制（通常约 30 秒）
- 如果任务执行时间较长，需要：
  - 使用 `BGTaskScheduler` 进行后台任务调度（已有实现）
  - 或者将长时间任务拆分为多个短任务
  - 在 Live Activity 中提示用户任务仍在进行

### 6.6 Live Activity 限制
- Live Activity 需要 iOS 16+ 支持
- 每个应用最多同时显示 5 个 Live Activity
- Live Activity 有大小限制（建议内容简洁）
- 需要用户授权才能显示 Live Activity

### 6.7 设备兼容性
- Live Activity 在 iPhone 14 Pro 及更新机型上显示在灵动岛
- 其他支持 iOS 16+ 的设备显示在锁屏
- 低版本 iOS 自动降级到普通 Indicator

## 7. 技术实现细节

### 7.1 Live Activity 数据模型

```swift
import ActivityKit
import WidgetKit

// Live Activity 的内容数据
struct TaskGroupActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var title: String
        var subtitle: String?
        var progress: Double?
        var activeTasks: [String]
        var completedTasks: [String]
        var status: TaskStatus  // .inProgress, .completed, .failed
    }
    
    var groupId: String
    var icon: String
}

enum TaskStatus: String, Codable {
    case inProgress
    case completed
    case failed
}
```

### 7.2 Live Activity Widget UI

```swift
import WidgetKit
import SwiftUI

struct TaskGroupActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TaskGroupActivityAttributes.self) { context in
            // 紧凑视图（灵动岛）
            TaskGroupCompactView(state: context.state)
        } dynamicIsland: { context in
            DynamicIsland {
                // 展开区域
                DynamicIslandExpandedRegion(.leading) {
                    // 左侧内容
                }
                DynamicIslandExpandedRegion(.trailing) {
                    // 右侧内容
                }
                DynamicIslandExpandedRegion(.bottom) {
                    // 底部内容（任务列表和进度）
                }
            } compactLeading: {
                // 紧凑模式左侧
            } compactTrailing: {
                // 紧凑模式右侧
            } minimal: {
                // 最小化模式
            }
        }
    }
}
```

### 7.3 后台任务实现示例

```swift
extension Indicators {
    func startBackgroundTask(for groupId: String) {
        guard let taskGroup = taskGroups[groupId],
              taskGroup.allowBackgroundExecution else { return }
        
        let identifier = UIApplication.shared.beginBackgroundTask { [weak self] in
            // 后台时间即将用完
            self?.handleBackgroundTaskExpiration(groupId: groupId)
        }
        
        taskGroup.backgroundTaskIdentifier = identifier
    }
    
    func endBackgroundTask(for groupId: String) {
        guard let taskGroup = taskGroups[groupId],
              let identifier = taskGroup.backgroundTaskIdentifier else { return }
        
        UIApplication.shared.endBackgroundTask(identifier)
        taskGroup.backgroundTaskIdentifier = nil
    }
}
```

### 7.4 应用生命周期处理

```swift
extension Indicators {
    func handleAppWillResignActive() {
        // 遍历所有支持实时任务的任务组
        for (groupId, taskGroup) in taskGroups {
            if taskGroup.supportsLiveActivity {
                // 启动 Live Activity
                liveActivityManager?.startActivity(for: taskGroup)
            }
            
            if taskGroup.allowBackgroundExecution {
                // 申请后台执行时间
                startBackgroundTask(for: groupId)
            }
        }
    }
    
    func handleAppDidBecomeActive() {
        // 同步 Live Activity 状态到应用内 Indicator
        for (groupId, taskGroup) in taskGroups {
            if taskGroup.supportsLiveActivity {
                liveActivityManager?.syncFromActivity(to: taskGroup)
                liveActivityManager?.endActivity(for: taskGroup)
            }
            
            // 结束后台任务
            endBackgroundTask(for: groupId)
        }
    }
}
```

### 7.5 配置要求

#### 7.5.1 Info.plist 配置
需要在 `Info.plist` 中添加 Live Activity 支持：
```xml
<key>NSSupportsLiveActivities</key>
<true/>
```

#### 7.5.2 Capabilities 配置
- 启用 Background Modes（已有）
  - Background fetch
  - Background processing
  - Background app refresh
- 添加 Live Activities capability（新增）

#### 7.5.3 Widget Extension 配置
- 创建 Widget Extension Target
- 配置 Widget Bundle
- 实现 Live Activity Widget UI

## 8. 成功指标

- ✅ 多个相关任务共享同一个 Indicator
- ✅ 不再出现重叠的 Indicator
- ✅ 用户能够清楚地看到当前执行的所有任务
- ✅ 现有代码无需大幅修改即可使用新功能
- ✅ 代码可维护性和可扩展性提升
- ✅ **实时任务支持**：应用进入后台后任务继续执行
- ✅ **Live Activity 集成**：在灵动岛和锁屏显示任务进度（iOS 16+）
- ✅ **状态同步**：应用前后台切换时状态无缝同步

## 9. 风险评估

### 9.1 技术风险
- **低风险**：主要是数据结构和管理逻辑的扩展，不涉及核心架构变更
- **兼容性风险**：需要确保现有代码不受影响
- **Live Activity 风险**：
  - iOS 16+ 才支持，需要版本检查
  - Widget Extension 的开发和调试相对复杂
  - Live Activity 的更新频率有限制（不能过于频繁）
- **后台执行风险**：
  - iOS 系统对后台执行时间有严格限制
  - 长时间任务可能被系统终止
  - 需要合理使用 `BGTaskScheduler` 和 `beginBackgroundTask`

### 9.2 用户体验风险
- **低风险**：改进用户体验，降低风险
- **Live Activity 权限风险**：用户可能拒绝 Live Activity 权限，需要优雅降级
- **后台执行限制风险**：如果任务执行时间超过系统限制，用户可能看不到完成状态

### 9.3 性能风险
- **低风险**：Live Activity 更新需要序列化数据，频繁更新可能影响性能
- **内存风险**：多个任务组和 Live Activity 同时存在时，需要注意内存管理

## 10. 后续优化方向

### 10.1 功能增强
1. **进度条支持**：为任务组添加整体进度条（已完成）
2. **任务优先级**：支持任务优先级，高优先级任务优先显示
3. **任务历史**：记录任务组执行历史，便于调试和问题排查
4. **自定义样式**：不同业务场景可以使用不同的 Indicator 样式
5. **任务预估时间**：根据历史数据预估任务完成时间
6. **任务暂停/恢复**：支持暂停长时间任务，稍后恢复执行

### 10.2 Live Activity 增强
1. **交互式按钮**：在 Live Activity 中添加操作按钮（如"取消任务"）
2. **通知集成**：任务完成时发送通知，即使 Live Activity 已关闭
3. **多设备同步**：通过 iCloud 同步任务状态到其他设备
4. **动态内容**：根据任务类型显示不同的 UI 样式

### 10.3 性能优化
1. **批量更新**：合并多个更新操作，减少 Live Activity 更新频率
2. **延迟加载**：非关键信息延迟加载，提升响应速度
3. **缓存机制**：缓存任务组状态，减少重复计算

### 10.4 用户体验优化
1. **动画效果**：添加平滑的过渡动画
2. **声音反馈**：任务完成时播放提示音（可选）
3. **触觉反馈**：重要状态变化时提供触觉反馈
4. **深色模式**：优化深色模式下的显示效果

## 11. 测试计划

### 11.1 功能测试
- [ ] 测试任务组的创建和管理
- [ ] 测试子任务的注册和完成
- [ ] 测试多个任务组同时存在的情况
- [ ] 测试任务取消和错误处理

### 11.2 实时任务测试
- [ ] 测试应用进入后台时任务继续执行
- [ ] 测试后台任务时间限制的处理
- [ ] 测试应用返回前台时的状态同步
- [ ] 测试任务在后台完成时的处理

### 11.3 Live Activity 测试
- [ ] 测试 Live Activity 的创建和显示
- [ ] 测试 Live Activity 的更新
- [ ] 测试 Live Activity 的结束
- [ ] 测试不同设备上的显示效果（iPhone 14 Pro、其他 iPhone、iPad）
- [ ] 测试 iOS 版本兼容性（iOS 16+）

### 11.4 集成测试
- [ ] 测试与现有代码的兼容性
- [ ] 测试与 BackgroundTaskManager 的集成
- [ ] 测试多个业务场景的完整流程

### 11.5 性能测试
- [ ] 测试大量任务组时的性能
- [ ] 测试频繁更新 Live Activity 的性能
- [ ] 测试内存使用情况

## 12. 文档要求

### 12.1 开发文档
- API 使用文档
- 代码注释和文档字符串
- 架构设计文档

### 12.2 用户文档
- Live Activity 使用说明（如需要）
- 后台任务权限说明

### 12.3 测试文档
- 测试用例文档
- 测试结果报告

