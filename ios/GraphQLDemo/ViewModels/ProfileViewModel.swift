import Foundation
import Observation

@MainActor
@Observable
final class ProfileViewModel {
    private(set) var syncStatus: [SyncResult] = []
    private(set) var isSyncing = false
    var message: String?
    var errorMessage: String?

    let endpoint: URL
    private let authService: any AuthServicing
    private let syncService: any SyncServicing
    private let session: SessionViewModel

    init(
        authService: any AuthServicing,
        syncService: any SyncServicing,
        settings: ServerSettings,
        session: SessionViewModel
    ) {
        self.authService = authService
        self.syncService = syncService
        self.endpoint = settings.endpoint
        self.session = session
    }

    var user: User? { session.currentUser }

    /// Refresh the user (`query Me`) and the DB sync status (`query SyncStatus`).
    func load() async {
        errorMessage = nil
        let auth = authService
        let sync = syncService
        do {
            // Two GraphQL requests in parallel.
            async let me = auth.currentUser()
            async let status = sync.status()
            let (user, rows) = try await (me, status)
            session.updateUser(user)
            syncStatus = rows
        } catch is CancellationError {
        } catch {
            errorMessage = session.message(for: error)
        }
    }

    /// `mutation SyncAll`: the server re-downloads DummyJSON products + carts into SQLite.
    func syncNow() async {
        guard !isSyncing else { return }
        isSyncing = true
        message = nil
        errorMessage = nil
        defer { isSyncing = false }
        do {
            let results = try await syncService.syncAll()
            let summary = results.map { "\($0.count) \($0.entity)" }.joined(separator: " and ")
            message = "Saved \(summary) to the database."
            syncStatus = try await syncService.status()
        } catch is CancellationError {
        } catch {
            errorMessage = session.message(for: error)
        }
    }

    func logout() async {
        await session.logout()
    }
}
