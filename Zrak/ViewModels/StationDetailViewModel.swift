import Combine
import Foundation

@MainActor
final class StationDetailViewModel: ObservableObject {
    struct Metric: Identifiable {
        let id = UUID()
        let title: String
        let value: String
    }

    enum ChartRange: String, CaseIterable, Identifiable {
        case last24Hours
        case last7Days

        var id: String { rawValue }

        var title: String {
            switch self {
            case .last24Hours:
                return "24 ur"
            case .last7Days:
                return "7 dni"
            }
        }

        var seconds: TimeInterval {
            switch self {
            case .last24Hours:
                return 24 * 60 * 60
            case .last7Days:
                return 7 * 24 * 60 * 60
            }
        }

        var desiredTickCount: Int {
            switch self {
            case .last24Hours:
                return 6
            case .last7Days:
                return 7
            }
        }

        var axisFormat: Date.FormatStyle {
            switch self {
            case .last24Hours:
                return .dateTime.hour(.twoDigits(amPM: .omitted))
            case .last7Days:
                return .dateTime.day().month(.abbreviated)
            }
        }
    }

    let item: StationMapItem

    @Published var selectedRange: ChartRange = .last24Hours {
        didSet {
            applySelectedRange()
        }
    }
    @Published private(set) var chartPoints: [AirQualityChartPoint] = []
    @Published private(set) var isChartLoading = false
    @Published private(set) var chartMessage: String?

    private let service: ARSOService
    private var allChartPoints: [AirQualityChartPoint] = []
    private var didLoadChart = false

    init(item: StationMapItem, service: ARSOService) {
        self.item = item
        self.service = service
    }

    var stationName: String {
        item.station.name
    }

    var level: AirQualityLevel {
        item.airQualityLevel
    }

    var badgeTitle: String {
        item.airQualityLevel.title
    }

    var badgeValue: String {
        guard let primaryValue = item.primaryValue else {
            return "Ni podatkov"
        }

        return "\(item.primaryMetricLabel) \(DisplayFormatter.rawValue(primaryValue)) µg/m³"
    }

    var lastUpdate: String {
        DisplayFormatter.dateTime(item.measurement?.lastUpdate)
    }

    var chartLegend: String {
        "Prikaz: PM2.5, če manjka PM10"
    }

    var chartUpperBound: Double {
        let maxValue = chartPoints.map(\.value).max() ?? 10
        return max(maxValue * 1.15, 10)
    }

    var metrics: [Metric] {
        [
            Metric(title: "PM2.5", value: DisplayFormatter.concentration(item.measurement?.pm25)),
            Metric(title: "PM10", value: DisplayFormatter.concentration(item.measurement?.pm10)),
            Metric(title: "NO2", value: DisplayFormatter.concentration(item.measurement?.no2)),
            Metric(title: "O3", value: DisplayFormatter.concentration(item.measurement?.o3)),
            Metric(title: "SO2", value: DisplayFormatter.concentration(item.measurement?.so2)),
            Metric(title: "CO", value: DisplayFormatter.concentration(item.measurement?.co))
        ]
    }

    func loadChartIfNeeded() async {
        guard !didLoadChart else { return }
        didLoadChart = true
        await refreshChart(forceRefresh: false)
    }

    func refreshChart(forceRefresh: Bool) async {
        isChartLoading = true
        chartMessage = nil

        do {
            let measurements = try await service.fetchHistoricalMeasurements(
                for: item.station.code,
                forceRefresh: forceRefresh
            )

            allChartPoints = measurements.compactMap { measurement in
                guard let value = measurement.pm25 ?? measurement.pm10,
                      value >= 0,
                      let date = measurement.lastUpdate else {
                    return nil
                }

                return AirQualityChartPoint(date: date, value: value)
            }
            .sorted { $0.date < $1.date }

            applySelectedRange()
        } catch {
            allChartPoints = []
            chartPoints = []
            chartMessage = "Grafa trenutno ni mogoče naložiti."
        }

        isChartLoading = false
    }

    private func applySelectedRange() {
        guard !allChartPoints.isEmpty else {
            chartPoints = []
            chartMessage = chartMessage ?? "Ni podatkov za izbrano obdobje."
            return
        }

        let referenceDate = allChartPoints.last?.date ?? Date()
        let fromDate = referenceDate.addingTimeInterval(-selectedRange.seconds)

        let filtered = allChartPoints.filter { point in
            point.date >= fromDate && point.date <= referenceDate
        }

        chartPoints = filtered
        chartMessage = filtered.isEmpty ? "Ni podatkov za izbrano obdobje." : nil
    }
}
