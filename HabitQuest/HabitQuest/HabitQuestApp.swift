import SwiftUI
import SwiftData

@main
struct HabitQuestApp: App {
    @StateObject private var notificationManager = NotificationManager.shared

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([Habit.self, HabitCompletion.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(notificationManager)
                .onAppear {
                    notificationManager.refreshAuthorizationStatus()
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
