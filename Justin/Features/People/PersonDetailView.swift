import SwiftUI
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
    @State private var avatarURL: URL?

    @State private var isLoading = false
    @State private var showEditPerson = false
    @State private var showDeleteConfirmation = false
    @State private var isDeleting = false

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
        .task { await loadPerson() }
    }

    // MARK: - Header (avatar + relationship tagline)

    private var headerSection: some View {
        Section {
            HStack {
                Spacer()
                VStack(spacing: 8) {
                    PersonAvatarView(name: name, size: 80, remoteAvatarURL: avatarURL)
                    if !relationship.isEmpty {
                        Text(relationship)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
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
            NavigationLink(destination: GiftDetailView(giftId: person.givingGiftId, recipientName: name)) {
                Label("Your gift to them", systemImage: "arrow.up.circle")
                    .foregroundColor(.brandRose)
            }
        }
    }

    // MARK: - Load

    private func loadPerson() async {
        guard let ownerId = auth.currentPerson?.id else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            struct PersonRow: Decodable { let phone: String? }
            let rows: [PersonRow] = try await supabase
                .from("people")
                .select("phone")
                .eq("id", value: person.id.uuidString)
                .limit(1)
                .execute()
                .value
            phone = rows.first?.phone ?? ""
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
                if let path = o.avatarStoragePath {
                    avatarURL = try? await supabase.storage
                        .from("photos")
                        .createSignedURL(path: path, expiresIn: 3600)
                }
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
    }

    // MARK: - Delete

    private func deletePerson() async {
        guard let ownerId = auth.currentPerson?.id else { return }
        isDeleting = true
        // No defer reset — we pop immediately on success; reset only on failure.

        do {
            try await supabase
                .from("occasions")
                .delete()
                .eq("owner_id", value: ownerId.uuidString)
                .eq("person_id", value: person.id.uuidString)
                .execute()

            try await supabase
                .from("person_overrides")
                .delete()
                .eq("owner_id", value: ownerId.uuidString)
                .eq("person_id", value: person.id.uuidString)
                .execute()

            // Only delete the people row for standalone contacts (no gift relationships).
            // People tied to gifts are left in the people table; their override/occasions are removed above.
            if !person.isGiving && !person.isReceiving {
                try await supabase
                    .from("people")
                    .delete()
                    .eq("id", value: person.id.uuidString)
                    .execute()
            }

            print("[Person] deleted \(name)")
            dismiss()

        } catch {
            print("[PersonDetail] delete failed: \(error)")
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
