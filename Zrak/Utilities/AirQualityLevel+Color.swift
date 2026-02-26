import SwiftUI

extension AirQualityLevel {
    var color: Color {
        switch self {
        case .good:
            return .green
        case .moderate:
            return .yellow
        case .unhealthySensitive:
            return .orange
        case .unhealthy:
            return .red
        case .veryUnhealthy:
            return .purple
        case .noData:
            return .gray
        }
    }
}
