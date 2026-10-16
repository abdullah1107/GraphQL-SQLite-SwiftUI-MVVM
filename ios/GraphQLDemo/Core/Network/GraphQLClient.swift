import Foundation

/// Anything that can run a `GraphQLOperation`. View models never see URLSession — only this protocol,
/// so it can be swapped for a mock in previews and tests.
protocol GraphQLClientProtocol: Sendable {
    func execute<Operation: GraphQLOperation>(_ operation: Operation) async throws -> Operation.Response
}

/// URLSession-based GraphQL client.
///
/// Every operation is sent as `POST { operationName, query, variables }` to a single endpoint.
/// The access token (if any) is attached as `Authorization: Bearer <token>`.
final class GraphQLClient: GraphQLClientProtocol {
    private let session: URLSession
    private let endpoint: @Sendable () -> URL
    private let tokenStore: any TokenStoring

    init(
        endpoint: @escaping @Sendable () -> URL,
        tokenStore: any TokenStoring,
        session: URLSession = .shared
    ) {
        self.endpoint = endpoint
        self.tokenStore = tokenStore
        self.session = session
    }

    func execute<Operation: GraphQLOperation>(_ operation: Operation) async throws -> Operation.Response {
        let request = try makeRequest(for: operation)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw NetworkError.transport(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        #if DEBUG
        print("⬅️ [GraphQL] \(Operation.operationName) HTTP \(http.statusCode), \(data.count) bytes")
        #endif

        let decoder = JSONDecoder()

        // 1. GraphQL errors can arrive with HTTP 200 *or* 4xx, so check them first.
        if let envelope = try? decoder.decode(GraphQLErrorEnvelope.self, from: data),
           let errors = envelope.errors, !errors.isEmpty {
            if let authError = errors.first(where: { $0.extensions?.code == "UNAUTHENTICATED" }) {
                throw NetworkError.unauthenticated(authError.message)
            }
            throw NetworkError.graphQL(errors.map(\.message))
        }

        // 2. Transport-level failure without a GraphQL body.
        guard (200..<300).contains(http.statusCode) else {
            throw NetworkError.httpStatus(http.statusCode)
        }

        // 3. Decode `data` into the operation's Response type.
        do {
            return try decoder.decode(GraphQLDataEnvelope<Operation.Response>.self, from: data).data
        } catch {
            throw NetworkError.decoding(Self.describe(error))
        }
    }

    private func makeRequest<Operation: GraphQLOperation>(for operation: Operation) throws -> URLRequest {
        var request = URLRequest(url: endpoint())
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token = tokenStore.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let body = GraphQLRequestBody(
            operationName: Operation.operationName,
            query: Operation.document,
            variables: operation.variables
        )
        request.httpBody = try JSONEncoder().encode(body)

        #if DEBUG
        print("➡️ [GraphQL] \(Operation.operationName) → \(request.url?.absoluteString ?? "")")
        #endif
        return request
    }

    private static func describe(_ error: Error) -> String {
        guard let decodingError = error as? DecodingError else { return error.localizedDescription }
        switch decodingError {
        case .keyNotFound(let key, let context):
            return "Missing field '\(key.stringValue)' at \(context.codingPath.map(\.stringValue).joined(separator: "."))"
        case .typeMismatch(_, let context), .valueNotFound(_, let context), .dataCorrupted(let context):
            return "\(context.debugDescription) at \(context.codingPath.map(\.stringValue).joined(separator: "."))"
        @unknown default:
            return decodingError.localizedDescription
        }
    }
}
