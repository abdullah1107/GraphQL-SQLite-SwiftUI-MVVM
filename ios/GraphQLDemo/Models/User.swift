import Foundation

struct User: Codable, Identifiable, Hashable, Sendable {
    let id: Int
    let username: String
    let email: String?
    let firstName: String?
    let lastName: String?
    let fullName: String
    let gender: String?
    let image: String?
}

struct AuthPayload: Decodable, Sendable {
    let accessToken: String
    let refreshToken: String?
    let user: User
}
