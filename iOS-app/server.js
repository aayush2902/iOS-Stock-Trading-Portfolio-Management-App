const express = require('express');
// const path = require('path');
const axios = require('axios');
const cors = require('cors');
const { MongoClient } = require('mongodb');

const app = express();
// Enable CORS for all routes
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({extended: false}));
// console.log("This is the root dir",__dirname)
// app.use(express.static(path.join(__dirname, '../app/build')));

// Autocomplete route
app.get('/autocomplete', async (req, res) => {
  try {
    const { query } = req.query;
    const response = await fetchAutocompleteData(query);
    res.json(response);
  } catch (error) {
    console.error('Error fetching autocomplete data:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Function to fetch autocomplete data
async function fetchAutocompleteData(query) {
  try {
    const response = await axios.get(`https://finnhub.io/api/v1/search?q=${query}&token=cn94799r01qoee99k2kgcn94799r01qoee99k2l0`);
    const data = response.data;
    
    // Check if data is an object and contains an array of items
    if (typeof data === 'object' && Array.isArray(data.result)) {
      const filteredData = data.result.filter(item => item.type === 'Common Stock' && !item.symbol.includes('.'));
      return filteredData;
    } else {
      console.error('Unexpected autocomplete response format:', data);
      return [];
    }
  } catch (error) {
    console.error('Error fetching autocomplete data:', error);
    throw error;
  }
}

// MongoDB connection setup
const uri = 'mongodb+srv://aayushprabhu:P7CknIF5LxMed8jg@cluster0.1o32nga.mongodb.net/?retryWrites=true&w=majority&appName=Cluster0'
const client = new MongoClient(uri);

async function connectDB() {
  try {
    await client.connect();
    console.log('Connected to MongoDB');
    // Initialize wallet balance if it doesn't exist
    await initializeWalletBalance();
    startServer(client);
  } catch (error) {
    console.error('Error connecting to MongoDB:', error);
  }
}
connectDB();

async function initializeWalletBalance() {
  try {
    const database = client.db('Assignment-3');
    const walletCollection = database.collection('Wallet');

    // Check if any document exists in the Wallet collection
    const walletExists = await walletCollection.findOne();

    // If wallet document does not exist, initialize wallet balance
    if (!walletExists) {
      await walletCollection.insertOne({
        balance: 25000  // Initial wallet balance
      });
      console.log('Wallet balance initialized successfully');
    }
  } catch (error) {
    console.error('Error initializing wallet balance:', error);
  }
}

// Route to fetch wallet balance
app.get('/wallet', async (req, res) => {
  try {
    const wallet = await client.db('Assignment-3').collection('Wallet').findOne();
    res.json(wallet);
  } catch (error) {
    console.error('Error fetching wallet balance:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Route to update wallet balance
app.post('/wallet/update', async (req, res) => {
  try {
    const { newBalance } = req.body;
    await client.db('Assignment-3').collection('Wallet').updateOne({}, { $set: { balance: newBalance } });
    res.json({ success: true });
  } catch (error) {
    console.error('Error updating wallet balance:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Define route to handle checking if a stock exists in the watchlist
// Define route to handle checking if a stock exists in the watchlist
app.get('/watchlist/check/:symbol', async (req, res) => {
  try {
    const { symbol } = req.params;

    // Fetch data from the Watchlist collection
    const watchlistCollection = client.db('Assignment-3').collection('Watchlist');
    const existingStock = await watchlistCollection.findOne({ symbol: symbol });

    // If the stock exists in the watchlist, return inWatchlist state as true
    if (existingStock) {
      res.json({ inWatchlist: true });
    } else {
      res.json({ inWatchlist: false });
    }
  } catch (error) {
    console.error('Error checking stock in watchlist:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});


// Define route to handle adding stocks to the watchlist
// Define route to handle adding stocks to the watchlist
app.post('/watchlist/add', async (req, res) => {
  try {
    const { symbol, name, currentPrice, dailyChange, percentChange } = req.body;

    // Get the database and collection
    const database = client.db('Assignment-3');
    const watchlistCollection = database.collection('Watchlist');

    // Check if the stock already exists in the watchlist
    const existingStock = await watchlistCollection.findOne({ symbol: symbol });

    if (existingStock) {
      await watchlistCollection.updateOne(
        { symbol: symbol },
        {
          $set: {
            name: name,
            currentPrice: currentPrice,
            dailyChange: dailyChange, // Add daily change
            percentChange: percentChange // Add percent change
          }
        });
    } 
    else {
      // Insert the stock into the watchlist collection
      await watchlistCollection.insertOne({
        symbol: symbol,
        name: name,
        currentPrice: currentPrice,
        dailyChange: dailyChange, // Add daily change
        percentChange: percentChange // Add percent change
      });
      
      console.log('Stock added to watchlist successfully');
      res.status(200).json({ message: 'Stock added to watchlist successfully' });
    }
  } catch (error) {
    console.error('Error adding stock to watchlist:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Define route to handle removing stocks from the watchlist
app.post('/watchlist/remove/:symbol', async (req, res) => {
  try {
    const { symbol } = req.params;

    // Get the database and collection
    const database = client.db('Assignment-3');
    const watchlistCollection = database.collection('Watchlist');

    // Find and remove the stock from the watchlist
    const result = await watchlistCollection.deleteOne({ symbol: symbol });

    if (result.deletedCount === 1) {
      console.log('Stock removed from watchlist successfully');
      res.status(200).json({ message: 'Stock removed from watchlist successfully' });
    } else {
      console.error('Stock not found in the watchlist');
      res.status(404).json({ error: 'Stock not found in the watchlist' });
    }
  } catch (error) {
    console.error('Error removing stock from watchlist:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Function to fetch data from the Watchlist collection
async function fetchDataFromWatchlist() {
  try {
    // Access the database and collection
    const database = client.db('Assignment-3');
    const collection = database.collection('Watchlist');

    // Query the collection to fetch data
    const result = await collection.find({}).toArray();

    return result; // Return the fetched data
  } catch (error) {
    console.error('Error fetching data from Watchlist:', error);
    throw error;
  }
}

// Define route to handle fetching data from the Watchlist collection
app.get('/watchlistData', async (req, res) => {
  try {
    // Fetch data from the Watchlist collection
    const watchlistData = await fetchDataFromWatchlist();

    res.json(watchlistData); // Send the fetched data as JSON response
  } catch (error) {
    console.error('Error handling /watchlistData request:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Function to fetch data from the Portfolio collection
async function fetchDataFromPortfolio() {
  try {
    // Access the database and collection
    const database = client.db('Assignment-3');
    const collection = database.collection('Portfolio');

    // Query the collection to fetch data
    const result = await collection.find({}).toArray();

    return result; // Return the fetched data
  } catch (error) {
    console.error('Error fetching data from Portfolio:', error);
    throw error;
  }
}

// Define route to handle fetching data from the Portfolio collection
app.get('/portfolioData', async (req, res) => {
  try {
    // Fetch data from the Portfolio collection
    const portfolioData = await fetchDataFromPortfolio();

    res.json(portfolioData); // Send the fetched data as JSON response
  } catch (error) {
    console.error('Error handling /portfolioData request:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Define route to handle buying stocks and updating user portfolio
app.post('/portfolio', async (req, res) => {
  try {
    const { symbol, name, quantity, totalCost, currentPrice } = req.body;

    // Calculate additional fields
    const averageCostPerShare = totalCost / quantity;
    const marketValue = currentPrice * quantity;
    const change = averageCostPerShare - currentPrice;

    const portfolioCollection = client.db('Assignment-3').collection('Portfolio');

    // Check if the user already has this stock in the portfolio
    const existingStock = await portfolioCollection.findOne({ symbol: symbol });

    if (existingStock) {
      // If the stock exists, update the portfolio with the new purchase
      const newQuantity = existingStock.quantity + quantity;
      const newTotalCost = existingStock.totalCost + totalCost;
      const newAverageCostPerShare = newTotalCost / newQuantity;
      const newchange = newAverageCostPerShare - currentPrice;
      const newmarketValue = currentPrice * newQuantity;

      await portfolioCollection.updateOne(
        { symbol: symbol },
        {
          $set: {
            quantity: newQuantity,
            totalCost: newTotalCost,
            averageCostPerShare: newAverageCostPerShare,
            currentPrice: currentPrice,
            change: newchange,
            marketValue: newmarketValue
          }
        }
      );
    } else {
      // If the stock doesn't exist, insert a new document in the portfolio collection
      await portfolioCollection.insertOne({
        symbol: symbol,
        name: name,
        quantity: quantity,
        totalCost: totalCost,
        averageCostPerShare: averageCostPerShare,
        currentPrice: currentPrice,
        change: change,
        marketValue: marketValue
      });
      
      console.log('Data inserted successfully into the portfolio collection');
    }

    res.status(200).json({ message: 'Portfolio updated successfully' });
  } catch (error) {
    console.error('Error updating portfolio:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Define route to handle selling stocks and updating user portfolio
app.post('/portfolio/sell', async (req, res) => {
  try {
    const { symbol, name, quantity, totalCost, currentPrice } = req.body;

    const portfolioCollection = client.db('Assignment-3').collection('Portfolio');

    // Check if the user has the stock in the portfolio
    const existingStock = await portfolioCollection.findOne({ symbol: symbol });

    if (existingStock) {
      // Check if the user has enough quantity to sell
      if (existingStock.quantity >= quantity) {
        // Calculate the new quantity after selling
        const newQuantity = existingStock.quantity - quantity;
        const newTotalCost = existingStock.totalCost - totalCost;
        const newAverageCostPerShare = newTotalCost / newQuantity;
        const newchange = newAverageCostPerShare - currentPrice;
        const newmarketValue = currentPrice * newQuantity;

        // If the new quantity becomes zero, remove the stock from the portfolio
        if (newQuantity === 0) {
          await portfolioCollection.deleteOne({ symbol: symbol });
        } else {
          // Update the portfolio with the new quantity
          await portfolioCollection.updateOne(
            { symbol: symbol },
            { $set: { 
              quantity: newQuantity,
              totalCost: newTotalCost,
              averageCostPerShare: newAverageCostPerShare,
              currentPrice: currentPrice,
              change: newchange,
              marketValue: newmarketValue
             } }
          );
        }

        res.status(200).json({ message: 'Stock sold successfully' });
      } else {
        res.status(400).json({ error: 'Insufficient quantity to sell' });
      }
    } else {
      res.status(404).json({ error: 'Stock not found in the portfolio' });
    }
  } catch (error) {
    console.error('Error selling stocks:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

const formatDate = (currentDate) => {
  var day = currentDate.getDate().toString().padStart(2, '0');
  var month = (currentDate.getMonth() + 1).toString().padStart(2, '0');
  var year = currentDate.getFullYear();
  return `${year}-${month}-${day}`
}

// Start Express server
function startServer(client) {
  // Route for fetching profile, quote, peers, and news data
  app.get('/data1', async (req, res) => {
    try {
      const { symbol } = req.query;

      // Fetch profile data
      const profileResponse = await axios.get(`https://finnhub.io/api/v1/stock/profile2?symbol=${symbol}&token=cn94799r01qoee99k2kgcn94799r01qoee99k2l0`);
      const profileData = profileResponse.data;

      // Fetch quote data
      const quoteResponse = await axios.get(`https://finnhub.io/api/v1/quote?symbol=${symbol}&token=cn94799r01qoee99k2kgcn94799r01qoee99k2l0`);
      const quoteData = quoteResponse.data;

      // Fetch peers data
      const peersResponse = await axios.get(`https://finnhub.io/api/v1/stock/peers?symbol=${symbol}&token=cn94799r01qoee99k2kgcn94799r01qoee99k2l0`);
      const peersData = peersResponse.data;

      // Fetch news data
      const from_date = new Date(new Date().getTime() - 30 * 24 * 60 * 60 * 1000).toISOString().slice(0, 10);
      const to_date = new Date().toISOString().slice(0, 10);
      const newsResponse = await axios.get(`https://finnhub.io/api/v1/company-news?symbol=${symbol}&from=${from_date}&to=${to_date}&token=cn94799r01qoee99k2kgcn94799r01qoee99k2l0`);
      const newsData = newsResponse.data;

      // Fetch insights data
      const insightsResponse = await axios.get(`https://finnhub.io/api/v1/stock/insider-sentiment?symbol=${symbol}&from=2022-01-01&token=cn94799r01qoee99k2kgcn94799r01qoee99k2l0`);
      const insightsData = insightsResponse.data;

      // Fetch chart3 data
      const chart3Response = await axios.get(`https://finnhub.io/api/v1/stock/recommendation`, {
        params: {
          symbol: symbol,
          token: 'cn94799r01qoee99k2kgcn94799r01qoee99k2l0'
        }
      });
      const chart3Data = chart3Response.data;

      // Fetch chart4 data
      const chart4Response = await axios.get(`https://finnhub.io/api/v1/stock/earnings`, {
        params: {
          symbol: symbol,
          token: 'cn94799r01qoee99k2kgcn94799r01qoee99k2l0'
        }
      });
      const chart4Data = chart4Response.data;

      res.json({ profileData, quoteData, peersData, newsData, insightsData, chart3Data, chart4Data });
    } catch (error) {
      console.error('Error fetching data1:', error);
      res.status(500).json({ error: 'Internal server error' });
    }
  });

  // Route for fetching other data (insights, charts, etc.)
  app.get('/data2', async (req, res) => {
    try {
      const { symbol } = req.query;

      // Fetch chart1 data
      const today = new Date();
      const todayFormatted = formatDate(today);
      const yesterday = new Date();
      yesterday.setDate(yesterday.getDate() - 1);
      const yesterdayFormatted = formatDate(yesterday);

      const chart1Response = await axios.get(`https://api.polygon.io/v2/aggs/ticker/${symbol}/range/1/hour/${yesterdayFormatted}/${todayFormatted}?adjusted=true&sort=asc&apiKey=Wfz0yDAqWamLS5gDAR3YuxuGtEJ4Sl8z`);
      const chart1Data = chart1Response.data;
      
      // // Get yesterday's date
      // const yesterday = new Date();
      // yesterday.setDate(yesterday.getDate() - 1);
      // const yesterdayFormatted = formatDate(yesterday);

      const twoYearsAgo = new Date();
      twoYearsAgo.setFullYear(twoYearsAgo.getFullYear() - 2);
      const twoYearsAgoFormatted = formatDate(twoYearsAgo);

      // Call Finnhub API
      const chart2Response = await axios.get(`https://api.polygon.io/v2/aggs/ticker/${symbol}/range/1/month/${twoYearsAgoFormatted}/${todayFormatted}?adjusted=true&sort=asc&apiKey=Wfz0yDAqWamLS5gDAR3YuxuGtEJ4Sl8z`);
      const chart2Data = chart2Response.data;

      const combinedData = { chart1Data, chart2Data };

      res.json(combinedData);
    } catch (error) {
      console.error('Error fetching data2:', error);
      res.status(500).json({ error: 'Internal server error' });
    }
  });

  const port = process.env.PORT || 8080;
  app.listen(port, () => {
    console.log(`Server is running on port ${port}`);
  });
}