import Foundation

protocol CartServicing: Sendable {
    // Read
    func carts(limit: Int, skip: Int) async throws -> Page<Cart>
    func cart(id: Int) async throws -> Cart
    func myCarts() async throws -> [Cart]
    func myCart() async throws -> Cart?

    // The logged-in user's cart — every call returns the updated cart
    func addToCart(productId: Int, quantity: Int) async throws -> Cart
    func updateItem(productId: Int, quantity: Int) async throws -> Cart
    func removeItem(productId: Int) async throws -> Cart
    func clear() async throws -> Cart
}

struct CartService: CartServicing {
    let client: any GraphQLClientProtocol

    func carts(limit: Int, skip: Int) async throws -> Page<Cart> {
        try await client.execute(CartsQuery(variables: .init(limit: limit, skip: skip))).carts
    }

    func cart(id: Int) async throws -> Cart {
        guard let cart = try await client.execute(CartQuery(id: id)).cart else {
            throw NetworkError.notFound("Cart \(id)")
        }
        return cart
    }

    func myCarts() async throws -> [Cart] {
        try await client.execute(MyCartsQuery()).myCarts
    }

    func myCart() async throws -> Cart? {
        try await client.execute(MyCartQuery()).myCart
    }

    func addToCart(productId: Int, quantity: Int) async throws -> Cart {
        try await client.execute(AddToCartMutation(productId: productId, quantity: quantity)).addToCart
    }

    func updateItem(productId: Int, quantity: Int) async throws -> Cart {
        try await client.execute(UpdateCartItemMutation(productId: productId, quantity: quantity)).updateCartItem
    }

    func removeItem(productId: Int) async throws -> Cart {
        try await client.execute(RemoveFromCartMutation(productId: productId)).removeFromCart
    }

    func clear() async throws -> Cart {
        try await client.execute(ClearCartMutation()).clearCart
    }
}
