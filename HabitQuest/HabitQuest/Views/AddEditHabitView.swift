import SwiftUI
import SwiftData

struct AddEditHabitView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var notificationManager: NotificationManager

    let habit: Habit?

    @State private var name: String
    @State private var icon: String
    @State private var colorHex: String
    @State private var weeklyTarget: Int
    @State private var reminderSlots: [ReminderSlot]
    @State private var newReminderWeekday = 2 // Monday
    @State private var newReminderTime = Date()

    init(habit: Habit?) {
        self.habit = habit
        _name = State(initialValue: habit?.name ?? "")
        _icon = State(initialValue: habit?.icon ?? "checkmark.circle.fill")
        _colorHex = State(initialValue: habit?.colorHex ?? "34C759")
        _weeklyTarget = State(initialValue: habit?.weeklyTarget ?? 3)
        _reminderSlots = State(initialValue: habit?.reminderSlots ?? [])
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Habit") {
                    TextField("Name", text: $name)
                    Stepper("Goal: \(weeklyTarget)x / week", value: $weeklyTarget, in: 1...21)
                }

                Section("Icon") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5)) {
                        ForEach(HabitPalette.icons, id: \.self) { option in
                            Image(systemName: option)
                                .font(.title2)
                                .foregroundStyle(icon == option ? Color(hex: colorHex) : Color.secondary)
                                .frame(width: 40, height: 40)
                                .background(icon == option ? Color(hex: colorHex).opacity(0.15) : Color.clear)
                                .clipShape(Circle())
                                .onTapGesture { icon = option }
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Color") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6)) {
                        ForEach(HabitPalette.colors, id: \.self) { hex in
                            Circle()
                                .fill(Color(hex: hex))
                                .frame(width: 32, height: 32)
                                .overlay {
                                    if colorHex == hex {
                                        Circle().stroke(Color.primary, lineWidth: 2).padding(-3)
                                    }
                                }
                                .onTapGesture { colorHex = hex }
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Reminders") {
                    if reminderSlots.isEmpty {
                        Text("No reminders yet.").foregroundStyle(.secondary)
                    }
                    ForEach(reminderSlots) { slot in
                        HStack {
                            Text(slot.weekdaySymbol)
                            Spacer()
                            Text(slot.timeDescription).foregroundStyle(.secondary)
                        }
                    }
                    .onDelete { indexSet in
                        reminderSlots.remove(atOffsets: indexSet)
                    }

                    Picker("Day", selection: $newReminderWeekday) {
                        ForEach(Array(Calendar.current.weekdaySymbols.enumerated()), id: \.offset) { index, symbol in
                            Text(symbol).tag(index + 1)
                        }
                    }
                    DatePicker("Time", selection: $newReminderTime, displayedComponents: .hourAndMinute)
                    Button("Add Reminder") {
                        let components = Calendar.current.dateComponents([.hour, .minute], from: newReminderTime)
                        let slot = ReminderSlot(
                            weekday: newReminderWeekday,
                            hour: components.hour ?? 9,
                            minute: components.minute ?? 0
                        )
                        reminderSlots.append(slot)
                    }
                }

                if !notificationManager.authorizationGranted {
                    Section {
                        Text("Notifications are off. Saving a reminder will ask for permission.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(habit == nil ? "New Habit" : "Edit Habit")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func save() {
        let targetHabit: Habit
        if let habit {
            targetHabit = habit
        } else {
            targetHabit = Habit(name: name, sortOrder: Int(Date.now.timeIntervalSince1970))
            context.insert(targetHabit)
        }
        targetHabit.name = name
        targetHabit.icon = icon
        targetHabit.colorHex = colorHex
        targetHabit.weeklyTarget = weeklyTarget
        targetHabit.reminderSlots = reminderSlots

        if reminderSlots.isEmpty {
            notificationManager.cancelReminders(for: targetHabit)
        } else if notificationManager.authorizationGranted {
            notificationManager.scheduleReminders(for: targetHabit)
        } else {
            notificationManager.requestAuthorization { granted in
                if granted {
                    notificationManager.scheduleReminders(for: targetHabit)
                }
            }
        }

        dismiss()
    }
}
