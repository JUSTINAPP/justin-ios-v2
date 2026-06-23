import Foundation
import Supabase

// MARK: - Model

/// A gift open that the author hasn't been notified about yet.
/// Fetched from the author's side — never exposes the recipient's data beyond their name.
struct GiftOpenNotification: Identifiable {
    let id: UUID           // messageId — used as the unique key and for DB updates
    let recipientName: String
    let releaseType: ReleaseType
    let releaseFeeling: String?
    let openedAt: Date?
}

// MARK: - Tone-scaled copy

extension GiftOpenNotification {
    /// Primary headline — warm, scaled by release type. Never alarm, never urgent.
    var headline: String {
        let name = recipientName
        switch releaseType {
        case .now, .always:
            return "\(name) heard your message"
        case .date:
            return "\(name) opened the message you saved for that day"
        case .feeling:
            if let f = releaseFeeling, !f.isEmpty {
                return "\(name) listened to the message you left for \(f)"
            }
            return "\(name) listened to the message you left"
        }
    }

    /// Optional softer second line — only for "feeling" type.
    var subtext: String? {
        switch releaseType {
        case .feeling: return "They reached for your voice."
        default:       return nil
        }
    }

    /// Icon name — warm, not alarm.
    var iconName: String {
        switch releaseType {
        case .now, .always: return "heart.fill"
        case .date:         return "envelope.open.fill"
        case .feeling:      return "hands.sparkles.fill"
        }
    }
}

// MARK: - Fetch

/// Returns the author's unacknowledged "your gift was heard" notifications,
/// newest first. Non-throwing — returns [] on any error.
func fetchGiftOpenNotifications(forAuthorId authorId: UUID) async -> [GiftOpenNotification] {
    // Step 1: gifts this user authored, with recipient names
    struct GiftRow: Decodable {
        let id: UUID
        let people: Recipient?
        struct Recipient: Decodable {
            let displayName: String?
            enum CodingKeys: String, CodingKey { case displayName = "display_name" }
        }
        enum CodingKeys: String, CodingKey {
            case id
            case people
        }
    }
    let giftRows: [GiftRow]
    do {
        giftRows = try await supabase
            .from("gifts")
            .select("id, people!recipient_id(display_name)")
            .eq("author_id", value: authorId.uuidString)
            .execute()
            .value
    } catch {
        debugLog("[OpenNotif] gift fetch failed: \(error)")
        return []
    }
    if giftRows.isEmpty { return [] }

    let nameByGiftId: [UUID: String] = Dictionary(
        giftRows.compactMap { row -> (UUID, String)? in
            guard let name = row.people?.displayName, !name.isEmpty else { return nil }
            return (row.id, name)
        },
        uniquingKeysWith: { first, _ in first }
    )
    if nameByGiftId.isEmpty { return [] }

    // Step 2: opened messages for those gifts that haven't been surfaced to the author yet
    struct MessageRow: Decodable {
        let id: UUID
        let giftId: UUID
        let releaseType: String
        let releaseFeeling: String?
        let openedAt: Date?
        enum CodingKeys: String, CodingKey {
            case id
            case giftId        = "gift_id"
            case releaseType   = "release_type"
            case releaseFeeling = "release_feeling"
            case openedAt      = "opened_at"
        }
    }
    let messageRows: [MessageRow]
    do {
        messageRows = try await supabase
            .from("messages")
            .select("id, gift_id, release_type, release_feeling, opened_at")
            .in("gift_id", values: Array(nameByGiftId.keys).map(\.uuidString))
            .eq("opened", value: true)
            .eq("author_notified_opened", value: false)
            .order("opened_at", ascending: false)
            .execute()
            .value
    } catch {
        debugLog("[OpenNotif] message fetch failed: \(error)")
        return []
    }

    return messageRows.compactMap { row -> GiftOpenNotification? in
        guard let name = nameByGiftId[row.giftId] else { return nil }
        return GiftOpenNotification(
            id: row.id,
            recipientName: name,
            releaseType: ReleaseType(rawValue: row.releaseType) ?? .now,
            releaseFeeling: row.releaseFeeling,
            openedAt: row.openedAt
        )
    }
}

// MARK: - Dismiss

/// Marks the notification as seen so it won't reappear. Non-throwing — logs on failure.
func markGiftOpenNotified(messageId: UUID) async {
    do {
        try await supabase
            .from("messages")
            .update(["author_notified_opened": true])
            .eq("id", value: messageId.uuidString)
            .execute()
        debugLog("[OpenNotif] marked \(messageId) as author_notified_opened")
    } catch {
        debugLog("[OpenNotif] mark notified failed (non-fatal): \(error)")
    }
}
