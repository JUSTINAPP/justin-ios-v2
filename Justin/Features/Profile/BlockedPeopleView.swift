import SwiftUI

struct BlockedPeopleView: View {
    @Binding var blockedPeople: [String]

    @State private var showBlockNumberField = false
    @State private var numberToBlock = ""
    @State private var showBlockNumberConfirm = false
    @State private var personToUnblock: String?
    @State private var showUnblockConfirm = false
    @FocusState private var numberFieldFocused: Bool

    var body: some View {
        List {
            // Explanation — clarify the two entry points
            Section {
                Text("These people can't reach you. To block someone already in your circle, go to Manage your circle.")
                    .font(.system(.subheadline))
                    .foregroundColor(.secondary)
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            // Block an unknown number
            Section {
                if showBlockNumberField {
                    HStack(spacing: 12) {
                        TextField("+1 555 000 0000", text: $numberToBlock)
                            .keyboardType(.phonePad)
                            .focused($numberFieldFocused)
                        Button("Block") {
                            showBlockNumberConfirm = true
                        }
                        .foregroundColor(.red)
                        .disabled(numberToBlock.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    Button("Cancel") {
                        showBlockNumberField = false
                        numberToBlock = ""
                    }
                    .font(.system(.subheadline))
                    .foregroundColor(.secondary)
                } else {
                    Button {
                        showBlockNumberField = true
                        numberFieldFocused = true
                    } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Label("Block a number", systemImage: "plus.circle.fill")
                                .font(.system(.body))
                                .foregroundColor(.brandPurple)
                            Text("Block someone who isn't in your circle yet.")
                                .font(.system(.caption))
                                .foregroundColor(.secondary)
                                .padding(.leading, 28)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            // Blocked people list (or empty state)
            if !blockedPeople.isEmpty {
                Section("Blocked") {
                    ForEach(blockedPeople, id: \.self) { person in
                        HStack(spacing: 14) {
                            InitialsAvatar(name: person, size: 40)
                            Text(person)
                                .font(.system(.body).weight(.medium))
                            Spacer()
                            Menu {
                                Button {
                                    personToUnblock = person
                                    showUnblockConfirm = true
                                } label: {
                                    Label("Unblock", systemImage: "person.badge.plus")
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                                    .font(.system(size: 20))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 6)
                    }
                }
            } else {
                Section {
                    Text("You haven't blocked anyone.")
                        .font(.system(.body))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
        }
        .navigationTitle("Blocked people")
        .navigationBarTitleDisplayMode(.inline)
        .scrollClearance()
        .alert("Block this number?", isPresented: $showBlockNumberConfirm) {
            Button("Block", role: .destructive) {
                let trimmed = numberToBlock.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty && !blockedPeople.contains(trimmed) {
                    blockedPeople.append(trimmed)
                }
                numberToBlock = ""
                showBlockNumberField = false
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("They won't be able to reach you on Justin.")
        }
        .alert("Unblock \(personToUnblock ?? "")?",
               isPresented: $showUnblockConfirm,
               presenting: personToUnblock) { person in
            Button("Unblock") {
                blockedPeople.removeAll { $0 == person }
            }
            Button("Cancel", role: .cancel) {}
        } message: { person in
            Text("\(person) will be able to send to you again.")
        }
    }
}

#Preview("With blocked person") {
    NavigationStack {
        BlockedPeopleView(blockedPeople: .constant(["Alex"]))
    }
}

#Preview("Empty") {
    NavigationStack {
        BlockedPeopleView(blockedPeople: .constant([]))
    }
}
