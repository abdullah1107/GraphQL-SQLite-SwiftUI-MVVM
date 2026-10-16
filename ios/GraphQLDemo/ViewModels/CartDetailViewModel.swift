import Foundation
import Observation

/// Read-only detail for a cart from "All carts" (DummyJSON carts or other users' carts).
/// The user's own cart is edited through `CartStore` instead.
@MainActor
@Observable
final class CartDetailViewModel {
    private(set) var cart: Cart
    private(set) var isRefreshing = false
    var errorMessage: String?

    private let cartService: any CartServicing
    private let session: SessionViewModel

    init(cart: Cart, cartService: any CartServicing, session: SessionViewModel) {
        self.cart = cart
        self.cartService = cartService
        self.session = session
    }

    /// `query Cart(id:)` — re-fetch the latest version of this cart.
    func refresh() async {
        isRefreshing = true
        defer { isRefreshing = false }
        do {
            cart = try await cartService.cart(id: cart.id)
            errorMessage = nil
        } catch is CancellationError {
        } catch {
            errorMessage = session.message(for: error)
        }
    }
}
