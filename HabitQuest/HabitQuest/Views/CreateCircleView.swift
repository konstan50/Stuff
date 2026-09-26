import SwiftUI

struct CreateCircleView: View {
    @EnvironmentObject private var cloudKit: CloudKitManager
    @Environment(\.dismiss) private var dismiss

    @State private var circleName = ""
    @State private var displayName = ""
    @State private var colorHex = HabitPalette.colors[0]
    @State private var isCreating = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Circle") {
                    TextField("Circle name (e.g. \"Smith Family\")", text: $circleName)
                }
                Section("You") {
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
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red).font(.caption)
                }
            }
            .navigationTitle("New Circle")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isCreating ? "Creating…" : "Create") { create() }
                        .disabled(
                            circleName.trimmingCharacters(in: .whitespaces).isEmpty
                                || displayName.trimmingCharacters(in: .whitespaces).isEmpty
                                || isCreating
                        )
                }
            }
        }
    }

    private func create() {
        isCreating = true
        errorMessage = nil
        Task {
            do {
                try await cloudKit.createCircle(name: circleName, myDisplayName: displayName, myColorHex: colorHex)
                dismiss()
            } catch {
                errorMessage = "Couldn't create circle: \(error.localizedDescription)"
            }
            isCreating = false
        }
    }
}
