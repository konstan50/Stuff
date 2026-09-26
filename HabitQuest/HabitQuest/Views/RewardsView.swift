import SwiftUI
import SwiftData

struct RewardsView: View {
    @Query private var habits: [Habit]

    private var totalPoints: Int {
        habits.reduce(0) { $0 + PointsEngine.summarize(habit: $1).totalPoints }
    }

    private var levelInfo: (level: Int, title: String, progress: Double, pointsToNext: Int) {
        PointsEngine.level(forPoints: totalPoints)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(spacing: 8) {
                        Text("Level \(levelInfo.level) · \(levelInfo.title)")
                            .font(.title3.bold())
                        ProgressView(value: levelInfo.progress)
                        Text(levelInfo.pointsToNext > 0 ? "\(levelInfo.pointsToNext) points to next level" : "Max level reached")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(totalPoints) total points")
                            .font(.headline)
                            .padding(.top, 4)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }

                Section("Habit Streaks") {
                    if habits.isEmpty {
                        Text("Add habits to start earning rewards.").foregroundStyle(.secondary)
                    } else {
                        ForEach(habits) { habit in
                            let summary = PointsEngine.summarize(habit: habit)
                            HStack {
                                Image(systemName: habit.icon).foregroundStyle(habit.color)
                                Text(habit.name)
                                Spacer()
                                Text("🔥 \(summary.currentStreak)w · best \(summary.bestStreak)w")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Section("Badges") {
                    let bestOverall = habits.map { PointsEngine.summarize(habit: $0).bestStreak }.max() ?? 0
                    let earned = PointsEngine.streakMilestones.filter { bestOverall >= $0 }
                    if earned.isEmpty {
                        Text("No badges yet — complete a habit's weekly goal for several weeks in a row.")
                            .foregroundStyle(.secondary)
                    } else {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4)) {
                            ForEach(earned, id: \.self) { milestone in
                                VStack {
                                    Image(systemName: "medal.fill")
                                        .font(.title)
                                        .foregroundStyle(.yellow)
                                    Text("\(milestone)-week streak")
                                        .font(.caption2)
                                        .multilineTextAlignment(.center)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Rewards")
        }
    }
}
