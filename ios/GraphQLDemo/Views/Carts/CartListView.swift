import SwiftUI

/// Carts tab: "My cart" (editable, shared CartStore) and "All carts" (everything in the server DB).
struct CartListView: View {
    @State private var viewModel: CartListViewModel
    @Environment(AppRouter.self) private var router
    private let container: AppContainer
    private let session: SessionViewModel
    private let cartStore: CartStore

    init(container: AppContainer, session: SessionViewModel, cartStore: CartStore) {
        self.container = container
        self.session = session
        self.cartStore = cartStore
        _viewModel = State(initialValue: CartListViewModel(cartService: container.cartService, session: session))
    }

    var body: some View {
        @Bindable var router = router
        NavigationStack {
            Group {
                switch router.cartSegment {
                case .mine:
                    MyCartView(cartStore: cartStore)
                case .all:
                    allCarts
                }
            }
            .navigationTitle("Carts")
            .safeAreaInset(edge: .top, spacing: 0) {
                Picker("Show", selection: $router.cartSegment) {
                    ForEach(CartSegment.allCases) { segment in
                        Text(segment.rawValue).tag(segment)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(.bar)
            }
            .navigationDestination(for: Cart.self) { cart in
                if cart.id == cartStore.cart?.id {
                    // Tapping your own cart in "All carts" opens the live, editable version.
                    MyCartView(cartStore: cartStore)
                        .navigationTitle("My cart")
                } else {
                    CartDetailView(cart: cart, container: container, session: session)
                }
            }
            .task(id: router.cartSegment) {
                switch router.cartSegment {
                case .mine: await cartStore.load()          // always fresh prices
                case .all: await viewModel.loadIfNeeded()
                }
            }
        }
    }

    @ViewBuilder
    private var allCarts: some View {
        if viewModel.carts.isEmpty {
            if viewModel.isLoading || !viewModel.hasLoaded && viewModel.errorMessage == nil {
                ProgressView("Loading carts…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let message = viewModel.errorMessage {
                ErrorStateView(message: message) {
                    Task { await viewModel.reload() }
                }
            } else {
                ContentUnavailableView(
                    "No carts",
                    systemImage: "cart",
                    description: Text("Sync the database from the Profile tab.")
                )
            }
        } else {
            List {
                ForEach(viewModel.carts) { cart in
                    NavigationLink(value: cart) {
                        CartRowView(cart: cart.id == cartStore.cart?.id ? (cartStore.cart ?? cart) : cart)
                    }
                    .task { await viewModel.loadMoreIfNeeded(currentItem: cart) }
                }

                if viewModel.isLoadingMore {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                }

                if let message = viewModel.errorMessage {
                    Label(message, systemImage: "exclamationmark.triangle")
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                Text("Showing \(viewModel.carts.count) of \(viewModel.total) carts")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .listRowSeparator(.hidden)
            }
            .listStyle(.plain)
            .refreshable { await viewModel.reload() }
        }
    }
}

#Preview {
    let container = AppContainer.preview()
    let session = SessionViewModel(authService: container.authService)
    return CartListView(
        container: container,
        session: session,
        cartStore: CartStore(cartService: container.cartService, session: session)
    )
    .environment(AppRouter())
}
