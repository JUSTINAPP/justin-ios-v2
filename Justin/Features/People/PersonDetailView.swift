import SwiftUI
import PhotosUI

struct PersonDetailView: View {
    let name: String

    // Local placeholder model — mirrors Occasion (Core/Models/Occasion.swift).
    // Replace with Occasion when Supabase is wired; personId will be the real UUID
    // from the people table. remindBeforeRecording drives the pre-date notification.
    private struct LocalOccasion: Identifiable {
        let id = UUID()
        var label: String
        var date: Date
        var remindBeforeRecording: Bool = true
    }

    @State private var relationship = ""
    @State private var notes = ""
    @State private var occasions: [LocalOccasion] = Self.placeholderOccasions
    @State private var showAddDate = false
    @State private var newLabel = ""
    @State private var newDate = Date()
    @FocusState private var labelFocused: Bool

    // Avatar photo (Tier 1 — your custom photo, stored on-device)
    @State private var avatarPickerItem: PhotosPickerItem?
    @State private var avatarImageData: Data?

    private static var placeholderOccasions: [LocalOccasion] {
        let cal = Calendar.current
        var aug = DateComponents(); aug.month = 8; aug.day = 12
        var oct = DateComponents(); oct.month = 10; oct.day = 4
        return [
            LocalOccasion(label: "Birthday",    date: cal.date(from: aug) ?? Date()),
            LocalOccasion(label: "Anniversary", date: cal.date(from: oct) ?? Date()),
        ]
    }

    private static let dayMonthFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "d MMM"; return f
    }()

    var body: some View {
        List {
            headerSection
            relationshipSection
            datesSection
            notesSection
            giftsSection
        }
        .navigationTitle(name)
        .navigationBarTitleDisplayMode(.inline)
        .scrollClearance()
        .onChange(of: avatarPickerItem) { _, item in
            Task { @MainActor in
                if let data = try? await item?.loadTransferable(type: Data.self) {
                    avatarImageData = data
                }
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        Section {
            HStack {
                Spacer()
                PhotosPicker(selection: $avatarPickerItem, matching: .images) {
                    VStack(spacing: 10) {
                        PersonAvatarView(name: name, size: 80, localPhotoData: avatarImageData)
                        Text(avatarImageData != nil ? "Change photo" : "Add photo")
                            .font(.system(.subheadline))
                            .foregroundColor(.brandPurple)
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

    // MARK: - Relationship

    private var relationshipSection: some View {
        Section {
            TextField("e.g. Daughter, Partner, Best friend", text: $relationship)
        } header: {
            Text("Relationship")
        }
    }

    // MARK: - Important dates

    private var datesSection: some View {
        Section {
            ForEach(occasions) { occasion in
                HStack {
                    Text(occasion.label)
                    Spacer()
                    Text(Self.dayMonthFormatter.string(from: occasion.date))
                        .foregroundColor(.secondary)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        occasions.removeAll { $0.id == occasion.id }
                    } label: {
                        Label("Remove", systemImage: "trash")
                    }
                }
            }

            if showAddDate {
                addDateRow
            } else {
                Button {
                    showAddDate = true
                    labelFocused = true
                } label: {
                    Label("Add a date", systemImage: "plus")
                }
                .foregroundColor(.brandPurple)
            }
        } header: {
            Text("Important dates")
        } footer: {
            // Design intent: these occasions are designed to trigger gentle reminder prompts
            // to record a message before the date — e.g. "Em's birthday is in 2 weeks —
            // want to leave her something?" Prompts are tied to real user-set occasions only.
            // Never nagging or engagement-farming. Author can toggle reminders per occasion.
            Text("Justin can gently remind you to leave a message before these dates.")
        }
    }

    @ViewBuilder
    private var addDateRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("Label (e.g. Birthday)", text: $newLabel)
                .focused($labelFocused)
            DatePicker("Date", selection: $newDate, displayedComponents: .date)
                .datePickerStyle(.compact)
            HStack {
                Button("Add") {
                    let trimmed = newLabel.trimmingCharacters(in: .whitespaces)
                    guard !trimmed.isEmpty else { return }
                    occasions.append(LocalOccasion(label: trimmed, date: newDate))
                    newLabel = ""; newDate = Date(); showAddDate = false
                }
                .foregroundColor(.brandPurple)
                .disabled(newLabel.trimmingCharacters(in: .whitespaces).isEmpty)

                Spacer()

                Button("Cancel") {
                    newLabel = ""; showAddDate = false
                }
                .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Notes

    private var notesSection: some View {
        Section {
            ZStack(alignment: .topLeading) {
                TextEditor(text: $notes)
                    .frame(minHeight: 80)
                if notes.isEmpty {
                    Text("Private notes about \(name)...")
                        .foregroundColor(Color(.placeholderText))
                        .font(.system(.body))
                        .padding(.top, 8)
                        .padding(.leading, 5)
                        .allowsHitTesting(false)
                }
            }
        } header: {
            Text("Notes")
        } footer: {
            Text("Only you can see these.")
        }
    }

    // MARK: - Gifts shortcuts

    private var giftsSection: some View {
        Section {
            NavigationLink(destination: ReceivedGiftDetailView(fromName: name)) {
                Label("Their gift to you", systemImage: "arrow.down.circle")
                    .foregroundColor(.brandPurple)
            }
            NavigationLink(destination: GiftDetailView(giftId: nil, recipientName: name)) {
                Label("Your gift to them", systemImage: "arrow.up.circle")
                    .foregroundColor(.brandRose)
            }
        } header: {
            Text("Gifts")
        }
    }
}

#Preview {
    NavigationStack { PersonDetailView(name: "Em") }
}
