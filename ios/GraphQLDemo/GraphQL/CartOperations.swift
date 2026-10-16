import Foundation

/// `query Carts` — every cart in the DB (synced from DummyJSON /carts), paged.
struct CartsQuery: GraphQLOperation {
    static let operationName = "Carts"
    static let document = """
    query Carts($userId: Int, $limit: Int, $skip: Int) {
      carts(userId: $userId, limit: $limit, skip: $skip) {
        total
        skip
        limit
        hasMore
        items { ...CartFields }
      }
    }
    """ + "\n" + GraphQLFragments.cartFields

    struct Variables: Encodable, Sendable {
        var userId: Int?
        var limit: Int?
        var skip: Int?
    }

    struct Response: Decodable, Sendable {
        let carts: Page<Cart>
    }

    let variables: Variables
}

/// `query Cart` — one cart by id (used to refresh a cart's detail screen).
struct CartQuery: GraphQLOperation {
    static let operationName = "Cart"
    static let document = """
    query Cart($id: Int!) {
      cart(id: $id) { ...CartFields }
    }
    """ + "\n" + GraphQLFragments.cartFields

    struct Variables: Encodable, Sendable {
        let id: Int
    }

    struct Response: Decodable, Sendable {
        let cart: Cart?
    }

    let variables: Variables

    init(id: Int) {
        variables = Variables(id: id)
    }
}

/// `query MyCart` — the logged-in user's shopping cart with prices refreshed from the catalogue.
/// `null` until the user adds something.
struct MyCartQuery: GraphQLOperation {
    typealias Variables = EmptyVariables

    static let operationName = "MyCart"
    static let document = """
    query MyCart {
      myCart { ...CartFields }
    }
    """ + "\n" + GraphQLFragments.cartFields

    struct Response: Decodable, Sendable {
        let myCart: Cart?
    }
}

/// `query MyCarts` — every cart of the logged-in user (their own cart + DummyJSON carts with their userId).
struct MyCartsQuery: GraphQLOperation {
    typealias Variables = EmptyVariables

    static let operationName = "MyCarts"
    static let document = """
    query MyCarts {
      myCarts { ...CartFields }
    }
    """ + "\n" + GraphQLFragments.cartFields

    struct Response: Decodable, Sendable {
        let myCarts: [Cart]
    }
}

/// `mutation AddToCart` — adds a product (or increases its quantity) and returns the updated cart.
struct AddToCartMutation: GraphQLOperation {
    static let operationName = "AddToCart"
    static let document = """
    mutation AddToCart($productId: Int!, $quantity: Int) {
      addToCart(productId: $productId, quantity: $quantity) { ...CartFields }
    }
    """ + "\n" + GraphQLFragments.cartFields

    struct Variables: Encodable, Sendable {
        let productId: Int
        let quantity: Int
    }

    struct Response: Decodable, Sendable {
        let addToCart: Cart
    }

    let variables: Variables

    init(productId: Int, quantity: Int) {
        variables = Variables(productId: productId, quantity: quantity)
    }
}

/// `mutation UpdateCartItem` — sets a line's quantity; 0 removes it.
struct UpdateCartItemMutation: GraphQLOperation {
    static let operationName = "UpdateCartItem"
    static let document = """
    mutation UpdateCartItem($productId: Int!, $quantity: Int!) {
      updateCartItem(productId: $productId, quantity: $quantity) { ...CartFields }
    }
    """ + "\n" + GraphQLFragments.cartFields

    struct Variables: Encodable, Sendable {
        let productId: Int
        let quantity: Int
    }

    struct Response: Decodable, Sendable {
        let updateCartItem: Cart
    }

    let variables: Variables

    init(productId: Int, quantity: Int) {
        variables = Variables(productId: productId, quantity: quantity)
    }
}

/// `mutation RemoveFromCart` — deletes one product line from the user's cart.
struct RemoveFromCartMutation: GraphQLOperation {
    static let operationName = "RemoveFromCart"
    static let document = """
    mutation RemoveFromCart($productId: Int!) {
      removeFromCart(productId: $productId) { ...CartFields }
    }
    """ + "\n" + GraphQLFragments.cartFields

    struct Variables: Encodable, Sendable {
        let productId: Int
    }

    struct Response: Decodable, Sendable {
        let removeFromCart: Cart
    }

    let variables: Variables

    init(productId: Int) {
        variables = Variables(productId: productId)
    }
}

/// `mutation ClearCart` — deletes every item in the user's cart.
struct ClearCartMutation: GraphQLOperation {
    typealias Variables = EmptyVariables

    static let operationName = "ClearCart"
    static let document = """
    mutation ClearCart {
      clearCart { ...CartFields }
    }
    """ + "\n" + GraphQLFragments.cartFields

    struct Response: Decodable, Sendable {
        let clearCart: Cart
    }
}
