import Charts
import SwiftUI

struct StationDetailSheet: View {
    @EnvironmentObject private var premiumManager: PremiumManager
    @StateObject private var viewModel: StationDetailViewModel

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    init(item: StationMapItem, service: ARSOService) {
        _viewModel = StateObject(wrappedValue: StationDetailViewModel(item: item, service: service))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    badge
                    updatedCard
                    metricsGrid
                    if premiumManager.hasPremiumAccess {
                        miniChartSection
                    } else {
                        lockedChartSection
                    }
                }
                .padding()
            }
            .navigationTitle(viewModel.stationName)
            .navigationBarTitleDisplayMode(.inline)
            .task {
                guard premiumManager.hasPremiumAccess else { return }
                await viewModel.loadChartIfNeeded()
            }
            .onChange(of: premiumManager.hasPremiumAccess) { _, hasAccess in
                guard hasAccess else { return }
                Task {
                    await viewModel.loadChartIfNeeded()
                }
            }
        }
    }

    private var badge: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(viewModel.badgeTitle)
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
            Text(viewModel.badgeValue)
                .font(.headline)
                .foregroundStyle(.white.opacity(0.95))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(viewModel.level.color, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var updatedCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Zadnja posodobitev")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(viewModel.lastUpdate)
                .font(.body.weight(.medium))
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var metricsGrid: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(viewModel.metrics) { metric in
                VStack(alignment: .leading, spacing: 6) {
                    Text(metric.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(metric.value)
                        .font(.body.weight(.semibold))
                        .minimumScaleFactor(0.8)
                        .lineLimit(2)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }

    private var miniChartSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Trend kakovosti zraka")
                    .font(.headline)
                Spacer()
                if viewModel.isChartLoading {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            Picker("Obdobje", selection: $viewModel.selectedRange) {
                ForEach(StationDetailViewModel.ChartRange.allCases) { range in
                    Text(range.title).tag(range)
                }
            }
            .pickerStyle(.segmented)

            if !viewModel.chartPoints.isEmpty {
                Chart(viewModel.chartPoints) { point in
                    LineMark(
                        x: .value("Čas", point.date),
                        y: .value("Koncentracija", point.value)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(viewModel.level.color)
                }
                .frame(height: 180)
                .chartYScale(domain: 0 ... viewModel.chartUpperBound)
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: viewModel.selectedRange.desiredTickCount)) {
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel(format: viewModel.selectedRange.axisFormat)
                    }
                }
            } else if viewModel.isChartLoading {
                ProgressView("Nalagam graf ...")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            } else {
                Text(viewModel.chartMessage ?? "Ni podatkov za izbrano obdobje.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            }

            HStack {
                Text(viewModel.chartLegend)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Osveži graf") {
                    Task {
                        await viewModel.refreshChart(forceRefresh: true)
                    }
                }
                .font(.caption.weight(.semibold))
            }
        }
        .padding(12)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var lockedChartSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Trend kakovosti zraka")
                .font(.headline)
            Text("Graf je na voljo v Zrak Premium.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Button("Odkleni Premium") {
                premiumManager.presentPaywall(for: .stationChart)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
