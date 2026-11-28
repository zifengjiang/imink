# SplatNet 3 同步「HTTP 400 空 body」根因报告

- 分支：`zifengjiang/fix-imink-sync-no`（不提交 `main`）
- 目标设备：iPhone 17（UDID `00008150-001A55461AE1401C`），上一版 `ac26481`
- 现场证据：app group `group.jiang.feng.imink.plist`
  `lastSyncError = "同步失败：服务返回错误（HTTP 400），请稍后重试"`、`battlesRefreshTime = 0`、`coopsRefreshTime = 0`、
  `scheduleRefreshTime = 1795845950`（日程刷新正常）→ 对战/打工历史**一次都没成功过**，卡在 400 且**没有响应体**。

## 1. 先排除两个「猜」出来的假设

### 1.1 hash_map 没有过期（逐条比对线上 JS）

`script/update-splatnet3-webview-data.py --check` 从
`https://cdn.jsdelivr.net/gh/nintendoapis/nintendo-app-versions/data/splatnet3-app.json`
拿到 `script_url = https://api.lp1.av5ja.srv.nintendo.net/static/js/main.8f32ce85.js`，
下载真 JS（3,103,894 B）并按
`params:{id:"<sha256>",metadata:{},name:"<Operation>",operationKind:"query"}` 抽出 106 个 query：

| 结论 | 数据 |
| --- | --- |
| 打包 `splatnet3_webview_data.json` 与线上 hash | 113 条中 **111 条完全相同** |
| 仅有的差异 | `PhotoAlbumQuery` 62383a05→903bd134、`PhotoAlbumRefetchQuery` 0819c222→572baf92 |
| 同步用到的 hash | `CoopHistoryQuery e11a8cf2…`、`CoopHistoryDetailQuery f2d55873…`、`LatestBattleHistoriesQuery b24d22fd…`、`RegularBattleHistoriesQuery 2fe6ea7a…`、`BankaraBattleHistoriesQuery 9863ea47…`、`XBattleHistoriesQuery eb5996a1…`、`EventBattleHistoriesQuery e47f9aac…`、`PrivateBattleHistoriesQuery fef94f39…`、`HistoryRecordQuery a654ecc8…`、`CoopRecordQuery 56f989a5…` —— **全部与线上一致** |

→ `PersistedQueryNotFound` / hash 过期**不成立**。顺手把这两个过期的 photo album hash 与
`version` 一起更新为线上值（文件只改 3 行），`--check` 现在返回 `OK`。

### 1.2 `X-Web-View-Ver` 的旧 build 不会被拒绝

对 `POST /api/graphql` 用同一份请求体、只改 `X-Web-View-Ver`（凭据故意用假的，看服务端的检查顺序）：

| `X-Web-View-Ver` | 状态 | body |
| --- | --- | --- |
| `10.0.0-d15503c4`（线上） | 401 | 空 |
| `10.0.0-4787c271`（打包里那个旧值） | **401** | 空 |
| `1.2.3`（格式不合法的版本） | 403 | 空 |
| **不发送** | **400** | **空** |

→ 旧 build 只是「认证失败」，不是 400；**400 空 body 出现在「版本头缺失」或「凭据缺失」时**。

## 2. 400 空 body 的完整状态矩阵（实测，全部来自 api.lp1.av5ja.srv.nintendo.net）

| 请求 | 条件 | 状态 | body |
| --- | --- | --- | --- |
| `POST /api/graphql` | 有 `X-Web-View-Ver`，`Authorization` 缺失 / 为空 / `Bearer ` 空 token | **400** | **空** |
| `POST /api/graphql` | `Authorization: Bearer dummy` | 401 | 空 |
| `POST /api/graphql` | 无 `X-Web-View-Ver` | **400** | **空** |
| `POST /api/graphql` | `X-Web-View-Ver: 1.2.3` | 403 | 空 |
| `POST /api/bullet_tokens` | 无 `_gtoken` cookie | **400** | **空** |
| `POST /api/bullet_tokens` | 有 cookie 但 token 无效 | 401 | 空 |
| `POST /api/bullet_tokens` | 无 `X-Web-View-Ver` | 400 | 空 |
| `POST /api/graphql` | hash 仍是占位串 / 空 body / 非法 JSON | 401 | 空 |

**决定性结论：HTTP 400 + 空 body 在这套 API 上等价于「这个请求既没有可用凭据、也没有版本头」——
也就是我们发出去的请求根本没带上 `Authorization: Bearer <bulletToken>`（甚至连 `X-Web-View-Ver` 都没带）。**
这不是 hash 问题、不是版本号问题，而是「根本没拿到 bulletToken 就开始请求」。

## 3. 根因（按证据排序）

### 根因 A（主因）`ensureToken()` 不会去取游戏服务令牌 → 整个请求链裸奔

- `Shared/API/SN3Client+Ext.swift:52`（旧代码）里 `// await NSOAccountManager.shared.refreshGameServiceTokenIfNeeded()` 是**注释掉的**，
  只剩「如果 `AppUserDefaults.gameServiceToken` 有值就 `setToken`」。
- app group plist 里没有 `gameServiceToken`（只有 `session_token` / `accountId` / `*RefreshTime`），
  所以 `setToken` 从未被调用 → `refreshBullet()` 从未跑过 → **`configureSession()` 从未跑过**。
- `configureSession()`（`Shared/SplatNet3/SN3Client.swift`）是唯一安装 `WebVersionPlugin`（`X-Web-View-Ver`）、
  `GraphQLPlugin`（hash）、`BulletTokenPlugin`（`Authorization`）的地方。没跑过 = 三个头全都没有。
- 于是 `POST /api/graphql` 是「无版本头 + 无凭据」→ 服务端 **400 空 body**，与现场 100% 吻合。

### 根因 B（放大问题）`makeBullet()` 在缺 token 时静默 `return`

- 旧代码 `guard let gameServiceToken = gameServiceToken else { return }`：没有令牌就直接返回，
  调用方`s `refreshBullet()` 以为「已经拿到 bullet」，继续用空 Authorization 发 GraphQL → 又是 400。
- 现在改为抛 `SN3Client.Error.noGameServiceToken`（`Shared/SplatNet3/SN3Client.swift:219-233`），
  文案「缺少游戏服务令牌（没有发起请求），请重新登录」。

### 根因 C（可见性）400 的详情全丢了

- 旧 `syncFailureMessage` 只输出 `服务返回错误（HTTP 400），请稍后重试`，URL / 请求头 / 响应体全丢，
  所以现场完全看不出「请求根本没带凭据」。

### 已排除

- hash_map 过期（见 1.1）；`X-Web-View-Ver` 旧 build（见 1.2）；FK 约束（上一版已修，且 400 在这一层之前）；
  `session_token` 过期（JWT `exp = 2028-03-24`，且用它对 `accounts.nintendo.com/connect/1.0.0/api/token` 换 token 实测 200）。

## 4. 这次的改动

### 4.1 让失败自己说话（`lastSyncDebug`）

新增 `Shared/SplatNet3/SyncDiagnostics.swift`，字段：

| 字段 | 含义 |
| --- | --- |
| `api` | 失败步骤：`graphql` / `bullet_tokens` / `nxapi-f` / `local` |
| `query` | GraphQL operation 名，如 `CoopHistoryQuery` |
| `url` / `method` | 完整请求 URL 与方法 |
| `status` | HTTP 状态（网络层失败时为 `null`） |
| `webVersion` / `webVersionSource` | 实际发送的 `X-Web-View-Ver`，以及它是 `bundled` 还是 `remote` |
| `requestHeaders` | 实际发出的全部请求头（`Cookie` 里的 `_gtoken` 已打码） |
| `requestBodyPrefix` | 请求体前 300 字符（含 `sha256Hash`） |
| `responseBody` | 响应体前 400 字符（空 body 就是 `""`） |
| `error` / `note` | 人话描述 / 补充说明（如「换 build 重试后成功」） |

写入点：

- `Shared/InkMoya/IMSession.swift`：每个 SplatNet 请求发出前 `SyncDiagnostics.noteRequest(request)`；
- `Shared/SplatNet3/SN3Client.swift:268` `requestGraphQL` 非 200 时记录（带 query 名）；
- `Shared/SplatNet3/SN3Client.swift:219` `makeBullet` 失败/缺令牌时记录；
- `Shared/API/NSOAuthorization+FAPI.swift`：nxapi `f` 步骤 401/429/其它状态都记录；
- `Shared/API/SN3Client+Ext.swift`：`runPipeline` 的非 HTTP 失败（落库等）补一条 `local` 记录；
  成功时清空 `lastSyncDebug`。
- 落地位置：`AppUserDefaults.lastSyncDebug`（`Shared/Data/AppUserDefaults.swift:68`，app group，可直接读 plist）。

### 4.2 修真正的阻塞点

- `Shared/Managers/NSOAccountManager.swift:40` 新增 `ensureGameServiceToken() async throws -> String`：
  手动令牌优先；否则没有令牌或 `gameServiceTokenRefreshTime + 3600 < now` 时**真的去刷新**，刷不到就抛错。
- `Shared/API/SN3Client+Ext.swift:52` `ensureToken()` 改为 `try await setToken(try await NSOAccountManager.shared.ensureGameServiceToken())`
  —— 保证 `refreshBullet()` / `configureSession()` 一定会跑，三个请求头一定会装上。

### 4.3 防御 + 自证：400/403 时换一个 build 再试一次

`Shared/SplatNet3/SN3Client.swift:154` `tryAlternateWebVersion()`：GraphQL 收到 400/403 时，
把 `X-Web-View-Ver` 在「远端声明的 build ↔ 打包内置的 build」之间切换**一次**再试，
结果写进 `lastSyncDebug.note`（成功 = 证明是版本头；失败 = 证明不是版本头）。只试一次，不会打转。
同时版本服务改成多镜像（`cdn.jsdelivr.net` → `fastly.jsdelivr.net` → `gcore.jsdelivr.net` → `raw.githubusercontent.com`），
避免国内网络拿不到版本时被迫用旧 build；`refreshWebConfigurationIfAvailable()` 更新完 hash_map 会重新 `configureSession()`。

### 4.4 顺手修

- `Shared/SplatNet3/SN3PersistedQuery.swift`：`EventBattleHistoriesQuery.name` 之前误写成 `XBattleHistoriesQuery`，
  活动对战实际是用 X 的 hash 去查的（永远查空）。
- `Shared/SplatNet3/splatnet3_webview_data.json`：`version` → `10.0.0-d15503c4`，两个 photo album hash 更新。
- `script/update-splatnet3-webview-data.py`：`--check` 只比对不写；无参数则重新生成（数据来源与算法见脚本头部注释）。

## 5. 装机验证（给协调者）

1. 装本分支构建，进「我的 → 开发者设置」，点「手动刷新数据（测试）」。
2. 同步走完后再读 app group plist：
   ```sh
   plutil -p "$(xcrun simctl get_app_container ... )"   # 真机用 idevicefs 或 Filza 取 group.jiang.feng.imink.plist
   ```
   关键键：`lastSyncError`、`lastSyncDebug`、`gameServiceToken`（应出现）、`gameServiceTokenRefreshTime`（应非 0）。
3. 判读：
   - `lastSyncDebug.api = "graphql"`、`status = 400`、`responseBody = ""` → 仍是凭据/版本头问题，
     看 `requestHeaders.Authorization` 与 `requestHeaders.X-Web-View-Ver` 是否存在；
   - `lastSyncDebug.api = "nxapi-f"`、`status = 429` → nxapi 限流（正文会说明），隔 10-30 分钟再试；
   - `lastSyncDebug.api = "local"` → 落库失败，`error` 里有 SQLite 原文；
   - 同步成功后 `lastSyncDebug` 会被清空，`battlesRefreshTime` / `coopsRefreshTime` 变成非 0。

## 6. 一句话结论

现场那条 400 不是 hash 过期、不是版本头过期，而是**请求根本没带凭据**：
`ensureToken()` 从不主动取 `gameServiceToken`（`refreshGameServiceTokenIfNeeded()` 被注释掉了），
`makeBullet()` 又在缺 token 时静默返回，于是 `configureSession()` 从未运行、`Authorization` 与
`X-Web-View-Ver` 全部缺失，服务端对「无凭据 + 无版本头」的 GraphQL 请求回的就是 `400` + 空 body。
