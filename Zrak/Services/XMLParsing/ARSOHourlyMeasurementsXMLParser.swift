import Foundation

nonisolated final class ARSOHourlyMeasurementsXMLParser: NSObject {
    private struct MeasurementBuilder {
        var stationCode: String = ""
        var intervalStart: Date?
        var intervalEnd: Date?
        var pm25: Double?
        var pm10: Double?
        var no2: Double?
        var o3: Double?
        var so2: Double?
        var co: Double?
    }

    nonisolated private final class Delegate: NSObject, XMLParserDelegate {
        private(set) var measurements: [Measurement] = []

        private static let dateFormatter: DateFormatter = {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(identifier: "Europe/Ljubljana")
            formatter.dateFormat = "yyyy-MM-dd HH:mm"
            return formatter
        }()

        private var currentBuilder: MeasurementBuilder?
        private var currentText: String = ""

        func parser(_ parser: XMLParser,
                    didStartElement elementName: String,
                    namespaceURI: String?,
                    qualifiedName qName: String?,
                    attributes attributeDict: [String: String] = [:]) {
            currentText = ""

            guard elementName == "postaja" else {
                return
            }

            var builder = MeasurementBuilder()
            builder.stationCode = attributeDict["sifra"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            currentBuilder = builder
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) {
            currentText.append(string)
        }

        func parser(_ parser: XMLParser,
                    didEndElement elementName: String,
                    namespaceURI: String?,
                    qualifiedName qName: String?) {
            let value = currentText.trimmingCharacters(in: .whitespacesAndNewlines)

            switch elementName {
            case "datum_od":
                currentBuilder?.intervalStart = parseDate(value)
            case "datum_do":
                currentBuilder?.intervalEnd = parseDate(value)
            case "pm2.5":
                currentBuilder?.pm25 = parseMeasurement(value)
            case "pm10":
                currentBuilder?.pm10 = parseMeasurement(value)
            case "no2":
                currentBuilder?.no2 = parseMeasurement(value)
            case "o3":
                currentBuilder?.o3 = parseMeasurement(value)
            case "so2":
                currentBuilder?.so2 = parseMeasurement(value)
            case "co":
                currentBuilder?.co = parseMeasurement(value)
            case "postaja":
                if let builder = currentBuilder, !builder.stationCode.isEmpty {
                    let measurement = Measurement(
                        stationCode: builder.stationCode,
                        intervalStart: builder.intervalStart,
                        intervalEnd: builder.intervalEnd,
                        pm25: builder.pm25,
                        pm10: builder.pm10,
                        no2: builder.no2,
                        o3: builder.o3,
                        so2: builder.so2,
                        co: builder.co
                    )
                    measurements.append(measurement)
                }
                currentBuilder = nil
            default:
                break
            }

            currentText = ""
        }

        private func parseDate(_ value: String) -> Date? {
            guard !value.isEmpty else { return nil }
            return Self.dateFormatter.date(from: value)
        }

        private func parseMeasurement(_ value: String) -> Double? {
            guard !value.isEmpty else { return nil }

            let normalized = value.replacingOccurrences(of: ",", with: ".")
            let numericOnly = normalized.filter {
                $0.isNumber || $0 == "." || $0 == "-"
            }

            guard !numericOnly.isEmpty else { return nil }
            return Double(numericOnly)
        }
    }

    nonisolated override init() {
        super.init()
    }

    nonisolated func parse(data: Data) throws -> [Measurement] {
        let parser = XMLParser(data: data)
        let delegate = Delegate()
        parser.delegate = delegate

        let success = parser.parse()
        if !success {
            throw parser.parserError ?? ARSOServiceError.malformedXML
        }

        return delegate.measurements
    }
}
