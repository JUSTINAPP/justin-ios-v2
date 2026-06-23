import SwiftUI
import Supabase

struct BlockedPeopleView: View {

    @State private var blocked: [BlockedEntry] = []
    @State private var isLoading = false
    @State private var toUnblock: BlockedEntry?
    @State private var showUnblockConfirm = false

    // MARK: - Body

    var body: some View {
        List {
            if isLoading {
                Section {
                    ProgressView().frame(maxWidth: .infinity).padding(.vertical, 24)
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            } else if blocked.isEmpty {
                Section {
                    Text("You haven't blocked anyone.")
                        .font(.system(.body))
                        .foregroundStyle(Color.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            } else {
                Section("Blocked") {
                    ForEach(blocked) { entry in
                        HStack(spacing: 14) {
                            CachedAvatarView(storagePath: nil, name: entry.displayName, size: 40)
                            Text(entry.displayName)
                                .font(.system(.body).weight(.medium))
                            Spacer()
                            Button {
                                toUnblock = entry
                                showUnblockConfirm = true
                            } label: {
                                Text("Unblock")
                                    .font(.system(.subheadline, weight: .medium))
                                    .foregroundStyle(Color.brandPurple)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .navigationTitle("Blocked people")
        .navigationBarTitleDisplayMode(.inline)
        .scrollClearance()
        .task { await load() }
        .alert(
            "Unblock \(toUnblock?.displayName ?? "")?",
            isPresented: $showUnblockConfirm,
            presenting: toUnblock
        ) { entry in
            Button("Unblock") { Task { await unblock(entry) } }
            Button("Cancel", role: .cancel) {}
        } message: { entry in
            Text("\(entry.displayName) will be able to send to you again.")
        }
    }

    // MARK: - Data

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let rows: [BlockedEntry] = try await supabase
                .from("blocks")
                .select("blocked_id, people!blocked_id(display_name)")
                .order("created_at", ascending: false)
                .execute()
                .value
            blocked = rows
            debugLog("[Blocked] loaded \(rows.count) blocked people")
        } catch {
            debugLog("[Blocked] load failed: \(error)")
        }
    }

    private func unblock(_ entry: BlockedEntry) async {
        debugLog("[Block] unblocking: \(entry.displayName) (\(entry.id))")
        do {
            try await supabase
                .rpc("unblock_person", params: BlockParams(pBlockedId: entry.id))
                .execute()
            blocked.removeAll { $0.id == entry.id }
            debugLog("[Block] unblocked: \(entry.id)")
        } catch {
            debugLog("[Block] unblock failed: \(error)")
        }
    }

    // MARK: - Types

    struct BlockedEntry: Identifiable, Decodable {
        let id: UUID           // blocked_id
        let people: PersonInfo?

        var displayName: String { people?.displayName ?? "Unknown" }

        struct PersonInfo: Decodable {
            let displayName: String?
            enum CodingKeys: String, CodingKey { case displayName = "display_name" }
        }

        enum CodingKeys: String, CodingKey {
            case id     = "blocked_id"
            case people
        }
    }

    private struct BlockParams: Encodable {
        let pBlockedId: UUID
        enum CodingKeys: String, CodingKey { case pBlockedId = "p_blocked_id" }
    }
}

#Preview {
    NavigationStack { BlockedPeopleView() }
}
