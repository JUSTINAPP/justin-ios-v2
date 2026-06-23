import Foundation
import Supabase
import Combine

enum AuthState: Equatable {
    case loading
    case signedOut
    case awaitingCode(phone: String)
    case awaitingName
    case signedIn
}

@MainActor
final class AuthService: ObservableObject {
    @Published var state: AuthState = .loading
    @Published var currentPerson: Person?
    @Published var isLoading = false
    @Published var errorMessage: String?
    /// Count of gifts that were re-pointed to this user during convergence.
    /// ShelfView reads this once on appear and resets it to 0 after showing the notice.
    @Published var pendingGiftsCount: Int = 0
    /// Triggers the "have a gift code?" sheet — set true after a new account is created.
    @Published var showClaimCodePrompt: Bool = false
    /// Set true after a successful gift claim so ShelfView knows to re-fetch.
    @Published var needsShelfRefresh: Bool = false

    private var pendingUserId: UUID?
    private var pendingPhone: String?

    init() {
        Task { await restoreSession() }
    }

    // MARK: - Public API

    func sendOTP(phone: String) async {
        clearError()
        isLoading = true
        defer { isLoading = false }
        let normPhone = normaliseToE164(phone)
        debugLog("[Auth] sending OTP to: \(phone) → '\(normPhone)'")
        do {
            try await supabase.auth.signInWithOTP(phone: normPhone)
            debugLog("[Auth] sendOTP succeeded for \(normPhone)")
            state = .awaitingCode(phone: normPhone)
        } catch {
            logAuthError("sendOTP", error)
            errorMessage = "Couldn't send the code. Check the number and try again."
        }
    }

    func verifyOTP(phone: String, code: String) async {
        clearError()
        isLoading = true
        defer { isLoading = false }
        let normPhone = normaliseToE164(phone)
        debugLog("[Auth] verifyOTP phone: \(phone) → '\(normPhone)'  code: \(code)")
        do {
            let response = try await supabase.auth.verifyOTP(
                phone: normPhone,
                token: code,
                type: .sms
            )
            debugLog("[Auth] verifyOTP succeeded — userId: \(response.user.id)")
            debugLog("[AuthCheck] current user id: \(String(describing: supabase.auth.currentUser?.id))")
            debugLog("[AuthCheck] current session exists: \(supabase.auth.currentSession != nil)")
            debugLog("[AuthCheck] access token present: \(supabase.auth.currentSession?.accessToken != nil)")
            await handleVerifiedUser(userId: response.user.id, phone: normPhone)
        } catch {
            logAuthError("verifyOTP", error)
            errorMessage = "Incorrect code. Please try again."
        }
    }

    func saveName(_ name: String) async {
        guard let userId = pendingUserId, let phone = pendingPhone else {
            debugLog("[Name] saveName called but pendingUserId=\(String(describing: pendingUserId)) pendingPhone=\(String(describing: pendingPhone))")
            return
        }
        clearError()
        isLoading = true
        defer { isLoading = false }
        debugLog("[Name] saving name '\(name)' for user: \(String(describing: supabase.auth.currentUser?.id))")
        debugLog("[Name] pendingUserId: \(userId)  pendingPhone: \(phone)")
        debugLog("[Name] operation: claim_or_create_account RPC (upgrades placeholder or creates fresh)")
        do {
            // SECURITY DEFINER RPC — finds an existing placeholder row with this phone
            // and upgrades it to a real account (sets auth_id, is_verified, display_name),
            // or creates a fresh row if none exists. Returns the people.id to use.
            // This replaces the plain INSERT which fails 23505 when a placeholder already
            // exists for this phone number (e.g. someone previously sent them a gift).
            struct ClaimParams: Encodable {
                let pDisplayName: String
                let pPhone: String
                enum CodingKeys: String, CodingKey {
                    case pDisplayName = "p_display_name"
                    case pPhone       = "p_phone"
                }
            }
            debugLog("[Name] calling claim_or_create_account displayName='\(name)' phone='\(phone)'")
            let personId: UUID = try await supabase
                .rpc("claim_or_create_account", params: ClaimParams(pDisplayName: name, pPhone: phone))
                .execute()
                .value
            debugLog("[Name] claim_or_create_account returned id=\(personId)")

            // Fetch the full Person row so currentPerson is populated correctly.
            let rows: [Person] = try await supabase
                .from("people")
                .select()
                .eq("id", value: personId.uuidString)
                .limit(1)
                .execute()
                .value
            guard let person = rows.first else {
                throw NSError(domain: "JustinAuth", code: -1, userInfo: [
                    NSLocalizedDescriptionKey: "Account created but couldn't load profile. Please restart the app."
                ])
            }
            debugLog("[Name] save succeeded — person id: \(person.id) displayName: \(person.displayName ?? "nil")")
            currentPerson = person
            // Convergence before signedIn so the Shelf fetch sees re-pointed gifts immediately.
            await runConvergence(userId: userId, phone: phone)
            pendingUserId = nil
            pendingPhone = nil
            state = .signedIn
            // Prompt new users to claim a gift by code — they may have one from the web.
            showClaimCodePrompt = true
        } catch {
            debugLog("[Name] save failed: \(error)")
            debugLog("[Name] localizedDescription: \(error.localizedDescription)")
            if let pgErr = error as? PostgrestError {
                debugLog("[Name] PostgrestError — code: \(pgErr.code ?? "nil")")
                debugLog("[Name] PostgrestError — message: \(pgErr.message)")
                debugLog("[Name] PostgrestError — detail: \(pgErr.detail ?? "nil")")
                debugLog("[Name] PostgrestError — hint: \(pgErr.hint ?? "nil")")
            }
            errorMessage = "Couldn't save your name. Please try again."
        }
    }

    func refreshCurrentPerson() async {
        guard let id = currentPerson?.id else { return }
        do {
            let rows: [Person] = try await supabase
                .from("people")
                .select()
                .eq("id", value: id.uuidString)
                .limit(1)
                .execute()
                .value
            if let person = rows.first { currentPerson = person }
        } catch {
            debugLog("[Auth] refreshCurrentPerson failed: \(error)")
        }
    }

    func signOut() async {
        try? await supabase.auth.signOut()
        currentPerson = nil
        pendingUserId = nil
        pendingPhone = nil
        state = .signedOut
    }

    // MARK: - Private

    private func restoreSession() async {
        do {
            let session = try await supabase.auth.session
            // Supabase auth returns phone without "+" (e.g. "61409774429").
            // Normalise to E.164 before storing as pendingPhone / passing to RPC.
            let rawPhone = session.user.phone ?? ""
            let phone    = normaliseToE164(rawPhone)
            if !rawPhone.isEmpty { debugLog("[Auth] restoreSession phone: '\(rawPhone)' → '\(phone)'") }
            await handleVerifiedUser(userId: session.user.id, phone: phone)
        } catch {
            state = .signedOut
        }
    }

    // normaliseToE164 is defined as a module-level function in AddPersonView.swift
    // so it's shared across the module without duplication.

    private func handleVerifiedUser(userId: UUID, phone: String) async {
        do {
            let rows: [Person] = try await supabase
                .from("people")
                .select()
                .eq("auth_id", value: userId.uuidString)
                .limit(1)
                .execute()
                .value
            if let person = rows.first {
                currentPerson = person
                // Convergence before signedIn so the Shelf fetch sees re-pointed gifts immediately.
                await runConvergence(userId: userId, phone: phone)
                state = .signedIn
            } else {
                pendingUserId = userId
                pendingPhone = phone
                state = .awaitingName
            }
        } catch {
            pendingUserId = userId
            pendingPhone = phone
            state = .awaitingName
        }
    }

    // MARK: - Gift convergence

    /// Calls the DB function that re-points any placeholder gifts addressed to
    /// p_phone over to this verified user. Safe to call on every login —
    /// idempotent, returns 0 if nothing new to attach.
    private func runConvergence(userId: UUID, phone: String) async {
        guard !phone.isEmpty else { return }
        do {
            let count: Int = try await supabase
                .rpc("converge_gifts_on_verify", params: ConvergeParams(pUserId: userId, pPhone: phone))
                .execute()
                .value
            if count > 0 {
                debugLog("[Converge] \(count) gift(s) attached to user \(userId)")
                pendingGiftsCount = count
            } else {
                debugLog("[Converge] no new gifts to attach")
            }
        } catch {
            // Non-fatal — log and continue. Convergence will retry on next login.
            debugLog("[Converge] RPC failed (non-fatal): \(error)")
        }
    }

    private struct ConvergeParams: Encodable {
        let pUserId: UUID
        let pPhone: String
        enum CodingKeys: String, CodingKey {
            case pUserId = "p_user_id"
            case pPhone  = "p_phone"
        }
    }

    private func logAuthError(_ context: String, _ error: Error) {
        debugLog("[Auth] \(context) FAILED: \(error)")
        debugLog("[Auth] localizedDescription: \(error.localizedDescription)")
        if let authError = error as? AuthError {
            debugLog("[Auth] AuthError.message: \(authError.message)")
            debugLog("[Auth] AuthError.errorCode: \(authError.errorCode.rawValue)")
            if case .api(let message, let errorCode, let data, let response) = authError {
                debugLog("[Auth] API status: \(response.statusCode)")
                debugLog("[Auth] API errorCode: \(errorCode.rawValue)")
                debugLog("[Auth] API message: \(message)")
                if let body = String(data: data, encoding: .utf8) {
                    debugLog("[Auth] API response body: \(body)")
                }
            }
        }
    }

    private func clearError() { errorMessage = nil }

    // MARK: - Insert shape

    private struct PersonInsert: Encodable {
        let id: UUID
        let displayName: String
        let phone: String
        let authId: UUID
        let isVerified: Bool = true

        enum CodingKeys: String, CodingKey {
            case id
            case displayName = "display_name"
            case phone
            case authId = "auth_id"
            case isVerified = "is_verified"
        }
    }
}
