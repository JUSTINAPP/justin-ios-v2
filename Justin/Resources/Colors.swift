import SwiftUI

// MARK: - Hex initializer

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8)  & 0xFF) / 255
        let b = Double( int        & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - Brand palette

extension Color {
    static let brandPurple = Color(hex: "7B6BA8")
    static let brandRose   = Color(hex: "C4849A")
    static let brandPeach  = Color(hex: "E8B48A")
    static let brandDeep   = Color(hex: "4A3B6B")
    static let ink         = Color(hex: "2e2540")
    static let cream       = Color(hex: "faf0e4")
    static let lilacBg     = Color(hex: "faf8fc")
    // Recording screen
    static let recordingBg = Color(hex: "1a1726")   // deep aubergine studio feel
    static let recordRose  = Color(hex: "D4537E")   // brighter rose for record button
}
