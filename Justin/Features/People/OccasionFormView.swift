import SwiftUI
import Supabase

// MARK: - Shared model (used by PersonDetailView and OccasionFormView)

struct OccasionEntry: Identifiable {
    let id: UUID
    var label: String
    var date: Date
    var remind: Bool
    var remindDaysBefore: Int?
}

// MARK: - Form

struct OccasionFormView: View {
    var existing: OccasionEntry? = nil   // nil = creating new
    let personId: UUID
    let ownerId:  UUID
    var onSaved:   () -> Void = {}
    var onDeleted: () -> Void = {}

    @Environment(\.dismiss) private var dismiss

    // MARK: - Picker options

    enum OccasionType: String, CaseIterable, Identifiable {
        case birthday    = "Birthday"
        case anniversary = "Anniversary"
        case mothersDay  = "Mother's Day"
        case fathersDay  = "Father's Day"
        case custom      = "Custom"
        var id: Self { self }
    }

    private let reminderOptions: [(label: String, days: Int)] = [
        ("Same day",     0),
        ("1 day before", 1),
        ("3 days",       3),
        ("1 week",       7),
    ]

    // MARK: - State

    @State private var selectedType = OccasionType.birthday
    @State private var customLabel  = ""
    @State private var date         = Date()
    @State private var reminderDays: Int? = nil   // nil = no reminder

    @State private var isSaving   = false
    @State private var isDeleting = false
    @State private var saveError:    String? = nil
    @State private var showSaveError = false

    // MARK: - Derived

    private var resolvedLabel: String {
        selectedType == .custom
            ? customLabel.trimmingCharacters(in: .whitespacesAndNewlines)
            : selectedType.rawValue
    }

    private var canSave: Bool {
        !isSaving && !isDeleting &&
        !(selectedType == .custom && resolvedLabel.isEmpty)
    }

    private static let isoFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale     = Locale(identifier: "en_US_POSIX")
        f.timeZone   = TimeZone(identifier: "UTC")
        return f
    }()

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                occasionTypeSection
                dateSection
                reminderSection
                if existing != nil { deleteSection }
            }
            .navigationTitle(existing == nil ? "Add a date" : "Edit date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("Save") { Task { await save() } }
                            .disabled(!canSave)
                            .fontWeight(.semibold)
                    }
                }
            }
            .alert("Couldn't save", isPresented: $showSaveError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(saveError ?? "Please try again.")
            }
            .onAppear { populate() }
        }
    }

    // MARK: - Sections

    private var occasionTypeSection: some View {
        Section("Occasion") {
            Picker("Type", selection: $selectedType) {
                ForEach(OccasionType.allCases) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(.menu)

            if selectedType == .custom {
                TextField("Label (e.g. Graduation)", text: $customLabel)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
            }
        }
    }

    private var dateSection: some View {
        Section("Date") {
            DatePicker(
                "Date",
                selection: $date,
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .labelsHidden()
        }
    }

    private var reminderSection: some View {
        Section {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(reminderOptions, id: \.days) { option in
                        let selected = reminderDays == option.days
                        Button {
                            reminderDays = selected ? nil : option.days
                        } label: {
                            Text(option.label)
                                .font(.system(.subheadline, weight: selected ? .semibold : .regular))
                                .foregroundStyle(selected ? Color.white : Color.ink)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(selected ? Color.brandPurple : Color(.systemFill))
                                .clipShape(Capsule())
                                .animation(.easeInOut(duration: 0.15), value: selected)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 6)
            }
            .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
        } header: {
            Text("Remind me")
        } footer: {
            Text(reminderDays == nil
                 ? "No reminder set."
                 : "Reminder preference saved — notifications coming in a later update.")
                .font(.system(.caption))
        }
    }

    private var deleteSection: some View {
        Section {
            Button(role: .destructive) {
                Task { await deleteOccasion() }
            } label: {
                if isDeleting {
                    HStack(spacing: 8) { ProgressView().tint(.red); Text("Deleting…") }
                } else {
                    Text("Delete this date")
                }
            }
            .disabled(isDeleting || isSaving)
        }
    }

    // MARK: - Populate from existing

    private func populate() {
        guard let occ = existing else { return }
        date         = occ.date
        reminderDays = occ.remindDaysBefore

        if let preset = OccasionType.allCases.first(where: { $0 != .custom && $0.rawValue == occ.label }) {
            selectedType = preset
        } else {
            selectedType = .custom
            customLabel  = occ.label
        }
    }

    // MARK: - Save

    private func save() async {
        let label      = resolvedLabel
        let dateString = Self.isoFmt.string(from: date)
        let remind     = reminderDays != nil

        debugLog("[Occasion] save type=\(selectedType.rawValue) label='\(label)' date=\(dateString) remind_days_before=\(reminderDays.map(String.init) ?? "nil") for person=\(personId)")

        isSaving = true
        defer { isSaving = false }

        struct Payload: Encodable {
            let ownerId:               UUID
            let personId:              UUID
            let label:                 String
            let date:                  String
            let remind:                Bool
            let remindDaysBefore:      Int?
            let remindBeforeRecording: Bool

            enum CodingKeys: String, CodingKey {
                case ownerId               = "owner_id"
                case personId              = "person_id"
                case label, date, remind
                case remindDaysBefore      = "remind_days_before"
                case remindBeforeRecording = "remind_before_recording"
            }

            // Custom encode so remind_days_before sends JSON null when nil
            func encode(to encoder: Encoder) throws {
                var c = encoder.container(keyedBy: CodingKeys.self)
                try c.encode(ownerId,               forKey: .ownerId)
                try c.encode(personId,              forKey: .personId)
                try c.encode(label,                 forKey: .label)
                try c.encode(date,                  forKey: .date)
                try c.encode(remind,                forKey: .remind)
                try c.encode(remindDaysBefore,      forKey: .remindDaysBefore)      // null when nil
                try c.encode(remindBeforeRecording, forKey: .remindBeforeRecording)
            }
        }

        let payload = Payload(
            ownerId:               ownerId,
            personId:              personId,
            label:                 label,
            date:                  dateString,
            remind:                remind,
            remindDaysBefore:      reminderDays,
            remindBeforeRecording: true
        )

        do {
            if let occ = existing {
                try await supabase
                    .from("occasions")
                    .update(payload)
                    .eq("id", value: occ.id.uuidString)
                    .execute()
                debugLog("[Occasion] updated id=\(occ.id)")
            } else {
                try await supabase
                    .from("occasions")
                    .insert(payload)
                    .execute()
                debugLog("[Occasion] inserted for person=\(personId)")
            }
            onSaved()
            dismiss()
        } catch {
            debugLog("[Occasion] save failed: \(error)")
            if let pgErr = error as? PostgrestError {
                debugLog("[Occasion] PostgrestError: \(pgErr.message)")
            }
            saveError = "Couldn't save. Please try again."
            showSaveError = true
        }
    }

    // MARK: - Delete

    private func deleteOccasion() async {
        guard let occ = existing else { return }
        debugLog("[Occasion] deleting id=\(occ.id)")
        isDeleting = true
        defer { isDeleting = false }
        do {
            try await supabase
                .from("occasions")
                .delete()
                .eq("id", value: occ.id.uuidString)
                .execute()
            debugLog("[Occasion] deleted id=\(occ.id)")
            onDeleted()
            dismiss()
        } catch {
            debugLog("[Occasion] delete failed: \(error)")
            saveError = "Couldn't delete. Please try again."
            showSaveError = true
        }
    }
}

#Preview {
    OccasionFormView(personId: UUID(), ownerId: UUID())
}
