import Foundation

extension BattleListRowInfo: GroupedRecord {}

extension BattleGroupStatus: GroupStatusCard {}

/// 对战列表的行模型（记录行 / 班次卡片行）。
typealias BattleListRowModel = RecordListRow<BattleListRowInfo, BattleGroupStatus>
