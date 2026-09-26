import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            TodayView()
                .tabItem { Label("Today", systemImage: "sun.max.fill") }
            HabitsListView()
                .tabItem { Label("Habits", systemImage: "list.bullet") }
            CircleView()
                .tabItem { Label("Circle", systemImage: "person.3.fill") }
            RewardsView()
                .tabItem { Label("Rewards", systemImage: "trophy.fill") }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Habit.self, HabitCompletion.self], inMemory: true)
}
