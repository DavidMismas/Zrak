import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

enum PremiumAccessSharedStore {
    private static let payloadFilename = "premium_access.json"

    private struct Payload: Codable {
        let isPremiumUnlocked: Bool
        let updatedAt: Date
    }

    static func write(isPremiumUnlocked: Bool) {
        guard let fileURL = payloadURL() else { return }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        let payload = Payload(
            isPremiumUnlocked: isPremiumUnlocked,
            updatedAt: Date()
        )

        do {
            let data = try encoder.encode(payload)
            try data.write(to: fileURL, options: [.atomic])
            #if canImport(WidgetKit)
            WidgetCenter.shared.reloadTimelines(ofKind: WidgetSharedConfig.widgetKind)
            WidgetCenter.shared.reloadAllTimelines()
            #endif
        } catch {
            #if DEBUG
            print("Premium access payload write failed: \(error)")
            #endif
        }
    }

    static func readIsPremiumUnlocked() -> Bool {
        guard let fileURL = payloadURL(),
              let data = try? Data(contentsOf: fileURL) else {
            return false
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let payload = try? decoder.decode(Payload.self, from: data)
        return payload?.isPremiumUnlocked ?? false
    }

    private static func payloadURL() -> URL? {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: WidgetSharedConfig.appGroupIdentifier
        ) else {
            return nil
        }

        return containerURL.appendingPathComponent(payloadFilename)
    }
}
