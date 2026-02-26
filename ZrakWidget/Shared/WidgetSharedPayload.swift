import Foundation

enum WidgetSharedConfig {
    static let appGroupIdentifier = "group.com.david.Zrak"
    static let payloadFilename = "air_quality_widget_payload.json"
}

struct WidgetSharedPayload: Codable {
    let generatedAt: Date
    let stations: [WidgetSharedStation]
}

struct WidgetSharedStation: Codable {
    let code: String
    let name: String
    let lastUpdate: Date?
    let pm25: Double?
    let pm10: Double?
    let no2: Double?
    let o3: Double?
    let so2: Double?
    let co: Double?
    let chart24h: [WidgetSharedChartPoint]
    let chart7d: [WidgetSharedChartPoint]

    nonisolated init(
        code: String,
        name: String,
        lastUpdate: Date?,
        pm25: Double?,
        pm10: Double?,
        no2: Double?,
        o3: Double?,
        so2: Double?,
        co: Double?,
        chart24h: [WidgetSharedChartPoint],
        chart7d: [WidgetSharedChartPoint] = []
    ) {
        self.code = code
        self.name = name
        self.lastUpdate = lastUpdate
        self.pm25 = pm25
        self.pm10 = pm10
        self.no2 = no2
        self.o3 = o3
        self.so2 = so2
        self.co = co
        self.chart24h = chart24h
        self.chart7d = chart7d
    }

    private enum CodingKeys: String, CodingKey {
        case code
        case name
        case lastUpdate
        case pm25
        case pm10
        case no2
        case o3
        case so2
        case co
        case chart24h
        case chart7d
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        code = try container.decode(String.self, forKey: .code)
        name = try container.decode(String.self, forKey: .name)
        lastUpdate = try container.decodeIfPresent(Date.self, forKey: .lastUpdate)
        pm25 = try container.decodeIfPresent(Double.self, forKey: .pm25)
        pm10 = try container.decodeIfPresent(Double.self, forKey: .pm10)
        no2 = try container.decodeIfPresent(Double.self, forKey: .no2)
        o3 = try container.decodeIfPresent(Double.self, forKey: .o3)
        so2 = try container.decodeIfPresent(Double.self, forKey: .so2)
        co = try container.decodeIfPresent(Double.self, forKey: .co)
        chart24h = try container.decodeIfPresent([WidgetSharedChartPoint].self, forKey: .chart24h) ?? []
        chart7d = try container.decodeIfPresent([WidgetSharedChartPoint].self, forKey: .chart7d) ?? []
    }
}

struct WidgetSharedChartPoint: Codable {
    let timestamp: Date
    let value: Double
}

enum WidgetSharedStore {
    static func readPayload() -> WidgetSharedPayload? {
        guard let fileURL = payloadURL(),
              let data = try? Data(contentsOf: fileURL) else {
            return nil
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(WidgetSharedPayload.self, from: data)
    }

    private static func payloadURL() -> URL? {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: WidgetSharedConfig.appGroupIdentifier
        ) else {
            return nil
        }

        return containerURL.appendingPathComponent(WidgetSharedConfig.payloadFilename)
    }
}
