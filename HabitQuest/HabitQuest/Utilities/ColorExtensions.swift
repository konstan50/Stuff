import SwiftUI

extension Color {
    init(hex: String) {
        var sanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        sanitized = sanitized.replacingOccurrences(of: "#", with: "")
        var rgb: UInt64 = 0
        Scanner(string: sanitized).scanHexInt64(&rgb)
        let r = Double((rgb & 0xFF0000) >> 16) / 255
        let g = Double((rgb & 0x00FF00) >> 8) / 255
        let b = Double(rgb & 0x0000FF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

extension Habit {
    var color: Color { Color(hex: colorHex) }
}

enum HabitPalette {
    static let icons = [
        "checkmark.circle.fill", "drop.fill", "figure.run", "book.fill",
        "bed.double.fill", "leaf.fill", "dumbbell.fill", "brain.head.profile",
        "pills.fill", "flame.fill", "heart.fill", "moon.stars.fill",
        "fork.knife", "cup.and.saucer.fill", "pencil.and.list.clipboard"
    ]

    static let colors = [
        "FF3B30", "FF9500", "FFCC00", "34C759", "00C7BE", "30B0C7",
        "32ADE6", "007AFF", "5856D6", "AF52DE", "FF2D55", "A2845E"
    ]
}
