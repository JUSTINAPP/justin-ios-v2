import SwiftUI
import PhotosUI
import Supabase

struct PersonDetailView: View {
    let person: PeopleEntry
    private var name: String { person.name }

    @EnvironmentObject var auth: AuthService
    @Environment(\.dismiss) private var dismiss  // pops this view in the NavigationStack

    struct LoadedOccasion: Identifiable {
        let id: UUID
        var label: String
        var date: Date
    }

    @State private var phone = ""
    @State private var relationship = ""
    @State private var notes = ""
    @State private var occasions: [LoadedOccasion] = []
    @State private var avatarStoragePath: String? = nil
    @State private var isLoading = false
    @State private var showEditPerson = false
    @State private var showDeleteConfirmation = false
    @State private var isDeleting = false
    @State private var showRecord = false
    @State private var avatarPickerItem: PhotosPickerItem?
    @State private var isUploadingAvatar = false
    @State private var isBlocked = false
    @State private var showBlockConfirm = false
    /// True when this person has a real Justin account (auth_id is non-null).
    /// Block is only meaningful for real users who can send messages.
    @State private var personHasAccount = false

    private static let dayMonthFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "d MMM"; return f
    }()

    private static let isoDateFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    var body: some View {
        Group {
            if isLoading || isDeleting {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    headerSection
                    sendMessageSection
                    if isBlocked { blockedSection }
                    if !phone.isEmpty { contactSection }
                    if !occasions.isEmpty { datesSection }
                    if !notes.isEmpty { notesSection }
                    giftsSection
                }
                .scrollClearance()
            }
        }
        .navigationTitle(name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button { showEditPerson = true } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    // Block/Unblock only shown for real app users (auth_id present).
                    // Placeholder recipients can't send messages so blocking is N/A.
                    if personHasAccount {
                        Divider()
                        if isBlocked {
                            Button {
                                Task { await unblockPerson() }
                            } label: {
                                Label("Unblock \(name)", systemImage: "person.badge.plus")
                            }
                        } else {
                            Button(role: .destructive) {
                                showBlockConfirm = true
                            } label: {
                                Label("Block \(name)", systemImage: "hand.raised")
                            }
                        }
                    }
                    Divider()
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label("Remove \(name)", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .disabled(isDeleting)
            }
        }
        .sheet(isPresented: $showEditPerson) {
            AddPersonView(isPresented: $showEditPerson, personId: person.id)
        }
        .onChange(of: showEditPerson) { _, isShowing in
            if !isShowing { Task { await loadPerson() } }
        }
        .alert("Remove \(name)?", isPresented: $showDeleteConfirmation) {
            Button("Remove", role: .destructive) { Task { await deletePerson() } }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This removes them and their saved dates.")
        }
        .alert("Block \(name)?", isPresented: $showBlockConfirm) {
            Button("Block", role: .destructive) { Task { await blockPerson() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("They won't be able to send you anything on Justin, and they won't be told.")
        }
        .task { await loadPerson() }
        .onChange(of: avatarPickerItem) { _, item in
            guard let item else { return }
            Task { await uploadAvatar(item: item) }
        }
        .fullScreenCover(isPresented: $showRecord) {
            RecordFlowView(prefillRecipientName: name, prefillRecipientId: person.id)
        }
    }

    // MARK: - Send message button

    private var sendMessageSection: some View {
        Section {
            Button { showRecord = true } label: {
                HStack {
                    Spacer()
                    Label("Send them a message", systemImage: "mic.circle.fill")
                        .font(.system(.body).weight(.semibold))
                        .foregroundStyle(.white)
                    Spacer()
                }
                .padding(.vertical, 14)
                .background(Color.brandPurple)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 4, leading: 20, bottom: 4, trailing: 20))
        }
        .listSectionSeparator(.hidden)
    }

    // MARK: - Blocked section (UI 3 + 4)

    private var blockedSection: some View {
        Section {
            HStack(spacing: 12) {
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 15))
                    .foregroundStyle(Color.ink.opacity(0.55))
                VStack(alignment: .leading, spacing: 2) {
                    Text("You've blocked \(name)")
                        .font(.system(.subheadline, weight: .medium))
                        .foregroundStyle(Color.ink)
                    Text("They can't send you anything new.")
                        .font(.system(.caption))
                        .foregroundStyle(Color.secondary)
                }
                Spacer()
                Button {
                    Task { await unblockPerson() }
                } label: {
                    Text("Unblock")
                        .font(.system(.subheadline, weight: .medium))
                        .foregroundStyle(Color.brandPurple)
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 4)
        }
        .listRowBackground(Color.ink.opacity(0.04))
        .listRowSeparator(.hidden)
        .listSectionSeparator(.hidden)
    }

    // MARK: - Header (avatar + relationship tagline)

    private var headerSection: some View {
        Section {
            HStack {
                Spacer()
                VStack(spacing: 8) {
                    PhotosPicker(selection: $avatarPickerItem, matching: .images) {
                        ZStack(alignment: .bottomTrailing) {
                            CachedAvatarView(storagePath: avatarStoragePath, name: name, size: 80)
                                .overlay {
                                    if isUploadingAvatar {
                                        Circle()
                                            .fill(.black.opacity(0.35))
                                        ProgressView().tint(.white)
                                    }
                                }

                            // Camera badge — makes it clear the avatar is tappable
                            Image(systemName: "camera.fill")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(5)
                                .background(Color.brandPurple)
                                .clipShape(Circle())
                                .offset(x: 4, y: 4)
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(isUploadingAvatar)

                    if !relationship.isEmpty {
                        Text(relationship)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    if isBlocked {
                        Label("Blocked", systemImage: "hand.raised.fill")
                            .font(.system(.caption, weight: .semibold))
                            .foregroundStyle(Color.ink.opacity(0.7))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .background(Color.ink.opacity(0.09))
                            .clipShape(Capsule())
                    }
                }
                Spacer()
            }
            .padding(.vertical, 8)
        }
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    private var contactSection: some View {
        Section("Contact") {
            Label(phone, systemImage: "phone")
                .foregroundStyle(.secondary)
        }
    }

    private var datesSection: some View {
        Section("Important dates") {
            ForEach(occasions) { occ in
                HStack {
                    Text(occ.label)
                    Spacer()
                    Text(Self.dayMonthFmt.string(from: occ.date))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var notesSection: some View {
        Section("Notes") {
            Text(notes)
                .foregroundStyle(.secondary)
        }
    }

    private var giftsSection: some View {
        Section("Gifts") {
            NavigationLink(destination: ReceivedGiftDetailView(giftId: person.receivingGiftId, fromName: name)) {
                Label("Their gift to you", systemImage: "arrow.down.circle")
                    .foregroundColor(.brandPurple)
            }
            NavigationLink(destination: GiftDetailView(giftId: person.givingGiftId, recipientName: name, recipientPersonId: person.id)) {
                Label("Your gift to them", systemImage: "arrow.up.circle")
                    .foregroundColor(.brandRose)
            }
        }
    }

    // MARK: - Avatar upload

    private func uploadAvatar(item: PhotosPickerItem) async {
        guard let ownerId = auth.currentPerson?.id else {
            print("[Avatar] guard failed — no ownerId")
            return
        }
        guard let rawData = try? await item.loadTransferable(type: Data.self),
              let originalImage = UIImage(data: rawData),
              let data = compressedAvatarData(from: originalImage) else {
            print("[Avatar] guard failed — could not load/compress image")
            return
        }
        print("[Avatar] image: \(rawData.count / 1024) KB raw → \(data.count / 1024) KB compressed")

        isUploadingAvatar = true
        defer { isUploadingAvatar = false }

        print("[Avatar] WRITE — before: avatarStoragePath = \(avatarStoragePath ?? "nil")")

        let uploadId = UUID().uuidString
        let path = "avatars/\(ownerId)/\(person.id)/\(uploadId).jpg"
        print("[Avatar] uploading to path: \(path)  size=\(data.count) bytes")

        do {
            try await supabase.storage
                .from("photos")
                .upload(path, data: data,
                        options: FileOptions(contentType: "image/jpeg", upsert: false))
            print("[Avatar] upload succeeded")

            // Upsert only avatar_storage_path — leaves relationship/notes untouched.
            struct AvatarPathUpsert: Encodable {
                let ownerId: UUID
                let personId: UUID
                let avatarStoragePath: String
                enum CodingKeys: String, CodingKey {
                    case ownerId           = "owner_id"
                    case personId          = "person_id"
                    case avatarStoragePath = "avatar_storage_path"
                }
            }
            let upsertPayload = AvatarPathUpsert(ownerId: ownerId, personId: person.id, avatarStoragePath: path)
            print("[Avatar] WRITE → person_overrides.avatar_storage_path = \(path)")
            try await supabase
                .from("person_overrides")
                .upsert(upsertPayload, onConflict: "owner_id,person_id")
                .execute()
            print("[Avatar] person_overrides upsert succeeded (onConflict owner_id,person_id)")

            // Cache the uploaded image immediately so CachedAvatarView shows it
            // the moment avatarStoragePath switches to the new path — no second fetch needed.
            if let uiImage = UIImage(data: data) {
                AvatarCache.shared.store(uiImage, for: path)
                print("[Avatar] image cached for path \(path)")
            }
            avatarStoragePath = path
            print("[Avatar] WRITE — after: avatarStoragePath = \(path)")

        } catch {
            print("[Avatar] FAILED — error: \(error)")
            if let pgErr = error as? PostgrestError {
                print("[Avatar] PostgrestError code=\(pgErr.code ?? "nil") message=\(pgErr.message)")
            }
        }
    }

    // MARK: - Load

    private func loadPerson() async {
        guard let ownerId = auth.currentPerson?.id else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            struct PersonRow: Decodable {
                let phone: String?
                let authId: UUID?
                enum CodingKeys: String, CodingKey {
                    case phone
                    case authId = "auth_id"
                }
            }
            let rows: [PersonRow] = try await supabase
                .from("people")
                .select("phone, auth_id")
                .eq("id", value: person.id.uuidString)
                .limit(1)
                .execute()
                .value
            phone = rows.first?.phone ?? ""
            // Block is only meaningful for people with real accounts (auth_id present).
            // Placeholder recipients (auth_id null) can't send messages, so blocking is irrelevant.
            personHasAccount = rows.first?.authId != nil
        } catch {
            print("[PersonDetail] phone load skipped: \(error)")
        }

        do {
            struct OverrideRow: Decodable {
                let relationship: String?
                let notes: String?
                let avatarStoragePath: String?
                enum CodingKeys: String, CodingKey {
                    case relationship, notes
                    case avatarStoragePath = "avatar_storage_path"
                }
            }
            let overrides: [OverrideRow] = try await supabase
                .from("person_overrides")
                .select()
                .eq("owner_id", value: ownerId.uuidString)
                .eq("person_id", value: person.id.uuidString)
                .limit(1)
                .execute()
                .value
            if let o = overrides.first {
                relationship = o.relationship ?? ""
                notes = o.notes ?? ""
                avatarStoragePath = o.avatarStoragePath
                print("[Avatar] READ ← person_overrides.avatar_storage_path = \(o.avatarStoragePath ?? "nil")")
            } else {
                print("[Avatar] READ — no person_overrides row found for this person")
            }
        } catch {
            print("[PersonDetail] overrides load skipped: \(error)")
        }

        do {
            struct OccasionRow: Decodable {
                let id: UUID
                let label: String
                let date: String
            }
            let rows: [OccasionRow] = try await supabase
                .from("occasions")
                .select()
                .eq("owner_id", value: ownerId.uuidString)
                .eq("person_id", value: person.id.uuidString)
                .execute()
                .value
            occasions = rows.compactMap { row in
                guard let date = Self.isoDateFmt.date(from: row.date) else { return nil }
                return LoadedOccasion(id: row.id, label: row.label, date: date)
            }
        } catch {
            print("[PersonDetail] occasions load skipped: \(error)")
        }

        // Check block status — RLS ensures we only see our own blocks
        do {
            struct BlockedRow: Decodable {
                let blockedId: UUID
                enum CodingKeys: String, CodingKey { case blockedId = "blocked_id" }
            }
            let rows: [BlockedRow] = try await supabase
                .from("blocks")
                .select("blocked_id")
                .eq("blocked_id", value: person.id.uuidString)
                .limit(1)
                .execute()
                .value
            isBlocked = !rows.isEmpty
        } catch {
            print("[Block] status check skipped: \(error)")
        }
    }

    // MARK: - Block / Unblock

    private struct BlockParams: Encodable {
        let pBlockedId: UUID
        enum CodingKeys: String, CodingKey { case pBlockedId = "p_blocked_id" }
    }

    private func blockPerson() async {
        print("[Block] blocking: \(name) (\(person.id))")
        do {
            try await supabase
                .rpc("block_person", params: BlockParams(pBlockedId: person.id))
                .execute()
            isBlocked = true
            print("[Block] blocked: \(person.id)")
        } catch {
            print("[Block] block failed: \(error)")
        }
    }

    private func unblockPerson() async {
        print("[Block] unblocking: \(name) (\(person.id))")
        do {
            try await supabase
                .rpc("unblock_person", params: BlockParams(pBlockedId: person.id))
                .execute()
            isBlocked = false
            print("[Block] unblocked: \(person.id)")
        } catch {
            print("[Block] unblock failed: \(error)")
        }
    }

    // MARK: - Delete

    private func deletePerson() async {
        guard let ownerId = auth.currentPerson?.id else { return }
        isDeleting = true
        // No defer reset — we pop immediately on success; reset only on failure.

        // ── BUG 2 DIAGNOSIS ────────────────────────────────────────────────────
        print("[Delete] TARGET: people.id=\(person.id) name='\(name)'")
        print("[Delete] isGiving=\(person.isGiving) isReceiving=\(person.isReceiving)")
        print("[Delete] NOTE: people row will \(person.isGiving || person.isReceiving ? "NOT be deleted (has gift FK references)" : "be deleted")")
        print("[Delete] auth.uid=\(supabase.auth.currentUser?.id.uuidString ?? "NIL") session=\(supabase.auth.currentSession != nil ? "EXISTS" : "NIL")")
        // ──────────────────────────────────────────────────────────────────────

        do {
            try await supabase
                .from("occasions")
                .delete()
                .eq("owner_id", value: ownerId.uuidString)
                .eq("person_id", value: person.id.uuidString)
                .execute()
            print("[Delete] occasions deleted OK")

            try await supabase
                .from("person_overrides")
                .delete()
                .eq("owner_id", value: ownerId.uuidString)
                .eq("person_id", value: person.id.uuidString)
                .execute()
            print("[Delete] person_overrides deleted OK")

            // Only delete the people row for standalone contacts (no gift relationships).
            // People tied to gifts are left in the people table; their override/occasions are removed above.
            if !person.isGiving && !person.isReceiving {
                try await supabase
                    .from("people")
                    .delete()
                    .eq("id", value: person.id.uuidString)
                    .execute()
                print("[Delete] people row deleted OK")

                // Verify the row is actually gone
                struct IdRow: Decodable { let id: UUID }
                let check: [IdRow] = (try? await supabase.from("people").select("id").eq("id", value: person.id.uuidString).limit(1).execute().value) ?? []
                print("[Delete] DB verification: people row still exists=\(!check.isEmpty) ← should be false")
            } else {
                print("[Delete] people row SKIPPED (isGiving=\(person.isGiving) isReceiving=\(person.isReceiving)) — row kept for gift FK integrity")
            }

            print("[Delete] calling dismiss() — PeopleView list will NOT auto-refresh (needs onAppear to re-fire or explicit callback)")
            dismiss()

        } catch {
            print("[Delete] FAILED: \(error)")
            if let pgErr = error as? PostgrestError {
                print("[Delete] PostgrestError code=\(pgErr.code ?? "nil") message=\(pgErr.message) detail=\(pgErr.detail ?? "nil") hint=\(pgErr.hint ?? "nil")")
            }
            isDeleting = false
        }
    }
}

#Preview {
    NavigationStack {
        PersonDetailView(person: PeopleEntry(id: UUID(), name: "Em"))
    }
    .environmentObject(AuthService())
}
