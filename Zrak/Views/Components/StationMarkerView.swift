import SwiftUI

struct StationMarkerView: View {
    let level: AirQualityLevel

    var body: some View {
        ZStack {
            Circle()
                .fill(level.color)
                .frame(width: 22, height: 22)
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 2)
                )
                .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 1)

            Circle()
                .fill(Color.white.opacity(0.9))
                .frame(width: 6, height: 6)
        }
        .padding(4)
        .background(.ultraThinMaterial, in: Circle())
    }
}
