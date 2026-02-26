import Foundation

struct Measurement: Identifiable, Hashable {
    let stationCode: String
    let intervalStart: Date?
    let intervalEnd: Date?
    let pm25: Double?
    let pm10: Double?
    let no2: Double?
    let o3: Double?
    let so2: Double?
    let co: Double?

    nonisolated var id: String { stationCode }
    nonisolated var lastUpdate: Date? { intervalEnd ?? intervalStart }
}
