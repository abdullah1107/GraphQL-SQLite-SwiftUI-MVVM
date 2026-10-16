import SwiftUI

struct MainTabView: View {
    let container: AppContainer
    let session: SessionViewModel

    @State private var router = AppRouter()
    /// One cart shared by Products, Product detail and the Carts tab.
    @State private var cartStore: CartStore

    init(container: AppContainer, session: SessionViewModel) {
        self.container = container
        self.session = session
        _cartStore = State(initialValue: CartStore(cartService: container.cartService, session: session))
    }

    var body: some View {
        TabView(selection: $router.selectedTab) {
            ProductListView(container: container, session: session, cartStore: cartStore)
                .tabItem { Label("Products", systemImage: "bag") }
                .tag(AppTab.products)

            CartListView(container: container, session: session, cartStore: cartStore)
                .tabItem { Label("Cart", systemImage: "cart") }
                .badge(cartStore.itemCount)
                .tag(AppTab.carts)

            ProfileView(container: container, session: session)
                .tabItem { Label("Profile", systemImage: "person.crop.circle") }
                .tag(AppTab.profile)
        }
        .environment(router)
        .task { await cartStore.load() }
    }
}

#Preview {
    let container = AppContainer.preview()
    let session = SessionViewModel(authService: container.authService)
    session.didLogin(PreviewData.user)
    return MainTabView(container: container, session: session)
}
