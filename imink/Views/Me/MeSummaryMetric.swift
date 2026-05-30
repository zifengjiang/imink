import Foundation

struct MeSummaryMetric: Equatable, Identifiable {
    enum Kind: Equatable {
        case battle
        case salmonRun
    }

    let kind: Kind
    let title: String
    let value: String
    let icon: String
    let caption: String

    var id: Kind {
        kind
    }

    static func recordCounts(
        battleCount: Int,
        salmonRunCount: Int,
        locale: Locale = .current
    ) -> [MeSummaryMetric] {
        [
            MeSummaryMetric(
                kind: .battle,
                title: "战斗记录",
                value: formattedCount(battleCount, locale: locale),
                icon: "paintpalette.fill",
                caption: "本地已保存"
            ),
            MeSummaryMetric(
                kind: .salmonRun,
                title: "鲑鱼跑记录",
                value: formattedCount(salmonRunCount, locale: locale),
                icon: "drop.fill",
                caption: "本地已保存"
            )
        ]
    }

    private static func formattedCount(_ count: Int, locale: Locale) -> String {
        count.formatted(.number.locale(locale))
    }
}
