import Foundation

struct StockInPortfolio: Codable {
    let symbol: String
    let name: String
    let quantity: Int
    let totalCost: Double
    let averageCostPerShare: Double
    let currentPrice: Double
    let change: Double
    let marketValue: Double
}

struct Wallet: Codable {
    let balance: Double
}

class StockNetworkManager {
    static let shared = StockNetworkManager()
    private init() {}  // Private initializer for Singleton

    func fetchWalletBalance(completion: @escaping (Result<Double, Error>) -> Void) {
        guard let url = URL(string: "https://stock-backend-82502.wl.r.appspot.com/wallet") else {
            completion(.failure(NSError(domain: "URL Error", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }

        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data else {
                completion(.failure(NSError(domain: "Data Error", code: -2, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }

            do {
                let wallet = try JSONDecoder().decode(Wallet.self, from: data)
                DispatchQueue.main.async {
                    completion(.success(wallet.balance))
                }
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }


    
    // Update wallet balance on the server
    private func updateWallet(balanceChange: Double, completion: @escaping (Bool) -> Void) {
        fetchCurrentWalletBalance { currentBalance in
            let newBalance = currentBalance + balanceChange
            let body = ["newBalance": newBalance]
            
            self.performRequest(with: "https://stock-backend-82502.wl.r.appspot.com/wallet/update", body: body, completion: completion)
        }
    }

    // Fetch the current wallet balance from the server
    private func fetchCurrentWalletBalance(completion: @escaping (Double) -> Void) {
        guard let url = URL(string: "https://stock-backend-82502.wl.r.appspot.com/wallet") else {
            print("Invalid URL")
            completion(0)
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data, error == nil else {
                print("Network error: \(error?.localizedDescription ?? "Unknown error")")
                completion(0)
                return
            }
            
            if let wallet = try? JSONDecoder().decode(Wallet.self, from: data) {
                completion(wallet.balance)
            } else {
                print("Error decoding wallet data")
                completion(0)
            }
        }.resume()
    }
    
    func fetchPortfolioStocks(completion: @escaping (Result<[StockInPortfolio], Error>) -> Void) {
            guard let url = URL(string: "https://stock-backend-82502.wl.r.appspot.com/portfolioData") else {
                completion(.failure(NSError(domain: "URL Error", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
                return
            }

            URLSession.shared.dataTask(with: url) { data, response, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }

                guard let data = data else {
                    completion(.failure(NSError(domain: "Data Error", code: -2, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                    return
                }

                do {
                    let stocks = try JSONDecoder().decode([StockInPortfolio].self, from: data)
                    DispatchQueue.main.async {
                        completion(.success(stocks))
                    }
                } catch {
                    completion(.failure(error))
                }
            }.resume()
        }
    
    // Adjust the wallet balance after buying stocks
    func buyStock(symbol: String, quantity: Int, currentPrice: Double, completion: @escaping (Bool) -> Void) {
        let totalCost = Double(quantity) * currentPrice
        let requestBody = [
            "symbol": symbol,
            "name": "Name of the Stock",
            "quantity": quantity,
            "totalCost": totalCost,
            "currentPrice": currentPrice
        ] as [String : Any]
        
        performRequest(with: "https://stock-backend-82502.wl.r.appspot.com/portfolio", body: requestBody) { success in
            if success {
                self.updateWallet(balanceChange: -totalCost, completion: completion)
            } else {
                completion(false)
            }
        }
    }

    // Adjust the wallet balance after selling stocks
    func sellStock(symbol: String, quantity: Int, currentPrice: Double, completion: @escaping (Bool) -> Void) {
        let totalCost = Double(quantity) * currentPrice
        let requestBody = [
            "symbol": symbol,
            "name": "Name of the Stock",
            "quantity": quantity,
            "totalCost": totalCost,
            "currentPrice": currentPrice
        ] as [String : Any]
        
        performRequest(with: "https://stock-backend-82502.wl.r.appspot.com/portfolio/sell", body: requestBody) { success in
            if success {
                self.updateWallet(balanceChange: totalCost, completion: completion)
            } else {
                completion(false)
            }
        }
    }


        private func performRequest(with urlString: String, body: [String: Any], completion: @escaping (Bool) -> Void) {
            guard let url = URL(string: urlString) else {
                print("Invalid URL")
                completion(false)
                return
            }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try? JSONSerialization.data(withJSONObject: body, options: [])

            URLSession.shared.dataTask(with: request) { data, response, error in
                guard let data = data, error == nil else {
                    print("Network error: \(error?.localizedDescription ?? "Unknown error")")
                    completion(false)
                    return
                }

                if let httpStatus = response as? HTTPURLResponse, httpStatus.statusCode == 200 {
                    completion(true)
                } else {
                    completion(false)
                }
            }.resume()
        }
    
    func fetchOwnedStockInfo(symbol: String, completion: @escaping (Result<StockOwnership?, Error>) -> Void) {
        guard let url = URL(string: "https://stock-backend-82502.wl.r.appspot.com/portfolioData") else {
            completion(.failure(NSError(domain: "URL Error", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "Data Error", code: -2, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }
            
            do {
                let ownedStocks = try JSONDecoder().decode([StockOwnership].self, from: data)
                let filteredStock = ownedStocks.first { $0.symbol.uppercased() == symbol.uppercased() }
                DispatchQueue.main.async {
                    completion(.success(filteredStock))
                }
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    func checkPortfolioForStock(symbol: String, completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: "https://stock-backend-82502.wl.r.appspot.com/portfolioData") else {
            print("Invalid URL")
            completion(false)
            return
        }

        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("Error fetching portfolio data: \(error)")
                completion(false)
                return
            }

            guard let data = data else {
                print("No data received from the server")
                completion(false)
                return
            }

            do {
                let stocks = try JSONDecoder().decode([StockInPortfolio].self, from: data)
                let stockExists = stocks.contains(where: { $0.symbol == symbol })
                DispatchQueue.main.async {
                    completion(stockExists)
                }
            } catch {
                print("Failed to decode JSON: \(error)")
                completion(false)
            }
        }.resume()
    }
}
