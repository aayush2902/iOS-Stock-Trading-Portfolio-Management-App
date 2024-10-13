import SwiftUI

class WalletViewModel: ObservableObject {
    @Published var walletBalance: Double = 0.0
    @Published var netWorth: Double = 0.0
    @Published var totalMarketValue: Double = 0.0

    func fetchWalletBalance() {
        StockNetworkManager.shared.fetchWalletBalance { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let balance):
                    self?.walletBalance = balance
                    self?.calculateNetWorth()
                case .failure(let error):
                    print("Error fetching wallet balance: \(error)")
                    // Handle error, maybe set a default value or show an error message
                }
            }
        }
    }

    func fetchPortfolioStocks() {
        StockNetworkManager.shared.fetchPortfolioStocks { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let stocks):
                    self?.totalMarketValue = stocks.reduce(0) { $0 + ($1.currentPrice * Double($1.quantity)) }
                    self?.calculateNetWorth()
                case .failure(let error):
                    print("Error fetching portfolio stocks: \(error)")
                    // Handle error, maybe set a default value or show an error message
                }
            }
        }
    }

    private func calculateNetWorth() {
        netWorth = walletBalance + totalMarketValue
    }
}
