import Combine
import CoreLocation
import MapKit
import SwiftUI

@MainActor
final class MapViewModel: ObservableObject {
    static let sloveniaRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 46.1512, longitude: 14.9955),
        span: MKCoordinateSpan(latitudeDelta: 2.5, longitudeDelta: 2.5)
    )

    @Published var cameraPosition: MapCameraPosition = .region(MapViewModel.sloveniaRegion)
    @Published var stations: [StationMapItem] = []
    @Published var selectedStation: StationMapItem?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var statusMessage: String?
    @Published var lastUpdated: Date?

    private let service: ARSOService
    private var didLoad = false

    var arsoService: ARSOService {
        service
    }

    init(service: ARSOService = ARSOService()) {
        self.service = service
    }

    func loadIfNeeded() async {
        guard !didLoad else { return }
        didLoad = true
        await fetch(forceRefresh: false, showLoading: true)
    }

    func refresh() async {
        await fetch(forceRefresh: true, showLoading: stations.isEmpty)
    }

    func retry() async {
        await fetch(forceRefresh: true, showLoading: true)
    }

    private func fetch(forceRefresh: Bool, showLoading: Bool) async {
        if showLoading {
            isLoading = true
        }
        errorMessage = nil
        statusMessage = nil

        do {
            let snapshot = try await service.fetchLatestSnapshot(forceRefresh: forceRefresh)
            apply(snapshot)
        } catch {
            if let cached = await service.cachedSnapshot() {
                apply(cached)
                statusMessage = "Brez povezave: prikazujem zadnje shranjene ARSO podatke."
            } else {
                stations = []
                errorMessage = "Brez povezave. Podatkov ARSO trenutno ni mogoče naložiti."
            }
        }

        isLoading = false
    }

    private func apply(_ snapshot: ARSOSnapshot) {
        let mapped = snapshot.stations.map { station in
            StationMapItem(station: station, measurement: snapshot.measurementsByCode[station.code])
        }

        stations = mapped.sorted {
            $0.station.name.localizedCaseInsensitiveCompare($1.station.name) == .orderedAscending
        }
        let latestMeasurementDate = mapped
            .compactMap { $0.measurement?.lastUpdate }
            .max()

        lastUpdated = latestMeasurementDate ?? snapshot.fetchedAt
    }
}
