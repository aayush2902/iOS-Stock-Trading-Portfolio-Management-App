import SwiftUI

class WatchlistViewModel: ObservableObject {
    @Published var watchlist: [Stock1] = []
    
    func moveStocks(from source: IndexSet, to destination: Int) {
        print("Before move: \(watchlist.map { $0.symbol })")
        
        // Perform the move operation
        watchlist.move(fromOffsets: source, toOffset: destination)
        
        print("After move: \(watchlist.map { $0.symbol })")
        
        // Explicitly notify observers that the `watchlist` array has changed.
        objectWillChange.send()
    }


    
    func deleteStocks(at offsets: IndexSet) {
        // Prepare for server requests while maintaining thread safety
        DispatchQueue.global(qos: .userInitiated).async {
            offsets.forEach { index in
                let stock = self.watchlist[index]
                guard let url = URL(string: "https://stock-backend-82502.wl.r.appspot.com/watchlist/remove/\(stock.symbol)") else { return }
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                
                // Since it's a simple deletion, no body is needed for this request
                let task = URLSession.shared.dataTask(with: request) { data, response, error in
                    guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                        print("Error: Failed to delete the stock from the watchlist.")
                        return
                    }
                    
                    DispatchQueue.main.async {
                        self.watchlist.remove(atOffsets: offsets)
                    }
                }
                task.resume()
            }
        }
    }
        
        func fetchWatchlist() {
            guard let url = URL(string: "https://stock-backend-82502.wl.r.appspot.com/watchlistData") else {
                print("Invalid URL")
                return
            }
            
            URLSession.shared.dataTask(with: url) { data, response, error in
                if let httpResponse = response as? HTTPURLResponse {
                    print("HTTP Status Code: \(httpResponse.statusCode)")
                }
                if let data = data {
                    print(String(data: data, encoding: .utf8) ?? "Invalid data")
                    do {
                        let decodedResponse = try JSONDecoder().decode([Stock1].self, from: data)
                        DispatchQueue.main.async {
                            self.watchlist = decodedResponse
                        }
                    } catch {
                        print("Decoding failed: \(error)")
                    }
                } else if let error = error {
                    print("Fetch failed: \(error.localizedDescription)")
                } else {
                    print("Fetch failed with no error and no data")
                }
            }.resume()
        }
    }
