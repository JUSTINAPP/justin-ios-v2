import SwiftUI

extension View {
    /// Ensures scrollable content can clear the floating tab bar in iOS 26.
    ///
    /// Uses safeAreaInset rather than contentMargins because:
    /// - safeAreaInset propagates inward through the view hierarchy regardless of
    ///   where in the modifier chain it is applied, so it reaches the List or
    ///   ScrollView even when applied after navigationTitle modifiers.
    /// - It directly reduces the safe area seen by scrollable children, which List
    ///   and ScrollView always respect when computing their content insets.
    /// - contentMargins(for: .scrollContent) is a preference that must be read by
    ///   the scrollable view itself; when applied to a navigation-wrapper it is
    ///   not reliably propagated inward in iOS 26.
    func scrollClearance() -> some View {
        safeAreaInset(edge: .bottom) {
            Color.clear
                .frame(height: 90)
                .allowsHitTesting(false)
        }
    }
}
