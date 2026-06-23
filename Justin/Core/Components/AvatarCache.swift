import UIKit
import Supabase

// MARK: - Cache

/// In-memory image cache keyed by storage PATH (not signed URL).
/// Paths are stable: `avatars/{ownerId}/{personId}/{uploadId}.jpg` doesn't
/// change unless a new photo is uploaded — and we upload to a unique path
/// each time, so a replaced avatar automatically gets a cache miss on the
/// new path. Signed URLs change on every call (new JWT token), so caching
/// by URL would never produce a hit.
final class AvatarCache {
    static let shared = AvatarCache()
    private let cache = NSCache<NSString, UIImage>()

    private init() {
        cache.countLimit     = 150
        cache.totalCostLimit = 60 * 1024 * 1024 // 60 MB
    }

    func image(for path: String) -> UIImage? {
        cache.object(forKey: path as NSString)
    }

    func store(_ image: UIImage, for path: String) {
        let cost = Int(image.size.width * image.size.height * 4)
        cache.setObject(image, forKey: path as NSString, cost: cost)
    }
}

// MARK: - Load helper

/// Returns a UIImage for the given storage path.
/// Cache hit → synchronous return; miss → fetches via signed URL, caches, returns.
/// All avatars live in the "photos" bucket.
/// Logs HIT or MISS so you can confirm caching behaviour in the console.
func loadCachedAvatar(path: String) async -> UIImage? {
    let label = (path.split(separator: "/").last).map(String.init) ?? path
    if let hit = AvatarCache.shared.image(for: path) {
        debugLog("[AvatarCache] HIT  \(label)")
        return hit
    }
    debugLog("[AvatarCache] MISS \(label) — fetching")
    do {
        let url = try await supabase.storage
            .from("photos")
            .createSignedURL(path: path, expiresIn: 3600)
        let (data, _) = try await URLSession.shared.data(from: url)
        guard let image = UIImage(data: data) else { return nil }
        AvatarCache.shared.store(image, for: path)
        debugLog("[AvatarCache] stored \(label)  (\(data.count / 1024) KB)")
        return image
    } catch {
        debugLog("[AvatarCache] fetch failed for \(label): \(error)")
        return nil
    }
}

// MARK: - Image compression

/// Resizes and JPEG-compresses a UIImage to avatar-appropriate dimensions
/// before upload. Typical output: 30–80 KB vs 3–4 MB raw photo library image.
///
/// - maxDimension: longest edge of the output in pixels (default 400 — plenty
///   for a retina 120 pt circle at 3×).
/// - quality: JPEG compression quality (default 0.7).
func compressedAvatarData(
    from source: UIImage,
    maxDimension: CGFloat = 400,
    quality: CGFloat = 0.7
) -> Data? {
    let longestEdge = max(source.size.width, source.size.height)
    let scale       = min(1.0, maxDimension / longestEdge)
    let targetSize  = CGSize(
        width:  (source.size.width  * scale).rounded(),
        height: (source.size.height * scale).rounded()
    )
    let renderer = UIGraphicsImageRenderer(size: targetSize)
    let resized  = renderer.image { _ in
        source.draw(in: CGRect(origin: .zero, size: targetSize))
    }
    return resized.jpegData(compressionQuality: quality)
}
