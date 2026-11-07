import Foundation

/// 可以归属到某个班次（Shift / Group）的列表记录。
protocol GroupedRecord: Identifiable where ID == Int64 {
    var GroupId: Int64 { get }
}

/// 班次统计卡片需要具备的能力。
protocol GroupStatusCard {
    var startTime: Date { get }
    var count: Int { get }
}

/// 对战 / 打工列表的统一行模型：一行要么是具体记录，要么是班次统计卡片。
///
/// 之前的 `BattleListRowModel` / `CoopListRowModel` 结构完全相同，
/// 这里用一个泛型行模型统一，避免两份几乎一致的代码各自演化。
struct RecordListRow<Detail: GroupedRecord, Card: GroupStatusCard>: Identifiable {
    let detail: Detail?
    let card: Card?

    init(detail: Detail) {
        self.detail = detail
        self.card = nil
    }

    init(card: Card) {
        self.detail = nil
        self.card = card
    }

    var isDetail: Bool { detail != nil }
    var isCard: Bool { card != nil }

    var id: String {
        if let detail {
            return "detail-\(detail.id)"
        }
        if let card {
            return "card-\(card.startTime)-\(card.count)"
        }
        return "empty"
    }
}

extension RecordListRow: Equatable {
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }
}
