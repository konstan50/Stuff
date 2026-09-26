import SwiftUI

struct CircleChatView: View {
    @EnvironmentObject private var cloudKit: CloudKitManager
    @State private var draft = ""
    @State private var isSending = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        if cloudKit.messages.isEmpty {
                            Text("No messages yet — send some encouragement!")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity)
                                .padding(.top, 40)
                        }
                        ForEach(cloudKit.messages) { message in
                            MessageBubble(message: message, isMine: message.authorID == cloudKit.myMemberID)
                                .id(message.id)
                        }
                    }
                    .padding()
                }
                .onChange(of: cloudKit.messages.count) { _, _ in
                    if let last = cloudKit.messages.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }

            Divider()

            HStack {
                TextField("Send encouragement…", text: $draft, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...4)
                Button {
                    send()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                }
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)
            }
            .padding()
        }
        .navigationTitle("Circle Chat")
        .task { await cloudKit.refreshCircle() }
        .refreshable { await cloudKit.refreshCircle() }
    }

    private func send() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        draft = ""
        isSending = true
        Task {
            try? await cloudKit.sendMessage(text: text)
            isSending = false
        }
    }
}

private struct MessageBubble: View {
    let message: CircleChatMessage
    let isMine: Bool

    var body: some View {
        VStack(alignment: isMine ? .trailing : .leading, spacing: 2) {
            Text(isMine ? "You" : message.authorName)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(message.text)
                .padding(10)
                .background(Color(hex: message.authorColorHex).opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .frame(maxWidth: .infinity, alignment: isMine ? .trailing : .leading)
    }
}
