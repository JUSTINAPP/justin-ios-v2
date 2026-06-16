import SwiftUI

// TODO(auth): This is a basic implementation — flag emoji + dial code + leading-zero strip.
// Full E.164 validation (length checks per country, subscriber-number formatting,
// detecting numbers already in full international format) is deferred to the auth phase
// when libPhoneNumber or a similar library will be added.

// MARK: - Country code model

struct CountryCode: Identifiable, Hashable {
    let id: String        // ISO 3166-1 alpha-2
    let flag: String
    let dialCode: String
    let name: String

    static let australia  = CountryCode(id: "AU", flag: "🇦🇺", dialCode: "+61", name: "Australia")

    static let all: [CountryCode] = [
        australia,
        CountryCode(id: "NZ", flag: "🇳🇿", dialCode: "+64", name: "New Zealand"),
        CountryCode(id: "GB", flag: "🇬🇧", dialCode: "+44", name: "United Kingdom"),
        CountryCode(id: "US", flag: "🇺🇸", dialCode: "+1",  name: "United States"),
        CountryCode(id: "CA", flag: "🇨🇦", dialCode: "+1",  name: "Canada"),
        CountryCode(id: "IN", flag: "🇮🇳", dialCode: "+91", name: "India"),
    ]
}

// MARK: - PhoneNumberField

/// A phone-number input that pairs a country-code picker with a local-number field.
/// Stores the result in E.164 format via `normalised` binding:
///   "0409 774 429" (AU) → "+61409774429"
/// The local number is shown naturally; the normalised E.164 value is stored.
struct PhoneNumberField: View {
    @Binding var normalised: String
    var placeholder: String = "0400 000 000"

    @State private var localNumber = ""
    @State private var selectedCountry = CountryCode.australia

    var body: some View {
        HStack(spacing: 0) {

            // Country-code picker
            Menu {
                ForEach(CountryCode.all) { country in
                    Button {
                        selectedCountry = country
                        updateNormalised()
                    } label: {
                        Text("\(country.flag) \(country.name)  \(country.dialCode)")
                    }
                }
            } label: {
                HStack(spacing: 5) {
                    Text(selectedCountry.flag)
                        .font(.system(size: 18))
                    Text(selectedCountry.dialCode)
                        .font(.system(.body).monospacedDigit())
                        .foregroundColor(.primary)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                .padding(.leading, 14)
                .padding(.trailing, 10)
                .frame(minHeight: 48)
            }

            // Separator
            Color(.separator)
                .frame(width: 0.5, height: 22)

            // Number field
            TextField(placeholder, text: $localNumber)
                .textFieldStyle(.plain)
                .keyboardType(.phonePad)
                .font(.system(.body))
                .padding(.horizontal, 14)
                .frame(maxWidth: .infinity, minHeight: 48)
                .onChange(of: localNumber) { _, _ in
                    updateNormalised()
                }
        }
        .background(Color(.systemFill))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    /// Strips the leading "0" (local trunk prefix) and prepends the dial code.
    /// Ignores spaces and dashes — they don't affect E.164 output.
    private func updateNormalised() {
        var digits = localNumber.filter(\.isNumber)
        if digits.hasPrefix("0") { digits.removeFirst() }
        normalised = digits.isEmpty ? "" : selectedCountry.dialCode + digits
    }
}

#Preview {
    @Previewable @State var phone = ""
    VStack(alignment: .leading, spacing: 8) {
        PhoneNumberField(normalised: $phone)
        Text(phone.isEmpty ? "(no number)" : phone)
            .font(.caption)
            .foregroundColor(.secondary)
    }
    .padding()
}
