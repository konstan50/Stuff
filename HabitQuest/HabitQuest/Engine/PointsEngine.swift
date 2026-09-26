import Foundation

/// Pure functions that turn a habit's completion history into points, streaks
/// and badge state. Everything is recomputed from `habit.completions` on demand
/// rather than stored incrementally, so it can never drift out of sync.
enum PointsEngine {
    static let pointsPerCompletion = 10
    static let weeklyBonusPoints = 30
    static let streakMilestones = [2, 4, 8, 12, 26, 52]

    struct Summary {
        var totalPoints: Int = 0
        var currentStreak: Int = 0
        var bestStreak: Int = 0
        var thisWeekCount: Int = 0
        var thisWeekGoalMet: Bool = false
    }

    static func summarize(habit: Habit, calendar: Calendar = .current, now: Date = .now) -> Summary {
        guard let currentWeekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start else {
            return Summary()
        }

        var weekly: [Date: Int] = [:]
        for completion in habit.completions {
            let weekStart = calendar.dateInterval(of: .weekOfYear, for: completion.date)?.start ?? completion.date
            weekly[weekStart, default: 0] += 1
        }

        let target = max(habit.weeklyTarget, 1)
        let thisWeekCount = weekly[currentWeekStart] ?? 0
        let thisWeekGoalMet = thisWeekCount >= target

        // Current streak: consecutive weeks meeting goal, walking backward. The
        // in-progress week only counts if it has already hit the target.
        var currentStreak = 0
        var cursor = currentWeekStart
        var isFirstIteration = true
        while true {
            let met = (weekly[cursor] ?? 0) >= target
            if isFirstIteration {
                isFirstIteration = false
                if met { currentStreak += 1 }
            } else if met {
                currentStreak += 1
            } else {
                break
            }
            guard let previousWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: cursor) else { break }
            cursor = previousWeek
        }

        // Best streak and total weeks met: scan forward from the habit's
        // creation week through the current week.
        let creationWeekStart = calendar.dateInterval(of: .weekOfYear, for: habit.createdAt)?.start ?? currentWeekStart
        var bestStreak = 0
        var runningStreak = 0
        var weeksMet = 0
        var scanCursor = creationWeekStart
        while scanCursor <= currentWeekStart {
            if (weekly[scanCursor] ?? 0) >= target {
                runningStreak += 1
                weeksMet += 1
                bestStreak = max(bestStreak, runningStreak)
            } else {
                runningStreak = 0
            }
            guard let next = calendar.date(byAdding: .weekOfYear, value: 1, to: scanCursor) else { break }
            scanCursor = next
        }
        bestStreak = max(bestStreak, currentStreak)

        let totalPoints = habit.completions.count * pointsPerCompletion + weeksMet * weeklyBonusPoints

        return Summary(
            totalPoints: totalPoints,
            currentStreak: currentStreak,
            bestStreak: bestStreak,
            thisWeekCount: thisWeekCount,
            thisWeekGoalMet: thisWeekGoalMet
        )
    }

    static func level(forPoints points: Int) -> (level: Int, title: String, progress: Double, pointsToNext: Int) {
        let titles = ["Seedling", "Sprout", "Bloomer", "Habit Builder", "Habit Master", "Legend"]
        let pointsPerLevel = 100
        let levelIndex = min(points / pointsPerLevel, titles.count - 1)
        let pointsIntoLevel = points - levelIndex * pointsPerLevel
        let isMaxLevel = levelIndex == titles.count - 1
        let progress = isMaxLevel ? 1.0 : Double(pointsIntoLevel) / Double(pointsPerLevel)
        let pointsToNext = isMaxLevel ? 0 : pointsPerLevel - pointsIntoLevel
        return (levelIndex + 1, titles[levelIndex], progress, pointsToNext)
    }
}
