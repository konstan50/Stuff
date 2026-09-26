import Foundation
import SwiftData

@Model
final class HabitCompletion {
    @Attribute(.unique) var id: UUID
    var date: Date
    var habit: Habit?

    init(date: Date = .now) {
        self.id = UUID()
        self.date = date
    }
}
