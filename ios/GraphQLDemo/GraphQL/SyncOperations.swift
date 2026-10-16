import Foundation

/// `query SyncStatus` — row counts and last sync time per table.
struct SyncStatusQuery: GraphQLOperation {
    typealias Variables = EmptyVariables

    static let operationName = "SyncStatus"
    static let document = """
    query SyncStatus {
      syncStatus { ...SyncFields }
    }
    """ + "\n" + GraphQLFragments.syncFields

    struct Response: Decodable, Sendable {
        let syncStatus: [SyncResult]
    }
}

/// `mutation SyncAll` — server re-pulls DummyJSON /products and /carts into SQLite.
struct SyncAllMutation: GraphQLOperation {
    typealias Variables = EmptyVariables

    static let operationName = "SyncAll"
    static let document = """
    mutation SyncAll {
      syncAll { ...SyncFields }
    }
    """ + "\n" + GraphQLFragments.syncFields

    struct Response: Decodable, Sendable {
        let syncAll: [SyncResult]
    }
}
