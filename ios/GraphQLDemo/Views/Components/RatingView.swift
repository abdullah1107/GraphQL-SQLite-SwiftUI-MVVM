import SwiftUI

/// ★★★★☆ 4.2
struct RatingView: View {
    let rating: Double
    var showsValue = true

    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { index in
                Image(systemName: symbol(for: index))
                    .foregroundStyle(.yellow)
            }
            if showsValue {
                Text(rating, format: .number.precision(.fractionLength(1)))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 2)
            }
        }
        .font(.caption)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Rated \(String(format: "%.1f", rating)) out of 5")
    }

    private func symbol(for index: Int) -> String {
        let value = rating - Double(index - 1)
        if value >= 0.75 { return "star.fill" }
        if value >= 0.25 { return "star.leadinghalf.filled" }
        return "star"
    }
}

#Preview {
    RatingView(rating: 3.6)
}
