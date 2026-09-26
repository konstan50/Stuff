import SwiftUI

/// Shown right after accepting a circle invite link, before the participant
/// can see or post anything — CloudKit knows their iCloud identity, but not
/// what name/color they want to show to the rest of the circle.
struct JoinCircleNameView: View {
    @EnvironmentObject private var cloudKit: CloudKitManager
    @State private var displayName = ""
    @State private var colorHex = HabitPalette.colors[0]
    @State private var isJoining = false

    var body: some View {
        NavigationStack {
            Form {
                Section("You've joined \(cloudKit.circleName ?? "a circle")!") {
                    TextField("Your display name", text: $displayName)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6)) {
                        ForEach(HabitPalette.colors, id: \.self) { hex in
                            Circle()
                                .fill(Color(hex: hex))
                                .frame(width: 28, height: 28)
                                .overlay {
                                    if colorHex == hex {
                                        Circle().stroke(Color.primary, lineWidth: 2).padding(-3)
                                    }
                                }
                                .onTapGesture { colorHex = hex }
                        }
                    }
                }
            }
            .navigationTitle("Join Circle")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(isJoining ? "Joining…" : "Done") {
                        isJoining = true
                        Task {
                            await cloudKit.finishJoining(displayName: displayName, colorHex: colorHex)
                            isJoining = false
                        }
                    }
                    .disabled(displayName.trimmingCharacters(in: .whitespaces).isEmpty || isJoining)
                }
            }
        }
        .interactiveDismissDisabled()
    }
}
