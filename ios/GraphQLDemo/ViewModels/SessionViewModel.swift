import Foundation
import Observation

/// App-wide login state. Decides whether the login screen or the tabs are shown.
@MainActor
@Observable
final class SessionViewModel {
    enum State: Equatable {
        case restoring
        case loggedOut
        case loggedIn(User)
    }

    private(set) var state: State = .restoring
    /// Message shown on the login screen (e.g. "session expired").
    var notice: String?

    private let authService: any AuthServicing

    init(authService: any AuthServicing) {
        self.authService = authService
    }

    var currentUser: User? {
        if case .loggedIn(let user) = state { return user }
        return nil
    }

    /// On launch: if a token is in the Keychain, ask the server who it belongs to (`query Me`).
    func restore() async {
        guard state == .restoring else { return }
        guard authService.hasStoredSession else {
            state = .loggedOut
            return
        }
        do {
            state = .loggedIn(try await authService.currentUser())
        } catch {
            if error.isAuthFailure {
                authService.clearLocalSession()
                notice = "Your session expired. Please log in again."
            } else {
                notice = error.localizedDescription
            }
            state = .loggedOut
        }
    }

    func didLogin(_ user: User) {
        notice = nil
        state = .loggedIn(user)
    }

    func updateUser(_ user: User) {
        if case .loggedIn = state { state = .loggedIn(user) }
    }

    func logout() async {
        await authService.logout()
        state = .loggedOut
    }

    /// Call from any view model's `catch`. Logs out on auth errors and returns a message to display.
    func message(for error: Error) -> String {
        if error.isAuthFailure {
            authService.clearLocalSession()
            notice = "Your session expired. Please log in again."
            state = .loggedOut
        }
        return error.localizedDescription
    }
}
