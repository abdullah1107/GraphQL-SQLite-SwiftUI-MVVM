import Foundation

/// A typed GraphQL operation (query or mutation).
///
/// Each operation bundles:
/// - the GraphQL document that is sent to the server,
/// - the `Variables` it needs (encoded as JSON),
/// - the `Response` shape the `data` field decodes into.
protocol GraphQLOperation: Sendable {
    associatedtype Variables: Encodable & Sendable = EmptyVariables
    associatedtype Response: Decodable & Sendable

    static var operationName: String { get }
    static var document: String { get }
    var variables: Variables { get }
}

/// Used by operations that take no variables. Encodes as `{}`.
struct EmptyVariables: Encodable, Sendable {}

extension GraphQLOperation where Variables == EmptyVariables {
    var variables: EmptyVariables { EmptyVariables() }
}

/// JSON body POSTed to the GraphQL endpoint.
struct GraphQLRequestBody<Variables: Encodable>: Encodable {
    let operationName: String
    let query: String
    let variables: Variables
}

/// `{ "data": ... }` part of a successful response.
struct GraphQLDataEnvelope<DataType: Decodable>: Decodable {
    let data: DataType
}

/// `{ "errors": [...] }` part of a response. Decoded first so errors are never hidden by a decoding failure.
struct GraphQLErrorEnvelope: Decodable {
    let errors: [GraphQLErrorPayload]?
}

struct GraphQLErrorPayload: Decodable, Sendable {
    struct Extensions: Decodable, Sendable {
        let code: String?
    }

    let message: String
    let extensions: Extensions?
}
