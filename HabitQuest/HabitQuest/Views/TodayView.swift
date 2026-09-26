import SwiftUI
import SwiftData

struct TodayView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Habit.sortOrder) private var habits: [Habit]

    var body: some View {
        NavigationStack {
            Group {
                if habits.isEmpty {
                    ContentUnavailableView(
                        "No Habits Yet",
                        systemImage: "sparkles",
                        description: Text("Add a habit from the Habits tab to start tracking.")
                    )
                } else {
                    List {
                        ForEach(habits) { habit in
                            HabitTodayRow(habit: habit)
                        }
                    }
                }
            }
            .navigationTitle("Today")
        }
        .onReceive(NotificationCenter.default.publisher(for: .markHabitDoneFromNotification)) { note in
            guard let habitID = note.object as? UUID,
                  let habit = habits.first(where: { $0.id == habitID }) else { return }
            habit.markDoneToday(context: context)
        }
    }
}

private struct HabitTodayRow: View {
    @Bindable var habit: Habit
    @Environment(\.modelContext) private var context

    private var summary: PointsEngine.Summary { PointsEngine.summarize(habit: habit) }

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(habit.color.opacity(0.2), lineWidth: 6)
                Circle()
                    .trim(from: 0, to: min(Double(summary.thisWeekCount) / Double(max(habit.weeklyTarget, 1)), 1))
                    .stroke(habit.color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Image(systemName: habit.icon)
                    .font(.subheadline)
                    .foregroundStyle(habit.color)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text(habit.name).font(.headline)
                Text("\(summary.thisWeekCount)/\(habit.weeklyTarget) this week · 🔥 \(summary.currentStreak)w streak")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                withAnimation { habit.toggleCompletion(on: .now, context: context) }
            } label: {
                Image(systemName: habit.isCompleted(on: .now) ? "checkmark.circle.fill" : "circle")
                    .font(.title)
                    .foregroundStyle(habit.isCompleted(on: .now) ? habit.color : Color.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 6)
    }
}
