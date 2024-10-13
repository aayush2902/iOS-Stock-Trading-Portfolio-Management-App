import Foundation

struct StockOwnership: Codable {
    var symbol: String
    var quantity: Int
    var averageCostPerShare: Double
    var totalCost: Double
    var marketValue: Double
    var change: Double
}

// Add additional functionalities related to stock ownership here if needed, such as:
// - Computed properties for display
// - Fetching from a database or network call
// - Calculations specific to stock ownership
