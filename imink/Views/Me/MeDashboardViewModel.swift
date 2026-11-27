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
        let imageName: String
        let nameId: String
        let matchCount: Int
        let winRate: Double
    }

    struct RecentPerformance {
        var windowTitle: String
        var matchCount: Int
        var winCount: Int
        var loseCount: Int
        var winRate: Double?
        var winRateDelta: Double?
        var kd: Double?
        var kdDelta: Double?
        var kad: Double?
        var recentCoopMatches: Int
        var recentCoopClearRate: Double?
        var topWeapons: [TopWeaponItem]
        var weaponSampleLabel: String
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
        windowTitle: "近 30 天",
        matchCount: 0,
        winCount: 0,
        loseCount: 0,
        winRate: nil,
        winRateDelta: nil,
        kd: nil,
        kdDelta: nil,
        kad: nil,
        recentCoopMatches: 0,
        recentCoopClearRate: nil,
        topWeapons: [],
        weaponSampleLabel: "近 30 天"
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

        // 若近期已确认离线且非用户手动下拉刷新，直接保持本地展示，不反复重试打扰
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
            // 达到有限重试上限后收敛为离线本地态，绝不弹出或常驻全局重试贴纸
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

    private struct WindowStats {
        let matches: Int
        let wins: Int
        let losses: Int
        let disconnects: Int
        let kills: Int
        let deaths: Int
        let assists: Int

        var winRate: Double? {
            let denom = wins + losses + disconnects
            guard denom > 0 else { return nil }
            return Double(wins) / Double(denom) * 100
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

                let identity = IdentitySummary(
                    name: account?.name ?? cachedHistory?.account.name ?? fallbackPlayerName ?? "乌贼玩家",
                    code: account?.code ?? cachedHistory?.account.code,
                    avatarData: account?.avatar ?? cachedHistory?.account.avatar,
                    udemae: cachedHistory?.udemae ?? latestUdemae,
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
                    latestUdemae: cachedHistory?.udemae ?? latestUdemae
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

                // Recent 30-day window (real calendar 30d first; fallback to latest active 30d window if 0 recent PvP matches)
                let thirtyDays: TimeInterval = 30 * 86_400
                let calendarStart = now.addingTimeInterval(-thirtyDays)
                let calendarPrevStart = now.addingTimeInterval(-2 * thirtyDays)
                let live30Stats = try queryBattleWindow(db: db, accountId: accountId, start: calendarStart, end: now)

                let activeEnd: Date
                let windowTitle: String
                let currentStats: WindowStats
                let previousStats: WindowStats

                if live30Stats.matches > 0 {
                    activeEnd = now
                    windowTitle = "近 30 天"
                    currentStats = live30Stats
                    previousStats = try queryBattleWindow(db: db, accountId: accountId, start: calendarPrevStart, end: calendarStart)
                } else if let maxBattleDate = try Date.fetchOne(
                    db,
                    sql: "SELECT MAX(playedTime) FROM battle WHERE accountId = ? AND isDeleted = 0",
                    arguments: [accountId]
                ) {
                    activeEnd = maxBattleDate.addingTimeInterval(1)
                    let activeStart = activeEnd.addingTimeInterval(-thirtyDays)
                    let prevStart = activeEnd.addingTimeInterval(-2 * thirtyDays)
                    let formatter = DateFormatter()
                    formatter.dateFormat = "MM/dd"
                    windowTitle = "最近活跃 30 天（截至 \(formatter.string(from: maxBattleDate))）"
                    currentStats = try queryBattleWindow(db: db, accountId: accountId, start: activeStart, end: activeEnd)
                    previousStats = try queryBattleWindow(db: db, accountId: accountId, start: prevStart, end: activeStart)
                } else {
                    activeEnd = now
                    windowTitle = "近 30 天"
                    currentStats = live30Stats
                    previousStats = WindowStats(matches: 0, wins: 0, losses: 0, disconnects: 0, kills: 0, deaths: 0, assists: 0)
                }

                let winRateDelta: Double? = {
                    guard let cur = currentStats.winRate, let prev = previousStats.winRate else { return nil }
                    return cur - prev
                }()

                let kdDelta: Double? = {
                    guard let cur = currentStats.kd, let prev = previousStats.kd else { return nil }
                    return cur - prev
                }()

                // Recent 30d Salmon Run pulse
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
                let recentCoopCnt: Int = coop30Row?["cnt"] ?? 0
                let recentCoopClears: Int = coop30Row?["clears"] ?? 0
                let recentCoopRate: Double? = recentCoopCnt > 0
                    ? Double(recentCoopClears) / Double(recentCoopCnt) * 100
                    : nil

                // Top 3 Weapons (from active 30-day window if >= 6 battles, else latest 60 battles for meaningful Top 3)
                let use30dForWeapons = currentStats.matches >= 6
                let weaponRows: [Row]
                let weaponSampleLabel: String
                if use30dForWeapons {
                    weaponSampleLabel = "周期内常用 Top 3"
                    weaponRows = try Row.fetchAll(
                        db,
                        sql: """
                        SELECT p.weapon AS weapon, b.judgement AS judgement
                        FROM battle b
                        JOIN vsTeam t ON t.battleId = b.id
                        JOIN player p ON p.vsTeamId = t.id AND p.isMyself = 1 AND p.isCoop = 0
                        WHERE b.accountId = ? AND b.isDeleted = 0 AND b.playedTime >= ? AND b.playedTime <= ?
                        ORDER BY b.playedTime DESC
                        """,
                        arguments: [accountId, activeEnd.addingTimeInterval(-thirtyDays), activeEnd]
                    )
                } else {
                    weaponSampleLabel = "近 \(min(allBattleStats.matches, 60)) 场对战主力 Top 3"
                    weaponRows = try Row.fetchAll(
                        db,
                        sql: """
                        SELECT p.weapon AS weapon, b.judgement AS judgement
                        FROM battle b
                        JOIN vsTeam t ON t.battleId = b.id
                        JOIN player p ON p.vsTeamId = t.id AND p.isMyself = 1 AND p.isCoop = 0
                        WHERE b.accountId = ? AND b.isDeleted = 0
                        ORDER BY b.playedTime DESC
                        LIMIT 60
                        """,
                        arguments: [accountId]
                    )
                }

                struct WeaponBucket {
                    let imageName: String
                    let nameId: String
                    var count: Int = 0
                    var wins: Int = 0
                    var lossesOrDisconnects: Int = 0
                }

                var weaponBuckets: [String: WeaponBucket] = [:]
                for row in weaponRows {
                    guard let packed = PackableNumbers.fromDatabaseValue(row["weapon"]) else { continue }
                    let resolved = Player.Weapon(with: packed, db: db)
                    let key = resolved.mainWeapon.name
                    guard !key.isEmpty else { continue }
                    var bucket = weaponBuckets[key] ?? WeaponBucket(
                        imageName: resolved.mainWeapon.name,
                        nameId: resolved.mainWeapon.nameId
                    )
                    bucket.count += 1
                    let judgement: String = row["judgement"] ?? ""
                    if judgement == "WIN" {
                        bucket.wins += 1
                    } else if judgement.contains("LOSE") {
                        bucket.lossesOrDisconnects += 1
                    }
                    weaponBuckets[key] = bucket
                }

                let topWeapons = weaponBuckets.values
                    .sorted {
                        if $0.count != $1.count { return $0.count > $1.count }
                        return $0.wins > $1.wins
                    }
                    .prefix(3)
                    .map { bucket in
                        let denom = max(bucket.wins + bucket.lossesOrDisconnects, 1)
                        return TopWeaponItem(
                            id: bucket.imageName,
                            imageName: bucket.imageName,
                            nameId: bucket.nameId,
                            matchCount: bucket.count,
                            winRate: Double(bucket.wins) / Double(denom) * 100
                        )
                    }

                let recent = RecentPerformance(
                    windowTitle: windowTitle,
                    matchCount: currentStats.matches,
                    winCount: currentStats.wins,
                    loseCount: currentStats.losses,
                    winRate: currentStats.winRate,
                    winRateDelta: winRateDelta,
                    kd: currentStats.kd,
                    kdDelta: kdDelta,
                    kad: currentStats.kad,
                    recentCoopMatches: recentCoopCnt,
                    recentCoopClearRate: recentCoopRate,
                    topWeapons: Array(topWeapons),
                    weaponSampleLabel: weaponSampleLabel
                )

                // Trash & Sync time
                let deletedBattles = try Int.fetchOne(
                    db,
                    sql: "SELECT COUNT(*) FROM battle WHERE isDeleted = 1"
                ) ?? 0
                let deletedCoops = try Int.fetchOne(
                    db,
                    sql: "SELECT COUNT(*) FROM coop WHERE isDeleted = 1"
                ) ?? 0

                let latestRecordDate: Date? = {
                    let bDate = try? Date.fetchOne(db, sql: "SELECT MAX(playedTime) FROM battle WHERE accountId = ?", arguments: [accountId])
                    let cDate = try? Date.fetchOne(db, sql: "SELECT MAX(playedTime) FROM coop WHERE accountId = ?", arguments: [accountId])
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
                    windowTitle: "近 30 天",
                    matchCount: 0,
                    winCount: 0,
                    loseCount: 0,
                    winRate: nil,
                    winRateDelta: nil,
                    kd: nil,
                    kdDelta: nil,
                    kad: nil,
                    recentCoopMatches: 0,
                    recentCoopClearRate: nil,
                    topWeapons: [],
                    weaponSampleLabel: "近 30 天"
                ),
                battleOverview: BattleOverview(),
                coopOverview: CoopOverview(),
                trashCount: 0,
                lastSyncText: "尚未同步记录"
            )
        }
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

        let sql = """
        SELECT COUNT(*) AS matches,
               SUM(CASE WHEN b.judgement = 'WIN' THEN 1 ELSE 0 END) AS wins,
               SUM(CASE WHEN b.judgement LIKE '%LOSE%' AND b.judgement NOT LIKE '%DEEMED_LOSE%' THEN 1 ELSE 0 END) AS losses,
               SUM(CASE WHEN b.judgement LIKE '%DEEMED_LOSE%' THEN 1 ELSE 0 END) AS disconnects,
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
            disconnects: row?["disconnects"] ?? 0,
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
