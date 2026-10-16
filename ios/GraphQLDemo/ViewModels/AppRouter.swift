import Foundation
import Observation

enum AppTab: Hashable {
    case products
    case carts
    case profile
}

enum CartSegment: String, CaseIterable, Identifiable {
    case mine = "My cart"
    case all = "All carts"
    var id: Self { self }
}

/// Which tab / cart segment is showing. Lets any screen jump to the cart ("View cart").
@MainActor
@Observable
final class AppRouter {
    var selectedTab: AppTab = .products
    var cartSegment: CartSegment = .mine

    func showMyCart() {
        cartSegment = .mine
        selectedTab = .carts
    }

    func showProducts() {
        selectedTab = .products
    }
}
