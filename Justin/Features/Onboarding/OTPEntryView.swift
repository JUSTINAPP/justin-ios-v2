import SwiftUI

struct OTPEntryView: View {
    let phone: String
    @EnvironmentObject var auth: AuthService
    @State private var code = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 28) {
                VStack(spacing: 8) {
                    Text("Enter the code")
                        .font(.system(.title2, weight: .semibold))
                    Text("Sent to \(phone)")
                        .font(.system(.body))
                        .foregroundStyle(Color.secondary)
                }

                ZStack {
                    TextField("", text: $code)
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)
                        .focused($focused)
                        .opacity(0.02)
                        .frame(width: 1, height: 1)
                        .onChange(of: code) { _, value in
                            code = String(value.filter(\.isNumber).prefix(6))
                            if code.count == 6 {
                                Task { await auth.verifyOTP(phone: phone, code: code) }
                            }
                        }

                    HStack(spacing: 10) {
                        ForEach(0..<6, id: \.self) { i in
                            OTPBox(
                                digit: codeDigit(at: i),
                                isActive: code.count == i && focused
                            )
                        }
                    }
                    .onTapGesture { focused = true }
                }

                if let error = auth.errorMessage {
                    Text(error)
                        .font(.system(.subheadline))
                        .foregroundStyle(Color.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 28)
                }

                if auth.isLoading {
                    ProgressView()
                }
            }

            Spacer()

            Button {
                code = ""
                Task { await auth.sendOTP(phone: phone) }
            } label: {
                Text("Resend code")
                    .font(.system(.subheadline))
                    .foregroundStyle(Color.brandPurple)
            }
            .disabled(auth.isLoading)
            .padding(.bottom, 52)
        }
        .onAppear { focused = true }
    }

    private func codeDigit(at index: Int) -> String {
        let chars = Array(code)
        return chars.count > index ? String(chars[index]) : ""
    }
}

private struct OTPBox: View {
    let digit: String
    let isActive: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.secondarySystemFill))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(isActive ? Color.brandPurple : Color.clear, lineWidth: 2)
                )
                .frame(width: 46, height: 54)
            Text(digit)
                .font(.system(.title2, design: .monospaced).weight(.semibold))
        }
    }
}

#Preview {
    OTPEntryView(phone: "+61400000000")
        .environmentObject(AuthService())
}
