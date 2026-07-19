import Foundation
import Combine
import GRDB
import SplatDatabase

@MainActor
final class BattleShiftDetailViewModel: ObservableObject {
    struct StageItem: Identifiable {
        let id: String
        let imageName: String
        let nameId: String
        let count: Int
    }

    struct WeaponItem: Identifiable {
        let id: String
        let imageName: String
        let nameId: String
        let count: Int
    }

    struct PlayerEncounter: Identifiable {
        let id: String
        let representative: Player
        let count: Int
        let kill: Int
        let assist: Int
        let death: Int
        let special: Int
        let paint: Int
        let color: ColorSnapshot

        var averagePaint: Int {
            guard count > 0 else { return 0 }
            return paint / count
        }
    }

    struct ColorSnapshot {
        let red: Double
        let green: Double
        let blue: Double
    }

    @Published private(set) var initialized = false
    @Published private(set) var status: BattleGroupStatus?
    @Published private(set) var battles: [Battle] = []
    @Published private(set) var summary = BattleShiftSummaryBuilder.Summary.empty
    @Published private(set) var stageItems: [StageItem] = []
    @Published private(set) var weaponItems: [WeaponItem] = []
    @Published private(set) var teammatePlayers: [PlayerEncounter] = []
    @Published private(set) var opponentPlayers: [PlayerEncounter] = []

    let groupId: Int

    init(groupId: Int) {
        self.groupId = groupId
    }

    func load() {
        Task {
            do {
                let snapshot = try await Self.loadSnapshot(groupId: groupId)
                status = snapshot.status
                battles = snapshot.battles
                summary = snapshot.summary
                stageItems = snapshot.stageItems
                weaponItems = snapshot.weaponItems
                teammatePlayers = snapshot.teammatePlayers
                opponentPlayers = snapshot.opponentPlayers
                initialized = true
            } catch {
                print("BattleShiftDetailViewModel load error: \(error)")
                initialized = true
            }
        }
    }

    private struct Snapshot {
        let status: BattleGroupStatus?
        let battles: [Battle]
        let summary: BattleShiftSummaryBuilder.Summary
        let stageItems: [StageItem]
        let weaponItems: [WeaponItem]
        let teammatePlayers: [PlayerEncounter]
        let opponentPlayers: [PlayerEncounter]
    }

    nonisolated private static func loadSnapshot(groupId: Int) async throws -> Snapshot {
        let accountId = AppUserDefaults.shared.accountId

        return try await SplatDatabase.shared.dbQueue.read { db in
            let status: BattleGroupStatus? = try BattleGroupStatus.create(from: db, identifier: (groupId, accountId))
            let ids = try Int64.fetchAll(
                db,
                sql: "SELECT id FROM battle_view WHERE GroupID = ? AND accountId = ? ORDER BY playedTime DESC",
                arguments: [groupId, accountId]
            )
            let battles = try ids.compactMap { try Battle.create(from: db, identifier: Int($0)) }
            let summary = BattleShiftSummaryBuilder.build(from: battles.map(Self.makeSummaryInput))

            return Snapshot(
                status: status,
                battles: battles,
                summary: summary,
                stageItems: makeStageItems(from: battles),
                weaponItems: makeWeaponItems(from: battles),
                teammatePlayers: makePlayerEncounters(from: battles, includeMyTeam: true),
                opponentPlayers: makePlayerEncounters(from: battles, includeMyTeam: false)
            )
        }
    }

    nonisolated private static func makeSummaryInput(from battle: Battle) -> BattleShiftSummaryBuilder.BattleInput {
        let player = battle.myPlayer
        return .init(
            judgement: battle.judgement,
            rule: battle.rule,
            stageName: battle.stage?.name,
            weaponName: player?._weapon?.mainWeapon.name,
            kill: player?.kill ?? 0,
            assist: player?.assist ?? 0,
            death: player?.death ?? 0
        )
    }

    nonisolated private static func makeStageItems(from battles: [Battle]) -> [StageItem] {
        let grouped = Dictionary(grouping: battles.compactMap(\.stage)) { $0.name }

        return battles.compactMap(\.stage)
            .reduce(into: [StageItem]()) { result, stage in
                guard !result.contains(where: { $0.id == stage.name }) else { return }
                result.append(
                    StageItem(
                        id: stage.name,
                        imageName: stage.name,
                        nameId: stage.nameId,
                        count: grouped[stage.name]?.count ?? 0
                    )
                )
            }
    }

    nonisolated private static func makeWeaponItems(from battles: [Battle]) -> [WeaponItem] {
        let weapons = battles.compactMap { $0.myPlayer?._weapon?.mainWeapon }
        let grouped = Dictionary(grouping: weapons) { $0.name }

        return weapons.reduce(into: [WeaponItem]()) { result, weapon in
            guard !result.contains(where: { $0.id == weapon.name }) else { return }
            result.append(
                WeaponItem(
                    id: weapon.name,
                    imageName: weapon.name,
                    nameId: weapon.nameId,
                    count: grouped[weapon.name]?.count ?? 0
                )
            )
        }
    }

    nonisolated private static func makePlayerEncounters(from battles: [Battle], includeMyTeam: Bool) -> [PlayerEncounter] {
        var buckets: [String: PlayerEncounterAccumulator] = [:]

        for battle in battles {
            guard let myTeamId = battle.myTeam?.id else { continue }

            for team in battle.teams {
                let isMyTeam = team.id == myTeamId
                guard isMyTeam == includeMyTeam else { continue }

                let color = team.color
                for player in team.players {
                    let id = player.sp3PrincipalId.isEmpty ? "\(player.name)#\(player.nameId)" : player.sp3PrincipalId
                    buckets[id, default: PlayerEncounterAccumulator(representative: player, color: color)]
                        .append(player)
                }
            }
        }

        return buckets.map { id, bucket in
            PlayerEncounter(
                id: id,
                representative: bucket.representative,
                count: bucket.count,
                kill: bucket.kill,
                assist: bucket.assist,
                death: bucket.death,
                special: bucket.special,
                paint: bucket.paint,
                color: ColorSnapshot(
                    red: Double(bucket.color[0]) / 255.0,
                    green: Double(bucket.color[1]) / 255.0,
                    blue: Double(bucket.color[2]) / 255.0
                )
            )
        }
        .sorted {
            if ($0.representative.isMyself ?? false) != ($1.representative.isMyself ?? false) {
                return $0.representative.isMyself ?? false
            }
            if $0.count == $1.count {
                return $0.representative.name < $1.representative.name
            }
            return $0.count > $1.count
        }
    }

    private struct PlayerEncounterAccumulator {
        var representative: Player
        var color: PackableNumbers
        var count = 0
        var kill = 0
        var assist = 0
        var death = 0
        var special = 0
        var paint = 0

        mutating func append(_ player: Player) {
            count += 1
            kill += player.kill ?? 0
            assist += player.assist ?? 0
            death += player.death ?? 0
            special += player.special ?? 0
            paint += player.paint ?? 0
            if player.isMyself == true {
                representative = player
            }
        }
    }
}

private extension Battle {
    var myTeam: VsTeam? {
        teams.first { team in
            team.players.contains { $0.isMyself == true }
        }
    }

    var myPlayer: Player? {
        myTeam?.players.first { $0.isMyself == true }
    }
}
