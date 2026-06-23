import Foundation

/// Debug-only logging. Compiles to a no-op in release/TestFlight builds.
/// Replace all debugLog() calls with debugLog() — user IDs, tokens, and session
/// details never reach the console in production.
///
/// Signature matches Swift's built-in debugLog() so call sites are drop-in compatible.
func debugLog(_ items: Any..., separator: String = " ", terminator: String = "\n") {
    #if DEBUG
    let message = items.map { "\($0)" }.joined(separator: separator)
    Swift.print(message, terminator: terminator)
    #endif
}
