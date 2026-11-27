import SwiftUI

struct SWKPICard<Trailing: View>: View {
    let title: LocalizedStringKey
    let value: String
    let icon: String
    let tint: Color
    @ViewBuilder let trailing: Trailing

    init(
        title: LocalizedStringKey,
        value: String,
        icon: String,
        tint: Color,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = title
        self.value = value
        self.icon = icon
        self.tint = tint
        self.trailing = trailing()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 8) {
                Image(systemName: icon)
                    .font(.appBody)
                    .foregroundStyle(tint)
                    .frame(width: 28, height: 28)
                    .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                Spacer(minLength: 0)

                trailing
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.appGameMetric(size: 24))
                    .foregroundStyle(.appLabel)
                    .contentTransition(.numericText())
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Text(title)
                    .font(.appCaption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
        .background(Color.listItemBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

extension SWKPICard where Trailing == EmptyView {
    init(
        title: LocalizedStringKey,
        value: String,
        icon: String,
        tint: Color
    ) {
        self.init(title: title, value: value, icon: icon, tint: tint) {
            EmptyView()
        }
    }
}
