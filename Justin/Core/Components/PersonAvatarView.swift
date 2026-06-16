import SwiftUI

/// Displays a person's avatar with a three-tier priority:
///
/// 1. Your custom photo — a photo YOU set for this person, stored on-device.
///    Highest priority: personalises how they appear in your app without
///    affecting what anyone else sees.
///
/// 2. Their own profile photo — the photo THEY set for themselves, synced from
///    Supabase (people.avatar_url). Used when you haven't set a custom photo.
///    Tier 2 is wired up once Supabase auth + Storage are connected; pass
///    `remoteAvatarURL` from the people row to activate it.
///
/// 3. Initials circle — colour-stable fallback derived from the person's name.
///
struct PersonAvatarView: View {
    let name: String
    let size: CGFloat
    /// Tier 1: raw image data you set locally via PhotosPicker.
    var localPhotoData: Data? = nil
    /// Tier 2: URL from people.avatar_url in Supabase. Nil until backend is wired.
    var remoteAvatarURL: URL? = nil

    var body: some View {
        Group {
            if let data = localPhotoData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else if let url = remoteAvatarURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        InitialsAvatar(name: name, size: size)
                    }
                }
            } else {
                InitialsAvatar(name: name, size: size)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}

#Preview {
    HStack(spacing: 16) {
        PersonAvatarView(name: "Em", size: 64)
        PersonAvatarView(name: "Mum", size: 64)
    }
    .padding()
}
