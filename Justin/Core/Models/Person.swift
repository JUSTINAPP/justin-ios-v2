import Foundation

struct Person: Codable, Identifiable {
    let id: UUID
    let phone: String
    let isVerified: Bool
    let displayName: String?
    let avatarUrl: String?
    let avatarColor: String?

    enum CodingKeys: String, CodingKey {
        case id
        case phone
        case isVerified = "is_verified"
        case displayName = "display_name"
        case avatarUrl = "avatar_url"
        case avatarColor = "avatar_color"
    }
}
