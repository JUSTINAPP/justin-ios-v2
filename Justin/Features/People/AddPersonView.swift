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
    /// True when editing a person who has a real Justin account (auth_id present).
    /// Their phone is their identity — show read-only. All override fields stay editable.
    @State private var isVerifiedPerson = false

    struct DraftOccasion: Identifiable {
        let id = UUID()
        var label: String
        var date: Date
    }

    private var isEditing: Bool { personId != nil }

    /// Phone is required when saving a person to the People list.
    /// The phone is the convergence anchor — without it, gifts sent to this
    /// placeholder are orphaned when the person later signs up with Justin.
    /// Exception: verified people in edit mode already have a locked phone.
    private var hasValidPhone: Bool {
        if isVerifiedPerson && isEditing { return true }   // read-only, already on file
        return phone.filter(\.isNumber).count >= 7         // 7+ digits covers all real numbers
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && !isSaving && hasValidPhone
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
            Task {
                guard let rawData = try? await item?.loadTransferable(type: Data.self),
                      let uiImage = UIImage(data: rawData),
                      let compressed = compressedAvatarData(from: uiImage) else { return }
                debugLog("[AddPerson] avatar: \(rawData.count / 1024) KB raw → \(compressed.count / 1024) KB compressed")
                avatarImageData = compressed
            }
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
                            name: name.isEmpty ? "New" : name,
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
            if isVerifiedPerson && isEditing {
                // Verified person's phone is their account identity — show read-only.
                HStack {
                    Text(formattedPhone.isEmpty ? phone : formattedPhone)
                        .foregroundStyle(.primary)
                    Spacer()
                    Text("account identity")
                        .font(.system(.caption))
                        .foregroundStyle(.secondary)
                }
            } else {
                PhoneNumberField(normalised: $phone)
                    .listRowInsets(EdgeInsets())
            }
        } header: {
            HStack(spacing: 6) {
                Text("Phone number")
                // Show a gentle "Required" badge until a valid number is entered.
                if !isVerifiedPerson && !hasValidPhone {
                    Text("Required")
                        .font(.system(.caption2, weight: .semibold))
                        .foregroundStyle(Color.brandRose)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.brandRose.opacity(0.12))
                        .clipShape(Capsule())
                }
            }
        } footer: {
            if isVerifiedPerson && isEditing {
                Text("This is their Justin account number and can't be changed here.")
            } else {
                Text("A phone number lets your gifts reach them when they join Justin. Only you can see it.")
            }
        }
    }

    /// Formats the raw stored phone number for display (e.g. "61409774429" → "+61 409 774 429").
    private var formattedPhone: String {
        guard !phone.isEmpty else { return "" }
        let digits = phone.filter(\.isNumber)
        if digits.count == 11, digits.hasPrefix("61") {
            let sub = digits.dropFirst(2)
            return "+61 \(sub.prefix(3)) \(sub.dropFirst(3).prefix(3)) \(sub.dropFirst(6))"
        }
        return phone.hasPrefix("+") ? phone : "+\(digits)"
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
                let authId: UUID?
                enum CodingKeys: String, CodingKey {
                    case displayName = "display_name"
                    case phone
                    case authId = "auth_id"
                }
            }
            let rows: [PersonRow] = try await supabase
                .from("people")
                .select("display_name, phone, auth_id")
                .eq("id", value: pid.uuidString)
                .limit(1)
                .execute()
                .value
            if let p = rows.first {
                // Only set name from display_name as initial fallback; override row takes priority below.
                name = p.displayName ?? ""
                phone = p.phone ?? ""
                // Verified people have a real account — their phone is identity-locked.
                isVerifiedPerson = p.authId != nil
                debugLog("[Edit] person \(pid): isVerified=\(isVerifiedPerson) phone=\(phone.isEmpty ? "nil" : "set")")
            }
        } catch {
            debugLog("[AddPerson] load people row skipped: \(error)")
        }

        do {
            struct OverrideRow: Decodable {
                let customLabel: String?
                let relationship: String?
                let notes: String?
                let avatarStoragePath: String?
                enum CodingKeys: String, CodingKey {
                    case customLabel  = "custom_label"
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
                // Prefer the giver's private label ("Bill") over the person's own name ("William")
                if let label = o.customLabel, !label.isEmpty {
                    name = label
                }
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
            debugLog("[AddPerson] load overrides skipped: \(error)")
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
            debugLog("[AddPerson] load occasions skipped: \(error)")
        }
    }

    // MARK: - Save

    private func save() async {
        debugLog("======= [AddPerson] SAVE BEGIN isEditing=\(isEditing) personId=\(String(describing: personId)) =======")
        // PhotosPicker loads data asynchronously; ensure it's ready before we enter create/update.
        if let item = avatarPickerItem, avatarImageData == nil {
            avatarImageData = try? await item.loadTransferable(type: Data.self)
        }
        if isEditing { await update() } else { await create() }
        debugLog("======= [AddPerson] SAVE END =======")
    }

    private func create() async {
        debugLog("======= [AddPerson] CREATE BEGIN =======")

        // Log auth state first — nil here is the most common silent failure.
        if let p = auth.currentPerson {
            debugLog("======= [AddPerson] owner id: \(p.id) phone: \(p.phone ?? "nil") =======")
        } else {
            debugLog("======= [AddPerson] owner id: NIL — auth.currentPerson is nil! =======")
        }

        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        // Normalise to E.164 before any Supabase call.
        // PhoneNumberField already outputs "+61...", but normalise defensively.
        let rawPhone    = phone.isEmpty ? nil : phone
        let cleanPhone: String? = rawPhone.map { normaliseToE164($0) }
        if let r = rawPhone, let c = cleanPhone, r != c {
            debugLog("======= [AddPerson] phone normalised: '\(r)' → '\(c)' =======")
        }
        debugLog("======= [AddPerson] data: name='\(trimmedName)' phone=\(cleanPhone ?? "nil") occasions=\(occasions.count) =======")

        guard !trimmedName.isEmpty else {
            debugLog("======= [AddPerson] ABORT: name is empty =======")
            saveError = "Name is required."
            showSaveError = true
            return
        }
        guard let owner = auth.currentPerson else {
            debugLog("======= [AddPerson] ABORT: auth.currentPerson is NIL — cannot save =======")
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
            debugLog("======= [AddPerson] step 1: people row ownerId=\(owner.id) =======")
            var resolvedId: UUID

            if let ph = cleanPhone {
                // Delegate to a SECURITY DEFINER RPC that sees all people rows (bypasses RLS).
                // Client-side lookup fails for phones belonging to OTHER users because RLS
                // hides their rows → client thinks no one exists → INSERT → 23505.
                // The RPC returns the existing person's id (if phone is already registered)
                // or creates a new placeholder and returns its id.
                struct FindOrCreateParams: Encodable {
                    let pPhone: String
                    let pDisplayName: String
                    enum CodingKeys: String, CodingKey {
                        case pPhone       = "p_phone"
                        case pDisplayName = "p_display_name"
                    }
                }
                debugLog("======= [AddPerson] step 1: calling find_or_create_person_by_phone phone=\(ph) =======")
                let personId: UUID = try await supabase
                    .rpc("find_or_create_person_by_phone", params: FindOrCreateParams(
                        pPhone: ph,
                        pDisplayName: trimmedName
                    ))
                    .execute()
                    .value
                resolvedId = personId
                debugLog("[AddPerson] find_or_create returned id=\(personId) (existing or new)")
            } else {
                let newId = UUID()
                debugLog("======= [AddPerson] step 1: inserting new person (no phone) id=\(newId) =======")
                try await supabase
                    .from("people")
                    .insert(PendingPersonInsert(id: newId, displayName: trimmedName, phone: nil))
                    .execute()
                resolvedId = newId
                debugLog("======= [AddPerson] created new person (no phone) id=\(newId) =======")
            }
            debugLog("======= [AddPerson] step 1 OK resolvedId=\(resolvedId) =======")

            // ── Auth state at write time ─────────────────────────────────────
            // Log before any write so we can see whether auth.uid() will be null
            // server-side (which causes 403 on storage and 42501 on RLS writes).
            let _authSession = supabase.auth.currentSession
            debugLog("[AuthDebug create] ── session at write time ──────────────────")
            debugLog("[AuthDebug create] currentSession: \(_authSession != nil ? "EXISTS" : "NIL ← auth.uid() will be NULL server-side")")
            if let s = _authSession {
                debugLog("[AuthDebug create] session.user.id:   \(s.user.id)")
                debugLog("[AuthDebug create] accessToken prefix: \(s.accessToken.prefix(24))…")
                debugLog("[AuthDebug create] isExpired:          \(s.isExpired)")
                debugLog("[AuthDebug create] expiresAt (unix):   \(s.expiresAt)  now: \(Date().timeIntervalSince1970)")
            }
            debugLog("[AuthDebug create] currentUser?.id:    \(supabase.auth.currentUser?.id.uuidString ?? "NIL")")
            debugLog("[AuthDebug create] auth.currentPerson: \(auth.currentPerson?.id.uuidString ?? "NIL")")
            debugLog("[AuthDebug create] AuthService.state:  \(auth.state)")
            debugLog("[AuthDebug create] ─────────────────────────────────────────────")
            // ────────────────────────────────────────────────────────────────────

            // Avatar upload (non-fatal)
            var avatarPath: String? = nil
            if let data = avatarImageData {
                let path = "avatars/\(owner.id)/\(resolvedId).jpg"
                debugLog("======= [AddPerson] avatar: uploading to \(path) =======")
                do {
                    try await supabase.storage
                        .from("photos")
                        .upload(path, data: data,
                                options: FileOptions(contentType: "image/jpeg", upsert: true))
                    avatarPath = path
                    debugLog("======= [AddPerson] avatar OK =======")
                } catch {
                    debugLog("======= [AddPerson] avatar upload skipped: \(error) =======")
                }
            }

            // Step 2 — occasions
            debugLog("======= [AddPerson] step 2: occasions count=\(occasions.count) personId=\(resolvedId) =======")
            if !occasions.isEmpty {
                let rows = occasions.map {
                    OccasionShape(ownerId: owner.id, personId: resolvedId,
                                  label: $0.label, dateString: Self.isoDateFmt.string(from: $0.date))
                }
                try await supabase.from("occasions").insert(rows).execute()
            }
            debugLog("======= [AddPerson] step 2 OK =======")

            // Step 3 — person_overrides (stores the giver's private label and details)
            debugLog("======= [AddPerson] step 3: person_overrides ownerId=\(owner.id) personId=\(resolvedId) displayName='\(trimmedName)' =======")
            try await supabase
                .from("person_overrides")
                .upsert(
                    PersonOverrideShape(
                        ownerId: owner.id, personId: resolvedId,
                        customLabel: trimmedName,           // giver's private label (e.g. "Bill")
                        relationship: relationship.isEmpty ? nil : relationship,
                        notes: notes.isEmpty ? nil : notes,
                        avatarStoragePath: avatarPath
                    ),
                    onConflict: "owner_id,person_id"
                )
                .execute()
            debugLog("[AddPerson] override upsert OK")
            debugLog("======= [AddPerson] step 3 OK =======")

            debugLog("======= [AddPerson] ALL SAVED =======")
            onSaved?(PeopleEntry(id: resolvedId, name: trimmedName))
            isPresented = false

        } catch {
            // Log every possible detail so nothing is hidden.
            debugLog("======= [AddPerson] SAVE ERROR: \(error) =======")
            debugLog("======= [AddPerson] String(describing:): \(String(describing: error)) =======")
            debugLog("======= [AddPerson] error type: \(type(of: error)) =======")
            let mirror = Mirror(reflecting: error)
            for child in mirror.children {
                debugLog("======= [AddPerson] error.\(child.label ?? "_"): \(child.value) =======")
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
        guard let pid = personId else {
            debugLog("[Edit] ABORT: personId is nil")
            return
        }
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else {
            debugLog("[Edit] ABORT: name is empty")
            return
        }
        guard let owner = auth.currentPerson else {
            debugLog("[Edit] ABORT: auth.currentPerson is nil — not signed in")
            return
        }

        debugLog("[Edit] update() — pid=\(pid) isVerified=\(isVerifiedPerson) customLabel='\(trimmedName)' relationship='\(relationship)' notes='\(notes.isEmpty ? "(empty)" : notes)'")

        isSaving = true
        saveError = nil
        defer { isSaving = false }

        do {
            // Edit writes ONLY to person_overrides (my private label + notes + avatar).
            // people.display_name is the person's own identity — we must not touch it.
            debugLog("[Edit] saving custom_label='\(trimmedName)' to person_overrides for person \(pid)")

            // Preserve existing avatar path unless a new photo was picked.
            var avatarPath: String? = existingAvatarStoragePath
            if let data = avatarImageData {
                let path = "avatars/\(owner.id)/\(pid).jpg"
                try? await supabase.storage
                    .from("photos")
                    .upload(path, data: data, options: FileOptions(contentType: "image/jpeg", upsert: true))
                avatarPath = path
            }

            // Upsert my private override row — custom_label stores MY name for this person.
            try await supabase
                .from("person_overrides")
                .upsert(
                    PersonOverrideShape(
                        ownerId: owner.id, personId: pid,
                        customLabel: trimmedName,
                        relationship: relationship.isEmpty ? nil : relationship,
                        notes: notes.isEmpty ? nil : notes,
                        avatarStoragePath: avatarPath
                    ),
                    onConflict: "owner_id,person_id"
                )
                .execute()
            debugLog("[Edit] person_overrides upsert OK")

            // Delete-then-reinsert keeps occasions clean with no stale or duplicate rows.
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

            debugLog("[AddPerson] saved and dismissing")
            onSaved?(PeopleEntry(id: pid, name: trimmedName))
            isPresented = false

        } catch {
            let msg = fmtError(error)
            debugLog("[NameEdit] UPDATE FAILED: \(msg)")
            if let pgErr = error as? PostgrestError {
                debugLog("[NameEdit] PostgrestError code=\(pgErr.code ?? "nil") message=\(pgErr.message) detail=\(pgErr.detail ?? "nil") hint=\(pgErr.hint ?? "nil")")
            }
            saveError = msg
            showSaveError = true
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
        /// The giver's private label for this person (e.g. "Bill" even if people.display_name is "William").
        /// Stored in person_overrides.custom_label, never in people.display_name.
        let customLabel: String?
        let relationship: String?
        let notes: String?
        let avatarStoragePath: String?
        enum CodingKeys: String, CodingKey {
            case ownerId      = "owner_id"
            case personId     = "person_id"
            case customLabel  = "custom_label"
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

// MARK: - Phone normalisation (module-level so it's available in AddPersonView and AuthService)

/// Converts any common phone format to canonical E.164 ("+" + digits, no spaces).
/// "61409774429" → "+61409774429"
/// "+61 409 774 429" → "+61409774429"
/// "+61409774429" → "+61409774429"  (unchanged)
/// "" → ""
func normaliseToE164(_ raw: String) -> String {
    guard !raw.isEmpty else { return raw }
    let digits = raw.filter(\.isNumber)
    guard !digits.isEmpty else { return raw }
    return "+" + digits
}

#Preview {
    AddPersonView(isPresented: .constant(true))
        .environmentObject(AuthService())
}
