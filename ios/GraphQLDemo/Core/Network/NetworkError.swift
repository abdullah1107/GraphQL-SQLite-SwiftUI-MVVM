import Foundation

enum NetworkError: LocalizedError, Equatable {
    /// Could not reach the server (offline, wrong URL, server not running…).
    case transport(String)
    /// The response was not HTTP.
    case invalidResponse
    /// Non-2xx HTTP status without a GraphQL error body.
    case httpStatus(Int)
    /// The server returned GraphQL `errors`.
    case graphQL([String])
    /// The server said the request needs a valid login.
    case unauthenticated(String)
    /// A query returned `null` for something we expected.
    case notFound(String)
    /// The JSON did not match our Swift models.
    case decoding(String)

    var isUnauthenticated: Bool {
        if case .unauthenticated = self { return true }
        return false
    }

    var errorDescription: String? {
        switch self {
        case .transport(let message):
            return "Can't reach the GraphQL server. Is it running? (\(message))"
        case .invalidResponse:
            return "The server sent an invalid response."
        case .httpStatus(let code):
            return "The server responded with HTTP \(code)."
        case .graphQL(let messages):
            return messages.joined(separator: "\n")
        case .unauthenticated(let message):
            return message
        case .notFound(let what):
            return "\(what) was not found."
        case .decoding(let details):
            return "Couldn't read the server response. \(details)"
        }
    }
}

extension Error {
    /// True when the server rejected the access token.
    var isAuthFailure: Bool {
        (self as? NetworkError)?.isUnauthenticated ?? false
    }
}
