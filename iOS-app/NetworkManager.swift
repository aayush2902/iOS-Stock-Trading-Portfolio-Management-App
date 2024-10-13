import Foundation

class NetworkManager {
    static let shared = NetworkManager()
    private init() {}

    func addToWatchlist(stock: StockDetail, completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: "https://stock-backend-82502.wl.r.appspot.com/watchlist/add") else {
            completion(false)
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "symbol": stock.profileData.ticker,
            "name": stock.profileData.name,
            "currentPrice": stock.quoteData.c,
            "dailyChange": stock.quoteData.d,
            "percentChange": stock.quoteData.dp
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                completion(false)
                return
            }
            completion(true)
        }.resume()
    }
}

