import Foundation

struct Gift: Codable, Identifiable {
    let id: UUID
    let authorId: UUID
    let recipientId: UUID
    let title: String?
    let status: String
    let accepted: Bool
    let shareToken: String?

    enum CodingKeys: String, CodingKey {
        case id
        case authorId    = "author_id"
        case recipientId = "recipient_id"
        case title
        case status
        case accepted
        case shareToken  = "share_token"
    }
}
