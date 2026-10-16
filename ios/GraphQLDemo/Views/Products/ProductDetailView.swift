import SwiftUI

struct ProductDetailView: View {
    @State private var viewModel: ProductDetailViewModel
    @Environment(AppRouter.self) private var router

    init(productId: Int, container: AppContainer, session: SessionViewModel, cartStore: CartStore) {
        _viewModel = State(initialValue: ProductDetailViewModel(
            productId: productId,
            productService: container.productService,
            cartStore: cartStore,
            session: session
        ))
    }

    var body: some View {
        Group {
            if let product = viewModel.product {
                detail(product)
            } else if let message = viewModel.errorMessage {
                ErrorStateView(message: message) {
                    Task { await viewModel.load() }
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle(viewModel.product?.title ?? "Product")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.loadIfNeeded() }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    router.showMyCart()
                } label: {
                    Label("Cart", systemImage: "cart")
                }
            }
        }
        .sheet(item: $viewModel.addResult) { result in
            AddedToCartSheet(result: result) {
                viewModel.addResult = nil
                router.showMyCart()
            } onContinue: {
                viewModel.addResult = nil
            }
            .presentationDetents([.medium, .large])
        }
    }

    // MARK: - Sections

    private func detail(_ product: Product) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                gallery(product)

                VStack(alignment: .leading, spacing: 8) {
                    if let brand = product.brand {
                        Text(brand.uppercased())
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                    }
                    Text(product.title)
                        .font(.title2.bold())
                    PriceView(
                        price: product.price,
                        finalPrice: product.finalPrice,
                        discountPercentage: product.discountPercentage,
                        font: .title3.bold()
                    )
                    HStack {
                        if let rating = product.rating {
                            RatingView(rating: rating)
                        }
                        Spacer()
                        if let status = product.availabilityStatus {
                            Text(status)
                                .font(.caption.bold())
                                .foregroundStyle((product.stock ?? 1) <= 0 ? Color.red : Color.green)
                        }
                    }
                }

                if let description = product.description {
                    Text(description)
                        .font(.body)
                }

                if let tags = product.tags, !tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(tags, id: \.self) { tag in
                                Text("#\(tag)")
                                    .font(.caption)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Color(.secondarySystemBackground), in: Capsule())
                            }
                        }
                    }
                }

                specs(product)

                if let reviews = product.reviews, !reviews.isEmpty {
                    reviewsSection(reviews)
                }

                if let error = viewModel.errorMessage {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
            .padding()
        }
        .safeAreaInset(edge: .bottom) { addToCartBar }
    }

    private func gallery(_ product: Product) -> some View {
        TabView {
            ForEach(product.gallery, id: \.self) { url in
                RemoteImage(url: url)
                    .padding()
            }
        }
        .tabViewStyle(.page)
        .indexViewStyle(.page(backgroundDisplayMode: .always))
        .frame(height: 300)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func specs(_ product: Product) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Details").font(.headline)
            Group {
                if let category = product.category { LabeledContent("Category", value: category.prettyCategory) }
                if let stock = product.stock { LabeledContent("In stock", value: "\(stock)") }
                if let sku = product.sku { LabeledContent("SKU", value: sku) }
                if let weight = product.weight { LabeledContent("Weight", value: "\(weight.formatted()) g") }
                if let dimensions = product.dimensions { LabeledContent("Size (W×H×D)", value: dimensions.formatted) }
                if let warranty = product.warrantyInformation { LabeledContent("Warranty", value: warranty) }
                if let shipping = product.shippingInformation { LabeledContent("Shipping", value: shipping) }
                if let returns = product.returnPolicy { LabeledContent("Returns", value: returns) }
                if let minimum = product.minimumOrderQuantity { LabeledContent("Min. order", value: "\(minimum)") }
            }
            .font(.subheadline)
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private func reviewsSection(_ reviews: [Review]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Reviews (\(reviews.count))").font(.headline)
            ForEach(Array(reviews.enumerated()), id: \.offset) { _, review in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(review.reviewerName ?? "Anonymous").font(.subheadline.bold())
                        Spacer()
                        if let rating = review.rating {
                            RatingView(rating: Double(rating), showsValue: false)
                        }
                    }
                    if let comment = review.comment {
                        Text(comment).font(.subheadline)
                    }
                }
                .padding(.vertical, 4)
                Divider()
            }
        }
    }

    private var addToCartBar: some View {
        VStack(spacing: 8) {
            if viewModel.inCartQuantity > 0 {
                HStack {
                    Label("\(viewModel.inCartQuantity) already in your cart", systemImage: "cart.fill")
                    Spacer()
                    Button("View cart") { router.showMyCart() }
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
            }

            HStack(spacing: 16) {
                Stepper(value: $viewModel.quantity, in: 1...viewModel.maxQuantity) {
                    Text("Qty \(viewModel.quantity)")
                        .font(.headline)
                        .monospacedDigit()
                }
                .fixedSize()
                .disabled(!viewModel.canAdd)

                Button {
                    Task { await viewModel.addToCart() }
                } label: {
                    HStack {
                        if viewModel.isAddingToCart {
                            ProgressView().tint(.white)
                        }
                        if viewModel.availableToAdd == 0 {
                            Text(viewModel.inCartQuantity > 0 ? "All stock in cart" : "Out of stock").bold()
                        } else {
                            Text("Add · \(viewModel.selectionTotal.asCurrency)").bold()
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!viewModel.canAdd)
            }
        }
        .padding()
        .background(.bar)
    }
}

#Preview {
    let container = AppContainer.preview()
    let session = SessionViewModel(authService: container.authService)
    return NavigationStack {
        ProductDetailView(
            productId: 1,
            container: container,
            session: session,
            cartStore: CartStore(cartService: container.cartService, session: session)
        )
    }
    .environment(AppRouter())
}
