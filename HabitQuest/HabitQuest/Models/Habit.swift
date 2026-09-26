import Foundation
import SwiftData

@Model
final class Habit {
    @Attribute(.unique) var id: UUID
    var name: String
    var icon: String
    var colorHex: String
    var weeklyTarget: Int
    var reminderSlots: [ReminderSlot]
    var createdAt: Date
    var sortOrder: Int
    var isSharedToCircle: Bool

    @Relationship(deleteRule: .cascade, inverse: \HabitCompletion.habit)
    var completions: [HabitCompletion] = []

    init(
        name: String,
        icon: String = "checkmark.circle.fill",
        colorHex: String = "34C759",
        weeklyTarget: Int = 3,
        reminderSlots: [ReminderSlot] = [],
        sortOrder: Int = 0,
        isSharedToCircle: Bool = false
    ) {
        self.id = UUID()
        self.name = name
        self.icon = icon
        self.colorHex = colorHex
        self.weeklyTarget = weeklyTarget
        self.reminderSlots = reminderSlots
        self.createdAt = .now
        self.sortOrder = sortOrder
        self.isSharedToCircle = isSharedToCircle
    }
}

extension Habit {
    func isCompleted(on date: Date, calendar: Calendar = .current) -> Bool {
        completions.contains { calendar.isDate($0.date, inSameDayAs: date) }
    }

    func toggleCompletion(on date: Date = .now, calendar: Calendar = .current, context: ModelContext) {
        if let existing = completions.first(where: { calendar.isDate($0.date, inSameDayAs: date) }) {
            completions.removeAll { $0.id == existing.id }
            context.delete(existing)
        } else {
            let completion = HabitCompletion(date: date)
            completion.habit = self
            completions.append(completion)
            context.insert(completion)
        }
    }

    func markDoneToday(context: ModelContext) {
        guard !isCompleted(on: .now) else { return }
        toggleCompletion(on: .now, context: context)
    }
}
