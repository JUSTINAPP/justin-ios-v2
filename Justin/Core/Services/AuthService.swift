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
        print("[Auth] sending OTP to: \(phone)")
        do {
            try await supabase.auth.signInWithOTP(phone: phone)
            print("[Auth] sendOTP succeeded for \(phone)")
            state = .awaitingCode(phone: phone)
        } catch {
            logAuthError("sendOTP", error)
            errorMessage = "Couldn't send the code. Check the number and try again."
        }
    }

    func verifyOTP(phone: String, code: String) async {
        clearError()
        isLoading = true
        defer { isLoading = false }
        print("[Auth] verifyOTP phone: \(phone)  code: \(code)")
        do {
            let response = try await supabase.auth.verifyOTP(
                phone: phone,
                token: code,
                type: .sms
            )
            print("[Auth] verifyOTP succeeded — userId: \(response.user.id)")
            print("[AuthCheck] current user id: \(String(describing: supabase.auth.currentUser?.id))")
            print("[AuthCheck] current session exists: \(supabase.auth.currentSession != nil)")
            print("[AuthCheck] access token present: \(supabase.auth.currentSession?.accessToken != nil)")
            await handleVerifiedUser(userId: response.user.id, phone: phone)
        } catch {
            logAuthError("verifyOTP", error)
            errorMessage = "Incorrect code. Please try again."
        }
    }

    func saveName(_ name: String) async {
        guard let userId = pendingUserId, let phone = pendingPhone else {
            print("[Name] saveName called but pendingUserId=\(String(describing: pendingUserId)) pendingPhone=\(String(describing: pendingPhone))")
            return
        }
        clearError()
        isLoading = true
        defer { isLoading = false }
        print("[Name] saving name '\(name)' for user: \(String(describing: supabase.auth.currentUser?.id))")
        print("[Name] pendingUserId: \(userId)  pendingPhone: \(phone)")
        print("[Name] operation: INSERT into people")
        do {
            let insert = PersonInsert(id: userId, displayName: name, phone: phone, authId: userId)
            let person: Person = try await supabase
                .from("people")
                .insert(insert)
                .select()
                .single()
                .execute()
                .value
            print("[Name] save succeeded — person id: \(person.id)")
            currentPerson = person
            pendingUserId = nil
            pendingPhone = nil
            state = .signedIn
        } catch {
            print("[Name] save failed: \(error)")
            print("[Name] localizedDescription: \(error.localizedDescription)")
            if let pgErr = error as? PostgrestError {
                print("[Name] PostgrestError — code: \(pgErr.code ?? "nil")")
                print("[Name] PostgrestError — message: \(pgErr.message)")
                print("[Name] PostgrestError — detail: \(pgErr.detail ?? "nil")")
                print("[Name] PostgrestError — hint: \(pgErr.hint ?? "nil")")
            }
            errorMessage = "Couldn't save your name. Please try again."
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
            await handleVerifiedUser(userId: session.user.id, phone: session.user.phone ?? "")
        } catch {
            state = .signedOut
        }
    }

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

    private func logAuthError(_ context: String, _ error: Error) {
        print("[Auth] \(context) FAILED: \(error)")
        print("[Auth] localizedDescription: \(error.localizedDescription)")
        if let authError = error as? AuthError {
            print("[Auth] AuthError.message: \(authError.message)")
            print("[Auth] AuthError.errorCode: \(authError.errorCode.rawValue)")
            if case .api(let message, let errorCode, let data, let response) = authError {
                print("[Auth] API status: \(response.statusCode)")
                print("[Auth] API errorCode: \(errorCode.rawValue)")
                print("[Auth] API message: \(message)")
                if let body = String(data: data, encoding: .utf8) {
                    print("[Auth] API response body: \(body)")
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
