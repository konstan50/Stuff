import SwiftUI

struct CircleView: View {
    @EnvironmentObject private var cloudKit: CloudKitManager
    @State private var showingCreateCircle = false

    var body: some View {
        NavigationStack {
            Group {
                if !cloudKit.hasCircle {
                    ContentUnavailableView(
                        "No Circle Yet",
                        systemImage: "person.3",
                        description: Text("Create a circle to invite friends and family, or open an invite link someone sent you.")
                    )
                    .safeAreaInset(edge: .bottom) {
                        Button {
                            showingCreateCircle = true
                        } label: {
                            Text("Create a Circle")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .padding()
                    }
                } else if cloudKit.needsDisplayName {
                    JoinCircleNameView()
                } else {
                    circleContent
                }
            }
            .navigationTitle("Circle")
        }
        .sheet(isPresented: $showingCreateCircle) {
            CreateCircleView()
        }
        .sheet(item: $cloudKit.pendingShareBox) { box in
            CloudSharingView(share: box.share, container: cloudKit.container)
        }
    }

    private var circleContent: some View {
        List {
            if let error = cloudKit.lastSyncError {
                Section {
                    Text(error).font(.caption).foregroundStyle(.red)
                }
            }

            Section("\(cloudKit.circleName ?? "Circle") Members") {
                if cloudKit.members.isEmpty {
                    Text("Syncing…").foregroundStyle(.secondary)
                } else {
                    ForEach(cloudKit.members) { member in
                        MemberProgressRow(member: member, goals: cloudKit.goals.filter { $0.memberID == member.id })
                    }
                }
            }

            Section {
                NavigationLink {
                    CircleChatView()
                } label: {
                    Label("Circle Chat", systemImage: "bubble.left.and.bubble.right.fill")
                }
            }

            Section {
                Button("Invite More People") {
                    Task { await cloudKit.presentInviteSheet() }
                }
                Button("Leave Circle", role: .destructive) {
                    cloudKit.leaveCircle()
                }
            }
        }
        .refreshable { await cloudKit.refreshCircle() }
        .task { await cloudKit.refreshCircle() }
    }
}

private struct MemberProgressRow: View {
    let member: CircleMember
    let goals: [SharedGoalSummary]
    @EnvironmentObject private var cloudKit: CloudKitManager
    @State private var isSendingCheer = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle().fill(Color(hex: member.colorHex)).frame(width: 10, height: 10)
                Text(member.displayName).font(.headline)
                if member.isMe {
                    Text("(you)").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if !member.isMe {
                    Button {
                        sendCheer()
                    } label: {
                        Label("Cheer", systemImage: "hands.clap.fill")
                    }
                    .font(.caption)
                    .buttonStyle(.bordered)
                    .disabled(isSendingCheer)
                }
            }

            if goals.isEmpty {
                Text(member.isMe ? "You haven't shared any goals yet." : "No shared goals yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(goals) { goal in
                    HStack {
                        Image(systemName: goal.habitIcon).foregroundStyle(Color(hex: goal.habitColorHex))
                        Text(goal.habitName).font(.subheadline)
                        Spacer()
                        Text("\(goal.thisWeekCount)/\(goal.weeklyTarget) · 🔥\(goal.currentStreak)w")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func sendCheer() {
        isSendingCheer = true
        Task {
            try? await cloudKit.sendCheer(to: member)
            isSendingCheer = false
        }
    }
}
