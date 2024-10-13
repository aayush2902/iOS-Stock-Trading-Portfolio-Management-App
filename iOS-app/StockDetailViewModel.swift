import SwiftUI
import Combine
import WebKit
import Kingfisher

// MARK: - Models
struct StockDetail: Codable {
    let profileData: ProfileData
    let quoteData: QuoteData
    let peersData: [String]
    let newsData: [NewsItem]
    let insightsData: InsightsData
    let chart3Data: [AnalystRecommendation]
    let chart4Data: [EarningsSurprise]
    var chart1Data: Chart1Data?
    var chart2Data: Chart2Data?
}

struct ChartDataResponse: Codable {
    var chart1Data: Chart1Data?
    var chart2Data: Chart2Data?
}

struct ProfileData: Codable {
    let country, currency, exchange, finnhubIndustry: String
    let ipo, logo, name, phone, ticker, weburl: String
    let marketCapitalization, shareOutstanding: Double
}

struct QuoteData: Codable {
    let c, d, dp, h, l, o, pc: Double
    let t: Int
}

struct NewsItem: Codable, Hashable {
    let category: String
    let datetime: Int
    let headline, image, related, source, summary, url: String
}

struct InsightsData: Codable {
    let data: [InsightData]
    let symbol: String
}

struct InsightData: Codable {
    let symbol: String
    let year, month, change: Int
    let mspr: Double
}

struct AnalystRecommendation: Codable {
    let buy, hold, sell, strongBuy, strongSell: Int
    let period: String
    let symbol: String
}

struct EarningsSurprise: Codable {
    let actual, estimate: Double
    let period: String
    let quarter: Int
    let surprise, surprisePercent: Double
    let symbol: String
    let year: Int
}

struct Chart1Data: Codable {
    let ticker: String
    let queryCount: Int
    let resultsCount: Int
    let adjusted: Bool
    let results: [ChartDataResult]
    let status: String
    let request_id: String
    let count: Int
}

struct Chart2Data: Codable {
    let ticker: String
    let queryCount: Int
    let resultsCount: Int
    let adjusted: Bool
    let results: [ChartDataResult]
    let status: String
    let request_id: String
    let count: Int
}

struct ChartDataResult: Codable {
    let v: Double    // volume
    let vw: Double   // volume weighted average price
    let o: Double    // open price
    let c: Double    // close price
    let h: Double    // high price
    let l: Double    // low price
    let t: Int64     // timestamp
    let n: Int       // number of transactions
}

// MARK: - Extensions for aggregation
extension InsightsData {
    func totalMSRP() -> Double {
        data.reduce(0) { $0 + $1.mspr }
    }

    func totalChange() -> Double {
        data.reduce(0) { $0 + Double($1.change) }
    }

    func positiveMSRP() -> Double {
        data.filter { $0.mspr > 0 }.reduce(0) { $0 + $1.mspr }
    }

    func positiveChange() -> Double {
        data.filter { $0.change > 0 }.reduce(0) { $0 + Double($1.change) }
    }

    func negativeMSRP() -> Double {
        data.filter { $0.mspr < 0 }.reduce(0) { $0 + $1.mspr }
    }

    func negativeChange() -> Double {
        data.filter { $0.change < 0 }.reduce(0) { $0 + Double($1.change) }
    }
}

// MARK: - View Model
class StockDetailViewModel: ObservableObject {
    @Published var stockDetail: StockDetail?
    @Published var isLoading = false
    @Published var errorMessage: String?
    var symbol: String
    @Published var chart3DataJSON = ""
    @Published var chart4DataJSON = ""
    @Published var chart1DataJSON = ""
    @Published var chart2DataJSON = ""
    @Published var isInWatchlist = false  // Track watchlist status
    @Published var isToastPresented = false
    @Published var toastMessage = ""
    @Published var isInPortfolio: Bool = false
    @Published var ownedStockInfo: StockOwnership?
    var navigateToHome = PassthroughSubject<Void, Never>()
    @Published var saleOccurred = false
    
    
    var filteredNewsItems: [NewsItem] {
            if let newsData = stockDetail?.newsData {
                return Array(newsData
                    .filter { !$0.image.isEmpty } // only check if image is not empty
                    .sorted { $0.datetime > $1.datetime }
                    .prefix(20))
            } else {
                return []
            }
        }
    
    init(symbol: String) {
        self.symbol = symbol
        // Don't call fetchStockDetail() here
    }
    
    func checkAndHandleStockDepletion() {
            // Only navigate home if a sale has occurred and no stocks are left
            if saleOccurred {
                if let info = ownedStockInfo, info.quantity == 0 {
                    navigateToHome.send(())
                } else if ownedStockInfo == nil {
                    navigateToHome.send(())
                }
            }
        }

        // Call this method whenever stocks are sold
        func updateStockInfoAfterSale() {
            // Example logic to update stock info
            // Set the flag that a sale has occurred
            saleOccurred = true
            // Once updated, check if we need to navigate home
            checkAndHandleStockDepletion()
        }

        // Reset the sale occurrence when navigating away or when the view reappears if needed
        func resetSaleFlag() {
            saleOccurred = false
        }
    
    func refreshOwnedStockInfo() {
        fetchOwnedStockInfo(symbol: symbol)
    }
    
    func loadStockDetails(symbol: String) {
        print("Loading stock details for \(symbol)")  // Add this print statement
        StockNetworkManager.shared.checkPortfolioForStock(symbol: symbol) { exists in
            DispatchQueue.main.async {
                self.isInPortfolio = exists
                print("Portfolio check complete: \(exists)")  // Print the result of the check
                if exists {
                    self.fetchOwnedStockInfo(symbol: symbol)
                }
            }
        }
    }
    
    private func fetchOwnedStockInfo(symbol: String) {
        StockNetworkManager.shared.fetchOwnedStockInfo(symbol: symbol) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let stockInfo):
                    if let stock = stockInfo {
                        self?.ownedStockInfo = stock
                    } else {
                        self?.ownedStockInfo = nil // Handle the case where no data was found
                        self?.errorMessage = "No ownership data found for \(symbol)"
                    }
                case .failure(let error):
                    self?.errorMessage = "Failed to fetch portfolio data: \(error.localizedDescription)"
                    self?.ownedStockInfo = nil
                }
            }
        }
    }


    
    // Function to add the stock to the watchlist
    func addToWatchlist(completion: @escaping (Bool) -> Void) {
        guard let stockDetail = stockDetail else {
            completion(false)
            return
        }

        NetworkManager.shared.addToWatchlist(stock: stockDetail) { success in
            completion(success)
        }
        self.isInWatchlist.toggle()
        // Simulating API call
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.isToastPresented = true
            self.toastMessage = "Adding \(stockDetail.profileData.name) to Favorites"
            completion(true)
        }
    }

    func fetchStockDetail() async {
            self.isLoading = true
            let data1URL = URL(string: "https://stock-backend-82502.wl.r.appspot.com/data1?symbol=\(symbol)")!
            let data2URL = URL(string: "https://stock-backend-82502.wl.r.appspot.com/data2?symbol=\(symbol)")!

            do {
                async let data1Response: (Data, URLResponse) = URLSession.shared.data(from: data1URL)
                async let data2Response: (Data, URLResponse) = URLSession.shared.data(from: data2URL)

                let (data1, _) = try await data1Response
                let (data2, _) = try await data2Response

                let stockDetail = try JSONDecoder().decode(StockDetail.self, from: data1)
                let chartDataResponse = try JSONDecoder().decode(ChartDataResponse.self, from: data2)

                // Update UI on the main thread
                DispatchQueue.main.async { [weak self] in
                    self?.stockDetail = stockDetail
                    self?.stockDetail?.chart1Data = chartDataResponse.chart1Data
                    self?.stockDetail?.chart2Data = chartDataResponse.chart2Data
                    self?.prepareChartData()
                    self?.encodeChartData()
                    self?.isLoading = false
                }
            } catch {
                // Handle errors appropriately
                DispatchQueue.main.async { [weak self] in
                    self?.errorMessage = "Error fetching data: \(error)"
                    self?.isLoading = false
                }
            }
        }

    private func prepareChartData() {
            if let chart3Data = stockDetail?.chart3Data {
                chart3DataJSON = String(data: try! JSONEncoder().encode(chart3Data), encoding: .utf8) ?? ""
            }
            if let chart4Data = stockDetail?.chart4Data {
                chart4DataJSON = String(data: try! JSONEncoder().encode(chart4Data), encoding: .utf8) ?? ""
            }
        }
    
    private func encodeChartData() {
        encodeChart1Data()
        encodeChart2Data()
    }
    
    private func encodeChart1Data() {
            guard let chartData = stockDetail?.chart1Data else {
                print("No Chart 1 Data Available")
                return
            }
            do {
                let jsonData = try JSONEncoder().encode(chartData)
                if let jsonString = String(data: jsonData, encoding: .utf8) {
                    DispatchQueue.main.async {
                        self.chart1DataJSON = jsonString
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to encode Chart 1 data: \(error)"
                }
            }
        }

        private func encodeChart2Data() {
            guard let chartData = stockDetail?.chart2Data else {
                print("No Chart 2 Data Available")
                return
            }
            do {
                let jsonData = try JSONEncoder().encode(chartData)
                if let jsonString = String(data: jsonData, encoding: .utf8) {
                    DispatchQueue.main.async {
                        self.chart2DataJSON = jsonString
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to encode Chart 2 data: \(error)"
                }
            }
        }
}


// MARK: - SwiftUI View
struct StockDetailView: View {
    @StateObject var viewModel: StockDetailViewModel
    @State private var selectedChart = "chart1" // Use this to toggle between charts
    @State private var showTradeView = false  // To control the presentation of the TradeView
    @State private var navigateToHome = false  // State to control navigation
    @Environment(\.presentationMode) var presentationMode
    @State private var selectedTab: Int = 0

    
    init(symbol: String) {
        _viewModel = StateObject(wrappedValue: StockDetailViewModel(symbol: symbol))
    }

    var body: some View {
        Group {
            if viewModel.isLoading {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        VStack {
                            ProgressView()
                            Text("Fetching Data...")
                                .font(.headline)
                                .foregroundColor(.gray)
                        }
                        Spacer()
                    }
                    Spacer()
                }
            } else if let stockDetail = viewModel.stockDetail {
                ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            HStack {
                                Text(stockDetail.profileData.ticker)
                                    .font(.largeTitle)
                                    .fontWeight(.bold)
                                Spacer()
                                Button(action: {
                                    viewModel.addToWatchlist { success in
                                        if success {
                                            print("Successfully added to watchlist.")
                                        } else {
                                            print("Failed to add to watchlist.")
                                        }
                                    }
                                })
                                {
                                    Image(systemName: viewModel.isInWatchlist ? "plus.circle.fill" : "plus.circle")
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(height: 28)
                                }

                            }
                            .padding(.top, 10)
                            .padding(.horizontal, 15)
                            
                            
                                Text(stockDetail.profileData.name)
                                    .font(.title3)
                                    .foregroundColor(.secondary)
                                    .padding(.bottom, 5)
                                    .padding(.horizontal, 15)
                            
                            HStack {
                                Text(String(format: "$%.2f", stockDetail.quoteData.c))
                                    .font(.title)
                                    .fontWeight(.bold)
                                    .padding(.horizontal, 0)

                                HStack(spacing: 4) {
                                    Image(systemName: stockDetail.quoteData.d < 0 ? "arrow.down.right" : "arrow.up.right")
                                        .foregroundColor(stockDetail.quoteData.d < 0 ? .red : .green)
                                    Text(String(format: "%.2f", stockDetail.quoteData.d))
                                        .foregroundColor(stockDetail.quoteData.d < 0 ? .red : .green)
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                    Text(String(format: "(%.2f%%)", stockDetail.quoteData.dp))
                                        .foregroundColor(stockDetail.quoteData.dp < 0 ? .red : .green)
                                        .font(.title3)
                                }
                            }
                            .padding(.horizontal, 15)
                        
                            // Toggle buttons for Chart 1 and Chart 2
                            // TabView with selection binding
                                    TabView(selection: $selectedTab) {
                                        // First tab with Chart1WebView
                                        Chart1WebView(viewModel: viewModel)
                                            .tabItem {
                                                Image(systemName: "chart.xyaxis.line") // System image for the tab
                                                Text("Hourly") // Text label for the tab
                                            }
                                            .tag(0) // Unique tag identifier for the tab
                                        
                                        // Second tab with Chart2WebView
                                        Chart2WebView(viewModel: viewModel)
                                            .tabItem {
                                                Image(systemName: "clock.fill") // System image for the tab
                                                Text("Historical") // Text label for the tab
                                            }
                                            .tag(1) // Unique tag identifier for the tab
                                    }
                                    .padding() // Padding around the TabView
                                    .frame(height: 380) // Set the height of the TabView
                                
                            
                            // Portfolio Section
                            HStack{
                                VStack(alignment: .leading, spacing: 5) {
                                    Text("Portfolio")
                                        .font(.title2)
                                        .padding(.vertical, 10)
                                    
                                    if let ownedStock = viewModel.ownedStockInfo {
                                        VStack(alignment: .leading, spacing: 5) {
                                            Text("Shares Owned: \(ownedStock.quantity)")
                                            Text("Avg. Cost / Share: $\(ownedStock.averageCostPerShare, specifier: "%.2f")")
                                            Text("Total Cost: $\(ownedStock.totalCost, specifier: "%.2f")")
                                            HStack {
                                                Text("Change:")
                                                Text("$\(ownedStock.change, specifier: "%.2f")")
                                                    .foregroundColor(ownedStock.change > 0 ? .green : (ownedStock.change < 0 ? .red : .primary))
                                            }
                                            HStack {
                                                Text("Market Value:")
                                                Text("$\(ownedStock.marketValue, specifier: "%.2f")")
                                                    .foregroundColor(ownedStock.change > 0 ? .green : (ownedStock.change < 0 ? .red : .primary))
                                            }

                                        }
                                    } else {
                                        Text("You have 0 shares of \(viewModel.symbol).")
                                        Text("Start trading!")
                                    }
                                }
                                
                                Spacer()
                                
                                Button("Trade") {
                                                    showTradeView = true
                                                }
                                                .foregroundColor(.white)
                                                .padding(.vertical, 10)
                                                .padding(.horizontal, 20)
                                                .background(Color.green)
                                                .cornerRadius(15)
                            }
                            .padding(.horizontal, 15)
                            .sheet(isPresented: $showTradeView) {
                                        TradeView(isPresented: $showTradeView, symbol: viewModel.symbol, currentPrice: viewModel.stockDetail?.quoteData.c ?? 0) {
                                            // This is the callback that gets called after the transaction.
                                            viewModel.loadStockDetails(symbol: viewModel.symbol)  // Reload data
                                        }
                                    }

                        // Stats Section
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Stats")
                                .font(.title2)
                                .padding(.vertical, 10)
                                
                            HStack {
                                VStack(alignment: .leading) {
                                    Text("High Price: \(String(format: "$%.2f", stockDetail.quoteData.h))")
                                    Text("Low Price: \(String(format: "$%.2f", stockDetail.quoteData.l))")
                                }
                                    
                                Spacer()
                                    
                                VStack(alignment: .leading) {
                                    Text("Open Price: \(String(format: "$%.2f", stockDetail.quoteData.o))")
                                    Text("Prev. Close: \(String(format: "$%.2f", stockDetail.quoteData.pc))")
                                }
                            }
                        }
                        .padding(.horizontal, 15)
                        

                            // About section
                            // For example, if your view's total width is 350 points, you might decide on 150 points for each side
                            let labelWidth: CGFloat = 150
                            let contentWidth: CGFloat = 150

                            VStack(alignment: .leading) {
                                Text("About")
                                    .font(.title2)
                                    .padding(.vertical, 10)
                                    .padding(.horizontal, 15)

                                HStack {
                                    Text("IPO Start Date:")
                                        .frame(width: labelWidth, alignment: .leading)
                                    Text(stockDetail.profileData.ipo)
                                        .frame(width: contentWidth, alignment: .leading)
                                }
                                .padding(.horizontal, 15)
                                
                                HStack {
                                    Text("Industry:")
                                        .frame(width: labelWidth, alignment: .leading)
                                    Text(stockDetail.profileData.finnhubIndustry)
                                        .frame(width: contentWidth, alignment: .leading)
                                }
                                .padding(.horizontal, 15)
                                
                                HStack {
                                    Text("Webpage:")
                                        .frame(width: labelWidth, alignment: .leading)
                                    Link(stockDetail.profileData.weburl, destination: URL(string: stockDetail.profileData.weburl) ?? URL(string: "https://www.apple.com")!)
                                        .foregroundColor(.blue)
                                }
                                .padding(.horizontal, 15)

                                HStack {
                                    Text("Company Peers:")
                                        .frame(width: labelWidth, alignment: .leading)
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 10) {
                                            ForEach(stockDetail.peersData, id: \.self) { peer in
                                                NavigationLink(destination: StockDetailView(symbol: peer)) {
                                                    Text(peer)
                                                        .foregroundColor(.blue)
                                                }
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal, 15)
                            }

                            
                            // Insights Section
                            InsightsSectionView(insightsData: stockDetail.insightsData, companyName: stockDetail.profileData.name)
                                .padding(.horizontal, 15)
                                
                            
                            //Chart3 & Chart4
                            WebView(viewModel: viewModel)
                                .frame(height: 615)  // Adjust height as needed
                            //News Section
                            NewsListView(newsItems: viewModel.filteredNewsItems)
                            
                    }
                    .padding(.horizontal, 15)
                }
            } else if let errorMessage = viewModel.errorMessage {
                Text("Error: \(errorMessage)")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .multilineTextAlignment(.center)
                    .padding()
            } else {
                Text("No data available")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .multilineTextAlignment(.center)
                    .padding()
            }
            EmptyView()
                          .onReceive(viewModel.navigateToHome) { _ in
                              // Dismiss the view or navigate away
                              presentationMode.wrappedValue.dismiss()
                          }
        }
        .navigationTitle("") // No title
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            Task {
                await viewModel.fetchStockDetail()
                viewModel.loadStockDetails(symbol: viewModel.symbol) // Check if the stock is in the portfolio
                viewModel.resetSaleFlag()
            }
        }
        .onChange(of: viewModel.ownedStockInfo?.quantity) { newQuantity in
            if newQuantity == 0 {
                navigateToHome = true
            }
        }
        .toast(message: viewModel.toastMessage, isShowing: $viewModel.isToastPresented)  // Add this line to enable the toast functionality
    }
}

struct CongratulationsView: View {
    var message: String
    var onDismiss: () -> Void
    @Binding var isPresented: Bool

    var body: some View {
        VStack {
            Spacer()
            Text("Congratulations!")
                .font(.largeTitle)
                .foregroundColor(.white)
            Text(message)
                .foregroundColor(.white)
                .padding()
                .onAppear {
                            print("Congratulations message: \(message)")
                        }
            Spacer()
            Button("Done") {
                isPresented = false
                onDismiss()  // Call the closure when button is pressed
            }
            .foregroundColor(.green)
            .font(.system(size: 18))
            .padding(.vertical, 15)
            .padding(.horizontal, 50)
            .background(Color.white)
            .cornerRadius(25)
            .padding(.bottom, 50)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.green)
        .edgesIgnoringSafeArea(.all)
    }
}


struct TradeView: View {
    @Binding var isPresented: Bool
    var symbol: String
    var currentPrice: Double
    var onTransactionComplete: () -> Void
    @ObservedObject var walletViewModel = WalletViewModel()
    @State private var numberOfShares: Int = 0

    @State private var shareText: String = "0"
    @State private var toastMessage: String = ""
    @State private var showToast: Bool = false
    @State private var showCongrats: Bool = false
    @State private var congratulationsMessage: String = ""
    

    var totalCost: Double {
        Double(numberOfShares) * currentPrice
    }

    var body: some View {
        NavigationView {
            VStack {
                Spacer(minLength: 20)

                VStack(alignment: .center, spacing: 20) {
                    HStack {
                        TextField("0", text: $shareText)
                            .keyboardType(.numberPad)
                            .padding(8)
                            .background(Color.clear)
                            .overlay(
                                RoundedRectangle(cornerRadius: 5)
                                    .stroke(Color.white, lineWidth: 0.5)
                            )
                            .frame(width: 70)
                            .onChange(of: shareText) { newValue in
                                if let value = Int(newValue), value >= 0 {
                                    numberOfShares = value
                                } else {
                                    shareText = ""
                                    numberOfShares = 0
                                }
                            }
                        Text("Shares x $\(currentPrice, specifier: "%.2f")/share = $\(totalCost, specifier: "%.2f")")
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    
                    Stepper("", value: $numberOfShares, in: 0...100)
                        .fixedSize()
                        .opacity(0)  // Make stepper invisible and does not occupy space visually
                        .labelsHidden()
                }
                .padding(.horizontal, 20)

                Spacer()

                VStack(spacing: 15) {
                    Text("$\(walletViewModel.walletBalance, specifier: "%.2f") available to buy \(symbol)")
                        .padding()
                        .frame(maxWidth: .infinity)
                        .cornerRadius(5)
                        .foregroundColor(.secondary)
                        .onAppear(){
                            walletViewModel.fetchWalletBalance()
                        }

                    HStack {
                        Spacer()
                        Button("Buy") {
                            handleBuy()
                        }
                        .buttonStyle(GreenButton())
                        .frame(maxWidth: .infinity)
                        Spacer()
                        Button("Sell") {
                            handleSell()
                        }
                        .buttonStyle(RedButton())
                        .frame(maxWidth: .infinity)
                        Spacer()
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .toast(message: toastMessage, isShowing: $showToast)
            .sheet(isPresented: $showCongrats) {
                CongratulationsView(
                    message: congratulationsMessage,
                    onDismiss: {
                        // Assuming viewModel here refers to StockDetailViewModel instance that needs refreshing
                        onTransactionComplete()
                    }, isPresented: $isPresented
                )
            }
            .navigationBarTitle(Text("Trade \(symbol) shares"), displayMode: .inline)
            .navigationBarItems(trailing: Button("Close") {
                isPresented = false
            })
            
        }
    }

    func handleBuy() {
        if numberOfShares <= 0 {
            DispatchQueue.main.async {
                toastMessage = "Cannot buy non-positive shares"
                showToast = true
            }
        } else if Double(numberOfShares) * currentPrice > walletViewModel.walletBalance {
            DispatchQueue.main.async {
                toastMessage = "Not enough money to buy"
                showToast = true
            }
        } else {
            StockNetworkManager.shared.buyStock(symbol: symbol, quantity: numberOfShares, currentPrice: currentPrice) { success in
                DispatchQueue.main.async {
                    if success {
                        print("Purchase successful")
                        self.congratulationsMessage = "You have successfully bought \(numberOfShares) shares of \(symbol)."
                        self.showCongrats = true
                    } else {
                        print("Purchase failed")
                        self.toastMessage = "Purchase failed"
                        self.showToast = true
                        onTransactionComplete()
                    }
                }
            }
        }
    }

    func handleSell() {
        if numberOfShares <= 0 {
            DispatchQueue.main.async {
                toastMessage = "Cannot sell non-positive shares"
                showToast = true
            }
        } else if numberOfShares > 10 {  // Adjust with your actual logic to check available shares
            DispatchQueue.main.async {
                toastMessage = "Not enough shares to sell"
                showToast = true
            }
        } else {
            StockNetworkManager.shared.sellStock(symbol: symbol, quantity: numberOfShares, currentPrice: currentPrice) { success in
                DispatchQueue.main.async {
                    if success {
                        print("Sale successful")
                        self.congratulationsMessage = "You have successfully sold \(numberOfShares) shares of \(symbol)."
                        self.showCongrats = true
                    } else {
                        print("Sale failed")
                        self.toastMessage = "Sale failed"
                        self.showToast = true
                        onTransactionComplete()
                    }
                }
            }
        }
    }
}

// Custom button styles for Buy and Sell
struct GreenButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.white)
            .font(.system(size: 18))
            .padding(.vertical, 15)
            .padding(.horizontal, 50)
            .background(Color.green)
            .cornerRadius(25)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

struct RedButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.white)
            .font(.system(size: 18))
            .padding(.vertical, 15)
            .padding(.horizontal, 50)
            .background(Color.red)
            .cornerRadius(25)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}


// Define your NewsRowView conforming to TableRowContent
struct NewsRowView: View {
    let newsItem: NewsItem
    let isLargeImage: Bool
    @State private var showDetail = false
    
    var body: some View {
        VStack {
            if isLargeImage {
                
                KFImage(URL(string: newsItem.image))
                    .resizable()
                    .frame(height: 200)
                    .cornerRadius(10)
                    .clipped()
                    .padding(.horizontal, 15)
                    
                
                VStack(alignment: .leading) {
                    Text(newsItem.headline)
                        .font(.headline)
                    Text(newsItem.source)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .padding(.horizontal, 15)
                
            }
            
            else {
                HStack {
                    VStack(alignment: .leading) {
                        Text(newsItem.headline)
                            .font(.headline)
                        Text(newsItem.source)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal, 15)
                    
                    Spacer()
                    
                    KFImage(URL(string: newsItem.image))
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 80, height: 80)
                        .cornerRadius(10)
                        .clipped()
                        .padding(.horizontal, 15)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            showDetail = true
        }
        .sheet(isPresented: $showDetail) {
            ArticleDetailView(article: newsItem)
        }
    }
}


// Your existing NewsListView
struct NewsListView: View {
    var newsItems: [NewsItem]

    var body: some View {
        VStack(alignment: .leading) {
            Text("News")
                .font(.title2)
                .padding(.vertical, 10)
                .padding(.horizontal, 15)
            ForEach(Array(newsItems.enumerated()), id: \.element) { (index, item) in
                NewsRowView(newsItem: item, isLargeImage: index == 0)
                Divider()
            }
        }
    }
}


struct ArticleDetailView: View {
    let article: NewsItem
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(article.source.uppercased()) // Source name in uppercase
                            .font(.title)
                            .fontWeight(.bold)

                        Text(dateFromUnixTime(article.datetime)) // Formatted date
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top)

                    Divider()

                    Text(article.headline)
                        .font(.title2)
                        .fontWeight(.bold)
                        .padding(.top)

                    Text(article.summary)
                        .font(.body)

                    Link("Read more", destination: URL(string: article.url)!)
                        .font(.headline)
                        .foregroundColor(.blue)

                    socialMediaButtons
                        .padding(.top)
                }
                .padding()
            }
            .navigationBarTitle("", displayMode: .inline)
            .navigationBarItems(trailing: Button("Close") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }

    var socialMediaButtons: some View {
        HStack {
            Button(action: {
                shareOnTwitter(title: article.headline, url: article.url)
            }) {
                Image("Twitter_logo")
                    .resizable()
                    .frame(width: 35, height: 35)
            }
            Button(action: {
                shareOnFacebook(url: article.url)
            }) {
                Image("Facebook_logo")
                    .resizable()
                    .frame(width: 40, height: 40)
            }
        }
        .padding()
    }

    func dateFromUnixTime(_ unixTime: Int) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(unixTime))
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM dd, yyyy"
        return dateFormatter.string(from: date)
    }

    func shareOnTwitter(title: String, url: String) {
        let text = title.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? ""
        let urlString = "https://twitter.com/intent/tweet?text=\(text)%20\(url)"
        if let url = URL(string: urlString) {
            UIApplication.shared.open(url)
        }
    }

    func shareOnFacebook(url: String) {
        let urlString = "https://www.facebook.com/sharer/sharer.php?u=\(url)"
        if let url = URL(string: urlString) {
            UIApplication.shared.open(url)
        }
    }
}


// Button Style for the chart toggling buttons
struct ChartButtonStyle: ButtonStyle {
    var isSelected: Bool

    func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label
            .foregroundColor(isSelected ? .white : .blue)
            .padding()
            .background(isSelected ? Color.blue : Color.clear)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.blue, lineWidth: 2)
            )
    }
}

// WebView for Chart 1
struct Chart1WebView: UIViewRepresentable {
    @ObservedObject var viewModel: StockDetailViewModel

    // HTML content for Chart 1
    let chart1HTML = """
    <!DOCTYPE html>
    <html>
    <head>
        <title>Hourly Price Chart</title>
        <script src="https://code.highcharts.com/highcharts.js"></script>
        <script src="https://code.highcharts.com/modules/exporting.js"></script>
    </head>
    <body>
        <div id="chart1Container" style="width:100%; height:800px;"></div>

        <script>
        function renderChart1(chart1Data) {
            const chartData = chart1Data.results.map(result => ({
                        x: result.t, // timestamp
                        y: result.c  // close price
                    }));

                    const options = {
                        chart: {
                            type: 'line'
                        },
                        title: {
                            text: chart1Data.ticker + ' Hourly Price Variation',
                            style: {fontSize: '50px'
                                }
                        },
                        xAxis: {
                            type: 'datetime',
                            labels: {
                                        style: {
                                                fontSize: '35px' // Adjust axis labels font size as needed
                                                }
                                    }
                        },
                        yAxis: {
                            title: {
                                text: 'Price',
                                style: {fontSize: '40px'
                                    }
                            },
                            labels: {
                                    style: {
                                            fontSize: '35px' // Adjust axis labels font size as needed
                                            }
                                    },
                            opposite: true
                        },
                        series: [{
                            data: chartData,
                            color: 'green',
                            marker: {
                                enabled: false
                            }
                        }],
                        tooltip: {
                            formatter: function() {
                                return '<b>' + chart1Data.ticker + '</b>: ' + this.y;
                            },
                            style: {
                                    fontSize: '30px'
                                }
                        },
                        legend: { itemStyle: {
                                            fontSize: '35px' // Increase legend item font size as needed
                                            }
                        }
                    };

                    Highcharts.chart('chart1Container', options);
        }

        // The data injection will be done from Swift
        </script>
    </body>
    </html>
    """

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        webView.loadHTMLString(chart1HTML, baseURL: nil)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        // Data injection is handled by the coordinator after the web view loads
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel)
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        var viewModel: StockDetailViewModel

        init(viewModel: StockDetailViewModel) {
            self.viewModel = viewModel
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
                let jsonData = viewModel.chart1DataJSON.replacingOccurrences(of: "\n", with: "\\n")
                print("Injecting chart data for chart 1: \(jsonData)")
                
                let chart1DataJS = """
                if (window.renderChart1) {
                    try {
                        var chartData = JSON.parse(`\(jsonData)`);
                        renderChart1(chartData);
                    } catch (e) {
                        console.error('Chart 1 rendering error: ' + e.toString());
                    }
                } else {
                    console.error('renderChart1 function not found.');
                }
                """
                
                webView.evaluateJavaScript(chart1DataJS) { (result, error) in
                    if let error = error {
                        print("Error when trying to render chart 1: \(error.localizedDescription)")
                    }
                }
            }

    }
}
// WebView for Chart 2
struct Chart2WebView: UIViewRepresentable {
    @ObservedObject var viewModel: StockDetailViewModel

    // HTML content for Chart 2
    let chart2HTML = """
    <!DOCTYPE html>
    <html>
    <head>
        <title>Historical OHLC Chart</title>
        <script src="https://code.highcharts.com/stock/highstock.js"></script>
        <script src="https://code.highcharts.com/stock/indicators/indicators-all.js"></script>
        <script src="https://code.highcharts.com/stock/indicators/volume-by-price.js"></script>
    </head>
    <body>
        <div id="chart2Container" style="width:100%; height:800px;"></div>

        <script>
        function renderChart2(chart2Data) {
            let ohlc = chart2Data.results.map(item => [item.t, item.o, item.h, item.l, item.c]);
                    let volume = chart2Data.results.map(item => [item.t, item.v]);

                    const options = {
                        rangeSelector: { selected: 2 },
                        title: { text: chart2Data.ticker + ' Historical',
                                  style: {fontSize: '50px'
                                        }
                                },
                        yAxis: [{
                            labels: { align: 'right', x: -3,
                                      style: {
                                            fontSize: '35px' // Adjust axis labels font size as needed
                                            }
                                    },
                            title: { text: 'OHLC',
                                     style: {fontSize: '40px'
                                            }
                                    },
                            height: '60%',
                            lineWidth: 2,
                            resize: { enabled: true }
                        }, {
                            labels: { align: 'right', x: -3,
                                      style: {
                                            fontSize: '35px' // Adjust axis labels font size as needed
                                            }
                                    },
                            title: { text: 'Volume',
                                     style: {
                                            fontSize: '35px' // Adjust axis labels font size as needed
                                            }
                                    },
                            top: '65%',
                            height: '35%',
                            offset: 0,
                            lineWidth: 2
                        }],
                        xAxis: { type: 'datetime',
                                 labels: {
                                            style: {
                                                    fontSize: '35px' // Adjust axis labels font size as needed
                                                    }
                                        }
                                },
                        series: [{
                            type: 'candlestick',
                            name: chart2Data.ticker,
                            data: ohlc
                        }, {
                            type: 'column',
                            name: 'Volume',
                            data: volume,
                            yAxis: 1
                        }, {
                            type: 'sma',
                            linkedTo: 'aapl',
                            zIndex: 1
                        }],
                        legend: { itemStyle: {
                                            fontSize: '35px' // Increase legend item font size as needed
                                            }
                        }
                    };

                    Highcharts.stockChart('chart2Container', options);
        }

        // The data injection will be done from Swift
        </script>
    </body>
    </html>
    """

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        webView.loadHTMLString(chart2HTML, baseURL: nil)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        // Data injection is handled by the coordinator after the web view loads
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel)
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        var viewModel: StockDetailViewModel

        init(viewModel: StockDetailViewModel) {
            self.viewModel = viewModel
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
                let jsonData = viewModel.chart2DataJSON.replacingOccurrences(of: "\n", with: "\\n")
                print("Injecting chart data for chart 2: \(jsonData)")
                
                let chart2DataJS = """
                if (window.renderChart2) {
                    try {
                        var chartData = JSON.parse(`\(jsonData)`);
                        renderChart2(chartData);
                    } catch (e) {
                        console.error('Chart 2 rendering error: ' + e.toString());
                    }
                } else {
                    console.error('renderChart2 function not found.');
                }
                """
                
                webView.evaluateJavaScript(chart2DataJS) { (result, error) in
                    if let error = error {
                        print("Error when trying to render chart 2: \(error.localizedDescription)")
                    }
                }
            }
    }
}

struct WebView: UIViewRepresentable {
    @ObservedObject var viewModel: StockDetailViewModel

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator

        // Here we're loading the HTML string directly
        let htmlString = """
        <!DOCTYPE html>
        <html>
        <head>
            <title>Charts</title>
            <script src="https://code.highcharts.com/highcharts.js"></script>
            <script src="https://code.highcharts.com/modules/exporting.js"></script> <!-- Optional: for exporting capabilities -->
        </head>
        <body>
            <div id="chart3Container" style="width:100%; height:800px; margin-bottom:62.5px"></div>
            <div id="chart4Container" style="width:100%; height:800px;"></div>

            <script>
                function renderChart3(chart3Data) {
                    if (!Array.isArray(chart3Data)) {
                        console.log("Data3 is not an array:", Data3);
                        return;
                    }

                    const periods = chart3Data.map(entry => entry.period.substr(0, 7));
                    const seriesData = {
                        strongBuy: [],
                        buy: [],
                        hold: [],
                        sell: [],
                        strongSell: []
                    };

                    chart3Data.forEach(entry => {
                        seriesData.strongBuy.push(entry.strongBuy);
                        seriesData.buy.push(entry.buy);
                        seriesData.hold.push(entry.hold);
                        seriesData.sell.push(entry.sell);
                        seriesData.strongSell.push(entry.strongSell);
                    });

                    const options = {
                        chart: { type: 'column' },
                        title: { text: 'Recommendation Trends',
                                 style: {fontSize: '50px'
                                        }
                                },
                        xAxis: { categories: periods,
                                 labels: {
                                            style: {
                                                    fontSize: '35px' // Adjust axis labels font size as needed
                                                 }
                                         }
                                },
                        yAxis: { title: { text: '#Analysis',
                                          style: {fontSize: '40px'
                                                }
                                        },
                                 tickInterval: 10,
                                 labels: {
                                                  style: {
                                                        fontSize: '35px' // Adjust axis labels font size as needed
                                                  }
                                              }
                                },
                        legend: { reversed: true,
                                  itemStyle: {
                                              fontSize: '35px' // Increase legend item font size as needed
                                          }
                                },
                        plotOptions: {
                            column: {
                                stacking: 'normal',
                                dataLabels: {
                                    enabled: true,
                                    format: '{point.y}',
                                    color: 'black',
                                    style: { textOutline: 'none',
                                             fontSize: '30px' // Adjust axis labels font size as needed
                                            }
                                }
                            }
                        },
                        series: [
                            { name: 'Strong Buy', data: seriesData.strongBuy, color: '#006400' },
                            { name: 'Buy', data: seriesData.buy, color: '#3ecf5b' },
                            { name: 'Hold', data: seriesData.hold, color: '#c29b3a' },
                            { name: 'Sell', data: seriesData.sell, color: '#e66a7a' },
                            { name: 'Strong Sell', data: seriesData.strongSell, color: '#8B0000' }
                        ]
                    };

                    Highcharts.chart('chart3Container', options);
                }

                function renderChart4(chart4Data) {
                    if (!Array.isArray(chart4Data)) {
                        console.log("Data4 is not an array:", Data4);
                        return;
                    }

                    const categories = chart4Data.map(entry => `${entry.period} Surprise: ${entry.surprise.toFixed(2)}`);
                    let actualValues = chart4Data.map(entry => entry.actual === null ? 0 : entry.actual);
                    let estimateValues = chart4Data.map(entry => entry.estimate === null ? 0 : entry.estimate);

                    const options = {
                        chart: { type: 'spline' },
                        title: { text: 'Historical EPS Surprises',
                                 style: {fontSize: '50px'
                                        }
                                },
                        xAxis: { categories: categories,
                                 labels: {
                                            style: {
                                                        fontSize: '35px' // Adjust axis labels font size as needed
                                                    }
                                        }
                                },
                        yAxis: { title: { text: 'Quarterly EPS',
                                          style: {fontSize: '40px'
                                                }
                                        },
                                 labels: {
                                            style: {
                                                        fontSize: '35px' // Adjust axis labels font size as needed
                                                    }
                                        }
                                },
                        legend: {
                                  itemStyle: {
                                                fontSize: '35px' // Increase legend item font size as needed
                                            }
                                },
                        tooltip: {
                            style: {
                                fontSize: '30px'
                            }
                        },
                        series: [
                            { name: 'Actual', data: actualValues },
                            { name: 'Estimate', data: estimateValues }
                        ]
                    };

                    Highcharts.chart('chart4Container', options);
                }

                // Example calls to renderChart3 and renderChart4, you will replace these with actual data injections
                // renderChart3(data3);
                // renderChart4(data4);
            </script>
        </body>
        </html>
        """
        webView.loadHTMLString(htmlString, baseURL: nil)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        // Here, you can optionally inject new data if the view model updates and you need to refresh the chart.
        // This is not required if your data does not change after initial load.
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        var viewModel: StockDetailViewModel
        
        init(viewModel: StockDetailViewModel) {
            self.viewModel = viewModel
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // JavaScript code to create a JS object from the JSON string
            let chart3DataJS = "var chart3Data = \(viewModel.chart3DataJSON);"
            let chart4DataJS = "var chart4Data = \(viewModel.chart4DataJSON);"
            
            webView.evaluateJavaScript(chart3DataJS) { _, error in
                if let error = error {
                    print("Error injecting chart3 data: \(error)")
                } else {
                    webView.evaluateJavaScript("renderChart3(chart3Data);", completionHandler: nil)
                }
            }
            
            webView.evaluateJavaScript(chart4DataJS) { _, error in
                if let error = error {
                    print("Error injecting chart4 data: \(error)")
                } else {
                    webView.evaluateJavaScript("renderChart4(chart4Data);", completionHandler: nil)
                }
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel)
    }
}


struct InsightsSectionView: View {
    let insightsData: InsightsData
    let companyName: String

    // Define the total width of the view or use UIScreen.main.bounds.width to get the device width
    let totalWidth: CGFloat = UIScreen.main.bounds.width - 32 // Assuming 16 points padding on each side
    // Calculate the width for each column, accounting for the spacing between columns
    let columnWidth: CGFloat
    
    init(insightsData: InsightsData, companyName: String) {
        self.insightsData = insightsData
        self.companyName = companyName
        // Subtract the total padding from the width and divide by number of columns
        // 2 gaps between 3 columns means 2 spacings are subtracted from the total width
        self.columnWidth = (totalWidth - (2 * 8)) / 3 // Here, 8 is the space between columns
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Insights")
                .font(.title2)
                .padding(.vertical, 10)

            HStack {
                Spacer()
                Text("Insider Sentiments")
                    .font(.title2)
                Spacer()
            }

            // Table Header
            HStack(spacing: 8) { // Here, 8 is the space between columns
                Text(companyName)
                    .bold()
                    .frame(width: columnWidth, alignment: .leading)
                Text("MSPR")
                    .bold()
                    .frame(width: columnWidth, alignment: .trailing)
                Text("Change")
                    .bold()
                    .frame(width: columnWidth, alignment: .trailing)
            }

            Divider()

            // Rows (Total, Positive, Negative)
            ForEach([
                ("Total", insightsData.totalMSRP(), insightsData.totalChange()),
                ("Positive", insightsData.positiveMSRP(), insightsData.positiveChange()),
                ("Negative", insightsData.negativeMSRP(), insightsData.negativeChange())
            ], id: \.0) { (label, mspr, change) in
                HStack(spacing: 8) { // Here, 8 is the space between columns
                    Text(label)
                        .frame(width: columnWidth, alignment: .leading)
                    Text(String(format: "%.2f", mspr))
                        .frame(width: columnWidth, alignment: .trailing)
                    Text(String(format: "%.2f", change))
                        .frame(width: columnWidth, alignment: .trailing)
                }
                Divider()
            }
        }
    }
}


// MARK: - Preview Provider
struct StockDetailView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            StockDetailView(symbol: "AMZN")
        }
    }
}
