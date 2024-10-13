import SwiftUI

class PortfolioViewModel: ObservableObject {
    @Published var portfolioStocks = [StockInPortfolio]()

    func moveStocks(from source: IndexSet, to destination: Int) {
            portfolioStocks.move(fromOffsets: source, toOffset: destination)
            // Recalculate or update any derived data if necessary
        }
    
    func fetchPortfolio() {
        StockNetworkManager.shared.fetchPortfolioStocks { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let stocks):
                    self?.portfolioStocks = stocks
                case .failure(let error):
                    print("Error fetching portfolio: \(error)")
                }
            }
        }
    }
}
