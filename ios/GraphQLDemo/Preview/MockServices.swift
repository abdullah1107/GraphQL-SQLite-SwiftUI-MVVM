import Foundation

// Canned data + in-memory services so SwiftUI previews render without the server.

enum PreviewData {
    static let user = User(
        id: 1,
        username: "emilys",
        email: "emily.johnson@x.dummyjson.com",
        firstName: "Emily",
        lastName: "Johnson",
        fullName: "Emily Johnson",
        gender: "female",
        image: "https://dummyjson.com/icon/emilys/128"
    )

    static let products: [Product] = (1...8).map { index in
        Product(
            id: index,
            title: "Sample Product \(index)",
            price: 9.99 * Double(index),
            finalPrice: 8.99 * Double(index),
            discountPercentage: 10,
            rating: 3.5 + Double(index % 3) * 0.5,
            stock: 5 * index,
            thumbnail: "https://cdn.dummyjson.com/product-images/beauty/essence-mascara-lash-princess/thumbnail.webp",
            category: index.isMultiple(of: 2) ? "beauty" : "groceries",
            brand: "Brand \(index)",
            availabilityStatus: "In Stock",
            description: "A short description of sample product \(index).",
            tags: ["sample", "preview"],
            images: [],
            sku: "SKU-\(index)",
            weight: 2,
            warrantyInformation: "1 year warranty",
            shippingInformation: "Ships in 2 days",
            returnPolicy: "30 days return policy",
            minimumOrderQuantity: 1,
            dimensions: Dimensions(width: 10, height: 5, depth: 2),
            reviews: [Review(rating: 5, comment: "Love it!", date: "2025-01-01T00:00:00.000Z", reviewerName: "Ava")]
        )
    }

    static func cart(id: Int, isLocal: Bool, productCount: Int = 3) -> Cart {
        let items = products.prefix(productCount).map { product in
            CartItem(
                productId: product.id,
                title: product.title,
                price: product.price,
                quantity: 2,
                total: product.price * 2,
                discountPercentage: 10,
                finalPrice: product.finalPrice,
                discountedTotal: product.finalPrice * 2,
                thumbnail: product.thumbnail,
                product: CartItemProduct(
                    id: product.id,
                    brand: product.brand,
                    category: product.category,
                    stock: product.stock,
                    availabilityStatus: product.availabilityStatus
                )
            )
        }
        return Cart(
            id: id,
            userId: 1,
            total: items.reduce(0) { $0 + $1.total },
            discountedTotal: items.reduce(0) { $0 + $1.discountedTotal },
            totalProducts: items.count,
            totalQuantity: items.reduce(0) { $0 + $1.quantity },
            isLocal: isLocal,
            updatedAt: "2026-01-01T10:00:00.000Z",
            items: Array(items)
        )
    }

    static let syncStatus = [
        SyncResult(entity: "carts", count: 208, syncedAt: "2026-01-01T10:00:00.000Z"),
        SyncResult(entity: "products", count: 194, syncedAt: "2026-01-01T10:00:00.000Z"),
    ]
}

struct MockAuthService: AuthServicing {
    var hasStoredSession: Bool { true }
    func login(username: String, password: String) async throws -> User { PreviewData.user }
    func currentUser() async throws -> User { PreviewData.user }
    func logout() async {}
    func clearLocalSession() {}
}

struct MockProductService: ProductServicing {
    func products(_ query: ProductQuery) async throws -> Page<Product> {
        let items = PreviewData.products.filter { product in
            (query.category == nil || product.category == query.category) &&
            (query.search?.isEmpty ?? true || product.title.localizedCaseInsensitiveContains(query.search ?? ""))
        }
        return Page(items: items, total: items.count, skip: 0, limit: query.limit, hasMore: false)
    }

    func product(id: Int) async throws -> Product {
        guard let product = PreviewData.products.first(where: { $0.id == id }) else {
            throw NetworkError.notFound("Product \(id)")
        }
        return product
    }

    func categories() async throws -> [String] { ["beauty", "groceries"] }
}

struct MockCartService: CartServicing {
    private static let myCartId = 100_000

    func carts(limit: Int, skip: Int) async throws -> Page<Cart> {
        let carts = (1...3).map { PreviewData.cart(id: $0, isLocal: false) }
        return Page(items: carts, total: carts.count, skip: 0, limit: limit, hasMore: false)
    }

    func cart(id: Int) async throws -> Cart { PreviewData.cart(id: id, isLocal: id >= Self.myCartId) }
    func myCarts() async throws -> [Cart] { [PreviewData.cart(id: Self.myCartId, isLocal: true)] }
    func myCart() async throws -> Cart? { PreviewData.cart(id: Self.myCartId, isLocal: true) }

    func addToCart(productId: Int, quantity: Int) async throws -> Cart {
        PreviewData.cart(id: Self.myCartId, isLocal: true)
    }

    func updateItem(productId: Int, quantity: Int) async throws -> Cart {
        PreviewData.cart(id: Self.myCartId, isLocal: true)
    }

    func removeItem(productId: Int) async throws -> Cart {
        PreviewData.cart(id: Self.myCartId, isLocal: true, productCount: 2)
    }

    func clear() async throws -> Cart {
        PreviewData.cart(id: Self.myCartId, isLocal: true, productCount: 0)
    }
}

struct MockSyncService: SyncServicing {
    func status() async throws -> [SyncResult] { PreviewData.syncStatus }
    func syncAll() async throws -> [SyncResult] { PreviewData.syncStatus }
}
