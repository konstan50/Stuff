import Foundation
import CloudKit

/// Drives the "Circle" feature: creating/joining a shared group via CKShare,
/// publishing your own habit progress to it, reading everyone else's, and a
/// simple append-only chat. Record types used (all in one custom zone,
/// "CircleZone"): CircleRoot, Member, SharedGoal, CircleMessage.
///
/// Sync is deliberately simple: every refresh re-queries all records of each
/// type in the zone and replaces the local cache. A friends-and-family circle
/// is small (tens of members/messages, not thousands), so this is far more
/// robust than tracking CloudKit change tokens, at negligible cost.
@MainActor
final class CloudKitManager: ObservableObject {
    static let shared = CloudKitManager()

    @Published private(set) var circleContext: CircleContext?
    @Published private(set) var myMemberID: String?
    @Published var members: [CircleMember] = []
    @Published var goals: [SharedGoalSummary] = []
    @Published var messages: [CircleChatMessage] = []
    @Published var pendingShareBox: ShareBox?
    @Published var lastSyncError: String?

    var hasCircle: Bool { circleContext != nil }
    var needsDisplayName: Bool { circleContext != nil && circleContext?.hasSetDisplayName == false }
    var circleName: String? { circleContext?.circleName }

    let container = CKContainer.default()

    private let memberRecordType = "Member"
    private let goalRecordType = "SharedGoal"
    private let messageRecordType = "CircleMessage"
    private let contextDefaultsKey = "circleContext.v1"
    private let subscriptionsFlagPrefix = "circleSubscriptionsConfigured."

    private var activeDatabase: CKDatabase {
        (circleContext?.isOwner ?? true) ? container.privateCloudDatabase : container.sharedCloudDatabase
    }

    private init() {
        loadContext()
    }

    // MARK: - Persistence of local membership info

    private func loadContext() {
        guard let data = UserDefaults.standard.data(forKey: contextDefaultsKey),
              let context = try? JSONDecoder().decode(CircleContext.self, from: data) else { return }
        circleContext = context
    }

    private func saveContext() {
        guard let context = circleContext,
              let data = try? JSONEncoder().encode(context) else { return }
        UserDefaults.standard.set(data, forKey: contextDefaultsKey)
    }

    // MARK: - Creating a circle (owner flow)

    func createCircle(name: String, myDisplayName: String, myColorHex: String) async throws {
        let zone = CKRecordZone(zoneName: "CircleZone")
        _ = try await container.privateCloudDatabase.save(zone)

        let rootRecordID = CKRecord.ID(recordName: "circleRoot", zoneID: zone.zoneID)
        let rootRecord = CKRecord(recordType: "CircleRoot", recordID: rootRecordID)
        rootRecord["name"] = name

        let share = CKShare(rootRecord: rootRecord)
        share[CKShare.SystemFieldKey.title] = "HabitQuest Circle: \(name)" as CKRecordValue
        share.publicPermission = .none

        let result = try await container.privateCloudDatabase.modifyRecords(saving: [rootRecord, share], deleting: [])
        guard case .success(let savedRecord) = result.saveResults[share.recordID],
              let savedShare = savedRecord as? CKShare else {
            throw CloudKitManagerError.shareSaveFailed
        }

        let userRecordID = try await container.userRecordID()

        circleContext = CircleContext(
            zoneOwnerName: zone.zoneID.ownerName,
            zoneName: zone.zoneID.zoneName,
            isOwner: true,
            circleName: name,
            myDisplayName: myDisplayName,
            myColorHex: myColorHex,
            hasSetDisplayName: true
        )
        myMemberID = userRecordID.recordName
        saveContext()

        try? await saveMyMemberRecord()
        await createSubscriptionsIfNeeded()
        await refreshCircle()

        pendingShareBox = ShareBox(share: savedShare)
    }

    /// Re-fetches the current share record so it can be presented again
    /// (e.g. to invite more people after the circle already exists).
    func currentShareForInviting() async -> CKShare? {
        guard let context = circleContext, context.isOwner else { return nil }
        let rootRecordID = CKRecord.ID(recordName: "circleRoot", zoneID: context.zoneID)
        guard let rootRecord = try? await container.privateCloudDatabase.record(for: rootRecordID),
              let shareRef = rootRecord.share,
              let share = try? await container.privateCloudDatabase.record(for: shareRef.recordID) as? CKShare else {
            return nil
        }
        return share
    }

    func presentInviteSheet() async {
        if let share = await currentShareForInviting() {
            pendingShareBox = ShareBox(share: share)
        }
    }

    // MARK: - Accepting a circle (participant flow, called from AppDelegate)

    func acceptShare(metadata: CKShare.Metadata) async {
        let shareContainer = CKContainer(identifier: metadata.containerIdentifier)
        let operation = CKAcceptSharesOperation(shareMetadatas: [metadata])

        let accepted: Bool = await withCheckedContinuation { continuation in
            operation.perShareResultBlock = { [weak self] _, result in
                if case .failure(let error) = result {
                    Task { @MainActor in self?.lastSyncError = error.localizedDescription }
                }
            }
            operation.acceptSharesResultBlock = { result in
                continuation.resume(returning: (try? result.get()) != nil)
            }
            shareContainer.add(operation)
        }
        guard accepted else { return }

        let zoneID = metadata.share.recordID.zoneID
        let name = (metadata.rootRecord?["name"] as? String)
            ?? (metadata.share[CKShare.SystemFieldKey.title] as? String)
            ?? "Circle"

        circleContext = CircleContext(
            zoneOwnerName: zoneID.ownerName,
            zoneName: zoneID.zoneName,
            isOwner: false,
            circleName: name,
            myDisplayName: "",
            myColorHex: HabitPalette.colors[0],
            hasSetDisplayName: false
        )
        saveContext()

        if let userRecordID = try? await shareContainer.userRecordID() {
            myMemberID = userRecordID.recordName
        }
    }

    func finishJoining(displayName: String, colorHex: String) async {
        guard var context = circleContext else { return }
        context.myDisplayName = displayName
        context.myColorHex = colorHex
        context.hasSetDisplayName = true
        circleContext = context
        saveContext()

        try? await saveMyMemberRecord()
        await createSubscriptionsIfNeeded()
        await refreshCircle()
    }

    func leaveCircle() {
        circleContext = nil
        myMemberID = nil
        members = []
        goals = []
        messages = []
        UserDefaults.standard.removeObject(forKey: contextDefaultsKey)
    }

    // MARK: - Reading and writing circle data

    func refreshCircle() async {
        guard let context = circleContext, context.hasSetDisplayName else { return }
        do {
            let memberRecords = try await fetchAllRecords(ofType: memberRecordType, in: activeDatabase, zoneID: context.zoneID)
            let goalRecords = try await fetchAllRecords(ofType: goalRecordType, in: activeDatabase, zoneID: context.zoneID)
            let messageRecords = try await fetchAllRecords(ofType: messageRecordType, in: activeDatabase, zoneID: context.zoneID)

            let myID = myMemberID

            let newMembers = memberRecords.compactMap { record -> CircleMember? in
                guard let id = record["memberID"] as? String,
                      let name = record["displayName"] as? String else { return nil }
                return CircleMember(
                    id: id,
                    displayName: name,
                    colorHex: record["colorHex"] as? String ?? "8E8E93",
                    isMe: id == myID
                )
            }

            let newGoals = goalRecords.compactMap { record -> SharedGoalSummary? in
                guard let memberID = record["memberID"] as? String,
                      let habitID = record["habitID"] as? String,
                      let habitName = record["habitName"] as? String else { return nil }
                return SharedGoalSummary(
                    id: "\(memberID)-\(habitID)",
                    memberID: memberID,
                    memberName: record["memberName"] as? String ?? "Someone",
                    memberColorHex: record["memberColorHex"] as? String ?? "8E8E93",
                    habitID: habitID,
                    habitName: habitName,
                    habitIcon: record["habitIcon"] as? String ?? "checkmark.circle.fill",
                    habitColorHex: record["habitColorHex"] as? String ?? "34C759",
                    weeklyTarget: record["weeklyTarget"] as? Int ?? 1,
                    thisWeekCount: record["thisWeekCount"] as? Int ?? 0,
                    currentStreak: record["currentStreak"] as? Int ?? 0,
                    bestStreak: record["bestStreak"] as? Int ?? 0,
                    updatedAt: record["updatedAt"] as? Date ?? .now
                )
            }

            let newMessages = messageRecords.compactMap { record -> CircleChatMessage? in
                guard let authorID = record["authorID"] as? String,
                      let text = record["text"] as? String else { return nil }
                return CircleChatMessage(
                    id: record.recordID.recordName,
                    authorID: authorID,
                    authorName: record["authorName"] as? String ?? "Someone",
                    authorColorHex: record["authorColorHex"] as? String ?? "8E8E93",
                    text: text,
                    sentAt: record["sentAt"] as? Date ?? .now
                )
            }.sorted { $0.sentAt < $1.sentAt }

            members = newMembers.sorted { $0.isMe && !$1.isMe }
            goals = newGoals
            messages = newMessages
            lastSyncError = nil
        } catch {
            lastSyncError = error.localizedDescription
        }
    }

    func publishMyGoal(habit: Habit) async {
        guard let context = circleContext, let memberID = myMemberID else { return }
        let summary = PointsEngine.summarize(habit: habit)
        let recordID = CKRecord.ID(recordName: "goal-\(memberID)-\(habit.id.uuidString)", zoneID: context.zoneID)
        do {
            try await upsertRecord(id: recordID, type: goalRecordType, in: activeDatabase) { record in
                record["memberID"] = memberID
                record["memberName"] = context.myDisplayName
                record["memberColorHex"] = context.myColorHex
                record["habitID"] = habit.id.uuidString
                record["habitName"] = habit.name
                record["habitIcon"] = habit.icon
                record["habitColorHex"] = habit.colorHex
                record["weeklyTarget"] = habit.weeklyTarget
                record["thisWeekCount"] = summary.thisWeekCount
                record["currentStreak"] = summary.currentStreak
                record["bestStreak"] = summary.bestStreak
                record["updatedAt"] = Date.now
            }
            await refreshCircle()
        } catch {
            lastSyncError = error.localizedDescription
        }
    }

    func removeMyGoal(habitID: UUID) async {
        guard let context = circleContext, let memberID = myMemberID else { return }
        let recordID = CKRecord.ID(recordName: "goal-\(memberID)-\(habitID.uuidString)", zoneID: context.zoneID)
        _ = try? await activeDatabase.deleteRecord(withID: recordID)
        await refreshCircle()
    }

    func sendMessage(text: String) async throws {
        guard let context = circleContext, let memberID = myMemberID else {
            throw CloudKitManagerError.notInCircle
        }
        let recordID = CKRecord.ID(recordName: UUID().uuidString, zoneID: context.zoneID)
        let record = CKRecord(recordType: messageRecordType, recordID: recordID)
        record["authorID"] = memberID
        record["authorName"] = context.myDisplayName
        record["authorColorHex"] = context.myColorHex
        record["text"] = text
        record["sentAt"] = Date.now
        _ = try await activeDatabase.save(record)
        await refreshCircle()
    }

    func sendCheer(to member: CircleMember) async throws {
        try await sendMessage(text: "👏 Sending encouragement to \(member.displayName) — keep it up!")
    }

    private func saveMyMemberRecord() async throws {
        guard let context = circleContext, let memberID = myMemberID else { return }
        let recordID = CKRecord.ID(recordName: "member-\(memberID)", zoneID: context.zoneID)
        try await upsertRecord(id: recordID, type: memberRecordType, in: activeDatabase) { record in
            record["memberID"] = memberID
            record["displayName"] = context.myDisplayName
            record["colorHex"] = context.myColorHex
            record["joinedAt"] = Date.now
        }
    }

    // MARK: - Push notification handling

    /// Called from the AppDelegate when a silent CloudKit push arrives. Diffs
    /// against the previous cache so we can surface a local notification for
    /// what actually changed (new messages from others, newly-met goals).
    func handleRemoteNotification() async {
        let previousMessageIDs = Set(messages.map(\.id))
        let previousGoalsMet = Dictionary(uniqueKeysWithValues: goals.map { ($0.id, $0.thisWeekGoalMet) })

        await refreshCircle()

        let newMessages = messages.filter { !previousMessageIDs.contains($0.id) && $0.authorID != myMemberID }
        for message in newMessages {
            NotificationManager.shared.presentImmediateNotification(title: message.authorName, body: message.text)
        }

        for goal in goals where goal.memberID != myMemberID {
            let wasMet = previousGoalsMet[goal.id] ?? false
            if goal.thisWeekGoalMet && !wasMet {
                NotificationManager.shared.presentImmediateNotification(
                    title: "Goal hit! 🎉",
                    body: "\(goal.memberName) just reached their \(goal.habitName) goal for the week."
                )
            }
        }
    }

    private func createSubscriptionsIfNeeded() async {
        guard let context = circleContext else { return }
        let flagKey = subscriptionsFlagPrefix + context.zoneName + context.zoneOwnerName
        guard !UserDefaults.standard.bool(forKey: flagKey) else { return }

        let messageSubscription = CKQuerySubscription(
            recordType: messageRecordType,
            predicate: NSPredicate(value: true),
            subscriptionID: "circle-message-changes",
            options: [.firesOnRecordCreation]
        )
        let goalSubscription = CKQuerySubscription(
            recordType: goalRecordType,
            predicate: NSPredicate(value: true),
            subscriptionID: "circle-goal-changes",
            options: [.firesOnRecordCreation, .firesOnRecordUpdate]
        )
        for subscription in [messageSubscription, goalSubscription] {
            let info = CKSubscription.NotificationInfo()
            info.shouldSendContentAvailable = true
            subscription.notificationInfo = info
        }

        // Best-effort: this silently no-ops without the Push Notifications
        // capability / a paid Apple Developer account. Manual refresh still
        // works regardless.
        _ = try? await activeDatabase.save(messageSubscription)
        _ = try? await activeDatabase.save(goalSubscription)
        UserDefaults.standard.set(true, forKey: flagKey)
    }

    // MARK: - Low-level helpers

    private func upsertRecord(
        id: CKRecord.ID,
        type: String,
        in database: CKDatabase,
        configure: (CKRecord) -> Void
    ) async throws {
        let record: CKRecord
        if let existing = try? await database.record(for: id) {
            record = existing
        } else {
            record = CKRecord(recordType: type, recordID: id)
        }
        configure(record)
        _ = try await database.save(record)
    }

    private func fetchAllRecords(ofType type: String, in database: CKDatabase, zoneID: CKRecordZone.ID) async throws -> [CKRecord] {
        var results: [CKRecord] = []
        let query = CKQuery(recordType: type, predicate: NSPredicate(value: true))
        var (matchResults, cursor) = try await database.records(matching: query, inZoneWith: zoneID)
        results.append(contentsOf: matchResults.compactMap { try? $0.1.get() })
        while let currentCursor = cursor {
            (matchResults, cursor) = try await database.records(continuingMatchFrom: currentCursor)
            results.append(contentsOf: matchResults.compactMap { try? $0.1.get() })
        }
        return results
    }
}
