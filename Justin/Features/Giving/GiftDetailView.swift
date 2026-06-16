import SwiftUI

struct GiftDetailView: View {
    let recipientName: String

    @State private var messages: [GiftMessage] = GiftDetailView.placeholderMessages
    @State private var showRecord = false
    @State private var messageToDelete: GiftMessage?
    @State private var showDeleteConfirm = false

    var body: some View {
        ZStack {
            Color.cream.ignoresSafeArea()

            List {
                // ── Header ───────────────────────────────
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

                // ── Messages ─────────────────────────────
                Section {
                    ForEach(messages) { message in
                        messageRow(message)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 5, leading: 20, bottom: 5, trailing: 20))
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                if !message.isOpened {
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

                // ── Add another ──────────────────────────
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
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .scrollClearance()
        }
        .navigationTitle("For \(recipientName)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.cream, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .alert("Delete this message?", isPresented: $showDeleteConfirm, presenting: messageToDelete) { msg in
            Button("Delete", role: .destructive) {
                messages.removeAll { $0.id == msg.id }
            }
            Button("Cancel", role: .cancel) {}
        } message: { msg in
            Text("\"\(msg.title)\" will be permanently removed from this gift.")
        }
        .fullScreenCover(isPresented: $showRecord) {
            RecordFlowView()
        }
    }

    // MARK: - Message row

    private func messageRow(_ message: GiftMessage) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(message.isOpened ? Color.brandPurple.opacity(0.25) : Color(.systemFill))
                .frame(width: 10, height: 10)
                .padding(.top, 5)

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .top) {
                    Text(message.title)
                        .font(.system(.body).weight(.medium))
                        .foregroundColor(.ink)
                    Spacer()
                    if message.isOpened {
                        Label("Received", systemImage: "lock.fill")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Color.ink.opacity(0.35))
                    }
                }

                Text(releaseLabel(for: message))
                    .font(.system(.caption))
                    .foregroundColor(Color.ink.opacity(0.45))

                HStack(spacing: 4) {
                    if message.isOpened {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.brandPurple)
                    }
                    Text(statusLabel(for: message))
                        .font(.system(.caption).weight(.medium))
                        .foregroundColor(message.isOpened ? .brandPurple : Color.ink.opacity(0.4))
                }
            }
        }
        .padding(14)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
    }

    // MARK: - Label helpers

    private func releaseLabel(for message: GiftMessage) -> String {
        switch message.releaseType {
        case .now:
            return "Opens right away"
        case .date:
            guard let date = message.releaseDate else { return "On a date" }
            let f = DateFormatter()
            f.dateFormat = "d MMM"
            let dateStr = f.string(from: date)
            return message.hiddenUntilRelease ? "Hidden until \(dateStr)" : "Opens \(dateStr)"
        case .feeling:
            guard let feeling = message.releaseFeeling, !feeling.isEmpty else {
                return "Opens when the moment is right"
            }
            return "Opens \(feeling)"
        case .always:
            return "Always available"
        }
    }

    private func statusLabel(for message: GiftMessage) -> String {
        if message.isOpened {
            if let days = message.openedDaysAgo {
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

    // MARK: - Placeholder data

    private static let placeholderMessages: [GiftMessage] = {
        let cal = Calendar.current
        let now = Date()

        var comps = DateComponents()
        comps.year = 2026
        comps.month = 10
        comps.day = 4
        let oct4 = cal.date(from: comps) ?? now

        return [
            // Opened — locked, cannot edit or delete
            GiftMessage(
                title: "For your birthday",
                releaseType: .date,
                releaseDate: cal.date(byAdding: .day, value: -2, to: now),
                isOpened: true,
                openedDaysAgo: 2
            ),
            // Not opened — editable
            GiftMessage(
                title: "Just because",
                releaseType: .always
            ),
            // Not opened — feeling-gated
            GiftMessage(
                title: "When you can't sleep",
                releaseType: .feeling,
                releaseFeeling: "when you can't sleep"
            ),
            // Not opened — hidden surprise date
            GiftMessage(
                title: "Keep this one close",
                releaseType: .date,
                releaseDate: oct4,
                hiddenUntilRelease: true
            ),
        ]
    }()
}

// MARK: - GiftMessage (placeholder model)

private struct GiftMessage: Identifiable {
    let id = UUID()
    let title: String
    let releaseType: ReleaseType
    let releaseDate: Date?
    let releaseFeeling: String?
    let hiddenUntilRelease: Bool
    let isOpened: Bool
    let openedDaysAgo: Int?

    init(
        title: String,
        releaseType: ReleaseType,
        releaseDate: Date? = nil,
        releaseFeeling: String? = nil,
        hiddenUntilRelease: Bool = false,
        isOpened: Bool = false,
        openedDaysAgo: Int? = nil
    ) {
        self.title = title
        self.releaseType = releaseType
        self.releaseDate = releaseDate
        self.releaseFeeling = releaseFeeling
        self.hiddenUntilRelease = hiddenUntilRelease
        self.isOpened = isOpened
        self.openedDaysAgo = openedDaysAgo
    }
}

#Preview {
    NavigationStack { GiftDetailView(recipientName: "Em") }
}
