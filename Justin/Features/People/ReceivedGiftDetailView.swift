import SwiftUI

struct ReceivedGiftDetailView: View {
    let fromName: String

    private struct ReceivedMessage: Identifiable {
        let id = UUID()
        let title: String
        let duration: String
        let isOpened: Bool
    }

    private let messages: [ReceivedMessage] = [
        ReceivedMessage(title: "For your birthday",    duration: "0:48", isOpened: true),
        ReceivedMessage(title: "Just because",         duration: "1:12", isOpened: false),
        ReceivedMessage(title: "When you can't sleep", duration: "0:55", isOpened: false),
    ]

    @State private var selectedMessage: ReceivedMessage?

    var body: some View {
        List {
            Section {
                HStack(spacing: 16) {
                    InitialsAvatar(name: fromName, size: 56)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("From \(fromName)")
                            .font(.system(.title3).weight(.semibold))
                        Text("\(messages.count) messages")
                            .font(.system(.subheadline))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(.vertical, 6)
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            Section {
                ForEach(messages) { message in
                    Button {
                        if !message.isOpened { selectedMessage = message }
                    } label: {
                        HStack(spacing: 14) {
                            Circle()
                                .fill(message.isOpened ? Color.brandPurple.opacity(0.3) : Color.brandPurple)
                                .frame(width: 8, height: 8)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(message.title)
                                    .font(.system(.body).weight(.medium))
                                    .foregroundColor(message.isOpened ? .secondary : .primary)
                                Text(message.duration)
                                    .font(.system(.caption))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            if message.isOpened {
                                Text("Opened")
                                    .font(.system(.caption))
                                    .foregroundColor(.secondary)
                            } else {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.brandPurple)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .navigationTitle("From \(fromName)")
        .navigationBarTitleDisplayMode(.inline)
        .scrollClearance()
        .fullScreenCover(item: $selectedMessage) { _ in
            KenBurnsPlayerView()
                .overlay(alignment: .topLeading) {
                    Button { selectedMessage = nil } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(11)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                    .padding(.top, 56)
                    .padding(.leading, 20)
                }
        }
    }
}

#Preview {
    NavigationStack { ReceivedGiftDetailView(fromName: "Mum") }
}
