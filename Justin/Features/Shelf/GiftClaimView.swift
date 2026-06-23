import SwiftUI
import Supabase

/// Sheet for claiming a gift by its JUSTIN-XXXX code.
/// Reachable at signup (ContentView presents it automatically)
/// and later via the Shelf toolbar button.
struct GiftClaimView: View {
    /// Called after a successful claim so the caller can refresh the shelf.
    var onClaimed: () -> Void = {}

    @EnvironmentObject var auth: AuthService
    @Environment(\.dismiss) private var dismiss

    @State private var code      = ""
    @State private var isLoading = false
    @State private var message: ClaimMessage? = nil

    private var trimmed: String {
        code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    private var canSubmit: Bool {
        !trimmed.isEmpty && !isLoading && message?.isSuccess != true
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 24) {

                VStack(alignment: .leading, spacing: 8) {
                    Text("Have a gift code?")
                        .font(.system(.title2, weight: .semibold))
                        .foregroundStyle(Color.ink)
                    Text("Enter the code from your gift link and we'll add it to your shelf.")
                        .font(.system(.body))
                        .foregroundStyle(Color.secondary)
                }

                TextField("JUSTIN-XXXX", text: $code)
                    .textFieldStyle(.plain)
                    .font(.system(.body, design: .monospaced))
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .onSubmit { if canSubmit { Task { await claim() } } }
                    .padding(14)
                    .background(Color(.systemFill))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .disabled(message?.isSuccess == true)

                if let msg = message {
                    HStack(spacing: 8) {
                        Image(systemName: msg.isSuccess ? "checkmark.circle.fill" : "exclamationmark.circle")
                            .foregroundStyle(msg.isSuccess ? Color.brandPurple : Color.secondary)
                        Text(msg.text)
                            .font(.system(.subheadline))
                            .foregroundStyle(msg.isSuccess ? Color.ink : Color.secondary)
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                // Explicit skip — makes dismissal obvious so users don't feel stuck
                if message?.isSuccess != true {
                    Button {
                        dismiss()
                    } label: {
                        Text("I don't have a code")
                            .font(.system(.subheadline))
                            .foregroundStyle(Color.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.plain)
                }

                Spacer()
            }
            .animation(.spring(duration: 0.35), value: message?.text)
            .padding(.horizontal, 28)
            .padding(.top, 32)
            .navigationTitle("Gift code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(message?.isSuccess == true ? "Done" : "Skip") {
                        if message?.isSuccess == true { onClaimed() }
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isLoading {
                        ProgressView()
                    } else if message?.isSuccess != true {
                        Button("Find gift") {
                            Task { await claim() }
                        }
                        .disabled(!canSubmit)
                        .fontWeight(.semibold)
                    }
                }
            }
        }
    }

    // MARK: - Claim

    private func claim() async {
        let codeToSubmit = trimmed
        debugLog("[Claim] submitting code: \(codeToSubmit)")
        isLoading = true
        message   = nil
        defer { isLoading = false }

        do {
            let giftId: UUID = try await supabase
                .rpc("claim_gift_by_code", params: ClaimParams(pClaimCode: codeToSubmit))
                .execute()
                .value
            debugLog("[Claim] success — giftId: \(giftId)")
            message = .success("Found it — it's on your shelf.")
        } catch {
            debugLog("[Claim] failed — error: \(error)")
            if let pgErr = error as? PostgrestError {
                debugLog("[Claim] PostgrestError: code=\(pgErr.code ?? "nil") message=\(pgErr.message)")
            }
            message = .failure("We couldn't find a gift with that code — double-check it?")
        }
    }

    private struct ClaimParams: Encodable {
        let pClaimCode: String
        enum CodingKeys: String, CodingKey { case pClaimCode = "p_claim_code" }
    }

    // MARK: - Message type

    struct ClaimMessage: Equatable {
        let text: String
        let isSuccess: Bool
        static func success(_ t: String) -> Self { .init(text: t, isSuccess: true) }
        static func failure(_ t: String) -> Self { .init(text: t, isSuccess: false) }
    }
}

#Preview {
    GiftClaimView(onClaimed: {})
        .environmentObject(AuthService())
}
