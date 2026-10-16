import SwiftUI

struct CartRowView: View {
    let cart: Cart

    var body: some View {
        HStack(spacing: 12) {
            thumbnails

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("Cart #\(cart.id)")
                        .font(.headline)
                    if cart.isLocal {
                        Text("YOURS")
                            .font(.caption2.bold())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.15), in: Capsule())
                            .foregroundStyle(Color.accentColor)
                    }
                }
                Text("User \(cart.userId) · \(cart.totalProducts) products · \(cart.totalQuantity) items")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(cart.discountedTotal.asCurrency)
                    .font(.headline)
                if cart.savings > 0.01 {
                    Text(cart.total.asCurrency)
                        .font(.caption)
                        .strikethrough()
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    /// Up to three overlapping product thumbnails.
    private var thumbnails: some View {
        ZStack {
            ForEach(Array(cart.items.prefix(3).enumerated()), id: \.element.id) { index, item in
                RemoteImage(url: item.thumbnail, contentMode: .fill)
                    .frame(width: 40, height: 40)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 2))
                    .offset(x: CGFloat(index) * 12)
            }
        }
        .frame(width: 70, height: 44, alignment: .leading)
    }
}

#Preview {
    List {
        CartRowView(cart: PreviewData.cart(id: 1, isLocal: true))
        CartRowView(cart: PreviewData.cart(id: 2, isLocal: false))
    }
}
