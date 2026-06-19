import Foundation
import UIKit
import Supabase

/// Persists a completed recording flow via a single atomic RPC call.
/// The database function create_gift_with_message handles recipient resolution,
/// gift find-or-create, and message insertion in one transaction, bypassing
/// per-table RLS issues that affected the previous three-step client-side approach.
struct GiftSaveResult {
    let giftId: UUID?
    let shareToken: String?
}

@MainActor
final class GiftSaveService {

    func save(model: RecordFlowModel, authorId: UUID) async throws -> GiftSaveResult {
        // Generate a stable key for all storage paths in this upload.
        let uploadId = UUID()

        // Upload voice — required; throw if it fails so the caller can surface the error.
        var voicePath: String? = nil
        if let audioURL = model.audioURL {
            let voiceData = try Data(contentsOf: audioURL)
            let path = "\(uploadId).m4a"
            try await supabase.storage
                .from("voice")
                .upload(path, data: voiceData, options: FileOptions(contentType: "audio/x-m4a"))
            voicePath = path
            print("[Upload] voice uploaded: \(path)")
        }

        // Upload photos — optional; continue on individual failures.
        var photoPaths: [String] = []
        for (i, image) in model.selectedImages.enumerated() {
            guard let jpegData = image.jpegData(compressionQuality: 0.85) else { continue }
            let path = "\(uploadId)_\(i).jpg"
            do {
                try await supabase.storage
                    .from("photos")
                    .upload(path, data: jpegData, options: FileOptions(contentType: "image/jpeg"))
                photoPaths.append(path)
            } catch {
                print("[Upload] photo \(i) upload failed: \(error)")
            }
        }
        print("[Upload] photos uploaded: \(photoPaths.count)")

        let params = CreateGiftParams(
            pRecipientName: model.recipientName,
            pRecipientPhone: model.recipientPhone.isEmpty ? nil : model.recipientPhone,
            pRecipientId: model.recipientPersonId,
            pReleaseType: model.releaseType.rawValue,
            pReleaseDate: model.releaseType == .date ? model.releaseDate : nil,
            pReleaseFeeling: model.releaseType == .feeling && !model.releaseFeeling.isEmpty
                ? model.releaseFeeling : nil,
            pVoiceUrl: voicePath,
            pPhotoUrls: photoPaths
        )

        print("[Save] recipient resolved as: name=\(params.pRecipientName), id=\(params.pRecipientId?.uuidString ?? "new")")

        let debugEncoder = JSONEncoder()
        debugEncoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        debugEncoder.dateEncodingStrategy = .iso8601
        if let data = try? debugEncoder.encode(params),
           let json = String(data: data, encoding: .utf8) {
            print("[Save] create_gift_with_message params:\n\(json)")
        }

        do {
            let messageId: UUID = try await supabase
                .rpc("create_gift_with_message", params: params)
                .execute()
                .value
            print("[Save] gift+message saved, message id: \(messageId)")

            // Caption lives in the messages.caption column; persist it after the RPC.
            let trimmedCaption = model.messageCaption.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedCaption.isEmpty {
                try? await supabase
                    .from("messages")
                    .update(["caption": trimmedCaption])
                    .eq("id", value: messageId.uuidString)
                    .execute()
                print("[Save] caption saved")
            }

            // Fetch the gift's id and share_token via the message FK — non-fatal.
            var giftId: UUID? = nil
            var shareToken: String? = nil
            do {
                let rows: [MessageGiftRow] = try await supabase
                    .from("messages")
                    .select("gift_id, gifts(id, share_token)")
                    .eq("id", value: messageId.uuidString)
                    .limit(1)
                    .execute()
                    .value
                giftId     = rows.first?.gifts.id
                shareToken = rows.first?.gifts.shareToken
                print("[Save] share_token: \(shareToken?.prefix(8) ?? "none")…")
            } catch {
                print("[Save] share_token fetch failed (migration needed?): \(error)")
            }

            return GiftSaveResult(giftId: giftId, shareToken: shareToken)

        } catch {
            print("[Save] gift save failed: \(error)")
            print("[Save] localizedDescription: \(error.localizedDescription)")
            if let pgErr = error as? PostgrestError {
                print("[Save] PostgrestError — code: \(pgErr.code ?? "nil"), message: \(pgErr.message)")
                print("[Save] PostgrestError — detail: \(pgErr.detail ?? "nil"), hint: \(pgErr.hint ?? "nil")")
            }
            throw error
        }
    }

    // MARK: - Token fetch helper

    private struct MessageGiftRow: Codable {
        let giftId: UUID
        let gifts: GiftTokenInfo

        struct GiftTokenInfo: Codable {
            let id: UUID
            let shareToken: String?
            enum CodingKeys: String, CodingKey {
                case id
                case shareToken = "share_token"
            }
        }

        enum CodingKeys: String, CodingKey {
            case giftId = "gift_id"
            case gifts
        }
    }

    // MARK: - RPC params

    private struct CreateGiftParams: Encodable {
        let pRecipientName: String
        let pRecipientPhone: String?
        let pRecipientId: UUID?
        let pReleaseType: String
        let pReleaseDate: Date?
        let pReleaseFeeling: String?
        let pVoiceUrl: String?
        let pPhotoUrls: [String]

        enum CodingKeys: String, CodingKey {
            case pRecipientName  = "p_recipient_name"
            case pRecipientPhone = "p_recipient_phone"
            case pRecipientId    = "p_recipient_id"
            case pReleaseType    = "p_release_type"
            case pReleaseDate    = "p_release_date"
            case pReleaseFeeling = "p_release_feeling"
            case pVoiceUrl       = "p_voice_url"
            case pPhotoUrls      = "p_photo_urls"
        }

        // Swift's synthesised Encodable uses encodeIfPresent for optionals, which
        // OMITS the key entirely when the value is nil. PostgREST matches Postgres
        // functions by the exact set of parameter names in the JSON body, so any
        // missing key reduces the apparent arity and causes PGRST202 "not found".
        // Custom encode(to:) uses encode(_:forKey:) instead, which writes
        // explicit JSON null for nil — all 8 keys are always present.
        func encode(to encoder: any Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(pRecipientName,  forKey: .pRecipientName)
            try c.encode(pRecipientPhone, forKey: .pRecipientPhone)   // null when nil
            try c.encode(pRecipientId,    forKey: .pRecipientId)      // null when nil
            try c.encode(pReleaseType,    forKey: .pReleaseType)
            try c.encode(pReleaseDate,    forKey: .pReleaseDate)       // null when nil
            try c.encode(pReleaseFeeling, forKey: .pReleaseFeeling)   // null when nil
            try c.encode(pVoiceUrl,       forKey: .pVoiceUrl)         // null when nil
            try c.encode(pPhotoUrls,      forKey: .pPhotoUrls)
        }
    }
}
