import SwiftUI

struct NameEntryView: View {
    @EnvironmentObject var auth: AuthService
    @State private var name       = ""
    @State private var showPrivacy = false
    @FocusState private var focused: Bool

    private let privacyURL = URL(string: "https://justinapp.com.au/privacy")!

    private var trimmed: String { name.trimmingCharacters(in: .whitespaces) }
    private var canContinue: Bool { !trimmed.isEmpty && !auth.isLoading }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("What should we call you?")
                        .font(.system(.title2, weight: .semibold))
                    Text("The people you give to will see this name.")
                        .font(.system(.body))
                        .foregroundStyle(Color.secondary)
                }

                TextField("Your first name", text: $name)
                    .textFieldStyle(.plain)
                    .font(.system(.body))
                    .padding(14)
                    .background(Color(.systemFill))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .focused($focused)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .onSubmit {
                        if canContinue { Task { await auth.saveName(trimmed) } }
                    }

                if let error = auth.errorMessage {
                    Text(error)
                        .font(.system(.subheadline))
                        .foregroundStyle(Color.red)
                }
            }
            .padding(.horizontal, 28)
            .padding(.top, 32)
            .padding(.bottom, 120)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                Button {
                    Task { await auth.saveName(trimmed) }
                } label: {
                    Group {
                        if auth.isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Text("Continue")
                                .font(.system(.body, weight: .semibold))
                                .foregroundStyle(Color.white)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(canContinue ? Color.brandPurple : Color.secondary.opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(!canContinue)
                .padding(.horizontal, 28)
                .padding(.top, 12)
                .padding(.bottom, 8)

                // Privacy notice
                HStack(spacing: 4) {
                    Text("By continuing, you agree to our")
                        .foregroundStyle(Color.secondary)
                    Button("Privacy Policy") { showPrivacy = true }
                        .foregroundStyle(Color.brandPurple)
                }
                .font(.system(.caption))
                .padding(.bottom, 16)
            }
            .background(.regularMaterial)
        }
        .sheet(isPresented: $showPrivacy) {
            SafariView(url: privacyURL).ignoresSafeArea()
        }
        .onAppear { focused = true }
    }
}

#Preview {
    NameEntryView()
        .environmentObject(AuthService())
}
