import SwiftUI
import SwiftData
import Charts

struct HabitDetailView: View {
    @Bindable var habit: Habit
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var cloudKit: CloudKitManager
    @State private var showingEdit = false

    private var summary: PointsEngine.Summary { PointsEngine.summarize(habit: habit) }

    private var weeklyHistory: [(weekStart: Date, count: Int)] {
        let calendar = Calendar.current
        guard let currentWeekStart = calendar.dateInterval(of: .weekOfYear, for: .now)?.start else { return [] }
        var result: [(Date, Int)] = []
        for offset in -7...0 {
            guard let weekStart = calendar.date(byAdding: .weekOfYear, value: offset, to: currentWeekStart),
                  let interval = calendar.dateInterval(of: .weekOfYear, for: weekStart) else { continue }
            let count = habit.completions.filter { interval.contains($0.date) }.count
            result.append((weekStart, count))
        }
        return result
    }

    var body: some View {
        List {
            Section {
                HStack {
                    statTile(title: "This Week", value: "\(summary.thisWeekCount)/\(habit.weeklyTarget)")
                    Spacer()
                    statTile(title: "Streak", value: "🔥 \(summary.currentStreak)w")
                    Spacer()
                    statTile(title: "Points", value: "\(summary.totalPoints)")
                }
                .padding(.vertical, 4)
            }

            Section("Last 8 Weeks") {
                Chart(weeklyHistory, id: \.weekStart) { entry in
                    BarMark(
                        x: .value("Week", entry.weekStart, unit: .weekOfYear),
                        y: .value("Completions", entry.count)
                    )
                    .foregroundStyle(habit.color)
                    RuleMark(y: .value("Goal", habit.weeklyTarget))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                        .foregroundStyle(.secondary)
                }
                .frame(height: 160)
            }

            Section("Badges") {
                let earned = PointsEngine.streakMilestones.filter { summary.bestStreak >= $0 }
                if earned.isEmpty {
                    Text("Keep your streak going to earn badges.").foregroundStyle(.secondary)
                } else {
                    HStack {
                        ForEach(earned, id: \.self) { milestone in
                            VStack {
                                Image(systemName: "medal.fill").foregroundStyle(.yellow)
                                Text("\(milestone)w").font(.caption2)
                            }
                            Spacer()
                        }
                    }
                }
            }

            Section("Reminders") {
                if habit.reminderSlots.isEmpty {
                    Text("No reminders set.").foregroundStyle(.secondary)
                } else {
                    ForEach(habit.reminderSlots) { slot in
                        HStack {
                            Text(slot.weekdaySymbol)
                            Spacer()
                            Text(slot.timeDescription).foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section {
                Button("Mark Done for Today") {
                    habit.toggleCompletion(on: .now, context: context)
                    if habit.isSharedToCircle {
                        Task { await cloudKit.publishMyGoal(habit: habit) }
                    }
                }
                Button("Delete Habit", role: .destructive) {
                    NotificationManager.shared.cancelReminders(for: habit)
                    if habit.isSharedToCircle {
                        let habitID = habit.id
                        Task { await cloudKit.removeMyGoal(habitID: habitID) }
                    }
                    context.delete(habit)
                    dismiss()
                }
            }
        }
        .navigationTitle(habit.name)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") { showingEdit = true }
            }
        }
        .sheet(isPresented: $showingEdit) {
            AddEditHabitView(habit: habit)
        }
    }

    private func statTile(title: String, value: String) -> some View {
        VStack(alignment: .leading) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.title3.bold())
        }
    }
}
