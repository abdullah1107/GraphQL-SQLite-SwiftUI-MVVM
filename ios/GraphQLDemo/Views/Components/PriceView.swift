import SwiftUI

/// Final price, the struck-through original price and a discount badge.
struct PriceView: View {
    let price: Double
    let finalPrice: Double
    let discountPercentage: Double?
    var font: Font = .headline

    private var hasDiscount: Bool { (discountPercentage ?? 0) > 0.01 && finalPrice < price }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(finalPrice.asCurrency)
                .font(font)
                .foregroundStyle(.primary)
            if hasDiscount {
                Text(price.asCurrency)
                    .font(.caption)
                    .strikethrough()
                    .foregroundStyle(.secondary)
                Text("-\((discountPercentage ?? 0).asPercent)")
                    .font(.caption2.bold())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.green.opacity(0.15), in: Capsule())
                    .foregroundStyle(.green)
            }
        }
    }
}

#Preview {
    PriceView(price: 19.99, finalPrice: 17.99, discountPercentage: 10)
}
