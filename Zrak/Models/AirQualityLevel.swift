import Foundation

enum AirQualityLevel: String, CaseIterable {
    case good
    case moderate
    case unhealthySensitive
    case unhealthy
    case veryUnhealthy
    case noData

    static func from(value: Double?) -> AirQualityLevel {
        fromPM25(value)
    }

    static func from(pm25: Double?, pm10: Double?) -> AirQualityLevel {
        if let pm25 {
            return fromPM25(pm25)
        }

        if let pm10 {
            return fromPM10(pm10)
        }

        return .noData
    }

    private static func fromPM25(_ value: Double?) -> AirQualityLevel {
        guard let value, value >= 0 else {
            return .noData
        }

        switch value {
        case 0 ... 15:
            return .good
        case 16 ... 35:
            return .moderate
        case 36 ... 55:
            return .unhealthySensitive
        case 56 ... 100:
            return .unhealthy
        default:
            return .veryUnhealthy
        }
    }

    private static func fromPM10(_ value: Double?) -> AirQualityLevel {
        guard let value, value >= 0 else {
            return .noData
        }

        switch value {
        case 0 ... 25:
            return .good
        case 26 ... 50:
            return .moderate
        case 51 ... 100:
            return .unhealthy
        default:
            return .veryUnhealthy
        }
    }

    var title: String {
        switch self {
        case .good:
            return "Dobro"
        case .moderate:
            return "Zmerno"
        case .unhealthySensitive:
            return "Nezdravo za občutljive skupine"
        case .unhealthy:
            return "Nezdravo"
        case .veryUnhealthy:
            return "Zelo nezdravo"
        case .noData:
            return "Ni podatkov"
        }
    }
}
