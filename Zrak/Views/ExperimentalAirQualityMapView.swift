import SwiftUI
import UIKit

struct ExperimentalAirQualityMapView: View {
    @EnvironmentObject private var premiumManager: PremiumManager
    let stations: [StationMapItem]
    let lastUpdated: Date?

    var body: some View {
        Group {
            if premiumManager.hasPremiumAccess {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        headerCard

                        SloveniaInterpolationHeatmap(stations: stations)
                            .frame(maxWidth: .infinity)
                            .padding(10)
                            .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Legenda barv")
                                .font(.caption.weight(.semibold))
                            AirQualityLegendView()
                        }
                        .padding(12)
                        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .padding()
                }
            } else {
                lockedContent
            }
        }
        .navigationTitle("Eksperimentalni prikaz")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Interpolirana kakovost zraka za Slovenijo")
                .font(.headline)
            Text("To je eksperimentalna vizualizacija, izračunana iz trenutnih meritev postaj (IDW interpolacija).")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("Ni uradna napoved kakovosti zraka.")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
            Text("Zadnja osvežitev: \(DisplayFormatter.dateTime(lastUpdated)) (vir: ARSO)")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var lockedContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Eksperimentalni prikaz je del Premium")
                .font(.headline)
            Text("Ta pogled prikazuje interpolirano stanje po celi Sloveniji in je na voljo v Zrak Premium.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Button("Odkleni Premium") {
                premiumManager.presentPaywall(for: .experimentalMap)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct SloveniaInterpolationHeatmap: View {
    let stations: [StationMapItem]

    private var samples: [InterpolationSample] {
        stations.compactMap { item in
            guard let score = levelScore(item.airQualityLevel) else {
                return nil
            }

            let normalized = normalize(item.station.latitude, item.station.longitude)
            guard (0 ... 1).contains(normalized.x), (0 ... 1).contains(normalized.y) else {
                return nil
            }

            return InterpolationSample(position: normalized, score: score, level: item.airQualityLevel)
        }
    }

    var body: some View {
        GeometryReader { proxy in
            Canvas { context, size in
                let silhouette = SloveniaSilhouetteShape().path(in: CGRect(origin: .zero, size: size))

                context.fill(
                    Path(CGRect(origin: .zero, size: size)),
                    with: .color(Color(uiColor: .systemGray6))
                )

                context.clip(to: silhouette)

                if samples.isEmpty {
                    context.fill(
                        Path(CGRect(origin: .zero, size: size)),
                        with: .color(Color.gray.opacity(0.35))
                    )
                } else {
                    let step: CGFloat = max(5, min(size.width, size.height) / 55)

                    var y: CGFloat = 0
                    while y < size.height {
                        var x: CGFloat = 0
                        while x < size.width {
                            let normalized = CGPoint(x: x / size.width, y: y / size.height)
                            if let score = interpolatedScore(at: normalized, samples: samples) {
                                let color = InterpolatedColorScale.color(for: score)
                                context.fill(
                                    Path(CGRect(x: x, y: y, width: step + 1, height: step + 1)),
                                    with: .color(color.opacity(0.8))
                                )
                            }
                            x += step
                        }
                        y += step
                    }
                }

                context.stroke(silhouette, with: .color(.secondary.opacity(0.8)), lineWidth: 1.5)

                for sample in samples {
                    let center = CGPoint(x: sample.position.x * size.width, y: sample.position.y * size.height)
                    let dotRect = CGRect(x: center.x - 3.5, y: center.y - 3.5, width: 7, height: 7)
                    context.fill(Path(ellipseIn: dotRect), with: .color(sample.level.color))
                    context.stroke(Path(ellipseIn: dotRect), with: .color(.white.opacity(0.9)), lineWidth: 1)
                }
            }
        }
        .aspectRatio(1.35, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func interpolatedScore(at point: CGPoint, samples: [InterpolationSample]) -> Double? {
        guard !samples.isEmpty else { return nil }

        var weightedSum = 0.0
        var totalWeight = 0.0

        for sample in samples {
            let distance = hypot(point.x - sample.position.x, point.y - sample.position.y)
            let clampedDistance = max(distance, 0.015)
            let weight = 1.0 / pow(clampedDistance, 2)
            weightedSum += sample.score * weight
            totalWeight += weight
        }

        guard totalWeight > 0 else { return nil }
        return weightedSum / totalWeight
    }

    private func levelScore(_ level: AirQualityLevel) -> Double? {
        switch level {
        case .good:
            return 0
        case .moderate:
            return 1
        case .unhealthySensitive:
            return 2
        case .unhealthy:
            return 3
        case .veryUnhealthy:
            return 4
        case .noData:
            return nil
        }
    }

    private func normalize(_ latitude: Double, _ longitude: Double) -> CGPoint {
        let x = (longitude - SloveniaGeoBounds.minLon) / (SloveniaGeoBounds.maxLon - SloveniaGeoBounds.minLon)
        let y = 1 - ((latitude - SloveniaGeoBounds.minLat) / (SloveniaGeoBounds.maxLat - SloveniaGeoBounds.minLat))
        return CGPoint(x: x, y: y)
    }
}

private struct InterpolationSample {
    let position: CGPoint
    let score: Double
    let level: AirQualityLevel
}

private enum InterpolatedColorScale {
    private static let palette: [UIColor] = [
        UIColor(AirQualityLevel.good.color),
        UIColor(AirQualityLevel.moderate.color),
        UIColor(AirQualityLevel.unhealthySensitive.color),
        UIColor(AirQualityLevel.unhealthy.color),
        UIColor(AirQualityLevel.veryUnhealthy.color)
    ]

    static func color(for score: Double) -> Color {
        let clamped = min(max(score, 0), Double(palette.count - 1))
        let lowerIndex = Int(floor(clamped))
        let upperIndex = Int(ceil(clamped))
        let t = CGFloat(clamped - Double(lowerIndex))

        let lower = palette[lowerIndex]
        let upper = palette[upperIndex]
        return Color(mix(lower, upper, t: t))
    }

    private static func mix(_ first: UIColor, _ second: UIColor, t: CGFloat) -> UIColor {
        var r1: CGFloat = 0
        var g1: CGFloat = 0
        var b1: CGFloat = 0
        var a1: CGFloat = 0
        first.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)

        var r2: CGFloat = 0
        var g2: CGFloat = 0
        var b2: CGFloat = 0
        var a2: CGFloat = 0
        second.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)

        return UIColor(
            red: r1 + ((r2 - r1) * t),
            green: g1 + ((g2 - g1) * t),
            blue: b1 + ((b2 - b1) * t),
            alpha: a1 + ((a2 - a1) * t)
        )
    }
}

private struct GeoPoint {
    let lon: Double
    let lat: Double
}

private enum SloveniaGeoBounds {
    static let minLat = 45.423637
    static let maxLat = 46.863962
    static let minLon = 13.365261
    static let maxLon = 16.515302
}

private enum SloveniaBoundary {
    static let points: [GeoPoint] = [
        GeoPoint(lon: 13.642920, lat: 45.459430),
        GeoPoint(lon: 13.589529, lat: 45.488837),
        GeoPoint(lon: 13.595958, lat: 45.518134),
        GeoPoint(lon: 13.568614, lat: 45.539252),
        GeoPoint(lon: 13.752940, lat: 45.552883),
        GeoPoint(lon: 13.711762, lat: 45.593207),
        GeoPoint(lon: 13.847764, lat: 45.584661),
        GeoPoint(lon: 13.894686, lat: 45.631841),
        GeoPoint(lon: 13.858409, lat: 45.649359),
        GeoPoint(lon: 13.778724, lat: 45.743411),
        GeoPoint(lon: 13.660334, lat: 45.792038),
        GeoPoint(lon: 13.581269, lat: 45.809246),
        GeoPoint(lon: 13.565973, lat: 45.830330),
        GeoPoint(lon: 13.569280, lat: 45.864540),
        GeoPoint(lon: 13.622817, lat: 45.966394),
        GeoPoint(lon: 13.605867, lat: 45.985411),
        GeoPoint(lon: 13.509439, lat: 45.967428),
        GeoPoint(lon: 13.461793, lat: 46.006392),
        GeoPoint(lon: 13.490008, lat: 46.025564),
        GeoPoint(lon: 13.482257, lat: 46.044839),
        GeoPoint(lon: 13.505098, lat: 46.066027),
        GeoPoint(lon: 13.616409, lat: 46.125041),
        GeoPoint(lon: 13.645037, lat: 46.161731),
        GeoPoint(lon: 13.637389, lat: 46.180386),
        GeoPoint(lon: 13.559048, lat: 46.184107),
        GeoPoint(lon: 13.510162, lat: 46.213976),
        GeoPoint(lon: 13.468304, lat: 46.223433),
        GeoPoint(lon: 13.422829, lat: 46.228601),
        GeoPoint(lon: 13.437402, lat: 46.210927),
        GeoPoint(lon: 13.410116, lat: 46.207982),
        GeoPoint(lon: 13.365261, lat: 46.290302),
        GeoPoint(lon: 13.391306, lat: 46.301568),
        GeoPoint(lon: 13.434094, lat: 46.353864),
        GeoPoint(lon: 13.530006, lat: 46.388332),
        GeoPoint(lon: 13.600182, lat: 46.442644),
        GeoPoint(lon: 13.677490, lat: 46.452075),
        GeoPoint(lon: 13.700951, lat: 46.519746),
        GeoPoint(lon: 13.782135, lat: 46.507782),
        GeoPoint(lon: 13.860683, lat: 46.515250),
        GeoPoint(lon: 13.982330, lat: 46.481918),
        GeoPoint(lon: 14.050026, lat: 46.484399),
        GeoPoint(lon: 14.149865, lat: 46.440061),
        GeoPoint(lon: 14.406490, lat: 46.439337),
        GeoPoint(lon: 14.450931, lat: 46.414481),
        GeoPoint(lon: 14.502194, lat: 46.418356),
        GeoPoint(lon: 14.540332, lat: 46.378643),
        GeoPoint(lon: 14.557695, lat: 46.383940),
        GeoPoint(lon: 14.590148, lat: 46.434428),
        GeoPoint(lon: 14.679961, lat: 46.458871),
        GeoPoint(lon: 14.709727, lat: 46.492512),
        GeoPoint(lon: 14.788585, lat: 46.506646),
        GeoPoint(lon: 14.850390, lat: 46.601136),
        GeoPoint(lon: 14.933589, lat: 46.621135),
        GeoPoint(lon: 14.967179, lat: 46.600257),
        GeoPoint(lon: 15.004386, lat: 46.636844),
        GeoPoint(lon: 15.061954, lat: 46.649557),
        GeoPoint(lon: 15.204891, lat: 46.638963),
        GeoPoint(lon: 15.388135, lat: 46.645578),
        GeoPoint(lon: 15.462653, lat: 46.614649),
        GeoPoint(lon: 15.511228, lat: 46.628369),
        GeoPoint(lon: 15.545955, lat: 46.671881),
        GeoPoint(lon: 15.626984, lat: 46.680873),
        GeoPoint(lon: 15.635975, lat: 46.717563),
        GeoPoint(lon: 15.728683, lat: 46.702990),
        GeoPoint(lon: 15.850743, lat: 46.724488),
        GeoPoint(lon: 15.986962, lat: 46.692190),
        GeoPoint(lon: 16.016723, lat: 46.670691),
        GeoPoint(lon: 16.014557, lat: 46.693714),
        GeoPoint(lon: 15.982001, lat: 46.718545),
        GeoPoint(lon: 15.970529, lat: 46.743014),
        GeoPoint(lon: 15.971976, lat: 46.820632),
        GeoPoint(lon: 16.094035, lat: 46.862774),
        GeoPoint(lon: 16.135376, lat: 46.855849),
        GeoPoint(lon: 16.272009, lat: 46.863962),
        GeoPoint(lon: 16.325339, lat: 46.839442),
        GeoPoint(lon: 16.327509, lat: 46.825463),
        GeoPoint(lon: 16.298157, lat: 46.775802),
        GeoPoint(lon: 16.314177, lat: 46.743324),
        GeoPoint(lon: 16.343426, lat: 46.714178),
        GeoPoint(lon: 16.357275, lat: 46.715832),
        GeoPoint(lon: 16.357585, lat: 46.699011),
        GeoPoint(lon: 16.405024, lat: 46.687255),
        GeoPoint(lon: 16.410502, lat: 46.668367),
        GeoPoint(lon: 16.368437, lat: 46.642994),
        GeoPoint(lon: 16.500832, lat: 46.544809),
        GeoPoint(lon: 16.515302, lat: 46.501711),
        GeoPoint(lon: 16.481298, lat: 46.519022),
        GeoPoint(lon: 16.440371, lat: 46.519022),
        GeoPoint(lon: 16.406264, lat: 46.539486),
        GeoPoint(lon: 16.344149, lat: 46.546979),
        GeoPoint(lon: 16.263947, lat: 46.515922),
        GeoPoint(lon: 16.234905, lat: 46.493339),
        GeoPoint(lon: 16.250925, lat: 46.404998),
        GeoPoint(lon: 16.278727, lat: 46.387351),
        GeoPoint(lon: 16.275626, lat: 46.373165),
        GeoPoint(lon: 16.191807, lat: 46.369781),
        GeoPoint(lon: 16.143851, lat: 46.394714),
        GeoPoint(lon: 16.106024, lat: 46.373734),
        GeoPoint(lon: 16.057965, lat: 46.377532),
        GeoPoint(lon: 16.059619, lat: 46.332315),
        GeoPoint(lon: 16.019208, lat: 46.298829),
        GeoPoint(lon: 15.883712, lat: 46.259400),
        GeoPoint(lon: 15.818290, lat: 46.255524),
        GeoPoint(lon: 15.749767, lat: 46.210772),
        GeoPoint(lon: 15.661297, lat: 46.215320),
        GeoPoint(lon: 15.639799, lat: 46.207672),
        GeoPoint(lon: 15.604349, lat: 46.167002),
        GeoPoint(lon: 15.589880, lat: 46.113517),
        GeoPoint(lon: 15.631531, lat: 46.070574),
        GeoPoint(lon: 15.697987, lat: 46.036209),
        GeoPoint(lon: 15.674216, lat: 45.993163),
        GeoPoint(lon: 15.675560, lat: 45.925157),
        GeoPoint(lon: 15.659436, lat: 45.888828),
        GeoPoint(lon: 15.676076, lat: 45.841699),
        GeoPoint(lon: 15.626054, lat: 45.820202),
        GeoPoint(lon: 15.523527, lat: 45.826816),
        GeoPoint(lon: 15.485390, lat: 45.810176),
        GeoPoint(lon: 15.451284, lat: 45.815137),
        GeoPoint(lon: 15.440328, lat: 45.811468),
        GeoPoint(lon: 15.441052, lat: 45.782168),
        GeoPoint(lon: 15.429063, lat: 45.775295),
        GeoPoint(lon: 15.303799, lat: 45.746149),
        GeoPoint(lon: 15.255017, lat: 45.723463),
        GeoPoint(lon: 15.250883, lat: 45.707650),
        GeoPoint(lon: 15.283025, lat: 45.680107),
        GeoPoint(lon: 15.304936, lat: 45.672149),
        GeoPoint(lon: 15.330774, lat: 45.684551),
        GeoPoint(lon: 15.373769, lat: 45.640213),
        GeoPoint(lon: 15.297391, lat: 45.625692),
        GeoPoint(lon: 15.268556, lat: 45.601662),
        GeoPoint(lon: 15.296668, lat: 45.522959),
        GeoPoint(lon: 15.361367, lat: 45.482031),
        GeoPoint(lon: 15.325193, lat: 45.452834),
        GeoPoint(lon: 15.184220, lat: 45.425600),
        GeoPoint(lon: 15.139262, lat: 45.430045),
        GeoPoint(lon: 15.056166, lat: 45.479912),
        GeoPoint(lon: 15.007383, lat: 45.480843),
        GeoPoint(lon: 14.922634, lat: 45.514949),
        GeoPoint(lon: 14.904444, lat: 45.514432),
        GeoPoint(lon: 14.881603, lat: 45.469784),
        GeoPoint(lon: 14.838815, lat: 45.458983),
        GeoPoint(lon: 14.797164, lat: 45.465185),
        GeoPoint(lon: 14.781247, lat: 45.493348),
        GeoPoint(lon: 14.668489, lat: 45.533966),
        GeoPoint(lon: 14.669833, lat: 45.564558),
        GeoPoint(lon: 14.603067, lat: 45.603574),
        GeoPoint(lon: 14.591905, lat: 45.663364),
        GeoPoint(lon: 14.580949, lat: 45.667808),
        GeoPoint(lon: 14.556145, lat: 45.656697),
        GeoPoint(lon: 14.498577, lat: 45.596184),
        GeoPoint(lon: 14.468915, lat: 45.525594),
        GeoPoint(lon: 14.372797, lat: 45.477845),
        GeoPoint(lon: 14.326805, lat: 45.474900),
        GeoPoint(lon: 14.218698, lat: 45.497172),
        GeoPoint(lon: 14.145524, lat: 45.476243),
        GeoPoint(lon: 14.092917, lat: 45.473918),
        GeoPoint(lon: 14.013956, lat: 45.507973),
        GeoPoint(lon: 13.971891, lat: 45.514226),
        GeoPoint(lon: 13.961452, lat: 45.493142),
        GeoPoint(lon: 13.982640, lat: 45.475313),
        GeoPoint(lon: 13.889002, lat: 45.423637),
        GeoPoint(lon: 13.819859, lat: 45.432628),
        GeoPoint(lon: 13.759294, lat: 45.463169),
        GeoPoint(lon: 13.659970, lat: 45.459978)
    ]
}

private struct SloveniaSilhouetteShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard let first = SloveniaBoundary.points.first else { return path }

        path.move(to: pointToCanvas(first, in: rect))
        for point in SloveniaBoundary.points.dropFirst() {
            path.addLine(to: pointToCanvas(point, in: rect))
        }
        path.closeSubpath()
        return path
    }

    private func pointToCanvas(_ point: GeoPoint, in rect: CGRect) -> CGPoint {
        let x = (point.lon - SloveniaGeoBounds.minLon) / (SloveniaGeoBounds.maxLon - SloveniaGeoBounds.minLon)
        let y = 1 - ((point.lat - SloveniaGeoBounds.minLat) / (SloveniaGeoBounds.maxLat - SloveniaGeoBounds.minLat))
        return CGPoint(x: rect.minX + (x * rect.width), y: rect.minY + (y * rect.height))
    }
}

#Preview {
    NavigationStack {
        ExperimentalAirQualityMapView(stations: [], lastUpdated: .now)
            .environmentObject(PremiumManager.preview(unlocked: true))
    }
}
