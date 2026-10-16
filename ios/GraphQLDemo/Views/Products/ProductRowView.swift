import SwiftUI

struct ProductRowView: View {
    let product: Product
    /// Units of this product already in the user's cart.
    var inCartQuantity: Int = 0

    var body: some View {
        HStack(spacing: 12) {
            RemoteImage(url: product.thumbnail)
                .frame(width: 72, height: 72)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 4) {
                Text(product.title)
                    .font(.headline)
                    .lineLimit(2)

                Text([product.brand, product.category?.prettyCategory].compactMap { $0 }.joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                PriceView(
                    price: product.price,
                    finalPrice: product.finalPrice,
                    discountPercentage: product.discountPercentage,
                    font: .subheadline.bold()
                )

                HStack {
                    if let rating = product.rating {
                        RatingView(rating: rating)
                    }
                    Spacer()
                    if inCartQuantity > 0 {
                        Label("\(inCartQuantity) in cart", systemImage: "cart.fill")
                            .font(.caption2.bold())
                            .foregroundStyle(Color.accentColor)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    List {
        ProductRowView(product: PreviewData.products[0])
        ProductRowView(product: PreviewData.products[1], inCartQuantity: 2)
    }
}
