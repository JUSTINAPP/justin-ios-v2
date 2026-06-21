import SwiftUI

struct AccountView: View {
    @EnvironmentObject var auth: AuthService
    @State private var displayName = ""

    // MARK: - Phone formatting

    /// Formats the raw E.164-ish phone string stored in people.phone to a human-readable form.
    /// Handles the common Supabase-stored formats: "61409774429", "+61409774429", "0409774429".
    private var formattedPhone: String {
        guard let raw = auth.currentPerson?.phone, !raw.isEmpty else { return "" }
        let digits = raw.filter(\.isNumber)

        // 11-digit international without + : 61XXXXXXXXX → +61 XXX XXX XXX
        if digits.count == 11, digits.hasPrefix("61") {
            let sub = digits.dropFirst(2)
            return "+61 \(sub.prefix(3)) \(sub.dropFirst(3).prefix(3)) \(sub.dropFirst(6))"
        }
        // 10-digit local starting with 0 : 0XXXXXXXXX → +61 XXX XXX XXX (AU assumption)
        if digits.count == 10, digits.hasPrefix("0") {
            let sub = digits.dropFirst(1)
            return "+61 \(sub.prefix(3)) \(sub.dropFirst(3).prefix(3)) \(sub.dropFirst(6))"
        }
        // Already has a + or is in another format — return as-is after cleaning spaces
        return raw.hasPrefix("+") ? raw : "+\(digits)"
    }

    // MARK: - Body

    var body: some View {
        List {
            // ── Avatar ──────────────────────────────────────────────────────
            Section {
                HStack {
                    Spacer()
                    CachedAvatarView(
                        storagePath: auth.currentPerson?.avatarUrl,
                        name: displayName.isEmpty ? "?" : displayName,
                        size: 72
                    )
                    Spacer()
                }
                .padding(.vertical, 8)
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            // ── Display name (editable field; name is set in signup) ─────────
            Section {
                TextField("Name", text: $displayName)
            } header: {
                Text("Your name")
            } footer: {
                Text("This is the name that signs your messages.")
            }

            // ── Phone — read only ────────────────────────────────────────────
            Section {
                HStack {
                    Text(formattedPhone.isEmpty ? "—" : formattedPhone)
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

            // ── Danger zone ──────────────────────────────────────────────────
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
        .onAppear {
            displayName = auth.currentPerson?.displayName ?? ""
        }
    }
}

#Preview {
    NavigationStack { AccountView() }
        .environmentObject(AuthService())
}
