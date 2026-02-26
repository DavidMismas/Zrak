import SwiftUI

struct AirQualityInfoSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    titleSection

                    ForEach(pollutants) { pollutant in
                        pollutantCard(pollutant)
                    }

                    appReadingSection
                }
                .padding()
            }
            .navigationTitle("Pomen meritev")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Zapri") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Kaj pomenijo meritve kakovosti zraka")
                .font(.title3.weight(.semibold))
            Text("Spodaj so praktične razlage posameznih meritev in orientacijski pragovi za hitro interpretacijo stanja.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("Barvne oznake so usklajene z barvami v aplikaciji.")
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func pollutantCard(_ pollutant: PollutantInfo) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(pollutant.title)
                .font(.headline)
            Text(pollutant.description)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 6) {
                Text("Pragovi")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                ForEach(pollutant.ranges) { item in
                    rangeRow(item)
                }
            }

            if let source = pollutant.source {
                infoLine(title: "Vir", value: source)
            }

            infoLine(title: "Vpliv", value: pollutant.impact)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func rangeRow(_ range: PollutantRange) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(range.level.color)
                .frame(width: 10, height: 10)

            Text("\(range.interval) -> \(range.label)")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(range.level.color.opacity(0.14), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
    }

    private func infoLine(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline)
        }
    }

    private var appReadingSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Kako brati podatke v aplikaciji")
                .font(.headline)
            Text("• Prikazane so zadnje urne meritve z ARSO merilnih postaj.")
            Text("• Barva označuje trenutno stanje, ne napoved.")
            Text("• Če podatka ni, postaja trenutno ne meri ali ni veljavnega podatka.")
        }
        .font(.subheadline)
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var pollutants: [PollutantInfo] {
        [
            PollutantInfo(
                title: "PM2.5 - fini delci (≤ 2,5 µm)",
                description: "Zelo majhni delci, ki prodrejo globoko v pljuča in kri. Najbolj škodljivi.",
                ranges: [
                    PollutantRange(interval: "0-15 µg/m³", label: "dobro", level: .good),
                    PollutantRange(interval: "16-35 µg/m³", label: "zmerno", level: .moderate),
                    PollutantRange(interval: "36-55 µg/m³", label: "slabo za občutljive", level: .unhealthySensitive),
                    PollutantRange(interval: "56-100 µg/m³", label: "slabo", level: .unhealthy),
                    PollutantRange(interval: ">100 µg/m³", label: "zelo slabo", level: .veryUnhealthy)
                ],
                source: "promet, kurjenje lesa, industrija",
                impact: "dihala, srce, dolgoročno večje tveganje za bolezni"
            ),
            PollutantInfo(
                title: "PM10 - grobi delci (≤ 10 µm)",
                description: "Večji delci, ki dražijo dihala, manj prodorni kot PM2.5.",
                ranges: [
                    PollutantRange(interval: "0-25 µg/m³", label: "dobro", level: .good),
                    PollutantRange(interval: "26-50 µg/m³", label: "zmerno", level: .moderate),
                    PollutantRange(interval: "51-100 µg/m³", label: "slabo", level: .unhealthy),
                    PollutantRange(interval: ">100 µg/m³", label: "zelo slabo", level: .veryUnhealthy)
                ],
                source: "promet, prah, kurjenje",
                impact: "kašelj, draženje, poslabšanje astme"
            ),
            PollutantInfo(
                title: "NO₂ - dušikov dioksid",
                description: "Plin, močno povezan s prometom.",
                ranges: [
                    PollutantRange(interval: "0-40 µg/m³", label: "dobro", level: .good),
                    PollutantRange(interval: "41-100 µg/m³", label: "zmerno", level: .moderate),
                    PollutantRange(interval: "101-200 µg/m³", label: "slabo", level: .unhealthy),
                    PollutantRange(interval: ">200 µg/m³", label: "zelo slabo", level: .veryUnhealthy)
                ],
                source: nil,
                impact: "draženje dihal, slabše delovanje pljuč"
            ),
            PollutantInfo(
                title: "O₃ - ozon (pri tleh)",
                description: "Poleti pogost, nastaja ob soncu iz drugih onesnaževal.",
                ranges: [
                    PollutantRange(interval: "0-60 µg/m³", label: "dobro", level: .good),
                    PollutantRange(interval: "61-120 µg/m³", label: "zmerno", level: .moderate),
                    PollutantRange(interval: "121-180 µg/m³", label: "slabo", level: .unhealthy),
                    PollutantRange(interval: ">180 µg/m³", label: "zelo slabo", level: .veryUnhealthy)
                ],
                source: nil,
                impact: "draženje oči in dihal, slabša telesna zmogljivost"
            ),
            PollutantInfo(
                title: "SO₂ - žveplov dioksid",
                description: "Redkejši, predvsem industrija in kurilna goriva.",
                ranges: [
                    PollutantRange(interval: "0-100 µg/m³", label: "dobro", level: .good),
                    PollutantRange(interval: "101-350 µg/m³", label: "slabo", level: .unhealthy),
                    PollutantRange(interval: ">350 µg/m³", label: "zelo slabo", level: .veryUnhealthy)
                ],
                source: nil,
                impact: "draženje dihal, nevarno za astmatike"
            ),
            PollutantInfo(
                title: "CO - ogljikov monoksid",
                description: "Brezbarven, brez vonja, zelo nevaren pri visokih koncentracijah.",
                ranges: [
                    PollutantRange(interval: "0-5 mg/m³", label: "normalno", level: .good),
                    PollutantRange(interval: "5-10 mg/m³", label: "povišano", level: .moderate),
                    PollutantRange(interval: ">10 mg/m³", label: "nevarno", level: .veryUnhealthy)
                ],
                source: nil,
                impact: "zmanjšan dovod kisika v telo"
            )
        ]
    }
}

private struct PollutantInfo: Identifiable {
    let title: String
    let description: String
    let ranges: [PollutantRange]
    let source: String?
    let impact: String

    var id: String { title }
}

private struct PollutantRange: Identifiable {
    let interval: String
    let label: String
    let level: AirQualityLevel

    var id: String { "\(interval)-\(label)" }
}

#Preview {
    AirQualityInfoSheet()
}
