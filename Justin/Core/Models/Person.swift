import Foundation

struct Person: Codable, Identifiable {
    let id: UUID
    var displayName: String?
    let phone: String?       // null for pending persons not yet on the app
    let authId: UUID?
    let isVerified: Bool
    let avatarUrl: String?
    let avatarColor: String?

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case phone
        case authId = "auth_id"
        case isVerified = "is_verified"
        case avatarUrl = "avatar_url"
        case avatarColor = "avatar_color"
    }
}
