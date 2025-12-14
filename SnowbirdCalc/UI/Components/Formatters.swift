import Foundation

/// Shared formatters for consistent formatting across the app
enum Formatters {
    /// Currency formatter for USD with whole dollars only
    static let currency: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "en_US")
        formatter.maximumFractionDigits = 0
        return formatter
    }()
    
    /// Format a percentage value (handles both 0-1 and 0-100 ranges)
    /// - Parameter value: The percentage value (0-1 or 0-100)
    /// - Returns: Formatted percentage string
    static func percent(_ value: Double) -> String {
        // Heuristic: if value <= 1 treat as 0–1, else assume 0–100
        let v = (value <= 1.0) ? value : (value / 100.0)
        return v.formatted(.percent.precision(.fractionLength(1)))
    }
    
    /// Format a dollar amount
    /// - Parameter value: The dollar amount
    /// - Returns: Formatted currency string
    static func dollar(_ value: Double) -> String {
        return currency.string(from: NSNumber(value: value)) ?? "$0"
    }
}

