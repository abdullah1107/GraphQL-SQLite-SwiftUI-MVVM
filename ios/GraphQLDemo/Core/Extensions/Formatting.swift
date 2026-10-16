import Foundation

extension Double {
    /// 12.5 → "$12.50"
    var asCurrency: String {
        formatted(.currency(code: "USD"))
    }

    /// 12.48 → "12%"
    var asPercent: String {
        (self / 100).formatted(.percent.precision(.fractionLength(0)))
    }
}

extension String {
    /// "home-decoration" → "Home Decoration"
    var prettyCategory: String {
        replacingOccurrences(of: "-", with: " ").capitalized
    }
}
