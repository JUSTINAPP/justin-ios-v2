import Foundation

enum ReleaseType: String, Codable {
    case now
    case date
    case feeling
    case always
}

struct Message: Codable, Identifiable {
    let id: UUID
    let giftId: UUID
    let voiceUrl: String?    // null until Storage upload is wired
    let photoUrls: [String]
    let caption: String?
    let releaseType: ReleaseType
    let releaseDate: Date?
    let releaseFeeling: String?
    let hiddenUntilRelease: Bool
    let opened: Bool
    let openedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case giftId = "gift_id"
        case voiceUrl = "voice_url"
        case photoUrls = "photo_urls"
        case caption
        case releaseType = "release_type"
        case releaseDate = "release_date"
        case releaseFeeling = "release_feeling"
        case hiddenUntilRelease = "hidden_until_release"
        case opened
        case openedAt = "opened_at"
    }
}
