import Foundation
import Observation

/// The logged-in user's shopping cart, shared by every screen.
///
/// Product detail adds to it, the Cart tab shows and edits it, and the tab badge reads `itemCount`.
/// Every mutation returns the full updated cart from the server (new line totals, discounts and prices),
/// which replaces `cart`, so all screens update together.
@MainActor
@Observable
final class CartStore {
    /// What changed after "Add to cart". Drives the confirmation sheet.
    struct AddResult: Identifiable, Equatable {
        let id = UUID()
        let productTitle: String
        let thumbnail: String?
        let addedQuantity: Int
        /// The product's cart line after the update (quantity includes what was already there).
        let line: CartItem?
        let cart: Cart
    }

    private(set) var cart: Cart?
    private(set) var isLoading = false
    private(set) var hasLoaded = false
    private(set) var isClearing = false
    /// Products with a request in flight (to show a spinner on that row).
    private(set) var busyProductIds: Set<Int> = []
    var errorMessage: String?

    private let cartService: any CartServicing
    private let session: SessionViewModel

    init(cartService: any CartServicing, session: SessionViewModel) {
        self.cartService = cartService
        self.session = session
    }

    var items: [CartItem] { cart?.items ?? [] }
    var isEmpty: Bool { items.isEmpty }
    /// Total units in the cart (tab badge).
    var itemCount: Int { cart?.totalQuantity ?? 0 }

    func quantity(of productId: Int) -> Int {
        cart?.item(for: productId)?.quantity ?? 0
    }

    func isBusy(_ productId: Int) -> Bool {
        busyProductIds.contains(productId)
    }

    // MARK: - Read

    /// `query MyCart` — fetches the cart with prices refreshed from the product catalogue.
    func load() async {
        isLoading = cart == nil
        defer { isLoading = false }
        do {
            cart = try await cartService.myCart()
            hasLoaded = true
            errorMessage = nil
        } catch is CancellationError {
        } catch {
            errorMessage = session.message(for: error)
        }
    }

    // MARK: - Add / update

    /// `mutation AddToCart`. Throws so the caller can show the error next to its button.
    func add(_ product: Product, quantity: Int) async throws -> AddResult {
        busyProductIds.insert(product.id)
        defer { busyProductIds.remove(product.id) }
        do {
            let updated = try await cartService.addToCart(productId: product.id, quantity: quantity)
            cart = updated
            hasLoaded = true
            return AddResult(
                productTitle: product.title,
                thumbnail: product.thumbnail,
                addedQuantity: quantity,
                line: updated.item(for: product.id),
                cart: updated
            )
        } catch {
            _ = session.message(for: error) // logs out on an expired token
            throw error
        }
    }

    /// `mutation UpdateCartItem`. A quantity of 0 deletes the line.
    func setQuantity(_ quantity: Int, for item: CartItem) async {
        guard quantity != item.quantity, !isBusy(item.productId) else { return }
        if quantity <= 0 {
            await remove(item)
            return
        }
        await mutate(item.productId) {
            try await self.cartService.updateItem(productId: item.productId, quantity: quantity)
        }
    }

    // MARK: - Delete

    /// `mutation RemoveFromCart` — deletes one product.
    func remove(_ item: CartItem) async {
        await mutate(item.productId) {
            try await self.cartService.removeItem(productId: item.productId)
        }
    }

    /// `mutation ClearCart` — deletes every item.
    func clear() async {
        guard !isClearing, !isEmpty else { return }
        isClearing = true
        defer { isClearing = false }
        do {
            cart = try await cartService.clear()
            errorMessage = nil
        } catch is CancellationError {
        } catch {
            errorMessage = session.message(for: error)
        }
    }

    // MARK: - Helpers

    private func mutate(_ productId: Int, _ request: @escaping () async throws -> Cart) async {
        busyProductIds.insert(productId)
        defer { busyProductIds.remove(productId) }
        do {
            cart = try await request()
            errorMessage = nil
        } catch is CancellationError {
        } catch {
            errorMessage = session.message(for: error)
        }
    }
}
