import Foundation

struct StationMapItem: Identifiable, Hashable {
    let station: Station
    let measurement: Measurement?

    var id: String { station.id }
    var primaryValue: Double? { measurement?.pm25 ?? measurement?.pm10 }
    var primaryMetricLabel: String { measurement?.pm25 != nil ? "PM2.5" : "PM10" }
    var airQualityLevel: AirQualityLevel {
        AirQualityLevel.from(pm25: measurement?.pm25, pm10: measurement?.pm10)
    }
}
