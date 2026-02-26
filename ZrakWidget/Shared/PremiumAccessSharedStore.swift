import Foundation

enum PremiumAccessSharedStore {
    private static let payloadFilename = "premium_access.json"

    private struct Payload: Codable {
        let isPremiumUnlocked: Bool
        let updatedAt: Date
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
