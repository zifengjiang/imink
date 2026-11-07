import Foundation

/// 批量操作（删除 / 恢复 / 收藏…）的统一进度反馈。
///
/// 把「进行中指示器 → 进度刷新 → 成功 / 失败提示」这套模板收敛到一处，
/// 调用方只关心真正的业务操作。
@MainActor
enum BatchOperation {
    /// 执行一次带进度提示的批量操作。
    ///
    /// - Parameters:
    ///   - title: 进行中的提示标题，例如「正在删除」。
    ///   - totalCount: 本次操作的总条数，用于进度展示；为 0 时直接返回。
    ///   - successTitle: 成功提示标题。
    ///   - successSubtitle: 成功提示副标题，入参为已处理条数。
    ///   - failureTitle: 失败提示标题。
    ///   - operation: 实际业务操作，通过 `reportProgress` 回调上报已处理条数。
    /// - Returns: 操作是否成功。
    @discardableResult
    static func run(
        title: String,
        totalCount: Int,
        successTitle: String,
        successSubtitle: @escaping (Int) -> String = { "已处理 \($0) 条记录" },
        failureTitle: String,
        operation: (_ reportProgress: @escaping (Int) async -> Void) async throws -> Void
    ) async -> Bool {
        guard totalCount > 0 else { return false }

        let indicatorId = Toast.progress(title: title, subtitle: "0/\(totalCount)")

        do {
            try await operation { processed in
                await MainActor.run {
                    Toast.update(id: indicatorId, subtitle: "\(processed)/\(totalCount)")
                }
            }
            Toast.dismiss(indicatorId)
            Toast.success(successTitle, subtitle: successSubtitle(totalCount))
            return true
        } catch {
            Toast.dismiss(indicatorId)
            Toast.failure(failureTitle, subtitle: error.localizedDescription)
            return false
        }
    }
}
