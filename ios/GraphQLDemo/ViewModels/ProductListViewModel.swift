import Foundation
import Observation

@MainActor
@Observable
final class ProductListViewModel {
    // Output
    private(set) var products: [Product] = []
    private(set) var categories: [String] = []
    private(set) var total = 0
    private(set) var hasMore = false
    private(set) var isLoading = false
    private(set) var isLoadingMore = false
    var errorMessage: String?

    // Input (bound to the UI)
    var searchText = ""
    var selectedCategory: String?
    var sort: ProductSort = .id
    var order: SortOrder = .asc

    private let pageSize = 20
    private let productService: any ProductServicing
    private let session: SessionViewModel
    /// Bumped on every reload so late responses from an older search are ignored.
    private var generation = 0
    /// Filters used for the products currently on screen.
    private var loadedKey: String?

    init(productService: any ProductServicing, session: SessionViewModel) {
        self.productService = productService
        self.session = session
    }

    /// Changes whenever a filter changes. The view runs `.task(id: filterKey)` to (debounced) reload.
    var filterKey: String {
        "\(searchText)|\(selectedCategory ?? "")|\(sort.rawValue)|\(order.rawValue)"
    }

    var needsReload: Bool { loadedKey != filterKey }
    var hasLoadedOnce: Bool { loadedKey != nil }

    func loadCategoriesIfNeeded() async {
        guard categories.isEmpty else { return }
        do {
            categories = try await productService.categories()
        } catch {
            // Categories are optional UI; the list shows its own error if the server is down.
        }
    }

    func loadIfNeeded() async {
        guard needsReload else { return }
        await reload()
    }

    /// Fetch page 1 for the current filters (also used by pull-to-refresh).
    func reload() async {
        generation += 1
        let current = generation
        let key = filterKey
        isLoading = true
        errorMessage = nil

        do {
            let page = try await productService.products(query(skip: 0))
            guard current == generation else { return }
            products = page.items
            total = page.total
            hasMore = page.hasMore
            loadedKey = key
        } catch is CancellationError {
            // A newer search replaced this one.
        } catch {
            if current == generation { errorMessage = session.message(for: error) }
        }
        if current == generation { isLoading = false }
    }

    /// Infinite scroll: when the last row appears, fetch the next page.
    func loadMoreIfNeeded(currentItem: Product) async {
        guard hasMore, !isLoading, !isLoadingMore, currentItem.id == products.last?.id else { return }
        let current = generation
        isLoadingMore = true
        defer { isLoadingMore = false }

        do {
            let page = try await productService.products(query(skip: products.count))
            guard current == generation else { return }
            let known = Set(products.map(\.id))
            products.append(contentsOf: page.items.filter { !known.contains($0.id) })
            total = page.total
            hasMore = page.hasMore
        } catch is CancellationError {
        } catch {
            if current == generation { errorMessage = session.message(for: error) }
        }
    }

    func clearFilters() {
        searchText = ""
        selectedCategory = nil
        sort = .id
        order = .asc
    }

    private func query(skip: Int) -> ProductQuery {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return ProductQuery(
            search: trimmed.isEmpty ? nil : trimmed,
            category: selectedCategory,
            sort: sort,
            order: order,
            limit: pageSize,
            skip: skip
        )
    }
}
