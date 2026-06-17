import SwiftUI
import Supabase

struct GiftDetailView: View {
    let giftId: UUID?        // nil from People tab (placeholder rows have no real DB id yet)
    let recipientName: String

    @State private var messages: [Message] = []
    @State private var isLoading = false
    @State private var showRecord = false
    @State private var messageToDelete: Message?
    @State private var showDeleteConfirm = false

    var body: some View {
        ZStack {
            Color.cream.ignoresSafeArea()

            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    headerSection
                    messagesSection
                    addAnotherSection
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .scrollClearance()
            }
        }
        .navigationTitle("For \(recipientName)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.cream, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .alert("Delete this message?", isPresented: $showDeleteConfirm, presenting: messageToDelete) { msg in
            Button("Delete", role: .destructive) {
                Task { await deleteMessage(msg) }
            }
            Button("Cancel", role: .cancel) {}
        } message: { msg in
            Text("\(releaseHeading(msg)) will be permanently removed from this gift.")
        }
        .fullScreenCover(isPresented: $showRecord) {
            RecordFlowView()
        }
        .task { await loadMessages() }
        .onChange(of: showRecord) { _, newValue in
            if !newValue { Task { await loadMessages() } }
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        Section {
            HStack(spacing: 16) {
                InitialsAvatar(name: recipientName, size: 64)
                VStack(alignment: .leading, spacing: 4) {
                    Text("For \(recipientName)")
                        .font(.system(.title2).weight(.semibold))
                        .foregroundColor(.ink)
                    Text("\(messages.count) message\(messages.count == 1 ? "" : "s")")
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

    @ViewBuilder
    private var messagesSection: some View {
        if messages.isEmpty && !isLoading {
            Section {
                VStack(spacing: 12) {
                    Text("No messages yet.")
                        .font(.system(.body).weight(.medium))
                        .foregroundColor(Color.ink.opacity(0.5))
                    Text("Tap \"Add another message\" below to record the first one.")
                        .font(.system(.caption))
                        .foregroundColor(Color.ink.opacity(0.35))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listSectionSeparator(.hidden)
        } else {
            Section {
                ForEach(messages) { message in
                    messageRow(message)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 5, leading: 20, bottom: 5, trailing: 20))
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            if !message.opened {
                                Button(role: .destructive) {
                                    messageToDelete = message
                                    showDeleteConfirm = true
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                Button {
                                    // TODO: open edit flow for this message
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(.brandPurple)
                            }
                        }
                }
            }
            .listSectionSeparator(.hidden)
        }
    }

    private var addAnotherSection: some View {
        Section {
            Button { showRecord = true } label: {
                HStack(spacing: 12) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.brandPurple)
                    Text("Add another message")
                        .font(.system(.body).weight(.medium))
                        .foregroundColor(.brandPurple)
                    Spacer()
                }
                .padding(16)
                .background(Color.brandPurple.opacity(0.07))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay {
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(Color.brandPurple.opacity(0.22), lineWidth: 1)
                }
            }
            .buttonStyle(.plain)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 10, leading: 20, bottom: 24, trailing: 20))
        }
        .listSectionSeparator(.hidden)
    }

    // MARK: - Message row

    private func messageRow(_ message: Message) -> some View {
        // TODO(storage): when voice_url is non-nil, wrap in a Button that opens KenBurnsPlayerView
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(message.opened ? Color.brandPurple.opacity(0.25) : Color(.systemFill))
                .frame(width: 10, height: 10)
                .padding(.top, 5)

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .top) {
                    Text(releaseHeading(message))
                        .font(.system(.body).weight(.medium))
                        .foregroundColor(.ink)
                    Spacer()
                    if message.opened {
                        Label("Opened", systemImage: "checkmark")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Color.ink.opacity(0.35))
                    }
                }

                Text(releaseDetail(message))
                    .font(.system(.caption))
                    .foregroundColor(Color.ink.opacity(0.45))

                HStack(spacing: 4) {
                    if message.opened {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.brandPurple)
                    }
                    Text(statusLabel(message))
                        .font(.system(.caption).weight(.medium))
                        .foregroundColor(message.opened ? .brandPurple : Color.ink.opacity(0.4))
                }
            }
        }
        .padding(14)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
    }

    // MARK: - Display helpers

    private func releaseHeading(_ message: Message) -> String {
        switch message.releaseType {
        case .now:
            return "Right now"
        case .date:
            guard let date = message.releaseDate else { return "On a date" }
            return DateFormatter.localizedString(from: date, dateStyle: .medium, timeStyle: .none)
        case .feeling:
            if let f = message.releaseFeeling, !f.isEmpty { return "When \(f)" }
            return "When the moment is right"
        case .always:
            return "Always available"
        }
    }

    private func releaseDetail(_ message: Message) -> String {
        switch message.releaseType {
        case .now:     return "Opens right away"
        case .date:    return message.hiddenUntilRelease ? "Hidden until the day" : "Visible, sealed"
        case .feeling: return "Recipient chooses when to open"
        case .always:  return "Always in their collection"
        }
    }

    private func statusLabel(_ message: Message) -> String {
        if message.opened {
            if let date = message.openedAt {
                let days = Calendar.current.dateComponents([.day], from: date, to: .now).day ?? 0
                return "Opened \(days) day\(days == 1 ? "" : "s") ago"
            }
            return "Opened"
        }
        switch message.releaseType {
        case .now:     return "Not opened yet"
        case .date:    return message.hiddenUntilRelease ? "Scheduled · hidden" : "Scheduled"
        case .feeling: return "Waiting for the right moment"
        case .always:  return "Not opened yet"
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
            print("[GiftDetail] loaded \(rows.count) messages for gift \(giftId)")
        } catch {
            print("[GiftDetail] fetch failed: \(error)")
        }
    }

    private func deleteMessage(_ message: Message) async {
        // Optimistically remove from local list first
        messages.removeAll { $0.id == message.id }
        guard giftId != nil else { return }
        do {
            try await supabase
                .from("messages")
                .delete()
                .eq("id", value: message.id.uuidString)
                .execute()
        } catch {
            print("[GiftDetail] delete failed: \(error)")
        }
    }
}

#Preview {
    NavigationStack {
        GiftDetailView(giftId: UUID(), recipientName: "Em")
    }
}
