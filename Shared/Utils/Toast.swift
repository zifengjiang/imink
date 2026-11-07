import Foundation
import SwiftUI

/// `Indicators` 的语义化封装。
///
/// 统一成功 / 失败 / 进行中提示的图标、样式与停留时长，
/// 避免各处重复拼装 `Indicator(...)` 参数。
///
/// 内部保证 UI 更新发生在主线程，因此可以在任意上下文中调用
/// （例如网络回调、数据库事务回调）。
enum Toast {
    /// 成功提示，默认 2 秒后自动消失。
    static func success(
        _ title: String,
        subtitle: String? = nil,
        dismissAfter delay: TimeInterval = 2
    ) {
        onMain {
            Indicators.shared.display(.init(
                icon: .systemImage("checkmark.circle.fill"),
                title: title,
                subtitle: subtitle,
                dismissType: .after(delay)
            ))
        }
    }

    /// 失败提示，默认 3 秒后自动消失。
    static func failure(
        _ title: String,
        subtitle: String? = nil,
        dismissAfter delay: TimeInterval = 3
    ) {
        onMain {
            Indicators.shared.display(.init(
                icon: .systemImage("xmark.circle.fill"),
                title: title,
                subtitle: subtitle,
                dismissType: .after(delay),
                style: .error
            ))
        }
    }

    /// 展示一个需要手动关闭的进度提示，返回其 id。
    @discardableResult
    static func progress(
        id: String = UUID().uuidString,
        title: String,
        subtitle: String? = nil
    ) -> String {
        onMain {
            Indicators.shared.display(.init(
                id: id,
                icon: .progressIndicator,
                title: title,
                subtitle: subtitle,
                dismissType: .manual,
                isUserDismissible: false
            ))
        }
        return id
    }

    /// 更新进度提示的副标题。
    static func update(id: String, subtitle: String) {
        onMain {
            Indicators.shared.updateSubtitle(for: id, subtitle: subtitle)
        }
    }

    /// 关闭指定提示。
    static func dismiss(_ id: String) {
        onMain {
            Indicators.shared.dismiss(with: id)
        }
    }

    /// 把进行中的提示切换为终态：成功显示对勾，失败显示错误图标。
    static func finish(id: String, title: String, failed: Bool = false) {
        onMain {
            Indicators.shared.updateTitle(for: id, title: title)
            Indicators.shared.updateIcon(for: id, icon: failed ? .systemImage("xmark.icloud") : .success)
        }
    }

    /// 已在主线程时同步执行，避免多一次调度；否则切到主线程执行。
    private static func onMain(_ block: @escaping @MainActor () -> Void) {
        if Thread.isMainThread {
            MainActor.assumeIsolated {
                block()
            }
        } else {
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    block()
                }
            }
        }
    }
}
