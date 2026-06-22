import SwiftUI
import Supabase

struct AccountView: View {
    @EnvironmentObject var auth: AuthService
    @State private var displayName = ""
    @State private var savedName   = ""   // last-persisted value; used for dirty detection
    @State private var isSaving    = false

    // MARK: - Derived state

    private var canSave: Bool {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && !isSaving && trimmed != savedName
    }

    // MARK: - Phone formatting

    private var formattedPhone: String {
        guard let raw = auth.currentPerson?.phone, !raw.isEmpty else { return "" }
        let digits = raw.filter(\.isNumber)
        if digits.count == 11, digits.hasPrefix("61") {
            let sub = digits.dropFirst(2)
            return "+61 \(sub.prefix(3)) \(sub.dropFirst(3).prefix(3)) \(sub.dropFirst(6))"
        }
        if digits.count == 10, digits.hasPrefix("0") {
            let sub = digits.dropFirst(1)
            return "+61 \(sub.prefix(3)) \(sub.dropFirst(3).prefix(3)) \(sub.dropFirst(6))"
        }
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

            // ── Display name — editable ──────────────────────────────────────
            Section {
                TextField("Your name", text: $displayName)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .onSubmit {
                        if canSave { Task { await saveDisplayName() } }
                    }
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
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                if isSaving {
                    ProgressView()
                } else {
                    Button("Save") {
                        Task { await saveDisplayName() }
                    }
                    .disabled(!canSave)
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            let name = auth.currentPerson?.displayName ?? ""
            displayName = name
            savedName   = name
        }
    }

    // MARK: - Save

    private func saveDisplayName() async {
        guard let userId = auth.currentPerson?.id else {
            print("[Account] ABORT: no currentPerson — not signed in")
            return
        }
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            print("[Account] ABORT: name is empty")
            return
        }

        print("[Account] saving own display_name='\(trimmed)' for id=\(userId)")
        isSaving = true
        defer { isSaving = false }

        do {
            struct NameUpdate: Encodable {
                let displayName: String
                enum CodingKeys: String, CodingKey { case displayName = "display_name" }
            }
            try await supabase
                .from("people")
                .update(NameUpdate(displayName: trimmed))
                .eq("id", value: userId.uuidString)
                .execute()

            print("[Account] display_name saved OK → '\(trimmed)'")
            savedName = trimmed                  // clears dirty state → disables Save button
            await auth.refreshCurrentPerson()   // updates Profile header and everywhere else
        } catch {
            print("[Account] save FAILED: \(error)")
            if let pgErr = error as? PostgrestError {
                print("[Account] PostgrestError code=\(pgErr.code ?? "nil") message=\(pgErr.message)")
            }
        }
    }
}

#Preview {
    NavigationStack { AccountView() }
        .environmentObject(AuthService())
}
