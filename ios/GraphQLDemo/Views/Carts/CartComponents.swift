import SwiftUI

/// One cart line: thumbnail, title, brand/category, unit price (with discount), quantity and line total.
/// Pass `onQuantityChange` to make it editable (stepper); leave it nil for read-only carts.
struct CartLineRow: View {
    let item: CartItem
    var isBusy = false
    var onQuantityChange: ((Int) -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            RemoteImage(url: item.thumbnail)
                .frame(width: 64, height: 64)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.subheadline.bold())
                    .lineLimit(2)

                if let details = detailsText {
                    Text(details)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                // Unit price
                HStack(spacing: 4) {
                    Text(item.finalPrice.asCurrency)
                    if item.hasDiscount {
                        Text(item.price.asCurrency)
                            .strikethrough()
                            .foregroundStyle(.secondary)
                        Text("-\(item.discountPercentage.asPercent)")
                            .foregroundStyle(.green)
                    }
                    Text("each").foregroundStyle(.secondary)
                }
                .font(.caption)

                if let stock = item.product?.stock, stock <= 5 {
                    Text("Only \(stock) left in stock")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }

                HStack {
                    if let onQuantityChange {
                        Stepper(
                            "Quantity",
                            value: Binding(get: { item.quantity }, set: { onQuantityChange($0) }),
                            in: 0...item.maxQuantity
                        )
                        .labelsHidden()
                        .disabled(isBusy)
                        Text("× \(item.quantity)")
                            .font(.subheadline.monospacedDigit())
                    } else {
                        Text("Qty \(item.quantity)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if isBusy {
                        ProgressView()
                    } else {
                        VStack(alignment: .trailing, spacing: 0) {
                            Text(item.discountedTotal.asCurrency)
                                .font(.subheadline.bold())
                            if item.savings > 0.01 {
                                Text(item.total.asCurrency)
                                    .font(.caption2)
                                    .strikethrough()
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var detailsText: String? {
        let parts = [item.product?.brand, item.product?.category?.prettyCategory].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

/// Subtotal / discount / total block shared by the cart screens and the add-to-cart sheet.
struct CartTotalsView: View {
    let cart: Cart

    var body: some View {
        LabeledContent("Products", value: "\(cart.totalProducts)")
        LabeledContent("Items", value: "\(cart.totalQuantity)")
        LabeledContent("Subtotal", value: cart.total.asCurrency)
        if cart.savings > 0.01 {
            LabeledContent("Discount") {
                Text("-\(cart.savings.asCurrency)").foregroundStyle(.green)
            }
        }
        LabeledContent("Total") {
            Text(cart.discountedTotal.asCurrency)
                .font(.headline)
                .foregroundStyle(.primary)
        }
    }
}

/// Shown after "Add to cart": what was added and the updated cart totals.
struct AddedToCartSheet: View {
    let result: CartStore.AddResult
    let onViewCart: () -> Void
    let onContinue: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title)
                            .foregroundStyle(.green)
                        VStack(alignment: .leading) {
                            Text("Added \(result.addedQuantity) × \(result.productTitle)")
                                .font(.headline)
                            if let line = result.line, line.quantity > result.addedQuantity {
                                Text("You now have \(line.quantity) in your cart.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                if let line = result.line {
                    Section("This product") {
                        CartLineRow(item: line)
                    }
                }

                Section("Updated cart") {
                    CartTotalsView(cart: result.cart)
                }
            }
            .navigationTitle("Cart updated")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                HStack(spacing: 12) {
                    Button("Continue shopping", action: onContinue)
                        .buttonStyle(.bordered)
                    Button(action: onViewCart) {
                        Text("View cart").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .controlSize(.large)
                .padding()
                .background(.bar)
            }
        }
    }
}

#Preview("Line") {
    List {
        CartLineRow(item: PreviewData.cart(id: 1, isLocal: true).items[0]) { _ in }
        CartLineRow(item: PreviewData.cart(id: 1, isLocal: true).items[1])
    }
}

#Preview("Added sheet") {
    let cart = PreviewData.cart(id: 100_000, isLocal: true)
    return AddedToCartSheet(
        result: CartStore.AddResult(
            productTitle: cart.items[0].title,
            thumbnail: cart.items[0].thumbnail,
            addedQuantity: 1,
            line: cart.items[0],
            cart: cart
        ),
        onViewCart: {},
        onContinue: {}
    )
}
