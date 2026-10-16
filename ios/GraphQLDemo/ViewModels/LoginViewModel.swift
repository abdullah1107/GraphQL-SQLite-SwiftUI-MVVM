import Foundation
import Observation

@MainActor
@Observable
final class LoginViewModel {
    // Pre-filled with a DummyJSON demo account.
    var username = "emilys"
    var password = "emilyspass"
    var serverURL: String
    var errorMessage: String?
    private(set) var isLoading = false

    private let authService: any AuthServicing
    private let settings: ServerSettings
    private let session: SessionViewModel

    init(authService: any AuthServicing, settings: ServerSettings, session: SessionViewModel) {
        self.authService = authService
        self.settings = settings
        self.session = session
        self.serverURL = settings.endpoint.absoluteString
    }

    var canSubmit: Bool {
        !username.trimmingCharacters(in: .whitespaces).isEmpty && !password.isEmpty && !isLoading
    }

    func login() async {
        guard canSubmit else { return }
        guard settings.update(serverURL) else {
            errorMessage = "Enter a valid server URL, e.g. http://localhost:4000/"
            return
        }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let user = try await authService.login(
                username: username.trimmingCharacters(in: .whitespaces),
                password: password
            )
            session.didLogin(user)
        } catch is CancellationError {
            // View went away; nothing to show.
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
