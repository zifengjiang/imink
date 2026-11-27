import Foundation
import SwiftUI
import GRDB
import SplatDatabase
import SwiftyJSON

@MainActor
final class MeDashboardViewModel: ObservableObject {
    enum RemoteSyncState: Equatable {
        case idle
        case syncing(attempt: Int, maxAttempts: Int)
        case synced
        case offlineLocal
    }

    struct LocalNameplateData {
        let name: String
        let byname: String
        let bynameFormatted: FormattedByname?
        let nameId: String
        let background: String
        let badges: [String?]
        let textColor: Color
    }

    struct IdentitySummary {
        var name: String
        var code: String?
        var avatarData: Data?
        var udemae: String?
        var udemaeMax: String?
        var rank: Int?
        var seasonLabel: String
        var localNameplate: LocalNameplateData?
        var remoteNameplate: HistoryRecord.Nameplate?
    }

    struct TopWeaponItem: Identifiable {
        let id: String
        let imageName: String?
        let nameId: String?
        let fallbackTitle: String
        let matchCount: Int
        let winRate: Double

        var displayTitle: String {
            if let nameId, !nameId.isEmpty {
                let localized = nameId.localizedFromSplatNet
                if !localized.isEmpty {
                    return localized
                }
            }
            return fallbackTitle
        }
    }

    /// 「我」页「近期表现」卡片的数据模型。
    ///
    /// 三项子模块的统计窗口严格定义且各自在 UI 上显式标注，避免口径混淆：
    /// 1. **对战近期窗口（`battleScopeLabel`）**：对齐 SplatNet 3 官方战绩总览与首页 `VDGridView` 的标准口径——
    ///    取当前账号**最近 50 场对战**（不足 50 场时取全部 `N` 场，显示为 `近 N 场`）；涨跌对比紧邻的前序 50 场（第 51~100 场）。
    ///    SplatNet 3 上游并无“周期”字段，按自然 30 天切分会在间歇游玩账号上截断同一次游玩序列（如仅剩 2 场残片）。
    /// 2. **鲑鱼跑近期窗口（`coopScopeLabel`）**：优先取**近 30 天**自然日内的打工场次与通关率（显示 `近 30 天鲑鱼跑`）；
    ///    若近 30 天为 0 场但本地存在历史打工记录，则回退至**最近 50 场打工**并显式切换标签为 `近 N 场鲑鱼跑`。
    /// 3. **主力武器样本（`weaponSampleLabel`）**：与上方对战胜率/KD **完全同源**——直接聚合同一批最近 50 场对战中的主武器，
    ///    标题显式写作 `近 N 场主力武器（共 N 场）`，杜绝总场次与单把武器场次之间的歧义。
    struct RecentPerformance {
        static let standardBattleWindowSize = 50

        var battleScopeLabel: String
        var matchCount: Int
        var winCount: Int
        var loseCount: Int
        var drawCount: Int
        var disconnectCount: Int
        var winRate: Double?
        var winRateDelta: Double?
        var kd: Double?
        var kdDelta: Double?
        var kad: Double?
        var coopScopeLabel: String
        var recentCoopMatches: Int
        var recentCoopClearRate: Double?
        var topWeapons: [TopWeaponItem]
        var weaponSampleLabel: String

        /// 胜 / 负（含豁免负）/ 平 / 掉线四个互斥完备桶始终全部展示，四项之和恒等于 `matchCount`。
        var recordSummaryText: String {
            "\(winCount)胜 \(loseCount)负 \(drawCount)平 \(disconnectCount)掉"
        }
    }

    struct BattleOverview {
        var totalCount: Int = 0
        var winRate: Double?
        var kd: Double?
        var festCount: Int = 0
        var latestUdemae: String?
    }

    struct CoopOverview {
        var totalCount: Int = 0
        var clearRate: Double?
        var maxGradePoint: Int?
        var maxGoldenEgg: Int?
    }

    @Published private(set) var isLoaded = false
    @Published private(set) var identity: IdentitySummary?
    @Published private(set) var recent = RecentPerformance(
        battleScopeLabel: "近 50 场",
        matchCount: 0,
        winCount: 0,
        loseCount: 0,
        drawCount: 0,
        disconnectCount: 0,
        winRate: nil,
        winRateDelta: nil,
        kd: nil,
        kdDelta: nil,
        kad: nil,
        coopScopeLabel: "近 30 天鲑鱼跑",
        recentCoopMatches: 0,
        recentCoopClearRate: nil,
        topWeapons: [],
        weaponSampleLabel: "近 50 场主力武器（共 0 场）"
    )
    @Published private(set) var battleOverview = BattleOverview()
    @Published private(set) var coopOverview = CoopOverview()
    @Published private(set) var onlineFriends: [FriendListResult.Data.Friends.Node] = []
    @Published private(set) var trashCount: Int = 0
    @Published private(set) var lastSyncText: String = "尚未同步"
    @Published private(set) var remoteSyncState: RemoteSyncState = .idle

    private var lastRemoteAttemptDate: Date?
    private let remoteRetryCooldown: TimeInterval = 120

    func reload(forceRemote: Bool = false) async {
        guard AppState.shared.isLogin else {
            identity = nil
            onlineFriends = []
            trashCount = 0
            remoteSyncState = .idle
            isLoaded = true
            return
        }

        let accountId = AppUserDefaults.shared.accountId
        let cachedHistory: HistoryRecord? = {
            guard let data = AppUserDefaults.shared.historyRecord?.data(using: .utf8) else { return nil }
            return try? JSONDecoder().decode(HistoryRecord.self, from: data)
        }()

        let snapshot = await Self.loadLocalSnapshot(accountId: accountId, cachedHistory: cachedHistory)
        applySnapshot(snapshot)
        isLoaded = true

        if !forceRemote,
           remoteSyncState == .offlineLocal,
           let lastAttempt = lastRemoteAttemptDate,
           Date().timeIntervalSince(lastAttempt) < remoteRetryCooldown {
            return
        }

        lastRemoteAttemptDate = Date()
        let maxAttempts = 2
        var fetchedHistory: HistoryRecord?

        for attempt in 1...maxAttempts {
            guard !Task.isCancelled else { return }
            remoteSyncState = .syncing(attempt: attempt, maxAttempts: maxAttempts)
            do {
                try await SN3Client.shared.ensureToken()
                let data = try await SN3Client.shared.graphQL(.historyRecord)
                fetchedHistory = HistoryRecord(json: try JSON(data: data))
                break
            } catch SN3Client.Error.invalidGameServiceToken {
                if !AppUserDefaults.shared.useManualGameServiceToken && attempt < maxAttempts {
                    try? await NSOAccountManager.shared.refreshGameServiceTokenManual()
                }
            } catch is CancellationError {
                return
            } catch {
                logError(error)
                if attempt < maxAttempts {
                    try? await Task.sleep(nanoseconds: 700_000_000)
                }
            }
        }

        if let remoteHistory = fetchedHistory {
            if let data = try? JSONEncoder().encode(remoteHistory),
               let jsonString = String(data: data, encoding: .utf8) {
                AppUserDefaults.shared.historyRecord = jsonString
            }
            applyRemoteHistory(remoteHistory)
            remoteSyncState = .synced

            if let friendList = await SN3Client.shared.fetchFriendList() {
                onlineFriends = friendList.data.friends?.nodes ?? []
            }
        } else {
            remoteSyncState = .offlineLocal
        }
    }

    private func applySnapshot(_ snapshot: LocalSnapshot) {
        identity = snapshot.identity
        recent = snapshot.recent
        battleOverview = snapshot.battleOverview
        coopOverview = snapshot.coopOverview
        trashCount = snapshot.trashCount
        lastSyncText = snapshot.lastSyncText
    }

    private func applyRemoteHistory(_ history: HistoryRecord) {
        guard var current = identity else { return }
        if let name = history.account.name, !name.isEmpty {
            current.name = name
        }
        if let avatar = history.account.avatar {
            current.avatarData = avatar
        }
        if let code = history.account.code, !code.isEmpty {
            current.code = code
        }
        current.rank = history.rank > 0 ? history.rank : current.rank
        current.udemae = history.udemae ?? current.udemae
        current.udemaeMax = history.udemaeMax ?? current.udemaeMax
        current.remoteNameplate = history.nameplate
        identity = current
    }

    // MARK: - Local SQLite Snapshot

    private struct LocalSnapshot {
        let identity: IdentitySummary
        let recent: RecentPerformance
        let battleOverview: BattleOverview
        let coopOverview: CoopOverview
        let trashCount: Int
        let lastSyncText: String
    }

    /// 复用 `SplatDatabase/Utility/SQL.swift:193-196` 的胜负口径，同时将总场次严格划分为
    /// 胜 / 负（含豁免负）/ 平 / 掉线四个互斥完备桶，确保展示数字总和恒等于 `matches`。
    private struct WindowStats {
        let matches: Int
        let wins: Int
        let losses: Int
        let draws: Int
        let disconnects: Int
        /// 参与胜率分母的有效场次（对齐 `SQL.swift:193-196`：`WIN` 为 1，`LOSE/DRAW/DEEMED_LOSE` 为 0，`EXEMPTED_LOSE` 等置 NULL 不计入分母）
        let decidedMatches: Int
        let kills: Int
        let deaths: Int
        let assists: Int

        static let zero = WindowStats(
            matches: 0,
            wins: 0,
            losses: 0,
            draws: 0,
            disconnects: 0,
            decidedMatches: 0,
            kills: 0,
            deaths: 0,
            assists: 0
        )

        var winRate: Double? {
            guard decidedMatches > 0 else { return nil }
            return Double(wins) / Double(decidedMatches) * 100
        }

        var kd: Double? {
            guard matches > 0 else { return nil }
            return Double(kills) / Double(max(deaths, 1))
        }

        var kad: Double? {
            guard matches > 0 else { return nil }
            return Double(kills + assists) / Double(max(deaths, 1))
        }
    }

    nonisolated private static func currentSeasonLabel(for date: Date = Date()) -> String {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)
        switch month {
        case 3...5:
            return "\(year) 春 · 新鲜赛季"
        case 6...8:
            return "\(year) 夏 · 灼热赛季"
        case 9...11:
            return "\(year) 秋 · 细雨赛季"
        default:
            return "\(year) 冬 · 寒冷赛季"
        }
    }

    nonisolated private static func loadLocalSnapshot(
        accountId: Int,
        cachedHistory: HistoryRecord?
    ) async -> LocalSnapshot {
        let now = Date()
        let season = currentSeasonLabel(for: now)
        let battlesRefresh = AppUserDefaults.shared.battlesRefreshTime
        let coopsRefresh = AppUserDefaults.shared.coopsRefreshTime

        let fallbackIdentity = IdentitySummary(
            name: cachedHistory?.account.name ?? "乌贼玩家",
            code: cachedHistory?.account.code,
            avatarData: cachedHistory?.account.avatar,
            udemae: cachedHistory?.udemae,
            udemaeMax: cachedHistory?.udemaeMax,
            rank: cachedHistory.flatMap { $0.rank > 0 ? $0.rank : nil },
            seasonLabel: season,
            localNameplate: nil,
            remoteNameplate: cachedHistory?.nameplate
        )

        do {
            return try await SplatDatabase.shared.dbQueue.read { db in
                let account = try Account.fetchOne(db, sql: "SELECT * FROM account WHERE id = ?", arguments: [accountId])
                let latestUdemae = try String.fetchOne(
                    db,
                    sql: "SELECT udemae FROM battle WHERE accountId = ? AND isDeleted = 0 AND udemae IS NOT NULL AND udemae != '' ORDER BY playedTime DESC LIMIT 1",
                    arguments: [accountId]
                )

                var localNameplate: LocalNameplateData?
                var fallbackPlayerName: String?
                if let playerRow = try Row.fetchOne(
                    db,
                    sql: """
                    SELECT p.name, p.byname, p.nameId, p.nameplate, p.nameplateTextColor, p.bynameFormatted
                    FROM player p
                    JOIN vsTeam t ON t.id = p.vsTeamId
                    JOIN battle b ON b.id = t.battleId
                    WHERE b.accountId = ? AND b.isDeleted = 0 AND p.isMyself = 1 AND p.isCoop = 0
                    ORDER BY b.playedTime DESC
                    LIMIT 1
                    """,
                    arguments: [accountId]
                ) ?? Row.fetchOne(
                    db,
                    sql: """
                    SELECT p.name, p.byname, p.nameId, p.nameplate, p.nameplateTextColor, p.bynameFormatted
                    FROM player p
                    JOIN coopPlayerResult r ON r.id = p.coopPlayerResultId
                    JOIN coop c ON c.id = r.coopId
                    WHERE c.accountId = ? AND c.isDeleted = 0 AND r.`order` = 0
                    ORDER BY c.playedTime DESC
                    LIMIT 1
                    """,
                    arguments: [accountId]
                ) {
                    let pName: String = playerRow["name"] ?? "----"
                    fallbackPlayerName = pName
                    let pByname: String = playerRow["byname"] ?? ""
                    let pNameId: String = (playerRow["nameId"] as String? ?? "").trimmingCharacters(in: CharacterSet(charactersIn: "'"))
                    if let npPack = PackableNumbers.fromDatabaseValue(playerRow["nameplate"]),
                       let tcPack = PackableNumbers.fromDatabaseValue(playerRow["nameplateTextColor"]) {
                        let resolved = Nameplate(nameplate: npPack, textColor: tcPack, db: db)
                        let formatted: FormattedByname? = PackableNumbers.fromDatabaseValue(playerRow["bynameFormatted"]).map {
                            FormattedByname(with: $0, db: db)
                        }
                        localNameplate = LocalNameplateData(
                            name: pName,
                            byname: pByname,
                            bynameFormatted: formatted,
                            nameId: pNameId,
                            background: resolved.background,
                            badges: resolved.badges,
                            textColor: resolved.textColor
                        )
                    }
                }

                // 本地最新对战段位优先于旧缓存，仅当本地无段位记录时回退 cachedHistory
                let resolvedUdemae = latestUdemae ?? cachedHistory?.udemae

                let identity = IdentitySummary(
                    name: account?.name ?? cachedHistory?.account.name ?? fallbackPlayerName ?? "乌贼玩家",
                    code: account?.code ?? cachedHistory?.account.code,
                    avatarData: account?.avatar ?? cachedHistory?.account.avatar,
                    udemae: resolvedUdemae,
                    udemaeMax: cachedHistory?.udemaeMax,
                    rank: cachedHistory.flatMap { $0.rank > 0 ? $0.rank : nil },
                    seasonLabel: season,
                    localNameplate: localNameplate,
                    remoteNameplate: cachedHistory?.nameplate
                )

                // All-time Battle Overview
                let allBattleStats = try queryBattleWindow(db: db, accountId: accountId, start: nil, end: nil)
                let festCount = try Int.fetchOne(
                    db,
                    sql: "SELECT COUNT(*) FROM battle WHERE accountId = ? AND isDeleted = 0 AND mode = 'FEST'",
                    arguments: [accountId]
                ) ?? 0

                let battleOverview = BattleOverview(
                    totalCount: allBattleStats.matches,
                    winRate: allBattleStats.winRate,
                    kd: allBattleStats.kd,
                    festCount: festCount,
                    latestUdemae: resolvedUdemae
                )

                // All-time Coop Overview
                let coopRow = try Row.fetchOne(
                    db,
                    sql: """
                    SELECT COUNT(*) AS totalCount,
                           SUM(CASE WHEN (rule = 'TEAM_CONTEST' AND wave >= 5 AND COALESCE(bossDefeated, 1) != 0)
                                      OR (rule != 'TEAM_CONTEST' AND wave >= 3)
                                    THEN 1 ELSE 0 END) AS clearCount,
                           MAX(afterGradePoint) AS maxGradePoint,
                           MAX(egg) AS maxEgg
                    FROM coop
                    WHERE accountId = ? AND isDeleted = 0
                    """,
                    arguments: [accountId]
                )
                let coopTotal: Int = coopRow?["totalCount"] ?? 0
                let coopClears: Int = coopRow?["clearCount"] ?? 0
                let coopOverview = CoopOverview(
                    totalCount: coopTotal,
                    clearRate: coopTotal > 0 ? Double(coopClears) / Double(coopTotal) * 100 : nil,
                    maxGradePoint: coopRow?["maxGradePoint"],
                    maxGoldenEgg: coopRow?["maxEgg"]
                )

                // MARK: - 近期表现三项明确口径
                // 口径 1（对战）：最近 50 场对战（对齐 SplatNet 3 官方战绩总览口径），涨跌对比第 51~100 场
                let windowSize = RecentPerformance.standardBattleWindowSize
                let currentSlice = try queryRecentBattleSlice(
                    db: db,
                    accountId: accountId,
                    limit: windowSize,
                    offset: 0
                )
                let previousSlice = try queryRecentBattleSlice(
                    db: db,
                    accountId: accountId,
                    limit: windowSize,
                    offset: windowSize
                )
                let currentStats = currentSlice.stats
                let previousStats = previousSlice.stats
                let sampleCount = currentStats.matches
                let battleScopeLabel = sampleCount > 0 ? "近 \(sampleCount) 场" : "近 \(windowSize) 场"

                let winRateDelta: Double? = {
                    guard previousStats.matches > 0,
                          let cur = currentStats.winRate,
                          let prev = previousStats.winRate else { return nil }
                    return cur - prev
                }()

                let kdDelta: Double? = {
                    guard previousStats.matches > 0,
                          let cur = currentStats.kd,
                          let prev = previousStats.kd else { return nil }
                    return cur - prev
                }()

                // 口径 2（鲑鱼跑）：优先取近 30 天自然日；若近 30 天为 0 场但存在历史记录，回退至最近 50 场并显式切换标签
                let thirtyDays: TimeInterval = 30 * 86_400
                let calendarStart = now.addingTimeInterval(-thirtyDays)
                let coop30Row = try Row.fetchOne(
                    db,
                    sql: """
                    SELECT COUNT(*) AS cnt,
                           SUM(CASE WHEN (rule = 'TEAM_CONTEST' AND wave >= 5 AND COALESCE(bossDefeated, 1) != 0)
                                      OR (rule != 'TEAM_CONTEST' AND wave >= 3)
                                    THEN 1 ELSE 0 END) AS clears
                    FROM coop
                    WHERE accountId = ? AND isDeleted = 0 AND playedTime >= ?
                    """,
                    arguments: [accountId, calendarStart]
                )
                let coop30Cnt: Int = coop30Row?["cnt"] ?? 0
                let coop30Clears: Int = coop30Row?["clears"] ?? 0

                let coopScopeLabel: String
                let recentCoopCnt: Int
                let recentCoopRate: Double?
                if coop30Cnt > 0 || coopTotal == 0 {
                    coopScopeLabel = "近 30 天鲑鱼跑"
                    recentCoopCnt = coop30Cnt
                    recentCoopRate = coop30Cnt > 0
                        ? Double(coop30Clears) / Double(coop30Cnt) * 100
                        : nil
                } else {
                    let fallbackCoopRow = try Row.fetchOne(
                        db,
                        sql: """
                        SELECT COUNT(*) AS cnt,
                               SUM(CASE WHEN (rule = 'TEAM_CONTEST' AND wave >= 5 AND COALESCE(bossDefeated, 1) != 0)
                                          OR (rule != 'TEAM_CONTEST' AND wave >= 3)
                                        THEN 1 ELSE 0 END) AS clears
                        FROM (
                            SELECT rule, wave, bossDefeated
                            FROM coop
                            WHERE accountId = ? AND isDeleted = 0
                            ORDER BY playedTime DESC, id DESC
                            LIMIT ?
                        )
                        """,
                        arguments: [accountId, windowSize]
                    )
                    let fbCnt: Int = fallbackCoopRow?["cnt"] ?? 0
                    let fbClears: Int = fallbackCoopRow?["clears"] ?? 0
                    coopScopeLabel = "近 \(fbCnt) 场鲑鱼跑"
                    recentCoopCnt = fbCnt
                    recentCoopRate = fbCnt > 0
                        ? Double(fbClears) / Double(fbCnt) * 100
                        : nil
                }

                // 口径 3（主力武器）：严格复用上方同一批最近 N（<=50）场对战样本，安全批量查询 imageMap 并提供缺失降级
                let weaponSampleLabel = "近 \(sampleCount) 场主力武器（共 \(sampleCount) 场）"
                let parsedEntries = currentSlice.weaponEntries

                // 一次性批量查询所有出现过的主武器 ID，若新赛季武器或半恢复数据库缺失对应行则优雅降级为占位图标与编号
                let uniqueWeaponIds = Array(Set(parsedEntries.map(\.mainWeaponId)))
                var weaponMapById: [UInt16: ImageMap] = [:]
                if !uniqueWeaponIds.isEmpty {
                    let placeholders = Array(repeating: "?", count: uniqueWeaponIds.count).joined(separator: ",")
                    let fetchedRows = (try? Row.fetchAll(
                        db,
                        sql: "SELECT id, nameId, name, hash FROM imageMap WHERE id IN (\(placeholders))",
                        arguments: StatementArguments(uniqueWeaponIds.map { Int($0) })
                    )) ?? []
                    for mapRow in fetchedRows {
                        if let rawId: Int = mapRow["id"],
                           let nameId: String = mapRow["nameId"],
                           let name: String = mapRow["name"] {
                            let hash: String = mapRow["hash"] ?? ""
                            weaponMapById[UInt16(rawId)] = ImageMap(nameId: nameId, name: name, hash: hash)
                        }
                    }
                }

                struct WeaponBucket {
                    let bucketKey: String
                    let imageName: String?
                    let nameId: String?
                    let fallbackTitle: String
                    var count: Int = 0
                    var wins: Int = 0
                    var decidedMatches: Int = 0
                }

                var weaponBuckets: [String: WeaponBucket] = [:]
                for entry in parsedEntries {
                    let resolvedMap = weaponMapById[entry.mainWeaponId]
                    let validImageName = resolvedMap.flatMap { $0.name.isEmpty ? nil : $0.name }
                    let validNameId = resolvedMap.flatMap { $0.nameId.isEmpty ? nil : $0.nameId }
                    let key = validImageName ?? "unknown-weapon-\(entry.mainWeaponId)"
                    let fallbackTitle = validImageName ?? "未知武器 #\(entry.mainWeaponId)"

                    var bucket = weaponBuckets[key] ?? WeaponBucket(
                        bucketKey: key,
                        imageName: validImageName,
                        nameId: validNameId,
                        fallbackTitle: fallbackTitle
                    )
                    bucket.count += 1
                    // 对齐 SplatDatabase/Utility/SQL.swift:193-196 的胜率口径
                    if entry.judgement == "WIN" {
                        bucket.wins += 1
                        bucket.decidedMatches += 1
                    } else if ["LOSE", "DRAW", "DEEMED_LOSE"].contains(entry.judgement) {
                        bucket.decidedMatches += 1
                    }
                    weaponBuckets[key] = bucket
                }

                let topWeapons = weaponBuckets.values
                    .sorted {
                        if $0.count != $1.count { return $0.count > $1.count }
                        if $0.wins != $1.wins { return $0.wins > $1.wins }
                        return $0.bucketKey < $1.bucketKey
                    }
                    .prefix(3)
                    .map { bucket in
                        let denom = max(bucket.decidedMatches, 1)
                        return TopWeaponItem(
                            id: bucket.bucketKey,
                            imageName: bucket.imageName,
                            nameId: bucket.nameId,
                            fallbackTitle: bucket.fallbackTitle,
                            matchCount: bucket.count,
                            winRate: Double(bucket.wins) / Double(denom) * 100
                        )
                    }

                let recent = RecentPerformance(
                    battleScopeLabel: battleScopeLabel,
                    matchCount: currentStats.matches,
                    winCount: currentStats.wins,
                    loseCount: currentStats.losses,
                    drawCount: currentStats.draws,
                    disconnectCount: currentStats.disconnects,
                    winRate: currentStats.winRate,
                    winRateDelta: winRateDelta,
                    kd: currentStats.kd,
                    kdDelta: kdDelta,
                    kad: currentStats.kad,
                    coopScopeLabel: coopScopeLabel,
                    recentCoopMatches: recentCoopCnt,
                    recentCoopClearRate: recentCoopRate,
                    topWeapons: Array(topWeapons),
                    weaponSampleLabel: weaponSampleLabel
                )

                // Trash（严格按当前 accountId 过滤）& 最新有效游玩时间（过滤 isDeleted = 0）
                let deletedBattles = try Int.fetchOne(
                    db,
                    sql: "SELECT COUNT(*) FROM battle WHERE accountId = ? AND isDeleted = 1",
                    arguments: [accountId]
                ) ?? 0
                let deletedCoops = try Int.fetchOne(
                    db,
                    sql: "SELECT COUNT(*) FROM coop WHERE accountId = ? AND isDeleted = 1",
                    arguments: [accountId]
                ) ?? 0

                let latestRecordDate: Date? = {
                    let bDate = try? Date.fetchOne(
                        db,
                        sql: "SELECT MAX(playedTime) FROM battle WHERE accountId = ? AND isDeleted = 0",
                        arguments: [accountId]
                    )
                    let cDate = try? Date.fetchOne(
                        db,
                        sql: "SELECT MAX(playedTime) FROM coop WHERE accountId = ? AND isDeleted = 0",
                        arguments: [accountId]
                    )
                    switch (bDate, cDate) {
                    case let (b?, c?): return max(b, c)
                    case let (b?, nil): return b
                    case let (nil, c?): return c
                    case (nil, nil): return nil
                    }
                }()

                let maxRefreshTs = max(battlesRefresh, coopsRefresh)
                let syncText: String
                if maxRefreshTs > 0 {
                    syncText = "最近同步 " + Date(timeIntervalSince1970: TimeInterval(maxRefreshTs)).toPlayedTimeString(full: false)
                } else if let latestRecordDate {
                    syncText = "最新记录 " + latestRecordDate.toPlayedTimeString(full: false)
                } else {
                    syncText = "尚未同步记录"
                }

                return LocalSnapshot(
                    identity: identity,
                    recent: recent,
                    battleOverview: battleOverview,
                    coopOverview: coopOverview,
                    trashCount: deletedBattles + deletedCoops,
                    lastSyncText: syncText
                )
            }
        } catch {
            logError(error)
            return LocalSnapshot(
                identity: fallbackIdentity,
                recent: RecentPerformance(
                    battleScopeLabel: "近 50 场",
                    matchCount: 0,
                    winCount: 0,
                    loseCount: 0,
                    drawCount: 0,
                    disconnectCount: 0,
                    winRate: nil,
                    winRateDelta: nil,
                    kd: nil,
                    kdDelta: nil,
                    kad: nil,
                    coopScopeLabel: "近 30 天鲑鱼跑",
                    recentCoopMatches: 0,
                    recentCoopClearRate: nil,
                    topWeapons: [],
                    weaponSampleLabel: "近 50 场主力武器（共 0 场）"
                ),
                battleOverview: BattleOverview(),
                coopOverview: CoopOverview(),
                trashCount: 0,
                lastSyncText: "尚未同步记录"
            )
        }
    }

    private struct BattleSliceResult {
        let stats: WindowStats
        let weaponEntries: [(mainWeaponId: UInt16, judgement: String)]
    }

    /// 按对战发生时间倒序取固定场次切片（如最近 1~50 场、前序 51~100 场），
    /// 同时返回聚合统计与主武器明细，保证「胜率 / KD / 主力武器」100% 同源。
    nonisolated private static func queryRecentBattleSlice(
        db: Database,
        accountId: Int,
        limit: Int,
        offset: Int
    ) throws -> BattleSliceResult {
        let rows = try Row.fetchAll(
            db,
            sql: """
            SELECT b.judgement AS judgement,
                   COALESCE(p.kill, 0) AS kill,
                   COALESCE(p.death, 0) AS death,
                   COALESCE(p.assist, 0) AS assist,
                   p.weapon AS weapon
            FROM battle b
            JOIN vsTeam t ON t.battleId = b.id
            JOIN player p ON p.vsTeamId = t.id AND p.isMyself = 1 AND p.isCoop = 0
            WHERE b.accountId = ? AND b.isDeleted = 0
            ORDER BY b.playedTime DESC, b.id DESC
            LIMIT ? OFFSET ?
            """,
            arguments: [accountId, limit, offset]
        )

        var wins = 0
        var losses = 0
        var draws = 0
        var disconnects = 0
        var decidedMatches = 0
        var kills = 0
        var deaths = 0
        var assists = 0
        var weaponEntries: [(mainWeaponId: UInt16, judgement: String)] = []
        weaponEntries.reserveCapacity(rows.count)

        for row in rows {
            let judgement: String = row["judgement"] ?? ""
            switch judgement {
            case "WIN":
                wins += 1
                decidedMatches += 1
            case "DRAW":
                draws += 1
                decidedMatches += 1
            case "DEEMED_LOSE":
                disconnects += 1
                decidedMatches += 1
            case "LOSE":
                losses += 1
                decidedMatches += 1
            default:
                // EXEMPTED_LOSE 等不计入胜率分母（对齐 SQL.swift:193-196），但归入负场桶保证四桶完备相加等于 matches
                losses += 1
            }

            kills += (row["kill"] as Int?) ?? 0
            deaths += (row["death"] as Int?) ?? 0
            assists += (row["assist"] as Int?) ?? 0

            if let packed = PackableNumbers.fromDatabaseValue(row["weapon"]), packed[0] != 0 {
                weaponEntries.append((mainWeaponId: packed[0], judgement: judgement))
            }
        }

        let stats = WindowStats(
            matches: rows.count,
            wins: wins,
            losses: losses,
            draws: draws,
            disconnects: disconnects,
            decidedMatches: decidedMatches,
            kills: kills,
            deaths: deaths,
            assists: assists
        )
        return BattleSliceResult(stats: stats, weaponEntries: weaponEntries)
    }

    nonisolated private static func queryBattleWindow(
        db: Database,
        accountId: Int,
        start: Date?,
        end: Date?
    ) throws -> WindowStats {
        var conditions = ["b.accountId = ?", "b.isDeleted = 0"]
        var args: [DatabaseValueConvertible] = [accountId]
        if let start {
            conditions.append("b.playedTime >= ?")
            args.append(start)
        }
        if let end {
            conditions.append("b.playedTime < ?")
            args.append(end)
        }

        // 胜率分母对齐 SplatDatabase/Utility/SQL.swift:193-196（WIN=1, LOSE/DRAW/DEEMED_LOSE=0, EXEMPTED_LOSE=NULL）；
        // 场次拆分桶满足 wins + losses + draws + disconnects == matches 恒成立。
        let sql = """
        SELECT COUNT(*) AS matches,
               SUM(CASE WHEN b.judgement = 'WIN' THEN 1 ELSE 0 END) AS wins,
               SUM(CASE WHEN b.judgement = 'DRAW' THEN 1 ELSE 0 END) AS draws,
               SUM(CASE WHEN b.judgement = 'DEEMED_LOSE' THEN 1 ELSE 0 END) AS disconnects,
               SUM(CASE WHEN b.judgement NOT IN ('WIN', 'DRAW', 'DEEMED_LOSE') THEN 1 ELSE 0 END) AS losses,
               SUM(CASE WHEN b.judgement IN ('WIN', 'LOSE', 'DRAW', 'DEEMED_LOSE') THEN 1 ELSE 0 END) AS decidedMatches,
               SUM(COALESCE(p.kill, 0)) AS kills,
               SUM(COALESCE(p.death, 0)) AS deaths,
               SUM(COALESCE(p.assist, 0)) AS assists
        FROM battle b
        JOIN vsTeam t ON t.battleId = b.id
        JOIN player p ON p.vsTeamId = t.id AND p.isMyself = 1 AND p.isCoop = 0
        WHERE \(conditions.joined(separator: " AND "))
        """

        let row = try Row.fetchOne(db, sql: sql, arguments: StatementArguments(args))
        return WindowStats(
            matches: row?["matches"] ?? 0,
            wins: row?["wins"] ?? 0,
            losses: row?["losses"] ?? 0,
            draws: row?["draws"] ?? 0,
            disconnects: row?["disconnects"] ?? 0,
            decidedMatches: row?["decidedMatches"] ?? 0,
            kills: row?["kills"] ?? 0,
            deaths: row?["deaths"] ?? 0,
            assists: row?["assists"] ?? 0
        )
    }
}

extension NameplateView {
    init(localData: MeDashboardViewModel.LocalNameplateData) {
        self.name = localData.name
        self.background = localData.background
        self.byname = localData.byname
        self.bynameFormatted = localData.bynameFormatted
        self.textColor = localData.textColor
        self.badges = localData.badges
        self.nameId = localData.nameId
    }
}
