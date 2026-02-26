import Foundation

struct ARSOSnapshot {
    let stations: [Station]
    let measurementsByCode: [String: Measurement]
    let fetchedAt: Date
}

enum ARSOServiceError: LocalizedError {
    case invalidHTTPResponse
    case malformedXML

    var errorDescription: String? {
        switch self {
        case .invalidHTTPResponse:
            return "ARSO je vrnil neveljaven odziv strežnika."
        case .malformedXML:
            return "ARSO je vrnil nepravilno oblikovan XML."
        }
    }
}

actor ARSOService {
    private let hourlyURL = URL(string: "https://www.arso.gov.si/xml/zrak/ones_zrak_urni_podatki_zadnji.xml")!
    private let stationsURL = URL(string: "https://www.arso.gov.si/xml/zrak/ones_zrak_dnevni_podatki_zadnji.xml")!
    private let sevenDayURL = URL(string: "https://www.arso.gov.si/xml/zrak/ones_zrak_urni_podatki_7dni.xml")!

    private let session: URLSession
    private var cache: ARSOSnapshot?
    private var historicalCacheByStation: [String: [Measurement]]?
    private var historicalCacheFetchedAt: Date?
    private let historicalCacheMaxAge: TimeInterval = 15 * 60

    init(session: URLSession = .shared) {
        self.session = session
    }

    func cachedSnapshot() -> ARSOSnapshot? {
        cache
    }

    func fetchLatestSnapshot(forceRefresh: Bool = false) async throws -> ARSOSnapshot {
        if !forceRefresh, let cache {
            return cache
        }

        async let hourlyData = requestData(from: hourlyURL)
        async let stationData = requestData(from: stationsURL)
        let (hourlyXML, stationsXML) = try await (hourlyData, stationData)

        async let measurements = parseMeasurements(from: hourlyXML)
        async let stationsFromDaily = parseStations(from: stationsXML)
        async let stationsFromHourly = parseStations(from: hourlyXML)

        let parsedMeasurements = try await measurements
        let dailyStations = try await stationsFromDaily
        let hourlyStations = try await stationsFromHourly

        let mergedStations = mergeStations(primary: dailyStations, secondary: hourlyStations)
        let measurementsByCode = Dictionary(uniqueKeysWithValues: parsedMeasurements.map { ($0.stationCode, $0) })

        let historicalByStation = await refreshHistoricalCacheIfAvailable(forceRefresh: forceRefresh)

        let snapshot = ARSOSnapshot(
            stations: mergedStations,
            measurementsByCode: measurementsByCode,
            fetchedAt: Date()
        )

        await persistWidgetPayload(
            stations: mergedStations,
            latestByStation: measurementsByCode,
            historicalByStation: historicalByStation
        )
        cache = snapshot
        return snapshot
    }

    func fetchHistoricalMeasurements(for stationCode: String, forceRefresh: Bool = false) async throws -> [Measurement] {
        let normalizedCode = stationCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedCode.isEmpty else {
            return []
        }

        if !forceRefresh, let cachedMeasurements = cachedHistoricalMeasurements(for: normalizedCode) {
            return cachedMeasurements
        }

        do {
            let xmlData = try await requestData(from: sevenDayURL)
            let parsed = try await parseMeasurements(from: xmlData)
            let groupedByStation = groupHistoricalMeasurements(parsed)
            historicalCacheByStation = groupedByStation
            historicalCacheFetchedAt = Date()
            return groupedByStation[normalizedCode] ?? []
        } catch {
            if let fallback = historicalCacheByStation?[normalizedCode] {
                return fallback
            }
            throw error
        }
    }

    private func requestData(from url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.cachePolicy = .reloadIgnoringLocalCacheData

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200 ..< 300).contains(httpResponse.statusCode) else {
            throw ARSOServiceError.invalidHTTPResponse
        }

        return data
    }

    private func parseMeasurements(from data: Data) async throws -> [Measurement] {
        try await Task.detached(priority: .utility) {
            let parser = ARSOHourlyMeasurementsXMLParser()
            return try parser.parse(data: data)
        }.value
    }

    private func parseStations(from data: Data) async throws -> [Station] {
        try await Task.detached(priority: .utility) {
            let parser = ARSOStationsXMLParser()
            return try parser.parse(data: data)
        }.value
    }

    private func mergeStations(primary: [Station], secondary: [Station]) -> [Station] {
        var byCode = Dictionary(uniqueKeysWithValues: primary.map { ($0.code, $0) })

        for station in secondary where byCode[station.code] == nil {
            byCode[station.code] = station
        }

        return byCode.values.sorted { lhs, rhs in
            lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    private func cachedHistoricalMeasurements(for stationCode: String) -> [Measurement]? {
        guard let fetchedAt = historicalCacheFetchedAt,
              let historicalCacheByStation,
              Date().timeIntervalSince(fetchedAt) <= historicalCacheMaxAge else {
            return nil
        }

        return historicalCacheByStation[stationCode] ?? []
    }

    private func groupHistoricalMeasurements(_ measurements: [Measurement]) -> [String: [Measurement]] {
        let grouped = Dictionary(grouping: measurements, by: \.stationCode)

        return grouped.mapValues { stationMeasurements in
            let deduplicated = deduplicateByTimestamp(stationMeasurements)
            return deduplicated.sorted { lhs, rhs in
                (lhs.lastUpdate ?? .distantPast) < (rhs.lastUpdate ?? .distantPast)
            }
        }
    }

    private func deduplicateByTimestamp(_ measurements: [Measurement]) -> [Measurement] {
        var byTimestamp: [Date: Measurement] = [:]
        var undatedMeasurements: [Measurement] = []

        for measurement in measurements {
            guard let timestamp = measurement.lastUpdate else {
                undatedMeasurements.append(measurement)
                continue
            }

            if let existing = byTimestamp[timestamp] {
                if existing.pm25 == nil, measurement.pm25 != nil {
                    byTimestamp[timestamp] = measurement
                }
            } else {
                byTimestamp[timestamp] = measurement
            }
        }

        return Array(byTimestamp.values) + undatedMeasurements
    }

    private func refreshHistoricalCacheIfAvailable(forceRefresh: Bool) async -> [String: [Measurement]] {
        if !forceRefresh,
           let fetchedAt = historicalCacheFetchedAt,
           let historicalCacheByStation,
           Date().timeIntervalSince(fetchedAt) <= historicalCacheMaxAge {
            return historicalCacheByStation
        }

        guard let xmlData = try? await requestData(from: sevenDayURL),
              let parsed = try? await parseMeasurements(from: xmlData) else {
            return historicalCacheByStation ?? [:]
        }

        let groupedByStation = groupHistoricalMeasurements(parsed)
        historicalCacheByStation = groupedByStation
        historicalCacheFetchedAt = Date()
        return groupedByStation
    }

    private func persistWidgetPayload(
        stations: [Station],
        latestByStation: [String: Measurement],
        historicalByStation: [String: [Measurement]]
    ) async {
        let sharedStations = stations.map { station in
            let latest = latestByStation[station.code]
            let history = historicalByStation[station.code] ?? []

            return WidgetSharedStation(
                code: station.code,
                name: station.name,
                lastUpdate: latest?.lastUpdate,
                pm25: latest?.pm25,
                pm10: latest?.pm10,
                no2: latest?.no2,
                o3: latest?.o3,
                so2: latest?.so2,
                co: latest?.co,
                chart24h: chart(from: history, fallback: latest, hoursBack: 24),
                chart7d: chart(from: history, fallback: latest, hoursBack: 24 * 7)
            )
        }

        let payload = WidgetSharedPayload(
            generatedAt: Date(),
            stations: sharedStations
        )
        await WidgetSharedStore.write(payload)
    }

    private func chart(from history: [Measurement], fallback: Measurement?, hoursBack: Double) -> [WidgetSharedChartPoint] {
        let values = history.compactMap { measurement -> WidgetSharedChartPoint? in
            guard let timestamp = measurement.lastUpdate,
                  let value = measurement.pm25 ?? measurement.pm10,
                  value >= 0 else {
                return nil
            }

            return WidgetSharedChartPoint(timestamp: timestamp, value: value)
        }
        .sorted { $0.timestamp < $1.timestamp }

        if values.isEmpty, let fallback, let timestamp = fallback.lastUpdate, let value = fallback.pm25 ?? fallback.pm10 {
            return [WidgetSharedChartPoint(timestamp: timestamp, value: value)]
        }

        let reference = values.last?.timestamp ?? Date()
        let fromDate = reference.addingTimeInterval(-(hoursBack * 60 * 60))
        return values.filter { $0.timestamp >= fromDate && $0.timestamp <= reference }
    }
}
