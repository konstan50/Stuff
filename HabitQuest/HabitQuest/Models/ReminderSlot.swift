import Foundation

/// A weekly recurring reminder time. `weekday` follows `Calendar`/`DateComponents`
/// convention: 1 = Sunday ... 7 = Saturday.
struct ReminderSlot: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var weekday: Int
    var hour: Int
    var minute: Int

    var timeDescription: String {
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        let date = Calendar.current.date(from: components) ?? .now
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    var weekdaySymbol: String {
        let symbols = Calendar.current.weekdaySymbols
        guard weekday >= 1 && weekday <= symbols.count else { return "" }
        return symbols[weekday - 1]
    }
}
