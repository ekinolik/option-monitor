import Foundation

enum ExpirationFiltering {
    static func parseExpirationDate(_ expiration: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: expiration)
    }

    static func isWithinDaysFromToday(_ expiration: String, days: Int) -> Bool {
        guard let expirationDate = parseExpirationDate(expiration) else { return false }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let endDate = calendar.date(byAdding: .day, value: days, to: today) else { return false }

        let expirationDay = calendar.startOfDay(for: expirationDate)
        return expirationDay >= today && expirationDay <= endDate
    }
}
