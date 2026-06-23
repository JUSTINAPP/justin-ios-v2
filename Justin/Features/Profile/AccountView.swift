import SwiftUI
import Supabase

struct AccountView: View {
    @EnvironmentObject var auth: AuthService
    @State private var displayName       = ""
    @State private var savedName         = ""
    @State private var isSaving          = false
    @State private var showDeleteConfirm = false
    @State private var isDeletingAccount = false
    @State private var deleteError:    String? = nil
    @State private var showDeleteError = false

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
                    showDeleteConfirm = true
                } label: {
                    if isDeletingAccount {
                        HStack(spacing: 8) {
                            ProgressView().tint(.red)
                            Text("Deleting…")
                        }
                    } else {
                        Text("Delete account")
                    }
                }
                .disabled(isDeletingAccount)
            }
        }
        .navigationTitle("Account")
        .navigationBarTitleDisplayMode(.inline)
        .scrollClearance()
        .alert("Permanently delete your account?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) { Task { await deleteAccount() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This deletes everything sent to you and removes your account. Gifts you've given others will remain, shown from a former user. This can't be undone.")
        }
        .alert("Couldn't delete account", isPresented: $showDeleteError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(deleteError ?? "Something went wrong. Please try again or contact support.")
        }
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
            debugLog("[Account] ABORT: no currentPerson — not signed in")
            return
        }
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            debugLog("[Account] ABORT: name is empty")
            return
        }

        debugLog("[Account] saving own display_name='\(trimmed)' for id=\(userId)")
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

            debugLog("[Account] display_name saved OK → '\(trimmed)'")
            savedName = trimmed                  // clears dirty state → disables Save button
            await auth.refreshCurrentPerson()   // updates Profile header and everywhere else
        } catch {
            debugLog("[Account] save FAILED: \(error)")
            if let pgErr = error as? PostgrestError {
                debugLog("[Account] PostgrestError code=\(pgErr.code ?? "nil") message=\(pgErr.message)")
            }
        }
    }
    // MARK: - Delete account

    private func deleteAccount() async {
        debugLog("[DeleteAccount] calling delete_my_account_data")
        isDeletingAccount = true
        // No defer reset — we sign out on success (view goes away) or reset on failure.

        do {
            // Step 1 — delete account data (RPC)
            struct NoParams: Encodable {}
            try await supabase
                .rpc("delete_my_account_data", params: NoParams())
                .execute()
            debugLog("[DeleteAccount] data RPC done")

            // Step 2 — delete auth identity via Edge Function (non-fatal)
            // Data is already gone so we sign out regardless of whether this succeeds.
            struct EdgeResult: Decodable { let success: Bool?; let error: String? }
            do {
                let result: EdgeResult = try await supabase.functions.invoke("delete-auth-user")
                debugLog("[DeleteAccount] auth-user function result: success=\(result.success ?? false) error=\(result.error ?? "none")")
            } catch {
                debugLog("[DeleteAccount] auth-user function error (non-fatal, signing out anyway): \(error)")
            }

            // Step 3 — sign out
            debugLog("[DeleteAccount] signed out")
            await auth.signOut()
        } catch {
            debugLog("[DeleteAccount] data RPC failed: \(error)")
            if let pgErr = error as? PostgrestError {
                debugLog("[DeleteAccount] PostgrestError code=\(pgErr.code ?? "nil") message=\(pgErr.message)")
            }
            isDeletingAccount = false
            deleteError = "Couldn't delete your account right now. Please try again or contact support."
            showDeleteError = true
        }
    }
}

#Preview {
    NavigationStack { AccountView() }
        .environmentObject(AuthService())
}
