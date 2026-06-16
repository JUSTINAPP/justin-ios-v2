import SwiftUI

struct ManageCircleView: View {
    @Binding var people: [String]
    @Binding var blockedPeople: [String]

    @State private var actionTarget: String?
    @State private var showRemoveConfirm = false
    @State private var showBlockConfirm = false

    var body: some View {
        List {
            Section {
                Text("These are the people who can send to your shelf. Tap \u{2026} on someone to remove or block them.")
                    .font(.system(.subheadline))
                    .foregroundColor(.secondary)
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            if people.isEmpty {
                Section {
                    Text("Your circle is empty.")
                        .font(.system(.body))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            } else {
                Section {
                    ForEach(people, id: \.self) { name in
                        HStack(spacing: 14) {
                            InitialsAvatar(name: name, size: 40)
                            Text(name)
                                .font(.system(.body).weight(.medium))
                            Spacer()
                            Menu {
                                Button {
                                    actionTarget = name
                                    showRemoveConfirm = true
                                } label: {
                                    Label("Remove", systemImage: "person.badge.minus")
                                }
                                Button(role: .destructive) {
                                    actionTarget = name
                                    showBlockConfirm = true
                                } label: {
                                    Label("Block", systemImage: "hand.raised.fill")
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
            }
        }
        .navigationTitle("Your circle")
        .navigationBarTitleDisplayMode(.inline)
        .scrollClearance()
        .alert("Remove \(actionTarget ?? "")?",
               isPresented: $showRemoveConfirm,
               presenting: actionTarget) { name in
            Button("Remove", role: .destructive) {
                people.removeAll { $0 == name }
            }
            Button("Cancel", role: .cancel) {}
        } message: { name in
            Text("Remove \(name)? They'll leave your circle and any unsent messages will be deleted. They could reconnect later.")
        }
        .alert("Block \(actionTarget ?? "")?",
               isPresented: $showBlockConfirm,
               presenting: actionTarget) { name in
            Button("Block", role: .destructive) {
                people.removeAll { $0 == name }
                if !blockedPeople.contains(name) {
                    blockedPeople.append(name)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: { name in
            Text("Block \(name)? They can never send to you or see your shelf unless you unblock them.")
        }
    }
}

#Preview {
    NavigationStack {
        ManageCircleView(
            people: .constant(["Mum", "Em", "Jordan"]),
            blockedPeople: .constant([])
        )
    }
}
