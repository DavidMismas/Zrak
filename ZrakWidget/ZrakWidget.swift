import StoreKit
import SwiftUI
import WidgetKit

struct WidgetAirQualityLevel {
    let title: String
    let color: Color

    static func from(pm25: Double?, pm10: Double?) -> WidgetAirQualityLevel {
        if let pm25, pm25 >= 0 {
            switch pm25 {
            case 0 ... 15:
                return WidgetAirQualityLevel(title: "Dobro", color: .green)
            case 16 ... 35:
                return WidgetAirQualityLevel(title: "Zmerno", color: .yellow)
            case 36 ... 55:
                return WidgetAirQualityLevel(title: "Občutljive skupine", color: .orange)
            case 56 ... 100:
                return WidgetAirQualityLevel(title: "Nezdravo", color: .red)
            default:
                return WidgetAirQualityLevel(title: "Zelo nezdravo", color: .purple)
            }
        }

        if let pm10, pm10 >= 0 {
            switch pm10 {
            case 0 ... 25:
                return WidgetAirQualityLevel(title: "Dobro", color: .green)
            case 26 ... 50:
                return WidgetAirQualityLevel(title: "Zmerno", color: .yellow)
            case 51 ... 100:
                return WidgetAirQualityLevel(title: "Nezdravo", color: .red)
            default:
                return WidgetAirQualityLevel(title: "Zelo nezdravo", color: .purple)
            }
        }

        return WidgetAirQualityLevel(title: "Ni podatkov", color: .gray)
    }
}

struct AirQualityWidgetEntry: TimelineEntry {
    let date: Date
    let station: WidgetSharedStation?
    let chartRange: WidgetChartRange
    let isPremiumUnlocked: Bool
}

struct AirQualityWidgetProvider: AppIntentTimelineProvider {
    typealias Entry = AirQualityWidgetEntry
    typealias Intent = StationSelectionIntent

    func placeholder(in context: Context) -> AirQualityWidgetEntry {
        AirQualityWidgetEntry(date: Date(), station: sampleStation, chartRange: .h24, isPremiumUnlocked: false)
    }

    func snapshot(for configuration: StationSelectionIntent, in context: Context) async -> AirQualityWidgetEntry {
        await makeEntry(configuration: configuration)
    }

    func timeline(for configuration: StationSelectionIntent, in context: Context) async -> Timeline<AirQualityWidgetEntry> {
        let entry = await makeEntry(configuration: configuration)
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date().addingTimeInterval(1800)
        return Timeline(entries: [entry], policy: .after(nextRefresh))
    }

    private func makeEntry(configuration: StationSelectionIntent) async -> AirQualityWidgetEntry {
        let payload = WidgetSharedStore.readPayload()
        let selectedCode = configuration.station?.id
        let isPremiumUnlocked = await resolvePremiumAccess()

        let station = payload?.stations.first(where: { $0.code == selectedCode }) ?? payload?.stations.first

        return AirQualityWidgetEntry(
            date: Date(),
            station: station,
            chartRange: configuration.chartRange,
            isPremiumUnlocked: isPremiumUnlocked
        )
    }

    private func resolvePremiumAccess() async -> Bool {
        if PremiumAccessSharedStore.readIsPremiumUnlocked() {
            return true
        }

        return await hasPremiumEntitlement()
    }

    private func hasPremiumEntitlement() async -> Bool {
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else {
                continue
            }

            guard WidgetPremiumConfig.productIDs.contains(transaction.productID) else {
                continue
            }

            if transaction.revocationDate != nil {
                continue
            }

            if let expirationDate = transaction.expirationDate,
               expirationDate < Date() {
                continue
            }

            return true
        }

        return false
    }

    private var sampleStation: WidgetSharedStation {
        WidgetSharedStation(
            code: "E403",
            name: "LJ Bežigrad",
            lastUpdate: Date(),
            pm25: 12,
            pm10: 18,
            no2: 22,
            o3: 65,
            so2: 3,
            co: 0.4,
            chart24h: [
                WidgetSharedChartPoint(timestamp: Date().addingTimeInterval(-3600 * 3), value: 10),
                WidgetSharedChartPoint(timestamp: Date().addingTimeInterval(-3600 * 2), value: 11),
                WidgetSharedChartPoint(timestamp: Date().addingTimeInterval(-3600), value: 13),
                WidgetSharedChartPoint(timestamp: Date(), value: 12)
            ],
            chart7d: [
                WidgetSharedChartPoint(timestamp: Date().addingTimeInterval(-3600 * 24 * 6), value: 8),
                WidgetSharedChartPoint(timestamp: Date().addingTimeInterval(-3600 * 24 * 5), value: 11),
                WidgetSharedChartPoint(timestamp: Date().addingTimeInterval(-3600 * 24 * 4), value: 12),
                WidgetSharedChartPoint(timestamp: Date().addingTimeInterval(-3600 * 24 * 3), value: 9),
                WidgetSharedChartPoint(timestamp: Date().addingTimeInterval(-3600 * 24 * 2), value: 14),
                WidgetSharedChartPoint(timestamp: Date().addingTimeInterval(-3600 * 24), value: 10),
                WidgetSharedChartPoint(timestamp: Date(), value: 12)
            ]
        )
    }
}

private enum WidgetPremiumConfig {
    static let productIDs: Set<String> = [
        "com.david.Zrak.premium.lifetime"
    ]
}

struct ZrakWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: AirQualityWidgetEntry

    var body: some View {
        if !isPremiumUnlocked {
            lockedView
        } else {
            unlockedBody
        }
    }

    private var isPremiumUnlocked: Bool {
        entry.isPremiumUnlocked || PremiumAccessSharedStore.readIsPremiumUnlocked()
    }

    @ViewBuilder
    private var unlockedBody: some View {
        switch family {
        case .systemSmall:
            smallView
        case .systemMedium:
            mediumView
        case .systemLarge:
            largeView
        default:
            smallView
        }
    }

    private var lockedView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "lock.fill")
                .font(.title3)
                .foregroundStyle(.secondary)

            Text("Widget je del Premium")
                .font(.headline)
                .lineLimit(2)

            Text("Odkleni v aplikaciji Zrak.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            Spacer(minLength: 0)
        }
    }

    private var smallView: some View {
        let level = WidgetAirQualityLevel.from(pm25: entry.station?.pm25, pm10: entry.station?.pm10)

        return VStack(alignment: .leading, spacing: 6) {
            Text(entry.station?.name ?? "Ni podatkov")
                .font(.caption.weight(.semibold))
                .lineLimit(2)

            Text(primaryMetricValueText)
                .font(.title3.bold())
                .foregroundStyle(level.color)
                .lineLimit(1)

            Text(level.title)
                .font(.caption2)
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)

            Text(lastUpdateText)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var mediumView: some View {
        let level = WidgetAirQualityLevel.from(pm25: entry.station?.pm25, pm10: entry.station?.pm10)

        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(entry.station?.name ?? "Ni podatkov")
                    .font(.headline)
                    .lineLimit(1)

                Spacer(minLength: 8)

                Text(primaryMetricValueText)
                    .font(.title3.bold())
                    .foregroundStyle(level.color)
                    .lineLimit(1)
            }

            Sparkline24hView(points: selectedChartPoints, color: level.color)
                .frame(height: 88)

            HStack {
                Text("\(primaryMetricName) • \(entry.chartRange.title)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Osveženo: \(lastUpdateText)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    private var largeView: some View {
        let level = WidgetAirQualityLevel.from(pm25: entry.station?.pm25, pm10: entry.station?.pm10)

        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(entry.station?.name ?? "Ni podatkov")
                    .font(.headline)
                    .lineLimit(1)

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 2) {
                    Text(primaryMetricName)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(primaryMetricValueText)
                        .font(.title3.bold())
                        .foregroundStyle(level.color)
                        .lineLimit(1)
                }
            }

            HStack(spacing: 10) {
                metricBadge("PM2.5", entry.station?.pm25)
                metricBadge("PM10", entry.station?.pm10)
                metricBadge("NO2", entry.station?.no2)
                metricBadge("O3", entry.station?.o3)
            }

            Sparkline24hView(points: selectedChartPoints, color: level.color)
                .frame(height: 78)

            if entry.chartRange == .d7 {
                HStack(spacing: 0) {
                    ForEach(dayAxisLabels, id: \.self) { label in
                        Text(label)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
            }

            HStack {
                Text("\(entry.chartRange.title) trend • \(primaryMetricName)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Osveženo: \(lastUpdateText)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    private var primaryMetricName: String {
        if entry.station?.pm25 != nil {
            return "PM2.5"
        }

        if entry.station?.pm10 != nil {
            return "PM10"
        }

        return "PM"
    }

    private var primaryMetricValueText: String {
        guard let station = entry.station,
              let value = station.pm25 ?? station.pm10 else {
            return "Ni podatkov"
        }

        return WidgetFormatter.value(value)
    }

    private var selectedChartPoints: [WidgetSharedChartPoint] {
        guard let station = entry.station else {
            return []
        }

        switch entry.chartRange {
        case .h24:
            return !station.chart24h.isEmpty ? station.chart24h : station.chart7d
        case .d7:
            return !station.chart7d.isEmpty ? station.chart7d : station.chart24h
        }
    }

    private var lastUpdateText: String {
        WidgetFormatter.time(entry.station?.lastUpdate)
    }

    private var dayAxisLabels: [String] {
        let calendar = Calendar.current
        let referenceDate = selectedChartPoints.last?.timestamp ?? entry.station?.lastUpdate ?? Date()
        let endOfRange = calendar.startOfDay(for: referenceDate)

        return (0 ..< 7).compactMap { index in
            guard let day = calendar.date(byAdding: .day, value: index - 6, to: endOfRange) else {
                return nil
            }
            return WidgetFormatter.weekday(day)
        }
    }

    @ViewBuilder
    private func metricBadge(_ title: String, _ value: Double?) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(WidgetFormatter.value(value))
                .font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 5)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}

struct Sparkline24hView: View {
    let points: [WidgetSharedChartPoint]
    let color: Color

    var body: some View {
        GeometryReader { proxy in
            let plottedPoints = points(in: proxy.size)

            if plottedPoints.count > 1 {
                ZStack {
                    Path { path in
                        guard let first = plottedPoints.first else { return }
                        path.move(to: first)
                        for point in plottedPoints.dropFirst() {
                            path.addLine(to: point)
                        }
                    }
                    .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

                    Path { path in
                        guard let first = plottedPoints.first,
                              let last = plottedPoints.last else { return }

                        path.move(to: CGPoint(x: first.x, y: proxy.size.height))
                        path.addLine(to: first)
                        for point in plottedPoints.dropFirst() {
                            path.addLine(to: point)
                        }
                        path.addLine(to: CGPoint(x: last.x, y: proxy.size.height))
                        path.closeSubpath()
                    }
                    .fill(color.opacity(0.15))
                }
            } else {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemBackground))
                    .overlay {
                        Text("Ni dovolj podatkov")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
            }
        }
    }

    private func points(in size: CGSize) -> [CGPoint] {
        let sorted = points.sorted { $0.timestamp < $1.timestamp }
        guard let minDate = sorted.first?.timestamp,
              let maxDate = sorted.last?.timestamp else {
            return []
        }

        let minValue = sorted.map(\.value).min() ?? 0
        let maxValue = sorted.map(\.value).max() ?? 0
        let dateRange = max(maxDate.timeIntervalSince(minDate), 1)
        let valueRange = max(maxValue - minValue, 1)

        return sorted.map { point in
            let xRatio = point.timestamp.timeIntervalSince(minDate) / dateRange
            let yRatio = (point.value - minValue) / valueRange
            return CGPoint(
                x: xRatio * size.width,
                y: (1 - yRatio) * size.height
            )
        }
    }
}

private enum WidgetFormatter {
    private static let numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 1
        formatter.minimumFractionDigits = 0
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "sl_SI")
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }()

    private static let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "sl_SI")
        formatter.setLocalizedDateFormatFromTemplate("EEE")
        return formatter
    }()

    static func value(_ rawValue: Double?) -> String {
        guard let rawValue else { return "-" }
        return numberFormatter.string(from: NSNumber(value: rawValue)) ?? "\(rawValue)"
    }

    static func time(_ date: Date?) -> String {
        guard let date else { return "Ni podatkov" }
        return timeFormatter.string(from: date)
    }

    static func weekday(_ date: Date) -> String {
        weekdayFormatter.string(from: date)
    }
}

struct ZrakWidget: Widget {
    let kind: String = "ZrakWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: StationSelectionIntent.self,
            provider: AirQualityWidgetProvider()
        ) { entry in
            if #available(iOS 17.0, *) {
                ZrakWidgetEntryView(entry: entry)
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                ZrakWidgetEntryView(entry: entry)
                    .padding()
                    .background()
            }
        }
        .configurationDisplayName("Kakovost zraka")
        .description("Prikaz izbrane merilne postaje ARSO.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

#Preview(as: .systemSmall) {
    ZrakWidget()
} timeline: {
    AirQualityWidgetEntry(
        date: .now,
        station: WidgetSharedStation(
            code: "E403",
            name: "LJ Bežigrad",
            lastUpdate: .now,
            pm25: 12,
            pm10: 18,
            no2: 22,
            o3: 65,
            so2: 3,
            co: 0.4,
            chart24h: [
                WidgetSharedChartPoint(timestamp: .now.addingTimeInterval(-3600 * 3), value: 10),
                WidgetSharedChartPoint(timestamp: .now.addingTimeInterval(-3600 * 2), value: 11),
                WidgetSharedChartPoint(timestamp: .now.addingTimeInterval(-3600), value: 13),
                WidgetSharedChartPoint(timestamp: .now, value: 12)
            ],
            chart7d: [
                WidgetSharedChartPoint(timestamp: .now.addingTimeInterval(-3600 * 24 * 6), value: 8),
                WidgetSharedChartPoint(timestamp: .now.addingTimeInterval(-3600 * 24 * 5), value: 11),
                WidgetSharedChartPoint(timestamp: .now.addingTimeInterval(-3600 * 24 * 4), value: 12),
                WidgetSharedChartPoint(timestamp: .now.addingTimeInterval(-3600 * 24 * 3), value: 9),
                WidgetSharedChartPoint(timestamp: .now.addingTimeInterval(-3600 * 24 * 2), value: 14),
                WidgetSharedChartPoint(timestamp: .now.addingTimeInterval(-3600 * 24), value: 10),
                WidgetSharedChartPoint(timestamp: .now, value: 12)
            ]
        ),
        chartRange: .h24,
        isPremiumUnlocked: true
    )
}
