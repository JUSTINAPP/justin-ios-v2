import SwiftUI
import PhotosUI
import Supabase

struct AddPersonView: View {
    /// Bound to the sheet's isPresented so setting false reliably dismisses it.
    @Binding var isPresented: Bool
    @EnvironmentObject var auth: AuthService

    /// Set to update an existing person. Nil = create mode.
    var personId: UUID? = nil
    var onSaved: ((PeopleEntry) -> Void)?

    @State private var name = ""
    @State private var phone = ""
    @State private var relationship = ""
    @State private var notes = ""
    @State private var occasions: [DraftOccasion] = []
    @State private var showAddDate = false
    @State private var newLabel = ""
    @State private var newDate = Date()
    // Edit-in-place state for existing occasions
    @State private var editingOccasionId: UUID? = nil
    @State private var editLabel = ""
    @State private var editDate = Date()

    @FocusState private var nameFocused: Bool
    @FocusState private var labelFocused: Bool

    @State private var avatarPickerItem: PhotosPickerItem?
    @State private var avatarImageData: Data?
    @State private var existingAvatarURL: URL?
    @State private var existingAvatarStoragePath: String?

    @State private var isLoadingExisting = false
    @State private var isSaving = false
    @State private var saveError: String?
    @State private var showSaveError = false

    struct DraftOccasion: Identifiable {
        let id = UUID()
        var label: String
        var date: Date
    }

    private var isEditing: Bool { personId != nil }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && !isSaving
    }

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
        NavigationStack {
            Group {
                if isLoadingExisting {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    Form {
                        avatarSection
                        nameSection
                        relationshipSection
                        phoneSection
                        datesSection
                        notesSection
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit" : "Add someone")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("Save") { Task { await save() } }
                            .disabled(!canSave)
                    }
                }
            }
        }
        .alert("Couldn't save", isPresented: $showSaveError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(saveError ?? "Unknown error")
        }
        .task {
            if let pid = personId {
                await loadExisting(pid)
            } else {
                nameFocused = true
            }
        }
        .onChange(of: avatarPickerItem) { _, item in
            Task { avatarImageData = try? await item?.loadTransferable(type: Data.self) }
        }
    }

    // MARK: - Sections

    private var avatarSection: some View {
        Section {
            HStack {
                Spacer()
                PhotosPicker(selection: $avatarPickerItem, matching: .images) {
                    VStack(spacing: 10) {
                        PersonAvatarView(
                            name: name.isEmpty ? "?" : name,
                            size: 80,
                            localPhotoData: avatarImageData,
                            remoteAvatarURL: avatarImageData == nil ? existingAvatarURL : nil
                        )
                        Text(avatarImageData != nil || existingAvatarURL != nil ? "Change photo" : "Add photo")
                            .font(.subheadline)
                            .foregroundStyle(Color.brandPurple)
                    }
                }
                .buttonStyle(.plain)
                Spacer()
            }
            .padding(.vertical, 8)
        }
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    private var nameSection: some View {
        Section("Name") {
            TextField("Their name", text: $name)
                .focused($nameFocused)
        }
    }

    private var relationshipSection: some View {
        Section("Relationship") {
            TextField("e.g. Daughter, Partner, Best friend", text: $relationship)
        }
    }

    private var phoneSection: some View {
        Section {
            PhoneNumberField(normalised: $phone)
                .listRowInsets(EdgeInsets())
        } header: {
            Text("Phone number")
        } footer: {
            Text("Helps gifts reach them later. Only you can see this.")
        }
    }

    private var datesSection: some View {
        Section {
            ForEach(occasions) { occ in
                if editingOccasionId == occ.id {
                    editOccasionRow(occ)
                } else {
                    HStack {
                        Text(occ.label)
                        Spacer()
                        Text(Self.dayMonthFmt.string(from: occ.date))
                            .foregroundStyle(.secondary)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        showAddDate = false
                        editingOccasionId = occ.id
                        editLabel = occ.label
                        editDate = occ.date
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            occasions.removeAll { $0.id == occ.id }
                        } label: { Label("Remove", systemImage: "trash") }
                    }
                }
            }

            if showAddDate {
                addDateRow
            } else {
                Button {
                    showAddDate = true
                    editingOccasionId = nil
                    labelFocused = true
                } label: {
                    Label("Add a date", systemImage: "plus")
                }
                .foregroundStyle(Color.brandPurple)
            }
        } header: {
            Text("Important dates")
        } footer: {
            Text("Justin can gently remind you to leave a message before these dates.")
        }
    }

    @ViewBuilder
    private var addDateRow: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Label (e.g. Birthday)", text: $newLabel)
                .focused($labelFocused)
            // .graphical shows an inline calendar — no popup, nothing to "dismiss"
            DatePicker("Date", selection: $newDate, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .labelsHidden()
            HStack {
                Button("Add") {
                    let t = newLabel.trimmingCharacters(in: .whitespaces)
                    guard !t.isEmpty else { return }
                    occasions.append(DraftOccasion(label: t, date: newDate))
                    newLabel = ""; newDate = Date(); showAddDate = false
                }
                .foregroundStyle(Color.brandPurple)
                .disabled(newLabel.trimmingCharacters(in: .whitespaces).isEmpty)
                Spacer()
                Button("Cancel") { newLabel = ""; showAddDate = false }
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func editOccasionRow(_ occ: DraftOccasion) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Label", text: $editLabel)
            DatePicker("Date", selection: $editDate, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .labelsHidden()
            HStack {
                Button("Done") {
                    let t = editLabel.trimmingCharacters(in: .whitespaces)
                    if !t.isEmpty, let idx = occasions.firstIndex(where: { $0.id == occ.id }) {
                        occasions[idx].label = t
                        occasions[idx].date = editDate
                    }
                    editingOccasionId = nil
                }
                .foregroundStyle(Color.brandPurple)
                .disabled(editLabel.trimmingCharacters(in: .whitespaces).isEmpty)
                Spacer()
                Button("Cancel") { editingOccasionId = nil }
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var notesSection: some View {
        Section {
            ZStack(alignment: .topLeading) {
                TextEditor(text: $notes)
                    .frame(minHeight: 80)
                if notes.isEmpty {
                    Text("Private notes...")
                        .foregroundStyle(Color(.placeholderText))
                        .padding(.top, 8).padding(.leading, 5)
                        .allowsHitTesting(false)
                }
            }
        } header: {
            Text("Notes")
        } footer: {
            Text("Only you can see these.")
        }
    }

    // MARK: - Load existing (edit mode)

    private func loadExisting(_ pid: UUID) async {
        guard let ownerId = auth.currentPerson?.id else { return }
        isLoadingExisting = true
        defer { isLoadingExisting = false }

        do {
            struct PersonRow: Decodable {
                let displayName: String?
                let phone: String?
                enum CodingKeys: String, CodingKey {
                    case displayName = "display_name"
                    case phone
                }
            }
            let rows: [PersonRow] = try await supabase
                .from("people")
                .select("display_name, phone")
                .eq("id", value: pid.uuidString)
                .limit(1)
                .execute()
                .value
            if let p = rows.first {
                name = p.displayName ?? ""
                phone = p.phone ?? ""
            }
        } catch {
            print("[AddPerson] load people row skipped: \(error)")
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
                .eq("person_id", value: pid.uuidString)
                .limit(1)
                .execute()
                .value
            if let o = overrides.first {
                relationship = o.relationship ?? ""
                notes = o.notes ?? ""
                existingAvatarStoragePath = o.avatarStoragePath
                if let path = o.avatarStoragePath {
                    existingAvatarURL = try? await supabase.storage
                        .from("photos")
                        .createSignedURL(path: path, expiresIn: 3600)
                }
            }
        } catch {
            print("[AddPerson] load overrides skipped: \(error)")
        }

        do {
            struct OccasionRow: Decodable {
                let label: String
                let date: String
            }
            let rows: [OccasionRow] = try await supabase
                .from("occasions")
                .select()
                .eq("owner_id", value: ownerId.uuidString)
                .eq("person_id", value: pid.uuidString)
                .execute()
                .value
            occasions = rows.compactMap { row in
                guard let date = Self.isoDateFmt.date(from: row.date) else { return nil }
                return DraftOccasion(label: row.label, date: date)
            }
        } catch {
            print("[AddPerson] load occasions skipped: \(error)")
        }
    }

    // MARK: - Save

    private func save() async {
        print("======= [AddPerson] SAVE BEGIN isEditing=\(isEditing) personId=\(String(describing: personId)) =======")
        if isEditing { await update() } else { await create() }
        print("======= [AddPerson] SAVE END =======")
    }

    private func create() async {
        print("======= [AddPerson] CREATE BEGIN =======")

        // Log auth state first — nil here is the most common silent failure.
        if let p = auth.currentPerson {
            print("======= [AddPerson] owner id: \(p.id) phone: \(p.phone ?? "nil") =======")
        } else {
            print("======= [AddPerson] owner id: NIL — auth.currentPerson is nil! =======")
        }

        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let cleanPhone: String? = phone.isEmpty ? nil : phone
        print("======= [AddPerson] data: name='\(trimmedName)' phone=\(cleanPhone ?? "nil") occasions=\(occasions.count) =======")

        guard !trimmedName.isEmpty else {
            print("======= [AddPerson] ABORT: name is empty =======")
            saveError = "Name is required."
            showSaveError = true
            return
        }
        guard let owner = auth.currentPerson else {
            print("======= [AddPerson] ABORT: auth.currentPerson is NIL — cannot save =======")
            saveError = "You're not signed in. Please restart the app and sign in again."
            showSaveError = true
            return
        }

        isSaving = true
        saveError = nil
        defer { isSaving = false }

        // All steps in one do/catch so nothing escapes unlogged.
        do {
            // Step 1 — find or create person row
            print("======= [AddPerson] step 1: people row ownerId=\(owner.id) =======")
            var resolvedId: UUID

            if let ph = cleanPhone {
                print("======= [AddPerson] step 1: phone=\(ph) — checking for existing =======")
                struct ExistingRow: Decodable { let id: UUID }
                let existing: [ExistingRow] = try await supabase
                    .from("people")
                    .select("id")
                    .eq("phone", value: ph)
                    .limit(1)
                    .execute()
                    .value

                if let found = existing.first {
                    resolvedId = found.id
                    print("======= [AddPerson] reused existing person id=\(found.id) =======")
                    struct NameUpdate: Encodable {
                        let displayName: String
                        enum CodingKeys: String, CodingKey { case displayName = "display_name" }
                    }
                    try await supabase
                        .from("people")
                        .update(NameUpdate(displayName: trimmedName))
                        .eq("id", value: found.id.uuidString)
                        .execute()
                    print("======= [AddPerson] step 1: name updated on existing person =======")
                } else {
                    let newId = UUID()
                    print("======= [AddPerson] step 1: inserting new person id=\(newId) =======")
                    try await supabase
                        .from("people")
                        .insert(PendingPersonInsert(id: newId, displayName: trimmedName, phone: ph))
                        .execute()
                    resolvedId = newId
                    print("======= [AddPerson] created new person id=\(newId) =======")
                }
            } else {
                let newId = UUID()
                print("======= [AddPerson] step 1: inserting new person (no phone) id=\(newId) =======")
                try await supabase
                    .from("people")
                    .insert(PendingPersonInsert(id: newId, displayName: trimmedName, phone: nil))
                    .execute()
                resolvedId = newId
                print("======= [AddPerson] created new person (no phone) id=\(newId) =======")
            }
            print("======= [AddPerson] step 1 OK resolvedId=\(resolvedId) =======")

            // Avatar upload (non-fatal)
            var avatarPath: String? = nil
            if let data = avatarImageData {
                let path = "avatars/\(owner.id)/\(resolvedId).jpg"
                print("======= [AddPerson] avatar: uploading to \(path) =======")
                do {
                    try await supabase.storage
                        .from("photos")
                        .upload(path, data: data, options: FileOptions(contentType: "image/jpeg"))
                    avatarPath = path
                    print("======= [AddPerson] avatar OK =======")
                } catch {
                    print("======= [AddPerson] avatar upload skipped: \(error) =======")
                }
            }

            // Step 2 — occasions
            print("======= [AddPerson] step 2: occasions count=\(occasions.count) personId=\(resolvedId) =======")
            if !occasions.isEmpty {
                let rows = occasions.map {
                    OccasionShape(ownerId: owner.id, personId: resolvedId,
                                  label: $0.label, dateString: Self.isoDateFmt.string(from: $0.date))
                }
                try await supabase.from("occasions").insert(rows).execute()
            }
            print("======= [AddPerson] step 2 OK =======")

            // Step 3 — person_overrides
            print("======= [AddPerson] step 3: person_overrides ownerId=\(owner.id) personId=\(resolvedId) =======")
            try await supabase
                .from("person_overrides")
                .upsert(PersonOverrideShape(
                    ownerId: owner.id, personId: resolvedId,
                    relationship: relationship.isEmpty ? nil : relationship,
                    notes: notes.isEmpty ? nil : notes,
                    avatarStoragePath: avatarPath
                ))
                .execute()
            print("======= [AddPerson] step 3 OK =======")

            print("======= [AddPerson] ALL SAVED =======")
            onSaved?(PeopleEntry(id: resolvedId, name: trimmedName))
            isPresented = false

        } catch {
            // Log every possible detail so nothing is hidden.
            print("======= [AddPerson] SAVE ERROR: \(error) =======")
            print("======= [AddPerson] String(describing:): \(String(describing: error)) =======")
            print("======= [AddPerson] error type: \(type(of: error)) =======")
            let mirror = Mirror(reflecting: error)
            for child in mirror.children {
                print("======= [AddPerson] error.\(child.label ?? "_"): \(child.value) =======")
            }
            let msg = fmtError(error)
            saveError = msg
            showSaveError = true
        }
    }

    /// Formats any error with full detail; extracts PostgrestError fields when available.
    private func fmtError(_ error: Error) -> String {
        let mirror = Mirror(reflecting: error)
        var parts: [String] = ["\(type(of: error))"]
        for child in mirror.children {
            if let label = child.label {
                parts.append("\(label): \(child.value)")
            }
        }
        let detail = parts.joined(separator: " | ")
        return detail.isEmpty ? "\(error)" : detail
    }

    private func update() async {
        guard let pid = personId else { return }
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty, let owner = auth.currentPerson else { return }

        isSaving = true
        saveError = nil
        defer { isSaving = false }

        do {
            struct PersonUpdate: Encodable {
                let displayName: String
                let phone: String?
                enum CodingKeys: String, CodingKey {
                    case displayName = "display_name"
                    case phone
                }
            }
            try await supabase
                .from("people")
                .update(PersonUpdate(displayName: trimmedName, phone: phone.isEmpty ? nil : phone))
                .eq("id", value: pid.uuidString)
                .execute()

            // Preserve existing avatar path unless a new photo was picked.
            var avatarPath: String? = existingAvatarStoragePath
            if let data = avatarImageData {
                let path = "avatars/\(owner.id)/\(pid).jpg"
                try? await supabase.storage
                    .from("photos")
                    .upload(path, data: data, options: FileOptions(contentType: "image/jpeg", upsert: true))
                avatarPath = path
            }

            try await supabase
                .from("person_overrides")
                .upsert(PersonOverrideShape(
                    ownerId: owner.id, personId: pid,
                    relationship: relationship.isEmpty ? nil : relationship,
                    notes: notes.isEmpty ? nil : notes,
                    avatarStoragePath: avatarPath
                ))
                .execute()

            try await supabase
                .from("occasions")
                .delete()
                .eq("owner_id", value: owner.id.uuidString)
                .eq("person_id", value: pid.uuidString)
                .execute()

            if !occasions.isEmpty {
                let rows = occasions.map {
                    OccasionShape(ownerId: owner.id, personId: pid,
                                  label: $0.label, dateString: Self.isoDateFmt.string(from: $0.date))
                }
                try await supabase.from("occasions").insert(rows).execute()
            }

            print("[AddPerson] saved and dismissing")
            onSaved?(PeopleEntry(id: pid, name: trimmedName))
            isPresented = false

        } catch {
            print("[AddPerson] update failed: \(error)")
            saveError = "Couldn't save. Please try again."
        }
    }

    // MARK: - Encodable shapes

    private struct PendingPersonInsert: Encodable {
        let id: UUID
        let displayName: String
        let phone: String?
        let isVerified: Bool = false
        enum CodingKeys: String, CodingKey {
            case id, phone
            case displayName = "display_name"
            case isVerified  = "is_verified"
        }
    }

    private struct PersonOverrideShape: Encodable {
        let ownerId: UUID
        let personId: UUID
        let relationship: String?
        let notes: String?
        let avatarStoragePath: String?
        enum CodingKeys: String, CodingKey {
            case ownerId = "owner_id"
            case personId = "person_id"
            case relationship, notes
            case avatarStoragePath = "avatar_storage_path"
        }
    }

    private struct OccasionShape: Encodable {
        let ownerId: UUID
        let personId: UUID
        let label: String
        let dateString: String
        let remindBeforeRecording: Bool = true
        enum CodingKeys: String, CodingKey {
            case ownerId = "owner_id"
            case personId = "person_id"
            case label
            case dateString = "date"
            case remindBeforeRecording = "remind_before_recording"
        }
    }
}

#Preview {
    AddPersonView(isPresented: .constant(true))
        .environmentObject(AuthService())
}
