import SwiftUI
import SwiftData

struct HabitsListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Habit.sortOrder) private var habits: [Habit]
    @State private var showingAddHabit = false
    @State private var habitToEdit: Habit?

    var body: some View {
        NavigationStack {
            Group {
                if habits.isEmpty {
                    ContentUnavailableView(
                        "No Habits Yet",
                        systemImage: "sparkles",
                        description: Text("Tap + to add your first habit.")
                    )
                } else {
                    List {
                        ForEach(habits) { habit in
                            NavigationLink(value: habit) {
                                HStack {
                                    Image(systemName: habit.icon)
                                        .foregroundStyle(habit.color)
                                        .frame(width: 28)
                                    VStack(alignment: .leading) {
                                        Text(habit.name)
                                        Text("\(habit.weeklyTarget)x / week")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    delete(habit)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                Button {
                                    habitToEdit = habit
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(.blue)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Habits")
            .navigationDestination(for: Habit.self) { habit in
                HabitDetailView(habit: habit)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddHabit = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddHabit) {
                AddEditHabitView(habit: nil)
            }
            .sheet(item: $habitToEdit) { habit in
                AddEditHabitView(habit: habit)
            }
        }
    }

    private func delete(_ habit: Habit) {
        NotificationManager.shared.cancelReminders(for: habit)
        if habit.isSharedToCircle {
            let habitID = habit.id
            Task { await CloudKitManager.shared.removeMyGoal(habitID: habitID) }
        }
        context.delete(habit)
    }
}
