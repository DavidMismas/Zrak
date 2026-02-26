import AppIntents
import Foundation

enum WidgetChartRange: String, AppEnum {
    case h24
    case d7

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Obdobje grafa")
    static var caseDisplayRepresentations: [WidgetChartRange: DisplayRepresentation] = [
        .h24: DisplayRepresentation(title: "24 ur"),
        .d7: DisplayRepresentation(title: "7 dni")
    ]

    var title: String {
        switch self {
        case .h24:
            return "24h"
        case .d7:
            return "7 dni"
        }
    }
}

struct StationEntity: AppEntity, Identifiable {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Merilna postaja")
    static var defaultQuery = StationEntityQuery()

    let id: String
    let name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: LocalizedStringResource(stringLiteral: name),
            subtitle: LocalizedStringResource(stringLiteral: id)
        )
    }
}

struct StationEntityQuery: EntityQuery {
    func entities(for identifiers: [StationEntity.ID]) async throws -> [StationEntity] {
        allStations().filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [StationEntity] {
        allStations()
    }

    func defaultResult() async -> StationEntity? {
        allStations().first
    }

    private func allStations() -> [StationEntity] {
        guard let payload = WidgetSharedStore.readPayload() else {
            return []
        }

        return payload.stations
            .map { StationEntity(id: $0.code, name: $0.name) }
            .sorted { lhs, rhs in
                lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
    }
}

struct StationSelectionIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Postaja"
    static var description = IntentDescription("Izberi merilno postajo za prikaz v widgetu.")

    @Parameter(title: "Merilna postaja")
    var station: StationEntity?

    @Parameter(title: "Obdobje grafa", default: .h24)
    var chartRange: WidgetChartRange

    static var parameterSummary: some ParameterSummary {
        Summary("Postaja: \(\.$station), obdobje: \(\.$chartRange)")
    }
}
