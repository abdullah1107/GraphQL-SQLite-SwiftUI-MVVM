import Foundation

/// Where the GraphQL server lives. Editable from the login screen so the app also works on a real device.
///
/// - Simulator: `http://localhost:4000/` reaches the server running on your Mac.
/// - iPhone on the same Wi-Fi: use your Mac's IP, e.g. `http://192.168.1.20:4000/`.
final class ServerSettings: @unchecked Sendable {
    static let defaultEndpoint = URL(string: "http://localhost:4000/")!

    private let defaults: UserDefaults
    private let key = "graphql.endpoint"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var endpoint: URL {
        guard let stored = defaults.string(forKey: key), let url = URL(string: stored) else {
            return Self.defaultEndpoint
        }
        return url
    }

    /// Saves a new endpoint if it is a valid http(s) URL. Returns false otherwise.
    @discardableResult
    func update(_ string: String) -> Bool {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme),
              url.host != nil else {
            return false
        }
        defaults.set(url.absoluteString, forKey: key)
        return true
    }
}
