import Foundation
import Combine
import UIKit

/// Shared state carried across the 5 recording steps.
@MainActor
final class RecordFlowModel: ObservableObject {
    @Published var recipientName: String = ""
    @Published var audioURL: URL?
    @Published var selectedImages: [UIImage] = []
    @Published var releaseType: ReleaseType = .now
    @Published var releaseDate: Date = Date()
    @Published var releaseFeeling: String = ""

    var hasRecording: Bool { audioURL != nil }
    var hasPhotos: Bool { !selectedImages.isEmpty }
}

// MARK: - ReleaseType display helpers (UI only, not persisted)

extension ReleaseType {
    var displayName: String {
        switch self {
        case .now:     return "Right now"
        case .date:    return "On a date"
        case .feeling: return "When a feeling hits"
        case .always:  return "Always available"
        }
    }

    var releaseSubtitle: String {
        switch self {
        case .now:     return "Opens as soon as you send it"
        case .date:    return "Sealed until a specific day you choose"
        case .feeling: return "They decide when the moment is right"
        case .always:  return "Always in their collection, never locked"
        }
    }

    var icon: String {
        switch self {
        case .now:     return "bolt"
        case .date:    return "calendar"
        case .feeling: return "heart"
        case .always:  return "infinity"
        }
    }
}
