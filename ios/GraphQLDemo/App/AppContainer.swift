import Foundation

/// Dependency container: builds the GraphQL client once and hands services to view models.
struct AppContainer: Sendable {
    let settings: ServerSettings
    let authService: any AuthServicing
    let productService: any ProductServicing
    let cartService: any CartServicing
    let syncService: any SyncServicing

    /// Real app: Keychain token + URLSession GraphQL client.
    static func live() -> AppContainer {
        let settings = ServerSettings()
        let tokenStore = KeychainTokenStore()
        let client = GraphQLClient(endpoint: { settings.endpoint }, tokenStore: tokenStore)
        return AppContainer(
            settings: settings,
            authService: AuthService(client: client, tokenStore: tokenStore),
            productService: ProductService(client: client),
            cartService: CartService(client: client),
            syncService: SyncService(client: client)
        )
    }

    /// SwiftUI previews: canned data, no network.
    static func preview() -> AppContainer {
        AppContainer(
            settings: ServerSettings(defaults: UserDefaults(suiteName: "preview") ?? .standard),
            authService: MockAuthService(),
            productService: MockProductService(),
            cartService: MockCartService(),
            syncService: MockSyncService()
        )
    }
}
