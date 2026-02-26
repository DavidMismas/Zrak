import Foundation

struct AirQualityChartPoint: Identifiable, Hashable {
    let date: Date
    let value: Double

    var id: String {
        "\(date.timeIntervalSince1970)-\(value)"
    }
}
