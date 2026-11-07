import Foundation
import Combine

/// 「先展示本地缓存、再拉取远端记录」的通用视图模型能力。
///
/// 地图记录、武器记录、打工记录等多个页面都遵循同一套缓存策略，
/// 这里统一加载与刷新流程，子类只提供数据来源。
@MainActor
protocol CachedRecordViewModel: AnyObject, ObservableObject {
    associatedtype Record

    /// 当前展示的数据。
    var value: Record? { get set }

    /// 读取本地缓存；没有缓存时返回 nil。
    func readCache() -> Record?

    /// 写入本地缓存。
    func writeCache(_ record: Record)

    /// 从远端拉取最新记录；失败时返回 nil。
    func fetchRemote() async -> Record?

    /// 数据更新后的回调，默认为空实现（有排序等派生状态时可覆盖）。
    func didUpdateValue()
}

extension CachedRecordViewModel {
    func didUpdateValue() {}

    /// 优先展示缓存，没有缓存时才发起网络请求。
    func loadCachedThenRemote() async {
        if let cached = readCache() {
            value = cached
            didUpdateValue()
        }
        guard value == nil else { return }
        await refreshRemote()
    }

    /// 强制从远端刷新并写入缓存。
    func refreshRemote() async {
        let record = await fetchRemote()
        value = record
        didUpdateValue()
        if let record {
            writeCache(record)
        }
    }
}
