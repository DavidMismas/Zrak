import SwiftUI

struct AirQualityLegendView: View {
    private let levels: [AirQualityLevel] = [
        .good,
        .moderate,
        .unhealthySensitive,
        .unhealthy,
        .veryUnhealthy,
        .noData
    ]
    private let columns = [
        GridItem(.flexible(), spacing: 6),
        GridItem(.flexible(), spacing: 6)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 6) {
            ForEach(levels, id: \.self) { level in
                HStack(spacing: 5) {
                    Circle()
                        .fill(level.color)
                        .frame(width: 8, height: 8)
                    Text(level.title)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(level == .unhealthySensitive ? 2 : 1)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 5)
                .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
    }
}
