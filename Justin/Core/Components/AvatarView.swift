import SwiftUI

/// Colored circle showing one or two initials. Color is deterministic per name
/// so the same person always gets the same hue across sessions.
struct InitialsAvatar: View {
    let name: String
    let size: CGFloat

    private var initials: String {
        name.split(separator: " ")
            .prefix(2)
            .compactMap { $0.first.map(String.init) }
            .joined()
            .uppercased()
    }

    private var avatarColor: Color {
        let palette: [Color] = [.brandPurple, .brandRose, .brandDeep, .brandPeach]
        // Stable hash using UTF-8 byte sum (avoids Swift's randomized hashValue)
        let sum = name.utf8.reduce(0) { ($0 &+ Int($1)) & Int.max }
        return palette[sum % palette.count]
    }

    var body: some View {
        Circle()
            .fill(avatarColor)
            .frame(width: size, height: size)
            .overlay(
                Text(initials)
                    .font(.system(size: size * 0.38, weight: .semibold))
                    .foregroundColor(.white)
            )
    }
}

#Preview {
    HStack(spacing: 12) {
        ForEach(["Mum", "Em", "Jordan", "Jonas", "Dad"], id: \.self) {
            InitialsAvatar(name: $0, size: 48)
        }
    }
    .padding()
}
