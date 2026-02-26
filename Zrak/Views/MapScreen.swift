import MapKit
import SwiftUI

struct MapScreen: View {
    @StateObject private var viewModel = MapViewModel()
    @State private var isShowingAirQualityInfo = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                header

                ZStack {
                    Map(position: $viewModel.cameraPosition) {
                        ForEach(viewModel.stations) { item in
                            Annotation(item.station.name, coordinate: item.station.coordinate) {
                                Button {
                                    viewModel.selectedStation = item
                                } label: {
                                    StationMarkerView(level: item.airQualityLevel)
                                }
                                .buttonStyle(.plain)
                            }
                            .annotationTitles(.hidden)
                        }
                    }
                    .mapStyle(.standard)

                    if let statusMessage = viewModel.statusMessage {
                        VStack {
                            statusMessageView(statusMessage)
                            Spacer()
                        }
                        .padding(10)
                    }

                    if let errorMessage = viewModel.errorMessage {
                        errorMessageView(errorMessage)
                            .padding(.horizontal, 20)
                    }

                    if viewModel.isLoading, viewModel.stations.isEmpty {
                        ProgressView("Nalagam ARSO podatke ...")
                            .padding(14)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(maxHeight: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color(uiColor: .separator), lineWidth: 1)
                )

                legendSection
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .navigationTitle("Zrak")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        ExperimentalAirQualityMapView(
                            stations: viewModel.stations,
                            lastUpdated: viewModel.lastUpdated
                        )
                    } label: {
                        Image(systemName: "flask")
                    }
                    .accessibilityLabel("Eksperimentalni prikaz Slovenije")
                }

                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        isShowingAirQualityInfo = true
                    } label: {
                        Image(systemName: "info.circle")
                    }
                    .accessibilityLabel("Pomen meritev")

                    Button {
                        Task { await viewModel.refresh() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .accessibilityLabel("Osveži")
                }
            }
            .sheet(isPresented: $isShowingAirQualityInfo) {
                AirQualityInfoSheet()
            }
            .sheet(item: $viewModel.selectedStation) { item in
                StationDetailSheet(item: item, service: viewModel.arsoService)
            }
            .task {
                await viewModel.loadIfNeeded()
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Kakovost zraka")
                .font(.title2.weight(.semibold))
            Text("Zadnji podatki: \(DisplayFormatter.dateTime(viewModel.lastUpdated)) (vir: ARSO)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var legendSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Legenda barv")
                .font(.caption.weight(.semibold))
            AirQualityLegendView()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func statusMessageView(_ message: String) -> some View {
        Text(message)
            .font(.caption.weight(.medium))
            .foregroundStyle(.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func errorMessageView(_ message: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "wifi.exclamationmark")
                .font(.title2)
            Text(message)
                .font(.subheadline)
                .multilineTextAlignment(.center)
            Button("Poskusi znova") {
                Task { await viewModel.retry() }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

#Preview {
    MapScreen()
}
