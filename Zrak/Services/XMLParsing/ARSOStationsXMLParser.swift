import Foundation

nonisolated final class ARSOStationsXMLParser: NSObject {
    private struct StationBuilder {
        var code: String = ""
        var name: String = ""
        var latitude: Double?
        var longitude: Double?
    }

    nonisolated private final class Delegate: NSObject, XMLParserDelegate {
        private(set) var stations: [Station] = []

        private var currentBuilder: StationBuilder?
        private var currentElement: String = ""
        private var currentText: String = ""

        func parser(_ parser: XMLParser,
                    didStartElement elementName: String,
                    namespaceURI: String?,
                    qualifiedName qName: String?,
                    attributes attributeDict: [String: String] = [:]) {
            currentElement = elementName
            currentText = ""

            guard elementName == "postaja" else {
                return
            }

            var builder = StationBuilder()
            builder.code = attributeDict["sifra"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            builder.latitude = parseDouble(attributeDict["wgs84_sirina"])
            builder.longitude = parseDouble(attributeDict["wgs84_dolzina"])
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

            if elementName == "merilno_mesto" {
                currentBuilder?.name = value
            }

            if elementName == "postaja", let builder = currentBuilder {
                defer { currentBuilder = nil }

                guard !builder.code.isEmpty,
                      let latitude = builder.latitude,
                      let longitude = builder.longitude else {
                    return
                }

                stations.append(
                    Station(
                        code: builder.code,
                        name: builder.name.isEmpty ? builder.code : builder.name,
                        latitude: latitude,
                        longitude: longitude
                    )
                )
            }

            currentElement = ""
            currentText = ""
        }

        private func parseDouble(_ rawValue: String?) -> Double? {
            guard let rawValue else { return nil }
            let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            return Double(trimmed.replacingOccurrences(of: ",", with: "."))
        }
    }

    nonisolated override init() {
        super.init()
    }

    nonisolated func parse(data: Data) throws -> [Station] {
        let parser = XMLParser(data: data)
        let delegate = Delegate()
        parser.delegate = delegate

        let success = parser.parse()
        if !success {
            throw parser.parserError ?? ARSOServiceError.malformedXML
        }

        return delegate.stations
    }
}
