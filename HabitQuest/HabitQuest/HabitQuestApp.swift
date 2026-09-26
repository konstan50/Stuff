import SwiftUI
import SwiftData

@main
struct HabitQuestApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var notificationManager = NotificationManager.shared
    @StateObject private var cloudKitManager = CloudKitManager.shared
    @Environment(\.scenePhase) private var scenePhase

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
                .environmentObject(cloudKitManager)
                .onAppear {
                    notificationManager.refreshAuthorizationStatus()
                    Task { await cloudKitManager.refreshCircle() }
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        Task { await cloudKitManager.refreshCircle() }
                    }
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
