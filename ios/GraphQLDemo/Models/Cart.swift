import Foundation

struct Cart: Codable, Identifiable, Hashable, Sendable {
    let id: Int
    let userId: Int
    let total: Double
    let discountedTotal: Double
    let totalProducts: Int
    let totalQuantity: Int
    /// True for the cart this app creates with `addToCart` (stored in the server's SQLite DB).
    let isLocal: Bool
    let updatedAt: String?
    let items: [CartItem]

    var savings: Double { max(total - discountedTotal, 0) }

    var updatedDate: Date? {
        updatedAt.flatMap { try? Date($0, strategy: Date.ISO8601FormatStyle(includingFractionalSeconds: true)) }
    }

    func item(for productId: Int) -> CartItem? {
        items.first { $0.productId == productId }
    }
}

struct CartItem: Codable, Identifiable, Hashable, Sendable {
    let productId: Int
    let title: String
    /// Unit price before discount.
    let price: Double
    let quantity: Int
    /// price × quantity
    let total: Double
    let discountPercentage: Double
    /// Unit price after discount.
    let finalPrice: Double
    /// Line total after discount.
    let discountedTotal: Double
    let thumbnail: String?
    /// Live product details from the products table (nil if that product isn't synced).
    let product: CartItemProduct?

    var id: Int { productId }
    var hasDiscount: Bool { discountPercentage > 0.01 }
    var savings: Double { max(total - discountedTotal, 0) }
    /// Highest quantity the stepper allows.
    var maxQuantity: Int { max(product?.stock ?? 99, quantity) }
}

struct CartItemProduct: Codable, Hashable, Sendable {
    let id: Int
    let brand: String?
    let category: String?
    let stock: Int?
    let availabilityStatus: String?
}
