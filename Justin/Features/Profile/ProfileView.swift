import SwiftUI

struct ProfileView: View {

    private let settingsRows = ["Account", "Notifications", "Safety & privacy"]

    var body: some View {
        List {
            Section {
                Text("Profile")
                    .font(.system(.title2).weight(.semibold))
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listSectionSeparator(.hidden)

            // Profile header
            Section {
                HStack(spacing: 14) {
                    InitialsAvatar(name: "Jonas", size: 60)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Jonas")
                            .font(.title3.weight(.semibold))
                        Text("+1 555 123 4567")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 6)
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            // Settings rows
            Section {
                ForEach(settingsRows, id: \.self) { row in
                    HStack {
                        Text(row)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 2)
                }
            }

            // Sign out — destructive, no chevron
            Section {
                Button(role: .destructive) {
                    // no-op for now
                } label: {
                    Text("Sign out")
                }
            }
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) { Wordmark() }
        }
    }
}

#Preview {
    NavigationStack { ProfileView() }
}
