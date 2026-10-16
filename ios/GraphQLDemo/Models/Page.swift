import Foundation

/// Generic paged result (`ProductPage`, `CartPage` in the schema).
struct Page<Item: Codable & Sendable>: Codable, Sendable {
    let items: [Item]
    let total: Int
    let skip: Int
    let limit: Int
    let hasMore: Bool
}

/// Result of a sync mutation / the `syncStatus` query.
struct SyncResult: Codable, Identifiable, Hashable, Sendable {
    let entity: String
    let count: Int
    let syncedAt: String

    var id: String { entity }

    var syncedDate: Date? {
        try? Date(syncedAt, strategy: Date.ISO8601FormatStyle(includingFractionalSeconds: true))
    }
}
