import Foundation

// Define the structure of the data you are fetching.
struct Stock: Codable {
    let description: String
    let displaySymbol: String
    let symbol: String
    let type: String
    let primary: [String]? // Since 'primary' can be null, it's marked as optional
}

// ViewModel responsible for fetching and decoding the autocomplete data.
class AutocompleteViewModel: ObservableObject {
    // Published property to store the array of Stock objects.
    @Published var autocompleteResults: [Stock] = []

    // Function to fetch autocomplete data.
    func fetchAutocompleteData(query: String) {
        // Ensure the query is properly encoded for a URL.
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        // Construct the URL for the network request.
        guard let url = URL(string: "https://stock-backend-82502.wl.r.appspot.com/autocomplete?query=\(encodedQuery)") else {
            print("Invalid URL")
            return
        }

        let request = URLRequest(url: url)

        // Perform the network request.
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            if let data = data {
                do {
                    // Attempt to decode the JSON into an array of Stock objects.
                    let decodedResponse = try JSONDecoder().decode([Stock].self, from: data)
                    DispatchQueue.main.async {
                        // Update the published property with the decoded results.
                        self?.autocompleteResults = decodedResponse
                    }
                } catch {
                    // If decoding fails, log the error.
                    print("Decoding error:", error)
                }
            } else if let error = error {
                // If the network request fails, log the error.
                print("Fetch failed:", error.localizedDescription)
            }
        }.resume() // Start the network task.
    }
}
