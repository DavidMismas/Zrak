import Foundation

enum DisplayFormatter {
    private static let dateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.timeZone = TimeZone.current
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    private static let valueFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale.current
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 1
        formatter.minimumFractionDigits = 0
        return formatter
    }()

    static func dateTime(_ date: Date?) -> String {
        guard let date else { return "Ni podatkov" }
        return dateTimeFormatter.string(from: date)
    }

    static func concentration(_ value: Double?) -> String {
        guard let value else { return "Ni podatkov" }
        let number = NSNumber(value: value)
        let formatted = valueFormatter.string(from: number) ?? "\(value)"
        return "\(formatted) µg/m³"
    }

    static func rawValue(_ value: Double?) -> String {
        guard let value else { return "Ni podatkov" }
        let number = NSNumber(value: value)
        return valueFormatter.string(from: number) ?? "\(value)"
    }
}
