import Foundation

/// One model for both the list and the detail screen.
/// Fields only requested by the detail query are optional, so the list query can skip them.
struct Product: Codable, Identifiable, Hashable, Sendable {
    // Requested everywhere (fragment ProductCard)
    let id: Int
    let title: String
    let price: Double
    let finalPrice: Double
    let discountPercentage: Double?
    let rating: Double?
    let stock: Int?
    let thumbnail: String?
    let category: String?
    let brand: String?
    let availabilityStatus: String?

    // Requested by the detail query only (fragment ProductDetail)
    var description: String?
    var tags: [String]?
    var images: [String]?
    var sku: String?
    var weight: Double?
    var warrantyInformation: String?
    var shippingInformation: String?
    var returnPolicy: String?
    var minimumOrderQuantity: Int?
    var dimensions: Dimensions?
    var reviews: [Review]?

    var hasDiscount: Bool { (discountPercentage ?? 0) > 0.01 }
    var gallery: [String] {
        if let images, !images.isEmpty { return images }
        return thumbnail.map { [$0] } ?? []
    }
}

struct Dimensions: Codable, Hashable, Sendable {
    let width: Double?
    let height: Double?
    let depth: Double?

    var formatted: String {
        [width, height, depth]
            .map { $0.map { String(format: "%.1f", $0) } ?? "–" }
            .joined(separator: " × ")
    }
}

struct Review: Codable, Hashable, Sendable {
    let rating: Int?
    let comment: String?
    let date: String?
    let reviewerName: String?
}

/// Matches the `ProductSort` enum in the GraphQL schema.
enum ProductSort: String, Codable, CaseIterable, Identifiable, Sendable {
    case id = "ID"
    case title = "TITLE"
    case price = "PRICE"
    case rating = "RATING"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .id: return "Default"
        case .title: return "Name"
        case .price: return "Price"
        case .rating: return "Rating"
        }
    }
}

/// Matches the `SortOrder` enum in the GraphQL schema.
enum SortOrder: String, Codable, CaseIterable, Identifiable, Sendable {
    case asc = "ASC"
    case desc = "DESC"

    var id: String { rawValue }
    var label: String { self == .asc ? "Ascending" : "Descending" }
}
