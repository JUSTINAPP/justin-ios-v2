import Foundation
import Supabase
import Combine

@MainActor
final class GivingViewModel: ObservableObject {
    @Published var gifts: [GiftRow] = []
    @Published var isLoading = false

    func fetch(authorId: UUID) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let rows: [GiftRow] = try await supabase
                .from("gifts")
                .select("id, status, accepted, recipient_id, people!recipient_id(display_name), messages(id)")
                .eq("author_id", value: authorId.uuidString)
                .order("created_at", ascending: false)
                .execute()
                .value
            print("[Giving] loaded \(rows.count) gifts")

            // Fetch recipient avatar paths from person_overrides (same source as People page).
            var pathByPersonId: [UUID: String] = [:]
            let recipientIds = rows.map(\.recipientId)
            if !recipientIds.isEmpty {
                do {
                    let overrides: [AvatarOverride] = try await supabase
                        .from("person_overrides")
                        .select("person_id, avatar_storage_path")
                        .eq("owner_id", value: authorId.uuidString)
                        .in("person_id", values: recipientIds.map(\.uuidString))
                        .execute()
                        .value
                    pathByPersonId = Dictionary(
                        overrides.compactMap { o -> (UUID, String)? in
                            guard let path = o.avatarStoragePath else { return nil }
                            return (o.personId, path)
                        },
                        uniquingKeysWith: { first, _ in first }
                    )
                    print("[Giving] avatar paths fetched for \(overrides.count) recipients")
                } catch {
                    print("[Giving] avatar paths fetch failed (non-fatal): \(error)")
                }
            }

            gifts = rows.map { gift in
                var g = gift
                g.avatarStoragePath = pathByPersonId[gift.recipientId]
                return g
            }
        } catch {
            print("[Giving] fetch failed: \(error)")
        }
    }

    private struct AvatarOverride: Decodable {
        let personId: UUID
        let avatarStoragePath: String?
        enum CodingKeys: String, CodingKey {
            case personId          = "person_id"
            case avatarStoragePath = "avatar_storage_path"
        }
    }

    struct GiftRow: Codable, Identifiable {
        let id: UUID
        let status: String
        let accepted: Bool
        let recipientId: UUID
        let people: RecipientSummary?
        let messages: [MessageStub]
        // Populated after the primary fetch via a separate person_overrides query.
        // Not in CodingKeys — defaults to nil when decoded from Supabase.
        var avatarStoragePath: String? = nil

        var recipientName: String { people?.displayName ?? "Someone" }
        var messageCount: Int { messages.count }

        enum CodingKeys: String, CodingKey {
            case id, status, accepted
            case recipientId = "recipient_id"
            case people, messages
        }

        struct RecipientSummary: Codable {
            let displayName: String?
            enum CodingKeys: String, CodingKey { case displayName = "display_name" }
        }

        struct MessageStub: Codable {
            let id: UUID
        }
    }
}
