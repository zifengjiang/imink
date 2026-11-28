# imink 同步诊断：为什么「提示加载完成」却没有任何新记录

分支：`zifengjiang/fix-imink-sync-no`（基于 `dd615fc`，未提交 main）
设备：iPhone 17 `00008150-001A55461AE1401C` ／ 库：`/tmp/dev3/db.sqlite`（+WAL）
结论一句话：**不是 UI 不显示，是写库事务整体回滚，而回滚错误被吞掉后按「抓到几条」报成功。**

---

## 1. 链路图

```
MainView / CoopListView / BattleListView / DeveloperSettingsPage
  └─ SN3Client.fetchCoops(groupId:) / fetchBattles(groupId:)      Shared/API/SN3Client+Records.swift:76 / :127
       └─ runPipeline(...)                                        Shared/API/SN3Client+Ext.swift:69
            ① ensureToken()                                       Shared/API/SN3Client+Ext.swift:32
               └─ AppUserDefaults.gameServiceToken → setToken()
            ② Gate.shouldProceed(last:refreshInterval:)           Shared/API/SN3Client+Ext.swift:24
            ③ getValidIDs()                                       (CoopHistoryQuery / 5 个对战列表查询)
                 └─ filterNotExists(in: .coop / .battle, ids:)     SplatDatabase.swift:1207
                     └─ 解析 id 里的 UUID+UTC 时间，LEFT JOIN 表判定「库里没有」
            ④ fetchAndPersistDetails(ids:...)                     Shared/API/SN3Client+Records.swift:16
                 ├─ 并发 graphQL(.coopHistoryDetail/.vsHistoryDetail)
                 ├─ ensureUnknownImageMapRow()                    Shared/Data/SplatDatabase+ImageMapPlaceholder.swift:21  ← 新增
                 └─ store(details)
                     ├─ SplatDatabase.insertCoops / insertBattles  （单事务，GRDB；foreign_keys=ON）
                     └─ CoopListViewModel.loadCoops / BattleListViewModel.loadBattles
            ⑤ 结果呈现（Indicator 标题 / lastSyncError / 后台通知）

后台：BackgroundTaskManager.performBackgroundDataRefresh()        Shared/Managers/BackgroundTaskManager.swift:175
       └─ 同上两步 → 累加 → completeTaskGroup → sendDataUpdateNotification（newDataCount）
```

关键：**「抓到的 detail 条数」与「真正 INSERT 的行数」在这一版之前是两个不同的数，但代码只传了前者。**

---

## 2. 静默失败点清单（修复前 → 修复后）

| # | 位置（修复前） | 行为 | 用户看到 | 后果 |
|---|---|---|---|---|
| 1 | `Shared/API/SN3Client+Records.swift:31-40` `fetchAndPersistDetails` | `do { try await store(details) } catch { logError(error) }` 之后 **`return details.count`** | 「加载了 N 个新纪录」 | 事务回滚但计数照算；后台通知「在后台获取到了 N 条新记录」也是这个数 → **反复通知、库里 0 行** |
| 2 | `Shared/API/SN3Client+Ext.swift:159-167` runPipeline 兜底 `catch` | 只 `logError` + `completeSubTask` / `dismiss` | 进度条消失，标题由 `Indicators.scheduleDelayedDismissCheck` 兜成「×完成」 | 「加载完成」= 只是把指示器收掉，与数据无关 |
| 3 | `Shared/Managers/BackgroundTaskManager.swift:191-214` | `var success = true` 从未被置 false；`?? 0` 把失败当 0 | 「成功加载 N 个新纪录」/「没有新纪录」 | 失败与「没新数据」不可区分 |
| 4 | `imink/Views/Me/DeveloperSettingsPage.swift:143-158` | `completeTaskGroup(success: true, message: "刷新完成")` 写死 | 「刷新完成」 | 手动测试永远假成功 |
| 5 | `Shared/API/SN3Client+Ext.swift:176-180`（`invalidGameServiceToken` 非手动分支） | 刷新令牌后**不重试、直接返回 count=0** | 「没有新纪录」 | 令牌问题被伪装成「无新数据」 |
| 6 | `Shared/Managers/NotificationManager.swift:114-118` | 文案只用调用方传的 `count` | 「在后台获取到了 7 条新记录」 | 数字来源未校验是否落库 |
| 7 | `SplatDatabase/Tables/ImageMap.swift:19-32` `getImageId(...)` | 素材查不到 **静默返回 0**，从不抛错、不插行 | 无感知 | 见根因 ① |

修复后：1 → 抛错上浮 + 返回真实行数；2 → 通用分支标题/图标变红 + `Toast.failure` + 写 `lastSyncError`；3 → `nil` = 失败、消息显式列出失败项、失败不发通知；4 → 按真实结果；5 → 记为失败并提示「令牌已刷新，请再次刷新」；7 → 插入前补 `imageMap(id=0)` 占位行。

---

## 3. 根因（按证据强度排序）

### ① 未知素材 → 外键失败 → 整批 coop 事务回滚（**真正的阻塞点**）

证据（本地用工程依赖 `SplatDatabase` 直接跑真库副本 `/tmp/dev3/db.sqlite`，`/tmp/repro`）：

```
coop rows (before): 12257
imageMap id=0 exists: false
step1 insertCoop (no placeholder): FAILED -> SQLite error 19: FOREIGN KEY constraint failed
                                   - while executing `INSERT INTO "coop" (...`
coop rows after step1: 12257          ← 回滚，一行没进
placeholder inserted
step3 insertCoop (with placeholder): SUCCESS
coop rows (after): 12258              ← 同一条数据，补占位行后写入成功
```

schema 事实：

- `coop.stageId INTEGER NOT NULL REFERENCES imageMap(id)`
- `weapon.imageMapId NOT NULL REFERENCES imageMap(id)`
- `player.uniformId REFERENCES imageMap(id)`
- GRDB 默认 `PRAGMA foreign_keys = ON`（实测 `true`）
- `imageMap` 实际 id 范围 **1..3115，没有 0**；`select count(*) from weapon where imageMapId = 0` = 0
- 插入路径里 `getImageId(for:hash:db:)` 找不到素材就返回 `0`（ImageMap.swift:19-32）
- `updateImageMap` 只在迁移 `insertImageMapForVersion800/810/900/910` 里跑，迁移已记录 → 新赛季素材**永远不会**补进库

所以：11-17 之后主人打的打工局里只要出现**素材包里没有的场景/武器/横纲**（新赛季），`Coop.init` 拿到 `stageId=0`，整个 `insertCoops` 事务 FK 回滚；`filterNotExists` 下次仍返回同一批 id → **「反复获取、反复通知、从不写入」**，与主人观察完全一致。

### ② 计数口径错误（**让 ① 完全隐形**）

`fetchAndPersistDetails` 返回抓到条数，注释见修复后 `Shared/API/SN3Client+Records.swift:16-35`。这就是「通知 7 条、库里 0 行」的直接来源。

### ③ 后台任务没有任何失败通道

`BackgroundTaskManager.swift:175`：`success` 恒 `true`、失败被 `?? 0` 吞、`sendDataUpdateNotification` 只看这个数。

### ④ 顺带查出的独立 bug：活动对战永远查成 X 对战

`Shared/SplatNet3/SN3PersistedQuery.swift:106-108`（修复前）

```swift
public struct EventBattleHistoriesQuery: SN3PersistedQuery {
    public static let name = "XBattleHistoriesQuery"   // ← 复制粘贴错
}
```

`Shared/SplatNet3/Plugins/GraphQLPlugin.swift:15-16` 用 `graphQLHashMap[type(of: target).name]` 取 hash，于是 `.eventBattleHistories` 实际发的是 X 对战的 hash。实测服务端 `EventBattleHistoriesQuery` 有 50 条、`XBattleHistoriesQuery` 返回 0 —— **活动对战记录从未入库**（不是本次「没有新记录」的主因，但会让对战列表长期缺一整类记录）。已改为 `"EventBattleHistoriesQuery"`。

### 已排除（有证据）

- **不是 token 过期**：app group 里的 313 字符 token 与 `account.id=1.sessionToken` 完全一致；JWT `exp = 2028-03-24`；真机 token 直接换 `access_token` 返回 200。api.lp1 的 401 从来不是「session token 过期」，bullet 步骤只用 `Cookie: _gtoken` 即 201。
- **不是 schema 漂移 / 缺表**：`SplatDatabase(path:)` + `migrator.migrate` 在真库副本上不抛错；`grdb_migrations` 35 条与代码一致；`pragma integrity_check` = ok、`foreign_key_check` 空；sqlite_master 里 table 15 / view 4 / index 28 / **trigger 0**（工程本来就没有触发器，`.recover` 没丢东西）。
- **不是 accountId 错位**：`account.id=1.sp3Id = qaenpmwwot2cvyq3qpmm`，与 GraphQL 返回的 detail id 里的 userId 相同；`filterNotExists` 的 JOIN 也带 `a.sp3Id`，没有过滤掉写入。
- **不是写到了另一个库**：`fetchBattles/fetchCoops` 只走 `SplatDatabase.shared`，`/tmp/dev3/db.sqlite` 的 WAL 里也没有任何 11-17 之后的行。
- **对战侧「今天没有记录」另有原因**：SplatNet 上这个账号的对战历史最新一条就是 `2026-07-18 12:23:29`（与库一致），11-27 之后 0 条；250 个 detail id 用 `filterNotExists` 复算 missing=0。→ 那部分不是 App 丢数据，是服务端该账号看不到。

---

## 4. 改动清单

| 文件 | 改动 |
|---|---|
| `Shared/API/SN3Client+Records.swift` | `fetchAndPersistDetails` 返回真实落库行数（插入前后 `COUNT(*)` 差）；`store` 抛错上浮；全部 detail 拉取失败抛 `noDetailFetched`；插入前 `ensureUnknownImageMapRow()` |
| `Shared/Data/SplatDatabase+ImageMapPlaceholder.swift`（新增） | `ensureUnknownImageMapRow()`：`INSERT OR IGNORE INTO imageMap (id, nameId, hash, name) VALUES (0, base64("Unknown-0"), "unknown-0", "Unknown")` |
| `Shared/API/SN3Client+Ext.swift` | 失败不再隐形：`syncFailureMessage(_:)`、`logSyncResult(kind:requested:saved:)`、失败分支改红标题+三角图标+`Toast.failure`+写 `lastSyncError`；`isPartial`（写入 < 抓到）单独提示；失败返回 `nil` 而不是 `0`；令牌刷新后不再伪装成「没有新纪录」 |
| `Shared/SplatNet3/SN3Client.swift` | `Error` 增 `case noDetailFetched(message:)` + `errorDescription` |
| `Shared/SplatNet3/SN3PersistedQuery.swift` | `EventBattleHistoriesQuery.name` 修正 |
| `Shared/Data/AppUserDefaults.swift` | 新增 `@AppStorage("lastSyncError", store: .appGroup) var lastSyncError: String?` |
| `Shared/Managers/BackgroundTaskManager.swift` | `success` 反映真实结果；失败消息点名哪一路失败；**失败不发通知**；通知只按真实落库行数 |
| `imink/Views/Me/DeveloperSettingsPage.swift` | 新增「最近同步错误」行；「手动刷新数据（测试）」不再写死 `success: true` |
| `imink/Views/Me/MyGearView.swift` | 补 `noDetailFetched` 分支（switch 穷尽性） |

日志：`os_log` 现在会输出 `sync[battle] requested=3 saved=0`（不相等时 level = error），
`log stream --predicate 'subsystem == "..."'` 或者 Console.app 直接可看。

---

## 5. 验证

### 5.1 已完成的验证

1. `xcodebuild -scheme imink -destination 'generic/platform=iOS Simulator' build` → **BUILD SUCCEEDED**。
2. 真库副本上的失败/修复对照实验（上一节代码块）：`FOREIGN KEY constraint failed` → 补占位行 → `SUCCESS`，行数 12257 → 12258。
3. 迁移无漂移：真库副本 `migrator.migrate` 不抛错，`grdb_migrations` 35 条。

### 5.2 从零建库 → 迁移 → 首次同步（干净基线）

```sh
# 1) 备份并清空设备容器里的库（App 会重建 + 迁移到最新版本）
xcrun devicectl device process launch --device 00008150-001A55461AE1401C --terminate-existing jiang.feng.imink
#    退出 App 后，删除 app group 容器里的 db 文件（db.sqlite / -wal / -shm）

# 2) 冷启动 App，登录，等一次同步；随后校验：
sqlite3 <容器>/db.sqlite 'select count(*) from grdb_migrations;'      # 应为 35
sqlite3 <容器>/db.sqlite 'select id,name from imageMap where id = 0;' # 修复后应存在占位行
sqlite3 <容器>/db.sqlite 'select count(*), max(playedTime) from coop;'
sqlite3 <容器>/db.sqlite "select substr(playedTime,1,10) d, count(*) from coop group by d order by d desc limit 5;"
sqlite3 <容器>/db.sqlite 'pragma foreign_key_check;'                   # 必须为空
```

判定：`coop` 的最大 `playedTime` 前进到最近一次打工，且新增行 `stageId != 0`；若出现 `stageId = 0`，说明占位行生效（该条素材缺失，但记录保住了）。

### 5.3 复现脚本（保留在 /tmp，未入库）

- `/tmp/repro`：独立 SwiftPM 包，直接引工程依赖的 `SplatDatabase` 源码 + GRDB/SwiftyJSON，对真库副本跑 `insertCoop`；
- `/tmp/repro/Repro/main.swift`：①无占位行 → 期望 FK 失败 ②插占位行 ③再插同形数据 → 期望成功；
- `/tmp/fetch_details.py`、`/tmp/get_chain.py`：真机同款认证链（session_token → nxapi → bullet → GraphQL），用于核对服务端到底有哪些记录。

---

## 6. 遗留 / 建议

1. `getImageId` 返回 0 仍是「静默降级」。占位行让记录能落库，但正确做法是在同步后补拉素材（`insertImageMapForVersion*` 的增量版本），否则新赛季素材会一直显示 Unknown。
2. 对战侧「今天没有记录」与该账号 SplatNet 历史停在 2026-07-18 有关（服务端只到 7-18），需要主人确认今天用的 NSO 账号是不是这个 sp3Id `qaenpmwwot2cvyq3qpmm`。
3. `.recover` 出来的库结构没问题，但如果主人在同一台机器上反复手写 app group plist，建议后续加「登录态与库 account.sessionToken 一致性校验」并给出显式提示。

---

## 7. 主人那几局能不能立刻看到

**能，但只能靠一次「重新拉取」把它补回来 —— 重装 App 不会自动补，必须让 App 成功跑完一次 coop 同步（打开 App 的打工页下拉刷新，或者在开发者设置页点「手动刷新数据（测试）」）**；修复后 `filterNotExists` 会把这 11 天错过的记录重新识别为「库里没有」，一次插入，因为它们都还在 `CoopHistoryQuery` 返回的窗口内（约 50 个打工轮次，覆盖 20 天以上，而主人断档只有 11 天）。如果主人今天玩的那几局在服务端也同样看不到（就像对战历史停在 2026-07-18 那样），那就得他确认登录的是哪个 NSO 账号（应为本机 `account.id=1` 的 `qaenpmwwot2cvyq3qpmm` / 昵称「喂不饱的猪」），否则任何客户端修复都无法把这些记录取回来。
