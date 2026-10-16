import Foundation
import Observation

@MainActor
@Observable
final class ProductDetailViewModel {
    private(set) var product: Product?
    private(set) var isLoading = false
    var errorMessage: String?
    var quantity = 1
    /// Set after a successful add; the view shows it as a sheet with the updated cart.
    var addResult: CartStore.AddResult?

    let productId: Int
    private let productService: any ProductServicing
    private let cartStore: CartStore
    private let session: SessionViewModel

    init(
        productId: Int,
        productService: any ProductServicing,
        cartStore: CartStore,
        session: SessionViewModel
    ) {
        self.productId = productId
        self.productService = productService
        self.cartStore = cartStore
        self.session = session
    }

    /// How many of this product are already in the cart.
    var inCartQuantity: Int { cartStore.quantity(of: productId) }
    var isAddingToCart: Bool { cartStore.isBusy(productId) }

    /// Units that can still be added without going over stock.
    var availableToAdd: Int {
        guard let stock = product?.stock else { return 99 }
        return max(stock - inCartQuantity, 0)
    }

    var maxQuantity: Int { max(availableToAdd, 1) }
    var canAdd: Bool { availableToAdd > 0 && !isAddingToCart }

    /// Price of the chosen quantity after discount (shown on the button).
    var selectionTotal: Double { (product?.finalPrice ?? 0) * Double(quantity) }

    func loadIfNeeded() async {
        guard product == nil else { return }
        await load()
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            product = try await productService.product(id: productId)
        } catch is CancellationError {
        } catch {
            errorMessage = session.message(for: error)
        }
    }

    func addToCart() async {
        guard let product, canAdd else { return }
        errorMessage = nil
        do {
            addResult = try await cartStore.add(product, quantity: min(quantity, availableToAdd))
            quantity = 1
        } catch is CancellationError {
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
