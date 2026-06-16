import Foundation
import Supabase

// MARK: - Project config

/// Supabase connection constants.
/// `supabaseKey` is the publishable anon key — it is safe to ship in the binary.
/// Row Level Security (RLS) on every table is the real access control layer; the
/// anon key on its own gives no more access than RLS permits.
/// If additional hardening is ever needed, move to an .xcconfig entry excluded
/// from git, but this is not required while RLS is correctly configured.
private enum Config {
    static let supabaseURL = URL(string: "https://wunjsacvvjzsbvjmcsmp.supabase.co")!
    static let supabaseKey = "sb_publishable_hDIYgIvEOu9TPXWbU2hjIw_dtLlgMyY"
}

// MARK: - Shared client

/// Module-level singleton — call `supabase.from(…)` from anywhere in the app.
/// SupabaseClient is thread-safe; one instance is the recommended pattern.
let supabase = SupabaseClient(
    supabaseURL: Config.supabaseURL,
    supabaseKey: Config.supabaseKey
)

// MARK: - Connection test

enum SupabaseManager {

    /// Runs a single lightweight query against the `people` table to confirm
    /// the app can reach Supabase. Call once on launch during development;
    /// remove or gate behind a debug flag before shipping.
    static func testConnection() async {
        do {
            struct Row: Decodable { let id: UUID }
            let rows: [Row] = try await supabase
                .from("people")
                .select("id")
                .limit(1)
                .execute()
                .value
            print("[Supabase] ✓ Connected — people table reachable (\(rows.count) row(s) visible)")
        } catch {
            // A PostgREST permission/RLS error still means we reached Supabase —
            // the anon role just has no SELECT grant on this table yet.
            print("[Supabase] Query result: \(error)")
            print("[Supabase] (An RLS/permission error confirms connectivity; grant anon SELECT or add auth)")
        }
    }
}
