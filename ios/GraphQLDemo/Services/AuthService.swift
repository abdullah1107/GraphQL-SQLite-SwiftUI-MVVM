import Foundation

protocol AuthServicing: Sendable {
    var hasStoredSession: Bool { get }
    func login(username: String, password: String) async throws -> User
    func currentUser() async throws -> User
    func logout() async
    func clearLocalSession()
}

struct AuthService: AuthServicing {
    let client: any GraphQLClientProtocol
    let tokenStore: any TokenStoring

    var hasStoredSession: Bool { tokenStore.accessToken != nil }

    func login(username: String, password: String) async throws -> User {
        let response = try await client.execute(LoginMutation(username: username, password: password))
        tokenStore.save(accessToken: response.login.accessToken, refreshToken: response.login.refreshToken)
        return response.login.user
    }

    func currentUser() async throws -> User {
        try await client.execute(MeQuery()).me
    }

    func logout() async {
        // Best effort: even if the server is unreachable we still forget the token locally.
        _ = try? await client.execute(LogoutMutation())
        tokenStore.clear()
    }

    func clearLocalSession() {
        tokenStore.clear()
    }
}
