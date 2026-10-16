import SwiftUI

/// Read-only view of a cart from "All carts" (DummyJSON data or another user's cart).
struct CartDetailView: View {
    @State private var viewModel: CartDetailViewModel

    init(cart: Cart, container: AppContainer, session: SessionViewModel) {
        _viewModel = State(initialValue: CartDetailViewModel(
            cart: cart,
            cartService: container.cartService,
            session: session
        ))
    }

    var body: some View {
        List {
            Section {
                Label(
                    viewModel.cart.isLocal
                        ? "Another user's cart (read-only)."
                        : "This cart comes from DummyJSON and is read-only.",
                    systemImage: "lock"
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
            }

            Section("Items") {
                if viewModel.cart.items.isEmpty {
                    Text("This cart is empty.")
                        .foregroundStyle(.secondary)
                }
                ForEach(viewModel.cart.items) { item in
                    CartLineRow(item: item)
                }
            }

            Section("Summary") {
                LabeledContent("User", value: "#\(viewModel.cart.userId)")
                CartTotalsView(cart: viewModel.cart)
            }

            if let error = viewModel.errorMessage {
                Section {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Cart #\(viewModel.cart.id)")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await viewModel.refresh() }
    }
}

#Preview {
    let container = AppContainer.preview()
    return NavigationStack {
        CartDetailView(
            cart: PreviewData.cart(id: 1, isLocal: false),
            container: container,
            session: SessionViewModel(authService: container.authService)
        )
    }
}
