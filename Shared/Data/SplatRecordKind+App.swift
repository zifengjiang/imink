import Foundation
import SplatDatabase

extension SplatRecordKind {
    /// 记录数据变更通知，用于列表与回收站自动刷新。
    var dataChangedNotification: Notification.Name {
        switch self {
        case .coop: return .coopDataChanged
        case .battle: return .battleDataChanged
        }
    }

    /// 展示用名称，例如「打工」。
    var recordName: String {
        switch self {
        case .coop: return "打工"
        case .battle: return "对战"
        }
    }
}
