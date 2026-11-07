import Foundation
import SplatDatabase

extension CoopListRowInfo: GroupedRecord {}

extension CoopGroupStatus: GroupStatusCard {}

/// 打工列表的行模型（记录行 / 班次卡片行）。
typealias CoopListRowModel = RecordListRow<CoopListRowInfo, CoopGroupStatus>
