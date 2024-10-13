import SwiftUI

struct ContentView: View {
    @State private var searchText = ""
    @State private var isNavigatingToDetail = false
    @State private var selectedStock: Stock?
    @ObservedObject var viewModel = AutocompleteViewModel()
    @ObservedObject var watchlistViewModel = WatchlistViewModel()
    @State private var isEditing = false
    @ObservedObject var portfolioViewModel = PortfolioViewModel()
    @ObservedObject var walletViewModel = WalletViewModel()


    // Helper function to format the current date
    func currentDateFormatted() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d, yyyy"
        return formatter.string(from: Date())
    }

    var body: some View {
        NavigationView {
            List {
                if searchText.isEmpty {
                    dateSection
                    portfolioSection
                    favoritesSection
                    footerSection
                } else {
                    searchResultsSection
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                        EditButton()
                    }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("Stocks")
            .searchable(text: $searchText, prompt: "Search for stocks")
            .onChange(of: searchText, perform: { newValue in
                viewModel.fetchAutocompleteData(query: newValue)
            })
            .background(
                NavigationLink(destination: StockDetailView(symbol: selectedStock?.displaySymbol ?? ""), isActive: $isNavigatingToDetail) { EmptyView() }
            )
            .onAppear {
                watchlistViewModel.fetchWatchlist()
                portfolioViewModel.fetchPortfolio()
                
            }
        }
    }

    private var dateSection: some View {
        Section(header: Text(""), footer: Text("")) {
            HStack {
                Text(currentDateFormatted())
                    .foregroundColor(.gray)
                    .font(.system(size: 25, weight: .medium, design: .default))
                    .padding(.vertical, 8)
                    .padding(.horizontal, 1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .listRowBackground(Color.white)
    }

    private var portfolioSection: some View {
        Section(header: Text("PORTFOLIO").foregroundColor(.gray)) {
            VStack{
                HStack {
                    VStack(alignment: .leading) {
                        Text("Net Worth")
                            .font(.title2)
                        Text("$\(walletViewModel.netWorth, specifier: "%.2f")")
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                    Spacer()
                    VStack(alignment: .leading) {
                        Text("Cash Balance")
                            .font(.title2)
                        Text("$\(walletViewModel.walletBalance, specifier: "%.2f")")
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                    .onAppear(){
                        walletViewModel.fetchWalletBalance()
                        walletViewModel.fetchPortfolioStocks()
                      }
                }
                .padding(.horizontal, 1)
                
                ForEach(portfolioViewModel.portfolioStocks, id: \.symbol) { stock in
                        Divider()
                        HStack {
                                VStack(alignment: .leading) {
                                    Text(stock.symbol)
                                        .font(.title3)
                                        .fontWeight(.bold)
                                    Text("\(stock.quantity) Shares")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                VStack(alignment: .trailing) {
                                    Text("$\(stock.marketValue, specifier: "%.2f")")
                                        .font(.headline)
                                        .fontWeight(.bold)
                                    HStack{
                                        Image(systemName: stock.change > 0 ? "arrow.up.right" : (stock.change < 0 ? "arrow.down.right" : ""))
                                            .foregroundColor(stock.change > 0 ? .green : (stock.change < 0 ? .red : .primary))
                                        
                                        Text(String(format: "$%.2f (%.2f%%)", stock.change, stock.change/100))
                                            .foregroundColor(stock.change > 0 ? .green : (stock.change < 0 ? .red : .primary))
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                .onMove(perform: portfolioViewModel.moveStocks)
            }
        }
    }

    private var favoritesSection: some View {
        Section(header: Text("FAVORITES").font(.headline).foregroundColor(.gray)) {
            ForEach(watchlistViewModel.watchlist, id: \.id) { stock in
                NavigationLink(destination: StockDetailView(symbol: stock.symbol)) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(stock.symbol)
                                .font(.title3)
                                .fontWeight(.bold)
                            Text(stock.name)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text("$\(stock.currentPrice, specifier: "%.2f")")
                                .font(.headline)
                                .fontWeight(.bold)
                            HStack {
                                Image(systemName: stock.dailyChange >= 0 ? "arrow.up.right" : "arrow.down.right")
                                    .foregroundColor(stock.dailyChange >= 0 ? .green : .red)
                                Text("\(stock.dailyChange, specifier: "%+.2f")")
                                    .foregroundColor(stock.dailyChange >= 0 ? .green : .red)
                                Text("(\(stock.percentChange, specifier: "%.2f")%)")
                                    .foregroundColor(stock.dailyChange >= 0 ? .green : .red)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .onDelete(perform: watchlistViewModel.deleteStocks)
            .onMove(perform: watchlistViewModel.moveStocks)
        }
    }


    private var footerSection: some View {
        HStack {
            Spacer()
            Link("Powered by Finnhub.io", destination: URL(string: "https://finnhub.io")!)
                .foregroundColor(.gray)
                .font(.system(size: 12.5))
            Spacer()
        }
        .listRowBackground(Color.white)
    }

    private var searchResultsSection: some View {
        Section(header: Text("Search Results")) {
            ForEach(viewModel.autocompleteResults, id: \.symbol) { stock in
                Button(action: {
                    self.selectedStock = stock
                    self.isNavigatingToDetail = true
                }) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(stock.displaySymbol).font(.headline)
                            Text(stock.description).font(.subheadline)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .foregroundColor(.gray)
                    }
                    .contentShape(Rectangle())
                }
                .foregroundColor(.black)
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
