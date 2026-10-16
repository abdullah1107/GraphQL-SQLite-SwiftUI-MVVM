import SwiftUI

struct ProductListView: View {
    @State private var viewModel: ProductListViewModel
    private let container: AppContainer
    private let session: SessionViewModel
    private let cartStore: CartStore

    init(container: AppContainer, session: SessionViewModel, cartStore: CartStore) {
        self.container = container
        self.session = session
        self.cartStore = cartStore
        _viewModel = State(initialValue: ProductListViewModel(
            productService: container.productService,
            session: session
        ))
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Products")
                .searchable(text: $viewModel.searchText, prompt: "Search title, brand, description")
                .toolbar { sortMenu }
                .safeAreaInset(edge: .top, spacing: 0) { categoryBar }
                .navigationDestination(for: Int.self) { productId in
                    ProductDetailView(productId: productId, container: container, session: session, cartStore: cartStore)
                }
                .task { await viewModel.loadCategoriesIfNeeded() }
                .task(id: viewModel.filterKey) {
                    // Debounce typing / filter taps; the very first load runs immediately.
                    if viewModel.hasLoadedOnce && viewModel.needsReload {
                        try? await Task.sleep(for: .milliseconds(350))
                        guard !Task.isCancelled else { return }
                    }
                    await viewModel.loadIfNeeded()
                }
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if viewModel.products.isEmpty {
            if viewModel.isLoading || !viewModel.hasLoadedOnce && viewModel.errorMessage == nil {
                ProgressView("Loading products…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let message = viewModel.errorMessage {
                ErrorStateView(message: message) {
                    Task { await viewModel.reload() }
                }
            } else {
                ContentUnavailableView {
                    Label("No products", systemImage: "magnifyingglass")
                } description: {
                    Text("Nothing matches your filters.")
                } actions: {
                    Button("Clear filters") { viewModel.clearFilters() }
                }
            }
        } else {
            productList
        }
    }

    private var productList: some View {
        List {
            ForEach(viewModel.products) { product in
                NavigationLink(value: product.id) {
                    ProductRowView(product: product, inCartQuantity: cartStore.quantity(of: product.id))
                }
                .task { await viewModel.loadMoreIfNeeded(currentItem: product) }
            }

            if viewModel.isLoadingMore {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .listRowSeparator(.hidden)
            }

            if let message = viewModel.errorMessage {
                Label(message, systemImage: "exclamationmark.triangle")
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            Text("Showing \(viewModel.products.count) of \(viewModel.total) products")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .listRowSeparator(.hidden)
        }
        .listStyle(.plain)
        .refreshable { await viewModel.reload() }
    }

    // MARK: - Filters

    private var categoryBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                CategoryChip(title: "All", isSelected: viewModel.selectedCategory == nil) {
                    viewModel.selectedCategory = nil
                }
                ForEach(viewModel.categories, id: \.self) { category in
                    CategoryChip(title: category.prettyCategory, isSelected: viewModel.selectedCategory == category) {
                        viewModel.selectedCategory = category
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(.bar)
    }

    private var sortMenu: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Picker("Sort by", selection: $viewModel.sort) {
                    ForEach(ProductSort.allCases) { sort in
                        Text(sort.label).tag(sort)
                    }
                }
                Picker("Order", selection: $viewModel.order) {
                    ForEach(SortOrder.allCases) { order in
                        Text(order.label).tag(order)
                    }
                }
            } label: {
                Label("Sort", systemImage: "arrow.up.arrow.down.circle")
            }
        }
    }
}

private struct CategoryChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(isSelected ? .semibold : .regular))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.accentColor : Color(.secondarySystemBackground), in: Capsule())
                .foregroundStyle(isSelected ? Color.white : Color.primary)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    let container = AppContainer.preview()
    let session = SessionViewModel(authService: container.authService)
    return ProductListView(
        container: container,
        session: session,
        cartStore: CartStore(cartService: container.cartService, session: session)
    )
    .environment(AppRouter())
}
