import Foundation

protocol SyncServicing: Sendable {
    func status() async throws -> [SyncResult]
    func syncAll() async throws -> [SyncResult]
}

struct SyncService: SyncServicing {
    let client: any GraphQLClientProtocol

    func status() async throws -> [SyncResult] {
        try await client.execute(SyncStatusQuery()).syncStatus
    }

    func syncAll() async throws -> [SyncResult] {
        try await client.execute(SyncAllMutation()).syncAll
    }
}
