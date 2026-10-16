import SwiftUI

/// The logged-in user's cart: item details, quantity steppers, swipe-to-delete and "Delete all".
struct MyCartView: View {
    let cartStore: CartStore
    @Environment(AppRouter.self) private var router
    @State private var confirmDeleteAll = false

    var body: some View {
        Group {
            if cartStore.isLoading && !cartStore.hasLoaded {
                ProgressView("Loading your cart…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let message = cartStore.errorMessage, !cartStore.hasLoaded {
                ErrorStateView(message: message) {
                    Task { await cartStore.load() }
                }
            } else if cartStore.isEmpty {
                ContentUnavailableView {
                    Label("Your cart is empty", systemImage: "cart")
                } description: {
                    Text("Open a product and tap “Add”.")
                } actions: {
                    Button("Browse products") { router.showProducts() }
                        .buttonStyle(.borderedProminent)
                }
            } else {
                cartList
            }
        }
        .refreshable { await cartStore.load() }
        .confirmationDialog(
            "Delete all items from your cart?",
            isPresented: $confirmDeleteAll,
            titleVisibility: .visible
        ) {
            Button("Delete all \(cartStore.itemCount) items", role: .destructive) {
                Task { await cartStore.clear() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This can't be undone.")
        }
    }

    private var cartList: some View {
        List {
            Section {
                ForEach(cartStore.items) { item in
                    CartLineRow(item: item, isBusy: cartStore.isBusy(item.productId)) { newQuantity in
                        Task { await cartStore.setQuantity(newQuantity, for: item) }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            Task { await cartStore.remove(item) }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            } header: {
                Text("Items")
            } footer: {
                Text("Swipe left to delete an item. Set quantity to 0 to remove it.")
            }

            if let cart = cartStore.cart {
                Section {
                    CartTotalsView(cart: cart)
                } header: {
                    Text("Summary")
                } footer: {
                    if let date = cart.updatedDate {
                        Text("Prices refreshed \(date.formatted(.relative(presentation: .named))) from the product catalogue.")
                    }
                }
            }

            if let error = cartStore.errorMessage {
                Section {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                }
            }

            Section {
                Button(role: .destructive) {
                    confirmDeleteAll = true
                } label: {
                    HStack {
                        Label("Delete all items", systemImage: "trash")
                        Spacer()
                        if cartStore.isClearing { ProgressView() }
                    }
                }
                .disabled(cartStore.isClearing)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .destructive) {
                    confirmDeleteAll = true
                } label: {
                    Label("Delete all", systemImage: "trash")
                }
                .disabled(cartStore.isClearing)
            }
        }
    }
}

#Preview {
    let container = AppContainer.preview()
    let session = SessionViewModel(authService: container.authService)
    let store = CartStore(cartService: container.cartService, session: session)
    return NavigationStack {
        MyCartView(cartStore: store)
            .task { await store.load() }
    }
    .environment(AppRouter())
}
