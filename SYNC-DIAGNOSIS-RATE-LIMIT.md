# nxapi 429 之后的同步：imink f 回退实测与 Retry-After 冷却

对象：`zifengjiang/fix-imink-sync-no`（基线 `f556161`）· 设备 iPhone 17 · 2026-11-28

## 一句话结论

`f556161` 的诊断已经能精确定位失败点（`nxapi-f` step1 / 429 / 官方错误体），本次改动把 429 变成**可读的冷却窗口**（`Retry-After` → prefs → UI + 本地守卫），并按需求接上了 imink 官方 f API 作为备用提供方；但**实测 imink 的 f API 现在返回 HTTP 500，而且即使拿到 f 值也救不了同步**——Nintendo 已经把明文 `f` 通道关掉了：任何明文 `/v4/Account/Login`（f 值真/假、版本 2.10.1/3.5.0/3.6.0/3.6.1 都一样）都回 `{"status": 9427, "errorMessage": "Upgrade required."}`，只有 nxapi 产出的**加密请求体**才能过。所以真正能解锁同步的只有「等 nxapi 限流窗口过去 + 冷却期间不重复鉴权」。

## 1. 三个必须知道的实测事实

### 1.1 imink 官方 f API 当前是坏的

```
POST https://api.imink.app/f
Content-Type: application/json; charset=utf-8
{"hash_method": 1, "token": "<814 字 id_token>", "na_id": "1d56804e7d2933f7"}

→ HTTP 500
{"reason":"Something went wrong.","error":true}
```

- 加上 `coral_user_id` / `country: JP` / `language: ja-JP` / `naBirthday` 同样是 500；`hash_method` 用数字 `1` 或字符串 `"1"` 都是 500。
- 响应里**没有任何 `Retry-After` / `X-RateLimit-*` 头**（`Server: nginx/1.18.0`），所以 imink 侧没法做冷却。
- 旁证：`GET https://api.imink.app/config` → 200 `{"nso_version":"2.10.1"}`；`GET /f` 的 wiki 仍在，说明服务在，只是 f 生成链路（它背后是一台跑 NSO 客户端的 Android 模拟器）坏了。

### 1.2 明文 f 通道已经关闭（这是「回退到 imink」不可能成功的根本原因）

用真 `id_token` + 真 znca 头（`com.nintendo.znca/3.6.1(Android/11)`、`X-Platform: Android`、`X-ProductVersion: 3.6.1`）打 `https://api-lp1.znc.srv.nintendo.net/v4/Account/Login`：

| 请求体 | 结果 |
| --- | --- |
| 明文 JSON `{"parameter":{f:<64hex>, naIdToken, requestId, timestamp, language}}` | 200 **`{"status": 9427, "errorMessage": "Upgrade required."}`** |
| f 换成 `""` / `"0"*64` / `"a"*64` | 同样 9427 |
| 版本换 3.6.0 / 3.5.0 / 2.10.1，路径换 `/v3`，加 `X-Requested-With` | 全部 9427 |
| 随机二进制体（`application/octet-stream`, 512B） | **9400 `{"status": 9400, "errorMessage": "Bad request."}`** |
| 随机 base64 文本（当 JSON 发） | 9427 |

→ 服务端是按「是不是加密信封」判定的：JSON/文本 → `9427 Upgrade required`，二进制 → `9400 Bad request`。**f 值本身不再是准入凭据**：只有 nxapi 的 `encrypted_token_request`（`POST /api/znca/f` 的产出）能进。这也是为什么 `imink-app/f-API` 的 README 强调「f API 必须与 NSO 版本号匹配」——它是给仍支持明文通道的旧版本用的。

### 1.3 `fapiRequestInterval` 默认是 **30 分钟**，不是 0

`Shared/Data/AppUserDefaults.swift` 默认值 `1800000`（毫秒），开发者页可选 5 / 15 / 30 分钟或「禁用」。

这解释了现场那个诡异现象：协调者「等 5 分钟再点一次」看到的「请求过于频繁」，**其实是本地 30 分钟间隔守卫**（`checkFAPIRequestInterval()` 抛 `.tooManyRequests`），`lastSyncDebug` 里那条 429 是上一次留下的快照。所以不需要改默认值——但现在它不再是一条看不懂的报错，而是明确告诉用户「本地请求间隔 30 分钟，还剩 X」。

## 2. 改动清单

### 2.1 新增 `Shared/API/FAPICooldown.swift`

限流冷却的唯一事实来源，落在 app group prefs：

- `fapiCooldownUntil` / `fapiCooldownProvider` / `fapiCooldownReason` / `fapiTryIminkFallback` / `fapiLastProvider`（`Shared/Data/AppUserDefaults.swift:78-84`，全部 `store: .appGroup`）。
- `record(from:status:provider:)`：读 `Retry-After`（秒数 / epoch 秒 / HTTP 日期）与 `X-RateLimit-Reset`，解析失败时 429 保守取 10 分钟、5xx 取 60 秒，夹到 `1...3600` 秒；**只在把窗口往后推时写**，避免并发请求互相缩短冷却。
- `isActive` / `remainingSeconds()` / `durationText()`（「9 分 30 秒」）/ `clockText()`（「14:52:10」）/ `message(prefix:)`（「FAPI 请求被限流，请在 9 分 30 秒后重试（14:52:10 之后）」）。

### 2.2 `Shared/API/NSOAuthorization+FAPI.swift`

- `checkFAPIRequestInterval()`（`:5-34`）：冷却优先于本地间隔，冷却中就**不再发请求**（连点不会继续加深限流）；本地间隔不足时抛 `.rateLimited(until:provider:"local", detail:"本地请求间隔 30 分钟，还剩 9 分 30 秒")`。
- `nxapiZncaAuthToken()`（`:60-73`）：以前任何非 200 都抛 `invalidSessionToken`（把限流误报成「会话失效」→ 用户去重登 → 继续打 Nintendo → 越锁越死）。现在 429/503 记冷却并抛 `.rateLimited`，其它状态带 HTTP 码与响应体前缀；`catch` 里也不再包装掉 `.rateLimited`（`:93`）。
- `nxapiZncaFAdvanced(...)`（`:150-230`）：429 → 记冷却 + 调回退链 + 把 `provider=nxapi(status=429); cooldown=…; nxapiBody=…; imink=…` 写进 `lastSyncDebug.note`；500/502/503/504 也走同一条链（5xx 记 60 秒冷却）。成功时 `fapiLastProvider = "nxapi"` 并 `FAPICooldown.clear()`。
- 新增 `fapiFallbackChainNote(...)`（`:275`）：nxapi 失败后尝试 imink，**两边结果都写进 `note`**，例如
  `provider=nxapi(status=429); cooldown=10 分钟(→14:52:00); nxapiBody={"error":"rate_limit"...}; imink=失败(imink f API HTTP 500：{"reason":"Something went wrong.","error":true}); 结论=两个 f 提供方都不可用，只能等冷却`。
- 新增 `iminkF(...)`（`:323`）：`POST https://api.imink.app/f`（`AppAPI.imink_f_v2`，`Shared/API/AppAPI.swift:9-46`，`IminkFBody` 用可选字段 → nil 时整键省略），成功返回 `NSOAuthorization.F`，非 200 抛带状态与 body 的错误，429/503 也记冷却。
- 新增 `probePlainAccountLogin(...)`（`:365`）：拿到 imink 的 f 后**只取证**地用明文 `/v4/Account/Login` 试一次，结果写进 `note`（就是上面 1.2 那套矩阵的在线版本）。不进入任何后续流程。

### 2.3 让失败可见

- `Shared/API/SN3Client+Ext.swift:42-50`：`syncFailureMessage(_:)` 增加 `.rateLimited` 分支 → 「生成 f 值被限流（nxapi），请在 9 分 30 秒后重试（14:52:10 之后）」，诊断长链留在 `lastSyncDebug` 不塞 toast。
- `Shared/API/SN3Client+Ext.swift:196-212`：`catch SN3Client.Error.tooManyRequests` 现在 `failed = true`、写 `lastSyncError`、红三角标题 + `Toast.failure`，文案带剩余时间与截止时刻（以前是不置 `failed` 的「FAPI请求过于频繁，稍后重试...」）。
- `imink/Views/Me/DeveloperSettingsPage.swift:247-304`（「FAPI 设置」）：新增「限流冷却」（provider + 剩余 + 截止时间）、「限流原因」、「上次 f 提供方」、「nxapi 限流时尝试 imink 回退」开关、「清除限流冷却」按钮，以及一句说明「Nintendo 现在只接受加密请求体，imink 的 f 只能用于诊断」。
- `Shared/SplatNet3/SyncDiagnostics.swift`：`noteFailure(...)` 新增 `note:` 参数并透传进快照。

## 3. 装机验证步骤

1. 装本 commit，进「设置 → 高级与开发者选项」，看「FAPI 设置 → 限流冷却」：若仍在窗口内，应显示 `nxapi · 剩 X 分 Y 秒（HH:mm:ss 之后）`——**期间不要点刷新**。
2. 点一次「手动刷新数据（测试）」：
   - 冷却内点：立刻返回「生成 f 值被限流（…），请在 X 后重试（HH:mm:ss 之后）」，并且**不会再发任何 nxapi 请求**（`lastSyncDebug.loggedAt` 不变）。
   - 冷却结束后点：若 nxapi 已恢复 → `lastSyncDebug` 清空、coop 行数增加；若仍 429 → `lastSyncDebug.note` 里会出现 `imink=失败(...)` 与冷却时间，`lastSyncError` 同步显示要等多久。
3. 想立刻重试可点「清除限流冷却」（会清 prefs；但如果服务端还在窗口内，下一次仍会 429 并重新写冷却）。

## 4. 给主人的答案

能不能立刻看到今天那几局，**取决于 nxapi 的限流窗口，不取决于 App 版本**：App 侧现在不会再把 429 伪装成「会话失效」或「同步完成」，会把「还要等多久」写清楚；但在这台 IP/账号的 nxapi 鉴权恢复之前，登录链第一步就过不去（`nxapi-auth` / `f step1` 都是服务端按 IP/账号限流），所以重装或升级都不能立刻看到新记录。需要他做的只有两件事：**一是别再连点刷新**（每次点都在给限流续命，冷却窗口会重算），等设置页显示的冷却时间过去后再点一次；**二是如果 24 小时后仍是 429**，告诉我——那说明这台出口 IP 被 nxapi 长期拉黑，得换网络环境（或改用 nxapi 之外的 f 提供方/自己部署 znc 服务）才能绕开，而 imink 的 `api.imink.app/f` 目前返回 500、且明文通道已被 Nintendo 关闭（9427 Upgrade required），不能作为替代。
