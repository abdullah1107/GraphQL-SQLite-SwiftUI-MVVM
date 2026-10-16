import Foundation

struct ProductQuery: Equatable, Sendable {
    var search: String?
    var category: String?
    var sort: ProductSort = .id
    var order: SortOrder = .asc
    var limit: Int = 20
    var skip: Int = 0
}

protocol ProductServicing: Sendable {
    func products(_ query: ProductQuery) async throws -> Page<Product>
    func product(id: Int) async throws -> Product
    func categories() async throws -> [String]
}

struct ProductService: ProductServicing {
    let client: any GraphQLClientProtocol

    func products(_ query: ProductQuery) async throws -> Page<Product> {
        let variables = ProductsQuery.Variables(
            search: query.search,
            category: query.category,
            limit: query.limit,
            skip: query.skip,
            sortBy: query.sort,
            order: query.order
        )
        return try await client.execute(ProductsQuery(variables: variables)).products
    }

    func product(id: Int) async throws -> Product {
        guard let product = try await client.execute(ProductDetailQuery(id: id)).product else {
            throw NetworkError.notFound("Product \(id)")
        }
        return product
    }

    func categories() async throws -> [String] {
        try await client.execute(CategoriesQuery()).categories
    }
}
