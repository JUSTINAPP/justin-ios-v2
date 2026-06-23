import SwiftUI
import Supabase

struct ReceivedGiftDetailView: View {
    let giftId: UUID?
    let fromName: String

    @State private var messages: [Message] = []
    @State private var isLoading = false
    @State private var playingMessage: Message?

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    headerSection
                    messagesSection
                }
                .listStyle(.plain)
                .scrollClearance()
            }
        }
        .navigationTitle("From \(fromName)")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(item: $playingMessage) { msg in
            KenBurnsPlayerView(
                voicePath: msg.voiceUrl,
                photoPaths: msg.photoUrls,
                fromName: fromName
            )
        }
        .task { await loadMessages() }
    }

    // MARK: - Header

    private var headerSection: some View {
        Section {
            HStack(spacing: 16) {
                InitialsAvatar(name: fromName, size: 56)
                VStack(alignment: .leading, spacing: 4) {
                    Text("From \(fromName)")
                        .font(.system(.title3).weight(.semibold))
                    Text("\(messages.count) message\(messages.count == 1 ? "" : "s")")
                        .font(.system(.subheadline))
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(.vertical, 6)
        }
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    // MARK: - Messages

    @ViewBuilder
    private var messagesSection: some View {
        if messages.isEmpty && !isLoading {
            Section {
                VStack(spacing: 10) {
                    Text("No messages yet.")
                        .font(.system(.body).weight(.medium))
                        .foregroundColor(.secondary)
                    if giftId == nil {
                        Text("\(fromName) hasn't left you a gift yet.")
                            .font(.system(.caption))
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        } else {
            Section {
                ForEach(messages) { message in
                    messageRow(message)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 5, leading: 20, bottom: 5, trailing: 20))
                }
            }
            .listSectionSeparator(.hidden)
        }
    }

    // MARK: - Message row

    private func messageRow(_ message: Message) -> some View {
        Button {
            guard message.voiceUrl != nil else { return }
            playingMessage = message
        } label: {
            HStack(spacing: 14) {
                Circle()
                    .fill(message.opened ? Color.brandPurple.opacity(0.3) : Color.brandPurple)
                    .frame(width: 8, height: 8)

                VStack(alignment: .leading, spacing: 3) {
                    Text(releaseLabel(message))
                        .font(.system(.body).weight(.medium))
                        .foregroundColor(message.opened ? .secondary : .primary)
                    Text(message.opened ? "Opened" : "Tap to listen")
                        .font(.system(.caption))
                        .foregroundColor(.secondary)
                }

                Spacer()

                if message.voiceUrl != nil {
                    Image(systemName: message.opened ? "checkmark.circle" : "play.fill")
                        .font(.system(size: 13))
                        .foregroundColor(.brandPurple)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .disabled(message.voiceUrl == nil)
    }

    private func releaseLabel(_ message: Message) -> String {
        switch message.releaseType {
        case .now:    return "A message for you"
        case .date:
            guard let date = message.releaseDate else { return "A message for you" }
            return "For " + DateFormatter.localizedString(from: date, dateStyle: .medium, timeStyle: .none)
        case .feeling:
            if let f = message.releaseFeeling, !f.isEmpty { return "Open when \(f)" }
            return "Open when you need it"
        case .always: return "Always here for you"
        }
    }

    // MARK: - Data

    private func loadMessages() async {
        guard let giftId else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let rows: [Message] = try await supabase
                .from("messages")
                .select()
                .eq("gift_id", value: giftId.uuidString)
                .order("created_at", ascending: true)
                .execute()
                .value
            messages = rows
            debugLog("[ReceivedGiftDetail] loaded \(rows.count) messages from \(fromName)")
        } catch {
            debugLog("[ReceivedGiftDetail] fetch failed: \(error)")
        }
    }
}

#Preview {
    NavigationStack { ReceivedGiftDetailView(giftId: nil, fromName: "Mum") }
}
