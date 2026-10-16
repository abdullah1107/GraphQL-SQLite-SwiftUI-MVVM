import Foundation
import Observation

/// "All carts" segment: every cart in the server DB (DummyJSON carts + users' own carts), paged.
@MainActor
@Observable
final class CartListViewModel {
    private(set) var carts: [Cart] = []
    private(set) var total = 0
    private(set) var hasMore = false
    private(set) var isLoading = false
    private(set) var isLoadingMore = false
    private(set) var hasLoaded = false
    var errorMessage: String?

    private let pageSize = 20
    private let cartService: any CartServicing
    private let session: SessionViewModel
    private var generation = 0

    init(cartService: any CartServicing, session: SessionViewModel) {
        self.cartService = cartService
        self.session = session
    }

    func loadIfNeeded() async {
        guard !hasLoaded else { return }
        await reload()
    }

    func reload() async {
        generation += 1
        let current = generation
        isLoading = carts.isEmpty
        errorMessage = nil
        do {
            let page = try await cartService.carts(limit: pageSize, skip: 0)
            guard current == generation else { return }
            carts = page.items
            total = page.total
            hasMore = page.hasMore
            hasLoaded = true
        } catch is CancellationError {
        } catch {
            if current == generation { errorMessage = session.message(for: error) }
        }
        if current == generation { isLoading = false }
    }

    func loadMoreIfNeeded(currentItem: Cart) async {
        guard hasMore, !isLoading, !isLoadingMore, currentItem.id == carts.last?.id else { return }
        let current = generation
        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let page = try await cartService.carts(limit: pageSize, skip: carts.count)
            guard current == generation else { return }
            let known = Set(carts.map(\.id))
            carts.append(contentsOf: page.items.filter { !known.contains($0.id) })
            total = page.total
            hasMore = page.hasMore
        } catch is CancellationError {
        } catch {
            if current == generation { errorMessage = session.message(for: error) }
        }
    }
}
