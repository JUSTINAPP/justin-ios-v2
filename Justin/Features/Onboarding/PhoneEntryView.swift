import SwiftUI

struct PhoneEntryView: View {
    @EnvironmentObject var auth: AuthService
    @State private var phone = ""

    private var canSend: Bool { phone.count >= 8 && !auth.isLoading }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("What's your number?")
                        .font(.system(.title2, weight: .semibold))
                    Text("We'll send a one-time code to verify it's you.")
                        .font(.system(.body))
                        .foregroundStyle(Color.secondary)
                }

                PhoneNumberField(normalised: $phone)

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
            Button {
                Task { await auth.sendOTP(phone: phone) }
            } label: {
                Group {
                    if auth.isLoading {
                        ProgressView().tint(.white)
                    } else {
                        Text("Send code")
                            .font(.system(.body, weight: .semibold))
                            .foregroundStyle(Color.white)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(canSend ? Color.brandPurple : Color.secondary.opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(!canSend)
            .padding(.horizontal, 28)
            .padding(.vertical, 12)
            .background(.regularMaterial)
        }
        .navigationTitle("Your number")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack { PhoneEntryView() }
        .environmentObject(AuthService())
}
