import Foundation

enum ReleaseType: String, Codable {
    case now
    case date
    case feeling
    case always
}

struct Message: Identifiable {
    let id: UUID
    let giftId: UUID
    let voiceUrl: String?
    let photoUrls: [String]
    let caption: String?
    let releaseType: ReleaseType
    let releaseDate: Date?
    let releaseFeeling: String?
    let hiddenUntilRelease: Bool
    let opened: Bool
    let openedAt: Date?
    let createdAt: Date?
}

// MARK: - Decodable with flexible date handling

extension Message: Decodable {
    enum CodingKeys: String, CodingKey {
        case id
        case giftId            = "gift_id"
        case voiceUrl          = "voice_url"
        case photoUrls         = "photo_urls"
        case caption
        case releaseType       = "release_type"
        case releaseDate       = "release_date"
        case releaseFeeling    = "release_feeling"
        case hiddenUntilRelease = "hidden_until_release"
        case opened
        case openedAt          = "opened_at"
        case createdAt         = "created_at"
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id               = try c.decode(UUID.self, forKey: .id)
        giftId           = try c.decode(UUID.self, forKey: .giftId)
        voiceUrl         = try? c.decodeIfPresent(String.self, forKey: .voiceUrl)
        photoUrls        = (try? c.decodeIfPresent([String].self, forKey: .photoUrls)) ?? []
        caption          = try? c.decodeIfPresent(String.self, forKey: .caption)
        releaseType      = (try? c.decode(ReleaseType.self, forKey: .releaseType)) ?? .now
        hiddenUntilRelease = (try? c.decode(Bool.self, forKey: .hiddenUntilRelease)) ?? false
        opened           = (try? c.decode(Bool.self, forKey: .opened)) ?? false
        releaseFeeling   = try? c.decodeIfPresent(String.self, forKey: .releaseFeeling)

        // Postgres `date` columns arrive as "yyyy-MM-dd"; `timestamptz` as ISO8601.
        // Try both formats so a type mismatch never corrupts the whole row.
        releaseDate      = Self.flexDate(c, forKey: .releaseDate)
        openedAt         = Self.flexDate(c, forKey: .openedAt)
        createdAt        = Self.flexDate(c, forKey: .createdAt)
    }

    // MARK: - Flexible date parsing

    private static let iso8601Full: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let iso8601Plain: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private static let plainDate: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()

    private static func flexDate<K: CodingKey>(_ c: KeyedDecodingContainer<K>, forKey key: K) -> Date? {
        guard let s = try? c.decodeIfPresent(String.self, forKey: key) else { return nil }
        return iso8601Full.date(from: s)
            ?? iso8601Plain.date(from: s)
            ?? plainDate.date(from: s)
    }
}
