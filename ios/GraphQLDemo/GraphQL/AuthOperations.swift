import Foundation

/// `mutation Login` → DummyJSON /auth/login (via the GraphQL server, which saves the user + session in SQLite).
struct LoginMutation: GraphQLOperation {
    static let operationName = "Login"
    static let document = """
    mutation Login($username: String!, $password: String!, $expiresInMins: Int) {
      login(username: $username, password: $password, expiresInMins: $expiresInMins) {
        accessToken
        refreshToken
        user { ...UserFields }
      }
    }
    """ + "\n" + GraphQLFragments.userFields

    struct Variables: Encodable, Sendable {
        let username: String
        let password: String
        let expiresInMins: Int
    }

    struct Response: Decodable, Sendable {
        let login: AuthPayload
    }

    let variables: Variables

    init(username: String, password: String, expiresInMins: Int = 24 * 60) {
        variables = Variables(username: username, password: password, expiresInMins: expiresInMins)
    }
}

/// `query Me` — the logged-in user (needs the bearer token).
struct MeQuery: GraphQLOperation {
    typealias Variables = EmptyVariables

    static let operationName = "Me"
    static let document = """
    query Me {
      me { ...UserFields }
    }
    """ + "\n" + GraphQLFragments.userFields

    struct Response: Decodable, Sendable {
        let me: User
    }
}

/// `mutation Logout` — revokes the session on the server.
struct LogoutMutation: GraphQLOperation {
    typealias Variables = EmptyVariables

    static let operationName = "Logout"
    static let document = """
    mutation Logout {
      logout
    }
    """

    struct Response: Decodable, Sendable {
        let logout: Bool
    }
}
