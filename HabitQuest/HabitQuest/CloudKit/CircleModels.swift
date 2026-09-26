import Foundation
import CloudKit

/// Local membership info for the single circle this device belongs to.
/// Persisted as JSON in UserDefaults — there's nothing here that needs
/// SwiftData, and circle membership is 1-per-device for this v1.
struct CircleContext: Codable {
    var zoneOwnerName: String
    var zoneName: String
    var isOwner: Bool
    var circleName: String
    var myDisplayName: String
    var myColorHex: String
    var hasSetDisplayName: Bool

    var zoneID: CKRecordZone.ID {
        CKRecordZone.ID(zoneName: zoneName, ownerName: zoneOwnerName)
    }
}

struct CircleMember: Codable, Identifiable, Hashable {
    var id: String
    var displayName: String
    var colorHex: String
    var isMe: Bool
}

struct SharedGoalSummary: Codable, Identifiable, Hashable {
    var id: String
    var memberID: String
    var memberName: String
    var memberColorHex: String
    var habitID: String
    var habitName: String
    var habitIcon: String
    var habitColorHex: String
    var weeklyTarget: Int
    var thisWeekCount: Int
    var currentStreak: Int
    var bestStreak: Int
    var updatedAt: Date

    var thisWeekGoalMet: Bool { thisWeekCount >= max(weeklyTarget, 1) }
}

struct CircleChatMessage: Codable, Identifiable, Hashable {
    var id: String
    var authorID: String
    var authorName: String
    var authorColorHex: String
    var text: String
    var sentAt: Date
}

/// Wraps a CKShare so it can be used with SwiftUI's `.sheet(item:)`.
struct ShareBox: Identifiable {
    let id = UUID()
    let share: CKShare
}

enum CloudKitManagerError: LocalizedError {
    case shareSaveFailed
    case notInCircle

    var errorDescription: String? {
        switch self {
        case .shareSaveFailed: return "Couldn't create the circle's share. Please try again."
        case .notInCircle: return "You're not part of a circle yet."
        }
    }
}
