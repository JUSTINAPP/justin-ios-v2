import SwiftUI
import Supabase

struct DeleteAccountView: View {
    @EnvironmentObject var auth: AuthService
    @Environment(\.dismiss) private var dismiss

    @State private var showConfirm    = false
    @State private var isDeleting     = false
    @State private var deleteError:   String? = nil
    @State private var showError      = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {

                // What happens
                VStack(alignment: .leading, spacing: 12) {
                    Text("What happens when you delete")
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundColor(.brandDeep)

                    VStack(alignment: .leading, spacing: 16) {
                        row(icon: "xmark.circle.fill", color: .red.opacity(0.65),
                            text: "Your account, shelf, and any messages you received are permanently deleted.")
                        row(icon: "heart.fill", color: .brandRose,
                            text: "Gifts you've given others remain with them — those are their keepsakes to keep, shown from a former user.")
                        row(icon: "photo.on.rectangle.angled", color: .secondary,
                            text: "Media files (voice recordings, photos) will be cleaned up separately.")
                    }
                    .padding(16)
                    .background(Color(.secondarySystemFill))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                Divider()

                // Delete button
                Button(role: .destructive) {
                    showConfirm = true
                } label: {
                    if isDeleting {
                        HStack(spacing: 8) {
                            ProgressView().tint(.white)
                            Text("Deleting…")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(14)
                        .background(Color.red.opacity(0.7))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    } else {
                        Text("Delete my account")
                            .frame(maxWidth: .infinity)
                            .padding(14)
                            .background(Color.red)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .foregroundColor(.white)
                            .font(.system(.body, weight: .semibold))
                    }
                }
                .buttonStyle(.plain)
                .disabled(isDeleting)
            }
            .padding(20)
        }
        .navigationTitle("Delete your account")
        .navigationBarTitleDisplayMode(.inline)
        .scrollClearance()
        .alert("Permanently delete your account?", isPresented: $showConfirm) {
            Button("Delete", role: .destructive) { Task { await deleteAccount() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This deletes everything sent to you and removes your account. Gifts you've given others will remain, shown from a former user. This can't be undone.")
        }
        .alert("Couldn't delete account", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(deleteError ?? "Something went wrong. Please try again or contact support.")
        }
    }

    // MARK: - Delete

    private func deleteAccount() async {
        debugLog("[DeleteAccount] calling delete_my_account_data")
        isDeleting = true

        do {
            struct NoParams: Encodable {}
            try await supabase
                .rpc("delete_my_account_data", params: NoParams())
                .execute()
            debugLog("[DeleteAccount] RPC succeeded — signing out")
            await auth.signOut()
        } catch {
            debugLog("[DeleteAccount] RPC failed: \(error)")
            if let pgErr = error as? PostgrestError {
                debugLog("[DeleteAccount] PostgrestError code=\(pgErr.code ?? "nil") message=\(pgErr.message)")
            }
            isDeleting = false
            deleteError = "Couldn't delete your account right now. Please try again or contact support."
            showError = true
        }
    }

    // MARK: - Helper

    @ViewBuilder
    private func row(icon: String, color: Color, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.system(.body))
                .padding(.top, 2)
            Text(text)
                .font(.system(.body))
        }
    }
}

#Preview {
    NavigationStack { DeleteAccountView() }
        .environmentObject(AuthService())
}
