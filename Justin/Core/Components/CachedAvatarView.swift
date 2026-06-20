import SwiftUI

/// Shared avatar component used on every screen.
///
/// Checks AvatarCache SYNCHRONOUSLY in body so a cache hit renders the photo
/// on the very first frame — no initials flash, no re-fetch on navigation.
/// (An `await` in .task would delay the result by at least one render pass even
/// on a hit; the synchronous read bypasses that entirely.)
///
/// On a cache miss: shows initials while the async load runs, then swaps in the
/// photo. The loaded image is stored in AvatarCache so the next visit is instant.
///
/// Cache key = storage path, which changes on every avatar replace (unique upload
/// path per replace), so stale images never served after a photo change.
struct CachedAvatarView: View {
    let storagePath: String?
    let name: String
    let size: CGFloat

    @State private var loadedImage: UIImage?

    var body: some View {
        // Synchronous cache check — no suspension, no initials flash on hit.
        let syncImage: UIImage? = storagePath.flatMap { AvatarCache.shared.image(for: $0) }
        let displayImage = syncImage ?? loadedImage

        Group {
            if let img = displayImage {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
            } else {
                InitialsAvatar(name: name, size: size)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .task(id: storagePath) {
            guard let path = storagePath else { loadedImage = nil; return }
            // Skip async fetch if the synchronous check already has it.
            if AvatarCache.shared.image(for: path) != nil { return }
            loadedImage = await loadCachedAvatar(path: path)
        }
    }
}
