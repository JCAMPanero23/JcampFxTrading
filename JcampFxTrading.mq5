//+------------------------------------------------------------------+
//|                                              JcampFxTrading.mq5 |
//|                                                    JcampFx Team |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "JcampFx Team"
#property link      ""
#property version   "1.00"
#property description "Advanced Multi-Pair Trading Bot with CSM and Smart Risk Management"

#include "TL_HL_Math.mqh"
#include "JcampFxStrategies.mqh"
#include "JcampFxTradeManager.mqh"

enum ENUM_SL_TYPE
{
    SL_TYPE_ATR,        // ATR Based
    SL_TYPE_FIXED,      // Fixed Pips
    SL_TYPE_STRUCTURE   // Market Structure
};

//--- Input Parameters
input group "=== TRADING SETTINGS ==="
input bool InpMultiFXTrade = true;                      // Multi FX Trading Enabled
input string InpFxPairs = "EURUSD,AUDCAD,CHFJPY,GBPUSD,USDJPY,EURGBP"; // FX Pairs to Trade (comma separated)
input string InpBrokerSuffix = ".sml";                 // Broker Symbol Suffix
input double InpRiskPercent = 2.0;                     // Risk % per trade
input double InpTPRDistance = 2.0;                     // TP R Distance
input double InpSLRDistance = 1.0;                     // SL R Distance
input double InpBEStartRDistance = 0.8;                // BE Start R Distance
input double InpSLStartRDistance = 0.5;                // SL Trail Start R Distance
input double InpTPStartRDistance = 1.5;                // TP Trail Start R Distance
input int InpMaxSimultaneousTrades = 5;                // Maximum Simultaneous Trades
input double InpMaxSpreadPips = 3.0;                   // Maximum Spread in Pips

// Add these new input parameters (after existing input groups)
input group "=== STOP LOSS SETTINGS ==="
input ENUM_SL_TYPE InpSLType = SL_TYPE_ATR;           // Stop Loss Type
input double InpFixedSLPips = 50;                      // Fixed SL in Pips (if Fixed type)
input double InpATRMultiplier = 1.0;                   // ATR Multiplier for SL
input double InpMinSLPips = 20;                        // Minimum SL in Pips
input double InpMaxSLPips = 100;                       // Maximum SL in Pips
input group "=== CSM SETTINGS ==="
input int InpCSMLookback = 48;                         // CSM Lookback Bars (H1)
input int InpCSMRefreshBars = 4;                       // CSM Refresh Every N Bars

input group "=== STRATEGY SETTINGS ==="
input bool InpEnableTrendRider = true;                 // Enable TrendRider Strategy
input bool InpEnableReversals = true;                  // Enable Reversal Strategy
input bool InpEnableNewsTrading = false;               // Enable News Trading Strategy

input group "=== DISPLAY SETTINGS ==="
input bool InpShowTradeResults = true;                 // Show Trade Results on Chart
input bool InpShowPerformancePanel = true;             // Show Performance Panel
input int InpMaxTrendlines = 3;                        // Max Trendlines per Direction
input int InpMaxSRLevels = 3;                          // Max S/R Levels per Direction

input group "=== LOGGING SETTINGS ==="
input bool InpVerboseLogs = true;                      // Verbose Logs
input bool InpCSVLogs = true;                          // CSV Logs Enabled
input bool InpShowCSMOnMainChart = true;               // Show CSM on Main Chart Only

input group "=== TIME SETTINGS ==="
input string InpTradingStartTime = "08:00";            // Trading Start Time
input string InpTradingEndTime = "22:00";              // Trading End Time

//--- Global Variables
CTL_HL_Math* g_MathLib;
CJcampFxStrategies* g_Strategies;
string g_FxPairsList[];
int g_FxPairsCount = 0;
datetime g_LastCSMUpdate = 0;
datetime g_LastScanTime = 0;
datetime g_LastLogTime = 0;
int g_MagicNumber = 20241201;
string g_CSVFileName = "";
double g_CurrentMonthlyR = 0.0;
int g_MonthlyWins = 0;
int g_MonthlyLosses = 0;
int g_MonthlyCancels = 0;
CTradeManager* g_TradeManager;  // Trade display and tracking manager

//--- CSM Data
struct CSMData
{
    string currency;
    double strength;
};
CSMData g_CSMStrengths[8]; // EUR, USD, GBP, JPY, AUD, CAD, CHF, NZD

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    Print("=== JcampFxTrading Bot Starting ===");
    
    // Initialize libraries
    g_MathLib = new CTL_HL_Math();
    g_Strategies = new CJcampFxStrategies();
    g_TradeManager = new CTradeManager(); 
    
    if(!g_MathLib.Initialize())
    {
        Print("ERROR: Failed to initialize Math Library");
        return INIT_FAILED;
    }
    
    if(!g_Strategies.Initialize(g_MathLib, InpRiskPercent, InpTPRDistance, InpSLRDistance,
                               InpBEStartRDistance, InpSLStartRDistance, InpTPStartRDistance,
                               g_MagicNumber))
    {
        Print("ERROR: Failed to initialize Strategies");
        return INIT_FAILED;
    }
    
    // Parse FX Pairs
    if(!ParseFxPairs())
    {
        Print("ERROR: Failed to parse FX pairs");
        return INIT_FAILED;
    }
    
    // Initialize CSV logging
    if(InpCSVLogs)
        InitializeCSVLogging();
    
    // Set up chart for main pair
    SetupMainChart();
    
    Print("JcampFxTrading Bot initialized successfully");
    Print("Trading pairs: ", g_FxPairsCount, " pairs");
    Print("Magic Number: ", g_MagicNumber);
    
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    if(g_MathLib != NULL)
    {
        delete g_MathLib;
        g_MathLib = NULL;
    }
    
    if(g_Strategies != NULL)
    {
        delete g_Strategies;
        g_Strategies = NULL;
    }
    
    if(g_TradeManager != NULL)  // ADD THIS BLOCK
    {
        delete g_TradeManager;
        g_TradeManager = NULL;
    }
    
    Print("JcampFxTrading Bot stopped. Reason: ", reason);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    if(!InpMultiFXTrade) return;
    if(!IsWithinTradingHours()) return;
    
    datetime currentTime = TimeCurrent();
    
    // Update CSM every N bars (H1 timeframe)
    if(currentTime - g_LastCSMUpdate >= InpCSMRefreshBars * 3600) // 3600 seconds = 1 hour
    {
        UpdateCSM();
        g_LastCSMUpdate = currentTime;
    }
    
    // Main scanning logic - every 1/15 of execution timeframe (M15 = 60 seconds)
    if(currentTime - g_LastScanTime >= 60) // 60 seconds for M15
    {
        PerformMainScan();
        g_LastScanTime = currentTime;
    }
    
    // Trade Management
    g_Strategies.ManageTrades();
    
    // Periodic logging (every 15 minutes)
    if(currentTime - g_LastLogTime >= 900) // 15 minutes
    {
        if(InpVerboseLogs && InpShowCSMOnMainChart && Symbol() == GetMainTradingPair())
        {
            LogCSMStatus();
        }
        g_LastLogTime = currentTime;
    }
}

//+------------------------------------------------------------------+
//| Parse FX pairs from input string                                 |
//+------------------------------------------------------------------+
bool ParseFxPairs()
{
    string pairs = InpFxPairs;
    ArrayResize(g_FxPairsList, 20); // Max 20 pairs
    g_FxPairsCount = 0;
    
    while(StringFind(pairs, ",") >= 0 && g_FxPairsCount < 20)
    {
        int pos = StringFind(pairs, ",");
        string pair = StringSubstr(pairs, 0, pos);
        StringTrimLeft(pair);
        StringTrimRight(pair);
        
        if(StringLen(pair) > 0)
        {
            g_FxPairsList[g_FxPairsCount] = pair + InpBrokerSuffix;
            g_FxPairsCount++;
        }
        
        pairs = StringSubstr(pairs, pos + 1);
    }
    
    // Add the last pair
    if(StringLen(pairs) > 0)
    {
        StringTrimLeft(pairs);
        StringTrimRight(pairs);
        g_FxPairsList[g_FxPairsCount] = pairs + InpBrokerSuffix;
        g_FxPairsCount++;
    }
    
    return g_FxPairsCount > 0;
}

//+------------------------------------------------------------------+
//| Update Currency Strength Meter                                   |
//+------------------------------------------------------------------+
void UpdateCSM()
{
    // Initialize currencies
    string currencies[] = {"EUR", "USD", "GBP", "JPY", "AUD", "CAD", "CHF", "NZD"};
    
    for(int i = 0; i < 8; i++)
    {
        g_CSMStrengths[i].currency = currencies[i];
        g_CSMStrengths[i].strength = 0.0;
    }
    
    // Calculate strength for each currency based on available pairs
    for(int i = 0; i < g_FxPairsCount; i++)
    {
        string symbol = g_FxPairsList[i];
        
        // Get currency codes from symbol
        string baseCurrency = StringSubstr(symbol, 0, 3);
        string quoteCurrency = StringSubstr(symbol, 3, 3);
        
        // Calculate price change over lookback period
        double currentPrice = SymbolInfoDouble(symbol, SYMBOL_BID);
        double pastPrice = iClose(symbol, PERIOD_H1, InpCSMLookback);
        
        if(currentPrice > 0 && pastPrice > 0)
        {
            double percentChange = ((currentPrice - pastPrice) / pastPrice) * 100;
            
            // Update base currency strength (positive change = stronger)
            UpdateCurrencyStrength(baseCurrency, percentChange);
            
            // Update quote currency strength (negative of base change)
            UpdateCurrencyStrength(quoteCurrency, -percentChange);
        }
    }
    
    // Sort currencies by strength
    SortCSMByStrength();
    
    if(InpVerboseLogs && InpShowCSMOnMainChart)
    {
        PrintCSMResults();
    }
}

//+------------------------------------------------------------------+
//| Update individual currency strength                              |
//+------------------------------------------------------------------+
void UpdateCurrencyStrength(string currency, double change)
{
    for(int i = 0; i < 8; i++)
    {
        if(g_CSMStrengths[i].currency == currency)
        {
            g_CSMStrengths[i].strength += change;
            break;
        }
    }
}

//+------------------------------------------------------------------+
//| Sort CSM by strength (descending)                               |
//+------------------------------------------------------------------+
void SortCSMByStrength()
{
    for(int i = 0; i < 7; i++)
    {
        for(int j = i + 1; j < 8; j++)
        {
            if(g_CSMStrengths[j].strength > g_CSMStrengths[i].strength)
            {
                CSMData temp = g_CSMStrengths[i];
                g_CSMStrengths[i] = g_CSMStrengths[j];
                g_CSMStrengths[j] = temp;
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Get priority order of pairs based on CSM                        |
//+------------------------------------------------------------------+
void GetPriorityPairs(string &priorityPairs[])
{
    ArrayResize(priorityPairs, g_FxPairsCount);
    int priorityIndex = 0;
    
    // Find pairs with strongest vs weakest currencies first
    for(int strong = 0; strong < 4; strong++) // Top 4 strongest
    {
        for(int weak = 7; weak > 3; weak--) // Bottom 4 weakest
        {
            string strongCurrency = g_CSMStrengths[strong].currency;
            string weakCurrency = g_CSMStrengths[weak].currency;
            
            // Check if we have this pair
            for(int p = 0; p < g_FxPairsCount; p++)
            {
                string symbol = g_FxPairsList[p];
                string base = StringSubstr(symbol, 0, 3);
                string quote = StringSubstr(symbol, 3, 3);
                
                if((base == strongCurrency && quote == weakCurrency) ||
                   (base == weakCurrency && quote == strongCurrency))
                {
                    // Check if not already added
                    bool alreadyAdded = false;
                    for(int check = 0; check < priorityIndex; check++)
                    {
                        if(priorityPairs[check] == symbol)
                        {
                            alreadyAdded = true;
                            break;
                        }
                    }
                    
                    if(!alreadyAdded && priorityIndex < g_FxPairsCount)
                    {
                        priorityPairs[priorityIndex] = symbol;
                        priorityIndex++;
                    }
                }
            }
        }
    }
    
    // Add remaining pairs
    for(int p = 0; p < g_FxPairsCount; p++)
    {
        bool alreadyAdded = false;
        for(int check = 0; check < priorityIndex; check++)
        {
            if(priorityPairs[check] == g_FxPairsList[p])
            {
                alreadyAdded = true;
                break;
            }
        }
        
        if(!alreadyAdded && priorityIndex < g_FxPairsCount)
        {
            priorityPairs[priorityIndex] = g_FxPairsList[p];
            priorityIndex++;
        }
    }
}

//+------------------------------------------------------------------+
//| Perform main scanning logic                                      |
//+------------------------------------------------------------------+
void PerformMainScan()
{
    // Check if we've reached maximum trades
    if(CountOurTrades() >= InpMaxSimultaneousTrades)
        return;
    
    string priorityPairs[];
    GetPriorityPairs(priorityPairs);
    
    // Scan pairs in priority order
    for(int i = 0; i < g_FxPairsCount; i++)
    {
        string symbol = priorityPairs[i];
        
        // Check spread filter
        if(!CheckSpreadFilter(symbol))
            continue;
        
        // Skip if we already have a trade on this symbol
        if(HasOpenTrade(symbol))
            continue;
        
        // Update technical analysis with LIMITED lines
        g_MathLib.UpdateTechnicalAnalysis(symbol, PERIOD_M15);
        
        // Use limited line methods if available
        // Note: These methods need to be added to CTL_HL_Math class
        // For now, we'll use the regular methods
        // g_MathLib.FindBestTrendLines(symbol, PERIOD_M15, InpMaxTrendlines);
        // g_MathLib.FindBestHorizontalLevels(symbol, PERIOD_M15, InpMaxSRLevels);
        
        // Run strategy scans
        if(InpEnableTrendRider)
        {
            int signal = g_Strategies.ScanTrendRider(symbol);
            if(signal != 0)
            {
                ExecuteTrade(symbol, signal, "TrendRider");
                break;
            }
        }
        
        if(InpEnableReversals)
        {
            int signal = g_Strategies.ScanReversals(symbol);
            if(signal != 0)
            {
                ExecuteTrade(symbol, signal, "Reversals");
                break;
            }
        }
        
        if(InpEnableNewsTrading)
        {
            int signal = g_Strategies.ScanNewsTrading(symbol);
            if(signal != 0)
            {
                ExecuteTrade(symbol, signal, "NewsTrading");
                break;
            }
        }
    }
}

// Event handler to detect closed trades
void OnTrade()
{
    // Check for closed positions
    static int lastHistoryTotal = 0;
    int currentHistoryTotal = HistoryDealsTotal();
    
    if(currentHistoryTotal > lastHistoryTotal)
    {
        // Select history for today
        HistorySelect(TimeCurrent() - 86400, TimeCurrent());
        
        // Check the last deal
        int totalDeals = HistoryDealsTotal();
        for(int i = totalDeals - 1; i >= MathMax(0, totalDeals - 5); i--)
        {
            ulong dealTicket = HistoryDealGetTicket(i);
            if(dealTicket > 0)
            {
                long dealMagic = HistoryDealGetInteger(dealTicket, DEAL_MAGIC);
                if(dealMagic == g_MagicNumber)
                {
                    long dealEntry = HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
                    if(dealEntry == DEAL_ENTRY_OUT) // Position closed
                    {
                        // Get position info
                        ulong positionTicket = HistoryDealGetInteger(dealTicket, DEAL_POSITION_ID);
                        string symbol = HistoryDealGetString(dealTicket, DEAL_SYMBOL);
                        double closePrice = HistoryDealGetDouble(dealTicket, DEAL_PRICE);
                        double profit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
                        
                        // Find the opening deal
                        for(int j = 0; j < totalDeals; j++)
                        {
                            ulong openDealTicket = HistoryDealGetTicket(j);
                            if(HistoryDealGetInteger(openDealTicket, DEAL_POSITION_ID) == positionTicket &&
                               HistoryDealGetInteger(openDealTicket, DEAL_ENTRY) == DEAL_ENTRY_IN)
                            {
                                double openPrice = HistoryDealGetDouble(openDealTicket, DEAL_PRICE);
                                string comment = HistoryDealGetString(openDealTicket, DEAL_COMMENT);
                                
                                // Extract strategy from comment
                                string strategy = "Unknown";
                                if(StringFind(comment, "TrendRider") >= 0) strategy = "TrendRider";
                                else if(StringFind(comment, "Reversals") >= 0) strategy = "Reversals";
                                else if(StringFind(comment, "NewsTrading") >= 0) strategy = "NewsTrading";
                                
                                // Calculate R-multiple (simplified - you may need to store SL info)
                                double rMultiple = 0;
                                bool isWin = profit > 0;
                                
                                // Log the trade result
                                if(g_TradeManager != NULL && InpShowTradeResults)
                                {
                                    g_TradeManager.DisplayTradeResult(symbol, TimeCurrent(), closePrice,
                                                                     rMultiple, isWin, strategy);
                                    g_TradeManager.RecordClosedTrade(positionTicket, symbol, strategy,
                                                                    rMultiple, isWin, profit);
                                }
                                
                                // Update monthly stats
                                if(isWin)
                                {
                                    g_MonthlyWins++;
                                    g_CurrentMonthlyR += rMultiple;
                                }
                                else
                                {
                                    g_MonthlyLosses++;
                                    g_CurrentMonthlyR -= MathAbs(rMultiple);
                                }
                                
                                // Log to CSV
                                LogToCSV(isWin ? "WIN" : "LOSS", symbol, strategy, openPrice, 0, closePrice,
                                        StringFormat("Profit: %.2f, R: %.2f", profit, rMultiple));
                                
                                break;
                            }
                        }
                    }
                }
            }
        }
        
        lastHistoryTotal = currentHistoryTotal;
    }
}
//+------------------------------------------------------------------+
//| Execute trade                                                    |
//+------------------------------------------------------------------+
bool ExecuteTrade(string symbol, int signal, string strategy)
{
    double currentPrice = (signal > 0) ? SymbolInfoDouble(symbol, SYMBOL_ASK) : SymbolInfoDouble(symbol, SYMBOL_BID);
    double stopLoss = CalculateStopLoss(symbol, signal, strategy, currentPrice);
    double takeProfit = CalculateTakeProfit(symbol, signal, currentPrice, stopLoss);
    
    if(!g_Strategies.ExecuteTradeWithSL(symbol, signal, strategy, stopLoss, takeProfit))
    {
        if(InpVerboseLogs)
            Print("TRADE CANCELLED: ", symbol, " Signal: ", signal, " Strategy: ", strategy);
        
        g_MonthlyCancels++;
        LogToCSV("CANCEL", symbol, strategy, 0, 0, 0, "Trade cancelled by smart rules");
        return false;
    }
    else
    {
        if(InpVerboseLogs)
            Print("TRADE EXECUTED: ", symbol, " Signal: ", (signal > 0 ? "BUY" : "SELL"), 
                  " Strategy: ", strategy, " SL: ", stopLoss, " TP: ", takeProfit);
        return true;
    }
}

// Add function to calculate stop loss
double CalculateStopLoss(string symbol, int signal, string strategy, double entryPrice)
{
    double sl = 0;
    double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
    double atr = g_MathLib.CalculateATR(symbol, PERIOD_M15);
    
    switch(InpSLType)
    {
        case SL_TYPE_FIXED:
            // Fixed pip stop loss
            if(signal > 0) // Buy
                sl = entryPrice - (InpFixedSLPips * point * 10);
            else // Sell
                sl = entryPrice + (InpFixedSLPips * point * 10);
            break;
            
        case SL_TYPE_ATR:
            // ATR based stop loss
            double atrDistance = atr * InpATRMultiplier * InpSLRDistance;
            if(signal > 0) // Buy
                sl = entryPrice - atrDistance;
            else // Sell
                sl = entryPrice + atrDistance;
            break;
            
        case SL_TYPE_STRUCTURE:
            // Structure based - find nearest swing point
            sl = FindStructureBasedSL(symbol, signal, entryPrice, strategy);
            break;
    }
    
    // Apply min/max limits
    double slDistance = MathAbs(entryPrice - sl);
    double slPips = slDistance / (point * 10);
    
    if(slPips < InpMinSLPips)
    {
        if(signal > 0)
            sl = entryPrice - (InpMinSLPips * point * 10);
        else
            sl = entryPrice + (InpMinSLPips * point * 10);
    }
    else if(slPips > InpMaxSLPips)
    {
        if(signal > 0)
            sl = entryPrice - (InpMaxSLPips * point * 10);
        else
            sl = entryPrice + (InpMaxSLPips * point * 10);
    }
    
    return NormalizeDouble(sl, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS));
}

// Add function to calculate take profit based on SL
double CalculateTakeProfit(string symbol, int signal, double entryPrice, double stopLoss)
{
    double slDistance = MathAbs(entryPrice - stopLoss);
    double tpDistance = slDistance * InpTPRDistance; // Use R:R ratio
    
    double tp;
    if(signal > 0) // Buy
        tp = entryPrice + tpDistance;
    else // Sell
        tp = entryPrice - tpDistance;
    
    return NormalizeDouble(tp, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS));
}

// Add helper function for structure-based SL
double FindStructureBasedSL(string symbol, int signal, double entryPrice, string strategy)
{
    double sl = 0;
    double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
    
    if(strategy == "Reversals")
    {
        // For reversals at S/R, place SL beyond the level
        if(signal > 0) // Buy at support
        {
            double support = g_MathLib.GetNearestSupportLevel(entryPrice);
            if(support > 0)
                sl = support - (10 * point * 10); // 10 pips below support
            else
                sl = entryPrice - (InpMinSLPips * point * 10);
        }
        else // Sell at resistance
        {
            double resistance = g_MathLib.GetNearestResistanceLevel(entryPrice);
            if(resistance > 0)
                sl = resistance + (10 * point * 10); // 10 pips above resistance
            else
                sl = entryPrice + (InpMinSLPips * point * 10);
        }
    }
    else
    {
        // Find recent swing high/low
        int lookback = 20;
        if(signal > 0) // Buy - find recent swing low
        {
            double lowestLow = entryPrice;
            for(int i = 1; i <= lookback; i++)
            {
                double low = iLow(symbol, PERIOD_M15, i);
                if(low < lowestLow)
                    lowestLow = low;
            }
            sl = lowestLow - (5 * point * 10);
        }
        else // Sell - find recent swing high
        {
            double highestHigh = entryPrice;
            for(int i = 1; i <= lookback; i++)
            {
                double high = iHigh(symbol, PERIOD_M15, i);
                if(high > highestHigh)
                    highestHigh = high;
            }
            sl = highestHigh + (5 * point * 10);
        }
    }
    
    return sl;
}

//+------------------------------------------------------------------+
//| Check spread filter                                              |
//+------------------------------------------------------------------+
bool CheckSpreadFilter(string symbol)
{
    double spread = SymbolInfoInteger(symbol, SYMBOL_SPREAD) * SymbolInfoDouble(symbol, SYMBOL_POINT);
    double pipValue = SymbolInfoDouble(symbol, SYMBOL_POINT) * 10;
    double spreadPips = spread / pipValue;
    
    return spreadPips <= InpMaxSpreadPips;
}

//+------------------------------------------------------------------+
//| Count our trades                                                 |
//+------------------------------------------------------------------+
int CountOurTrades()
{
    int count = 0;
    int total = PositionsTotal();
    
    if(total > 0)
    {
        for(int pos = total - 1; pos >= 0; pos--)
        {
            ulong ticket = PositionGetTicket(pos);
            if(ticket > 0)
            {
                if(PositionSelectByTicket(ticket))
                {
                    if(PositionGetInteger(POSITION_MAGIC) == g_MagicNumber)
                        count++;
                }
            }
        }
    }
    
    return count;
}

//+------------------------------------------------------------------+
//| Check if we have open trade on symbol                           |
//+------------------------------------------------------------------+
bool HasOpenTrade(string symbol)
{
    int total = PositionsTotal();
    
    if(total > 0)
    {
        for(int pos = total - 1; pos >= 0; pos--)
        {
            ulong ticket = PositionGetTicket(pos);
            if(ticket > 0)
            {
                if(PositionSelectByTicket(ticket))
                {
                    if(PositionGetInteger(POSITION_MAGIC) == g_MagicNumber &&
                       PositionGetString(POSITION_SYMBOL) == symbol)
                        return true;
                }
            }
        }
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Check if within trading hours                                    |
//+------------------------------------------------------------------+
bool IsWithinTradingHours()
{
    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);
    
    int currentMinutes = dt.hour * 60 + dt.min;
    
    string startTime = InpTradingStartTime;
    string endTime = InpTradingEndTime;
    
    int startHour = (int)StringToInteger(StringSubstr(startTime, 0, 2));
    int startMin = (int)StringToInteger(StringSubstr(startTime, 3, 2));
    int startMinutes = startHour * 60 + startMin;
    
    int endHour = (int)StringToInteger(StringSubstr(endTime, 0, 2));
    int endMin = (int)StringToInteger(StringSubstr(endTime, 3, 2));
    int endMinutes = endHour * 60 + endMin;
    
    return currentMinutes >= startMinutes && currentMinutes <= endMinutes;
}

//+------------------------------------------------------------------+
//| Setup main chart with indicators                                 |
//+------------------------------------------------------------------+
void SetupMainChart()
{
    // This will be called to setup the main chart where EA is attached
    g_MathLib.SetupChart(Symbol(), PERIOD_M15, true); // true = main chart
}

//+------------------------------------------------------------------+
//| Get main trading pair                                           |
//+------------------------------------------------------------------+
string GetMainTradingPair()
{
    return (g_FxPairsCount > 0) ? g_FxPairsList[0] : Symbol();
}

//+------------------------------------------------------------------+
//| Print CSM results                                               |
//+------------------------------------------------------------------+
void PrintCSMResults()
{
    string csmText = "CSM Results: ";
    for(int i = 0; i < 8; i++)
    {
        csmText += g_CSMStrengths[i].currency + "(" + DoubleToString(g_CSMStrengths[i].strength, 2) + ") ";
    }
    Print(csmText);
}

//+------------------------------------------------------------------+
//| Log CSM status                                                  |
//+------------------------------------------------------------------+
void LogCSMStatus()
{
    if(InpShowCSMOnMainChart && Symbol() == GetMainTradingPair())
    {
        PrintCSMResults();
        Print("Active Trades: ", CountOurTrades(), "/", InpMaxSimultaneousTrades);
        Print("Monthly Stats - Wins: ", g_MonthlyWins, " Losses: ", g_MonthlyLosses, " Cancels: ", g_MonthlyCancels, " R: ", DoubleToString(g_CurrentMonthlyR, 2));
    }
}

//+------------------------------------------------------------------+
//| Initialize CSV logging                                           |
//+------------------------------------------------------------------+
void InitializeCSVLogging()
{
    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);
    
    g_CSVFileName = StringFormat("JcampFxTrading_%04d_%02d.csv", dt.year, dt.mon);
    
    // Check if file exists, if not create header
    int fileHandle = FileOpen(g_CSVFileName, FILE_READ|FILE_CSV);
    if(fileHandle == INVALID_HANDLE)
    {
        // Create new file with header
        fileHandle = FileOpen(g_CSVFileName, FILE_WRITE|FILE_CSV);
        if(fileHandle != INVALID_HANDLE)
        {
            FileWrite(fileHandle, "DateTime", "Action", "Symbol", "Strategy", "Price", "SL", "TP", "Risk", "Result", "R-Multiple", "Comment");
            FileClose(fileHandle);
        }
    }
    else
    {
        FileClose(fileHandle);
    }
}

//+------------------------------------------------------------------+
//| Log to CSV                                                      |
//+------------------------------------------------------------------+
void LogToCSV(string action, string symbol, string strategy, double price, double sl, double tp, string comment)
{
    if(!InpCSVLogs) return;
    
    int fileHandle = FileOpen(g_CSVFileName, FILE_WRITE|FILE_CSV|FILE_READ);
    if(fileHandle != INVALID_HANDLE)
    {
        FileSeek(fileHandle, 0, SEEK_END);
        
        double risk = 0;
        double result = 0;
        double rMultiple = 0;
        
        if(action == "WIN" || action == "LOSS")
        {
            // Calculate R-multiple (will be implemented in strategies)
            // This is a placeholder
        }
        
        FileWrite(fileHandle, TimeToString(TimeCurrent()), action, symbol, strategy, 
                 DoubleToString(price, 5), DoubleToString(sl, 5), DoubleToString(tp, 5),
                 DoubleToString(risk, 2), DoubleToString(result, 2), DoubleToString(rMultiple, 2), comment);
        FileClose(fileHandle);
    }
}

//+------------------------------------------------------------------+