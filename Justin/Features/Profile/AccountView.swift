import SwiftUI

struct AccountView: View {
    @State private var displayName = "Jonas"

    var body: some View {
        List {
            // Profile photo
            Section {
                HStack {
                    Spacer()
                    VStack(spacing: 10) {
                        InitialsAvatar(name: displayName.isEmpty ? "?" : displayName, size: 72)
                        Button("Add photo") {}
                            .font(.system(.subheadline))
                            .foregroundColor(.brandPurple)
                    }
                    Spacer()
                }
                .padding(.vertical, 8)
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            // Display name
            Section {
                TextField("Name", text: $displayName)
            } header: {
                Text("Your name")
            } footer: {
                Text("This is the name that signs your messages.")
            }

            // Phone — read only
            Section {
                HStack {
                    Text("+61 412 345 678")
                        .foregroundColor(.primary)
                    Spacer()
                    Text("read only")
                        .font(.system(.caption))
                        .foregroundColor(.secondary)
                }
            } header: {
                Text("Phone number")
            } footer: {
                Text("This is your account identity. Contact support if you need to change it.")
            }

            // Delete account
            Section {
                Button(role: .destructive) {
                    // TODO: delete account flow
                } label: {
                    Text("Delete account")
                }
            }
        }
        .navigationTitle("Account")
        .navigationBarTitleDisplayMode(.inline)
        .scrollClearance()
    }
}

#Preview {
    NavigationStack { AccountView() }
}
