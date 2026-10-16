import Foundation

/// `query Products` — paged, searchable product list served from the server's SQLite DB.
struct ProductsQuery: GraphQLOperation {
    static let operationName = "Products"
    static let document = """
    query Products(
      $search: String
      $category: String
      $limit: Int
      $skip: Int
      $sortBy: ProductSort
      $order: SortOrder
    ) {
      products(
        search: $search
        category: $category
        limit: $limit
        skip: $skip
        sortBy: $sortBy
        order: $order
      ) {
        total
        skip
        limit
        hasMore
        items { ...ProductCard }
      }
    }
    """ + "\n" + GraphQLFragments.productCard

    /// `nil` values are left out of the JSON, so the server's defaults apply.
    struct Variables: Encodable, Sendable {
        var search: String?
        var category: String?
        var limit: Int?
        var skip: Int?
        var sortBy: ProductSort?
        var order: SortOrder?
    }

    struct Response: Decodable, Sendable {
        let products: Page<Product>
    }

    let variables: Variables
}

/// `query ProductDetail` — one product with images, specs and reviews.
struct ProductDetailQuery: GraphQLOperation {
    static let operationName = "ProductDetail"
    static let document = """
    query ProductDetail($id: Int!) {
      product(id: $id) {
        ...ProductCard
        ...ProductDetail
      }
    }
    """ + "\n" + GraphQLFragments.productCard + "\n" + GraphQLFragments.productDetail

    struct Variables: Encodable, Sendable {
        let id: Int
    }

    struct Response: Decodable, Sendable {
        let product: Product?
    }

    let variables: Variables

    init(id: Int) {
        variables = Variables(id: id)
    }
}

/// `query Categories` — distinct categories found in the products table.
struct CategoriesQuery: GraphQLOperation {
    typealias Variables = EmptyVariables

    static let operationName = "Categories"
    static let document = """
    query Categories {
      categories
    }
    """

    struct Response: Decodable, Sendable {
        let categories: [String]
    }
}
