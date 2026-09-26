import Foundation
import UserNotifications

extension Notification.Name {
    static let markHabitDoneFromNotification = Notification.Name("markHabitDoneFromNotification")
}

/// Schedules local notifications for each habit's weekly reminder slots.
/// These are on-device reminders (no server / Apple Push Notification service
/// involved), which is all a personal habit tracker needs — they fire reliably
/// even without network access.
@MainActor
final class NotificationManager: NSObject, ObservableObject {
    static let shared = NotificationManager()

    @Published var authorizationGranted = false

    private let center = UNUserNotificationCenter.current()
    private let markDoneActionID = "MARK_DONE_ACTION"
    private let habitCategoryID = "HABIT_REMINDER"
    private let identifierPrefix = "habit-"

    private override init() {
        super.init()
        center.delegate = self
        registerCategories()
        refreshAuthorizationStatus()
    }

    func refreshAuthorizationStatus() {
        center.getNotificationSettings { [weak self] settings in
            let granted = settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
            Task { @MainActor in self?.authorizationGranted = granted }
        }
    }

    func requestAuthorization(completion: @escaping (Bool) -> Void = { _ in }) {
        center.requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, _ in
            Task { @MainActor in
                self?.authorizationGranted = granted
                completion(granted)
            }
        }
    }

    private func registerCategories() {
        let markDone = UNNotificationAction(identifier: markDoneActionID, title: "Mark Done", options: [])
        let category = UNNotificationCategory(
            identifier: habitCategoryID,
            actions: [markDone],
            intentIdentifiers: [],
            options: []
        )
        center.setNotificationCategories([category])
    }

    /// Cancels any existing reminders for the habit, then schedules its current set.
    func scheduleReminders(for habit: Habit) {
        cancelReminders(for: habit) { [weak self] in
            guard let self, self.authorizationGranted else { return }
            for slot in habit.reminderSlots {
                let content = UNMutableNotificationContent()
                content.title = habit.name
                content.body = "Time for your \(habit.name.lowercased()) — keep the streak alive!"
                content.sound = .default
                content.categoryIdentifier = self.habitCategoryID
                content.userInfo = ["habitID": habit.id.uuidString]

                var dateComponents = DateComponents()
                dateComponents.weekday = slot.weekday
                dateComponents.hour = slot.hour
                dateComponents.minute = slot.minute

                let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
                let identifier = "\(self.identifierPrefix)\(habit.id.uuidString)-\(slot.id.uuidString)"
                let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
                self.center.add(request)
            }
        }
    }

    func cancelReminders(for habit: Habit, then completion: @escaping () -> Void = {}) {
        let prefix = "\(identifierPrefix)\(habit.id.uuidString)-"
        center.getPendingNotificationRequests { [weak self] requests in
            let ids = requests.map(\.identifier).filter { $0.hasPrefix(prefix) }
            self?.center.removePendingNotificationRequests(withIdentifiers: ids)
            Task { @MainActor in completion() }
        }
    }
}

extension NotificationManager: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .badge]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard response.actionIdentifier == UNNotificationDefaultActionIdentifier
            || response.actionIdentifier == "MARK_DONE_ACTION" else { return }
        guard let habitIDString = response.notification.request.content.userInfo["habitID"] as? String,
              let habitID = UUID(uuidString: habitIDString) else { return }
        await MainActor.run {
            NotificationCenter.default.post(name: .markHabitDoneFromNotification, object: habitID)
        }
    }
}
