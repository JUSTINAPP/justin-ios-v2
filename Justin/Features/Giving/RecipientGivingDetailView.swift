import SwiftUI
import Supabase

/// Detail view for one recipient's giving history.
/// Shows ALL messages sent to this person across ALL their gifts — each
/// message retains its own share link because each gift has its own token.
struct RecipientGivingDetailView: View {
    let recipient: GivingViewModel.RecipientRow
    var onRefresh: () -> Void = {}

    typealias Item = GivingViewModel.RecipientRow.MessageItem

    @EnvironmentObject var auth: AuthService
    @State private var showRecord   = false
    @State private var shareItem:   Item? = nil
    @State private var playingItem: Item? = nil
    @State private var authorAvatarURL: URL?

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.cream.ignoresSafeArea()

            List {
                headerSection
                messagesSection
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .scrollClearance()
            .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 80) }

            // FAB — add another message to this person
            Button { showRecord = true } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                        .font(.system(.body, weight: .bold))
                    Text("Add a message")
                        .font(.system(.body, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(Color.brandPurple)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(color: Color.brandPurple.opacity(0.35), radius: 8, x: 0, y: 4)
            }
            .padding(.bottom, 20)
        }
        .navigationTitle("For \(recipient.recipientName)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.cream, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .fullScreenCover(isPresented: $showRecord) {
            RecordFlowView(
                prefillRecipientName: recipient.recipientName,
                prefillRecipientId: recipient.id
            )
        }
        .onChange(of: showRecord) { _, isShowing in
            if !isShowing { onRefresh() }
        }
        // Share sheet — unique per message since each has its own gift token
        .sheet(item: $shareItem) { item in
            NavigationStack {
                GiftShareView(
                    recipientName: recipient.recipientName,
                    shareToken: item.shareToken,
                    onDone: { shareItem = nil }
                )
            }
            .environmentObject(auth)
        }
        // Player
        .fullScreenCover(item: $playingItem) { item in
            KenBurnsPlayerView(
                voicePath: item.message.voiceUrl,
                photoPaths: item.message.photoUrls,
                fromName: auth.currentPerson?.displayName ?? "Me",
                caption: item.message.caption,
                avatarURL: authorAvatarURL
            )
        }
        .task {
            if let path = auth.currentPerson?.avatarUrl {
                authorAvatarURL = try? await supabase.storage
                    .from("photos")
                    .createSignedURL(path: path, expiresIn: 3600)
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        Section {
            HStack(spacing: 16) {
                CachedAvatarView(
                    storagePath: recipient.avatarStoragePath,
                    name: recipient.recipientName,
                    size: 64
                )
                VStack(alignment: .leading, spacing: 4) {
                    Text("For \(recipient.recipientName)")
                        .font(.system(.title2).weight(.semibold))
                        .foregroundColor(.ink)
                    Text("\(recipient.messageCount) message\(recipient.messageCount == 1 ? "" : "s")")
                        .font(.system(.subheadline))
                        .foregroundColor(Color.ink.opacity(0.5))
                }
                Spacer()
            }
            .padding(.vertical, 8)
        }
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .listSectionSeparator(.hidden)
    }

    // MARK: - Messages

    @ViewBuilder
    private var messagesSection: some View {
        if recipient.items.isEmpty {
            Section {
                Text("No messages yet. Tap \"Add a message\" below to record the first one.")
                    .font(.system(.body).weight(.medium))
                    .foregroundColor(Color.ink.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listSectionSeparator(.hidden)
        } else {
            Section {
                ForEach(recipient.items) { item in
                    messageRow(item)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 5, leading: 20, bottom: 5, trailing: 20))
                }
            }
            .listSectionSeparator(.hidden)
        }
    }

    // MARK: - Message row

    private func messageRow(_ item: Item) -> some View {
        let msg = item.message
        return HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(msg.opened ? Color.brandPurple.opacity(0.25) : Color(.systemFill))
                .frame(width: 10, height: 10)
                .padding(.top, 5)

            VStack(alignment: .leading, spacing: 6) {
                // Release heading + opened badge
                HStack(alignment: .top) {
                    Text(releaseHeading(msg))
                        .font(.system(.body).weight(.medium))
                        .foregroundColor(.ink)
                    Spacer()
                    if msg.opened {
                        Label("Opened", systemImage: "checkmark")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Color.ink.opacity(0.35))
                    }
                }

                Text(releaseDetail(msg))
                    .font(.system(.caption))
                    .foregroundColor(Color.ink.opacity(0.45))

                // Action buttons
                HStack(spacing: 14) {
                    if msg.voiceUrl != nil {
                        Button {
                            playingItem = item
                        } label: {
                            Label("Play", systemImage: "play.circle.fill")
                                .font(.system(.caption, weight: .medium))
                                .foregroundStyle(Color.brandPurple)
                        }
                        .buttonStyle(.plain)
                    }

                    // Each message has its own share link because it's its own gift
                    Button {
                        shareItem = item
                    } label: {
                        Label("Share link", systemImage: "square.and.arrow.up")
                            .font(.system(.caption, weight: .medium))
                            .foregroundStyle(Color.brandRose)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 2)

                if let date = msg.createdAt {
                    Text("Sent " + DateFormatter.localizedString(from: date, dateStyle: .medium, timeStyle: .none))
                        .font(.system(.caption2))
                        .foregroundColor(Color.ink.opacity(0.3))
                }
            }
        }
        .padding(14)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
    }

    // MARK: - Display helpers

    private func releaseHeading(_ msg: Message) -> String {
        switch msg.releaseType {
        case .now:    return "Right now"
        case .always: return "Always available"
        case .date:
            guard let d = msg.releaseDate else { return "On a date" }
            return DateFormatter.localizedString(from: d, dateStyle: .medium, timeStyle: .none)
        case .feeling:
            if let f = msg.releaseFeeling, !f.isEmpty { return "When \(f)" }
            return "When the moment is right"
        }
    }

    private func releaseDetail(_ msg: Message) -> String {
        switch msg.releaseType {
        case .now:     return "Opens right away"
        case .always:  return "Always in their collection"
        case .date:    return msg.hiddenUntilRelease ? "Hidden until the day" : "Visible, sealed"
        case .feeling: return "Recipient chooses when to open"
        }
    }
}

#Preview {
    NavigationStack {
        RecipientGivingDetailView(
            recipient: GivingViewModel.RecipientRow(
                id: UUID(),
                recipientName: "Em",
                avatarStoragePath: nil,
                items: []
            )
        )
    }
    .environmentObject(AuthService())
}
