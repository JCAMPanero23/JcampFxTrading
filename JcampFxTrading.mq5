//+------------------------------------------------------------------+
//|                                              JcampFxTrading.mq5 |
//|                                                    JcampFx Team |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "JcampFx Team"
#property link      ""
#property version   "1.02"
#property description "Advanced Multi-Pair Trading Bot with CSM and Complete Daily Risk Management - FINAL"

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

input group "=== DAILY RISK LIMITS ==="
input double InpMaxDailyLossR = -3.0;                  // Max Daily Loss in R
input double InpMaxDailyLoss = 500.0;                  // Max Daily Loss in Account Currency
input int InpMaxDailyTrades = 8;                       // Max Trades Per Day
input int InpMaxConsecutiveLosses = 3;                 // Max Consecutive Losses
input int InpCooldownMinutes = 120;                    // Minutes to wait after max losses
input bool InpStopOnDailyLimit = true;                 // Stop Trading When Limits Hit
input bool InpAutoResetDaily = true;                   // Auto Reset Counters Daily

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
input bool InpShowRiskPanel = true;                    // Show Daily Risk Panel
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
CTradeManager* g_TradeManager;

//--- Daily Risk Management Variables
double g_DailyR = 0.0;
double g_DailyProfit = 0.0;
int g_DailyTradeCount = 0;
int g_ConsecutiveLosses = 0;
int g_ConsecutiveWins = 0;
datetime g_LastLossTime = 0;
datetime g_LastTradeTime = 0;
datetime g_DailyResetTime = 0;
datetime g_CooldownEndTime = 0;
bool g_DailyLimitHit = false;
bool g_InCooldown = false;
string g_RiskStatus = "SAFE";

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
    Print("=== JcampFxTrading Bot Starting (v1.02 - FINAL) ===");
    
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
    
    // Initialize daily risk management
    InitializeDailyRiskManagement();
    
    // Initialize CSV logging
    if(InpCSVLogs)
        InitializeCSVLogging();
    
    // Set up chart for main pair
    SetupMainChart();
    
    Print("JcampFxTrading Bot initialized successfully");
    Print("Trading pairs: ", g_FxPairsCount, " pairs");
    Print("Daily Risk Limits: R=", InpMaxDailyLossR, ", $=", InpMaxDailyLoss, ", Trades=", InpMaxDailyTrades);
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
    
    if(g_TradeManager != NULL)
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
    
    static bool testDone = false;
    if(!testDone && g_TradeManager != NULL)
    {
        TestTradeManager();
        testDone = true;
    }

    if(!InpMultiFXTrade) return;
    if(!IsWithinTradingHours()) return;
    
    datetime currentTime = TimeCurrent();
    
    // Update daily risk management
    UpdateDailyRiskManagement();
    
    // Check if trading is blocked by daily limits
    if(IsDailyLimitExceeded())
    {
        // Update risk panel but don't trade
        if(g_TradeManager != NULL && InpShowRiskPanel)
            UpdateTradeManagerRiskPanel();
        return;
    }
    
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
    
    // Update risk and performance panels
    if(g_TradeManager != NULL)
    {
        if(InpShowRiskPanel)
            UpdateTradeManagerRiskPanel();
        if(InpShowPerformancePanel)
            g_TradeManager.UpdatePerformancePanel();
    }
    
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
//| Update Trade Manager Risk Panel (FIXED)                         |
//+------------------------------------------------------------------+
void UpdateTradeManagerRiskPanel()
{
    if(g_TradeManager == NULL) return;
    
    DailyRiskData riskData;
    riskData.dailyR = g_DailyR;
    riskData.dailyProfit = g_DailyProfit;
    riskData.dailyTradeCount = g_DailyTradeCount;
    riskData.consecutiveLosses = g_ConsecutiveLosses;
    riskData.riskStatus = g_RiskStatus;
    riskData.dailyLimitHit = g_DailyLimitHit;
    riskData.inCooldown = g_InCooldown;
    riskData.cooldownEndTime = g_CooldownEndTime;
    riskData.maxDailyLossR = InpMaxDailyLossR;
    riskData.maxDailyLoss = InpMaxDailyLoss;
    riskData.maxDailyTrades = InpMaxDailyTrades;
    riskData.maxConsecutiveLosses = InpMaxConsecutiveLosses;
    
    g_TradeManager.UpdateRiskPanel(riskData);
}

//+------------------------------------------------------------------+
//| Initialize Daily Risk Management                                 |
//+------------------------------------------------------------------+
void InitializeDailyRiskManagement()
{
    // Set daily reset time to start of today
    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);
    dt.hour = 0;
    dt.min = 0;
    dt.sec = 0;
    g_DailyResetTime = StructToTime(dt);
    
    // Reset all counters
    ResetDailyCounters();
    
    g_RiskStatus = "SAFE";
    Print("Daily Risk Management Initialized");
}

//+------------------------------------------------------------------+
//| Update Daily Risk Management                                     |
//+------------------------------------------------------------------+
void UpdateDailyRiskManagement()
{
    // Check if we need to reset daily counters
    if(InpAutoResetDaily)
    {
        MqlDateTime dt;
        TimeToStruct(TimeCurrent(), dt);
        dt.hour = 0;
        dt.min = 0;
        dt.sec = 0;
        datetime todayStart = StructToTime(dt);
        
        if(todayStart > g_DailyResetTime)
        {
            ResetDailyCounters();
            g_DailyResetTime = todayStart;
            g_RiskStatus = "SAFE";
        }
    }
    
    // Update cooldown status
    if(g_InCooldown && TimeCurrent() >= g_CooldownEndTime)
    {
        g_InCooldown = false;
        g_ConsecutiveLosses = 0; // Reset consecutive losses after cooldown
        UpdateRiskStatus();
    }
    
    // Update risk status based on current levels
    UpdateRiskStatus();
}

//+------------------------------------------------------------------+
//| Reset Daily Counters                                             |
//+------------------------------------------------------------------+
void ResetDailyCounters()
{
    g_DailyR = 0.0;
    g_DailyProfit = 0.0;
    g_DailyTradeCount = 0;
    g_ConsecutiveLosses = 0;
    g_ConsecutiveWins = 0;
    g_DailyLimitHit = false;
    g_InCooldown = false;
    g_CooldownEndTime = 0;
    g_RiskStatus = "SAFE";
}

//+------------------------------------------------------------------+
//| Check if daily limits exceeded                                   |
//+------------------------------------------------------------------+
bool IsDailyLimitExceeded()
{
    if(!InpStopOnDailyLimit) return false;
    
    // Check daily R loss limit
    if(g_DailyR <= InpMaxDailyLossR)
    {
        if(!g_DailyLimitHit)
        {
            g_DailyLimitHit = true;
            g_RiskStatus = "BLOCKED - R LIMIT";
        }
        return true;
    }
    
    // Check daily dollar loss limit  
    if(g_DailyProfit <= -InpMaxDailyLoss)
    {
        if(!g_DailyLimitHit)
        {
            g_DailyLimitHit = true;
            g_RiskStatus = "BLOCKED - $ LIMIT";
        }
        return true;
    }
    
    // Check daily trade limit
    if(g_DailyTradeCount >= InpMaxDailyTrades)
    {
        if(!g_DailyLimitHit)
        {
            g_DailyLimitHit = true;
            g_RiskStatus = "BLOCKED - TRADE LIMIT";
        }
        return true;
    }
    
    // Check consecutive losses + cooldown
    if(g_ConsecutiveLosses >= InpMaxConsecutiveLosses)
    {
        if(!g_InCooldown)
        {
            g_InCooldown = true;
            g_CooldownEndTime = TimeCurrent() + (InpCooldownMinutes * 60);
            g_RiskStatus = "COOLDOWN";
        }
        return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Update Risk Status                                               |
//+------------------------------------------------------------------+
void UpdateRiskStatus()
{
    if(g_DailyLimitHit || g_InCooldown) return; // Status already set
    
    // Calculate risk percentages
    double rPercent = (g_DailyR / InpMaxDailyLossR) * 100;
    double dollarPercent = (MathAbs(g_DailyProfit) / InpMaxDailyLoss) * 100;
    double tradePercent = ((double)g_DailyTradeCount / (double)InpMaxDailyTrades) * 100;
    double lossPercent = ((double)g_ConsecutiveLosses / (double)InpMaxConsecutiveLosses) * 100;
    
    double maxPercent = MathMax(MathMax(rPercent, dollarPercent), MathMax(tradePercent, lossPercent));
    
    if(maxPercent >= 90)
        g_RiskStatus = "DANGER";
    else if(maxPercent >= 70)
        g_RiskStatus = "CAUTION";
    else if(maxPercent >= 50)
        g_RiskStatus = "WARNING";
    else
        g_RiskStatus = "SAFE";
}

//+------------------------------------------------------------------+
//| Record Trade Result for Daily Tracking                          |
//+------------------------------------------------------------------+
void RecordTradeResult(double rMultiple, double profit, bool isWin)
{
    g_DailyR += rMultiple;
    g_DailyProfit += profit;
    g_DailyTradeCount++;
    g_LastTradeTime = TimeCurrent();
    
    if(isWin)
    {
        g_ConsecutiveLosses = 0;
        g_ConsecutiveWins++;
    }
    else
    {
        g_ConsecutiveWins = 0;
        g_ConsecutiveLosses++;
        g_LastLossTime = TimeCurrent();
    }
    
    UpdateRiskStatus();
}

//+------------------------------------------------------------------+
//| Parse FX pairs from input string                                 |
//+------------------------------------------------------------------+
bool ParseFxPairs()
{
    string pairs = InpFxPairs;
    ArrayResize(g_FxPairsList, 20);
    g_FxPairsCount = 0;
    
    while(StringFind(pairs, ",") >= 0 && g_FxPairsCount < 20)
    {
        int pos = StringFind(pairs, ",");
        string pair = StringSubstr(pairs, 0, pos);
        StringTrimLeft(pair);
        StringTrimRight(pair);
        
        if(StringLen(pair) > 0)
        {
            // Check if symbol exists with suffix
            string symbolWithSuffix = pair + InpBrokerSuffix;
            string symbolWithoutSuffix = pair;
            
            // Try with suffix first
            if(SymbolInfoInteger(symbolWithSuffix, SYMBOL_SELECT))
            {
                g_FxPairsList[g_FxPairsCount] = symbolWithSuffix;
                g_FxPairsCount++;
            }
            // If not found, try without suffix
            else if(SymbolInfoInteger(symbolWithoutSuffix, SYMBOL_SELECT))
            {
                g_FxPairsList[g_FxPairsCount] = symbolWithoutSuffix;
                g_FxPairsCount++;
            }
            else
            {
                Print("Warning: Symbol ", pair, " not found with or without suffix");
            }
        }
        
        pairs = StringSubstr(pairs, pos + 1);
    }
    
    // Add the last pair
    if(StringLen(pairs) > 0)
    {
        StringTrimLeft(pairs);
        StringTrimRight(pairs);
        
        string symbolWithSuffix = pairs + InpBrokerSuffix;
        string symbolWithoutSuffix = pairs;
        
        if(SymbolInfoInteger(symbolWithSuffix, SYMBOL_SELECT))
        {
            g_FxPairsList[g_FxPairsCount] = symbolWithSuffix;
            g_FxPairsCount++;
        }
        else if(SymbolInfoInteger(symbolWithoutSuffix, SYMBOL_SELECT))
        {
            g_FxPairsList[g_FxPairsCount] = symbolWithoutSuffix;
            g_FxPairsCount++;
        }
    }
    
    return g_FxPairsCount > 0;
}

//+------------------------------------------------------------------+
//| CORRELATION CHECK                                                |
//+------------------------------------------------------------------+
bool IsCorrelatedPair(string symbol1, string symbol2)
{
    // Extract base and quote currencies
    string base1 = StringSubstr(symbol1, 0, 3);
    string quote1 = StringSubstr(symbol1, 3, 3);
    string base2 = StringSubstr(symbol2, 0, 3);
    string quote2 = StringSubstr(symbol2, 3, 3);
    
    // Check for correlation (same currency in both pairs)
    if(base1 == base2 || quote1 == quote2) return true;
    if(base1 == quote2 || quote1 == base2) return true;
    
    // Special correlation groups
    string correlatedGroups[][4] = {
        {"EUR", "GBP", "CHF", ""},  // European currencies
        {"AUD", "NZD", "", ""},      // Commodity currencies
        {"USD", "CAD", "", ""}       // Dollar bloc
    };
    
    for(int i = 0; i < ArrayRange(correlatedGroups, 0); i++)
    {
        bool pair1InGroup = false;
        bool pair2InGroup = false;
        
        for(int j = 0; j < 4; j++)
        {
            if(correlatedGroups[i][j] == "") break;
            if(base1 == correlatedGroups[i][j] || quote1 == correlatedGroups[i][j])
                pair1InGroup = true;
            if(base2 == correlatedGroups[i][j] || quote2 == correlatedGroups[i][j])
                pair2InGroup = true;
        }
        
        if(pair1InGroup && pair2InGroup) return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Check for open trades or correlated pairs                       |
//+------------------------------------------------------------------+
bool HasOpenTradeOrCorrelated(string symbol)
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
                    if(PositionGetInteger(POSITION_MAGIC) == g_MagicNumber)
                    {
                        string posSymbol = PositionGetString(POSITION_SYMBOL);
                        
                        // Check exact match
                        if(posSymbol == symbol) return true;
                        
                        // Check correlation
                        if(IsCorrelatedPair(symbol, posSymbol)) 
                        {
                            if(InpVerboseLogs)
                                Print("Skipping ", symbol, " - correlated with open position on ", posSymbol);
                            return true;
                        }
                    }
                }
            }
        }
    }
    
    return false;
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
//| FIXED: Perform main scanning logic                              |
//+------------------------------------------------------------------+
void PerformMainScan()
{
    if(CountOurTrades() >= InpMaxSimultaneousTrades)
        return;
    
    // Check daily limits before scanning
    if(IsDailyLimitExceeded())
        return;
    
    string priorityPairs[];
    GetPriorityPairs(priorityPairs);
    
    for(int i = 0; i < g_FxPairsCount; i++)
    {
        string symbol = priorityPairs[i];
        
        if(!CheckSpreadFilter(symbol))
            continue;
        
        // Use correlation-aware check
        if(HasOpenTradeOrCorrelated(symbol))
            continue;
        
        // **FIXED**: Analyze symbol INDIVIDUALLY and run strategies IMMEDIATELY
        if(!g_MathLib.UpdateTechnicalAnalysis(symbol, PERIOD_M15))
        {
            if(InpVerboseLogs)
                Print("WARNING: Failed to analyze ", symbol);
            continue;
        }
        
        // Run strategy scans immediately after analysis (while data is fresh)
        bool tradeExecuted = false;
        
        if(InpEnableTrendRider && !tradeExecuted)
        {
            int signal = g_Strategies.ScanTrendRider(symbol);
            if(signal != 0)
            {
                tradeExecuted = ExecuteTrade(symbol, signal, "TrendRider");
                if(tradeExecuted) break; // Exit loop after successful trade
            }
        }
        
        if(InpEnableReversals && !tradeExecuted)
        {
            int signal = g_Strategies.ScanReversals(symbol);
            if(signal != 0)
            {
                tradeExecuted = ExecuteTrade(symbol, signal, "Reversals");
                if(tradeExecuted) break;
            }
        }
        
        if(InpEnableNewsTrading && !tradeExecuted)
        {
            int signal = g_Strategies.ScanNewsTrading(symbol);
            if(signal != 0)
            {
                tradeExecuted = ExecuteTrade(symbol, signal, "NewsTrading");
                if(tradeExecuted) break;
            }
        }
        
        // Update drawings ONLY for current chart symbol
        if(symbol == Symbol())
        {
            g_MathLib.UpdateDrawings();
            ChartRedraw();
        }
    }
}

//+------------------------------------------------------------------+
//| Event handler to detect closed trades                           |
//+------------------------------------------------------------------+
void OnTrade()
{
    Print("=== OnTrade() triggered ===");
    
    static int lastHistoryTotal = 0;
    int currentHistoryTotal = HistoryDealsTotal();
    
    Print("OnTrade: History deals - Last:", lastHistoryTotal, " Current:", currentHistoryTotal);
    
    if(currentHistoryTotal > lastHistoryTotal)
    {
        // Select recent history
        if(!HistorySelect(TimeCurrent() - 86400, TimeCurrent()))
        {
            Print("ERROR: Failed to select history");
            return;
        }
        
        int totalDeals = HistoryDealsTotal();
        Print("OnTrade: Processing ", totalDeals, " history deals");
        
        for(int i = totalDeals - 1; i >= MathMax(0, totalDeals - 10); i--) // Check last 10 deals
        {
            ulong dealTicket = HistoryDealGetTicket(i);
            if(dealTicket > 0)
            {
                long dealMagic = HistoryDealGetInteger(dealTicket, DEAL_MAGIC);
                Print("OnTrade: Deal ", i, " - Ticket:", dealTicket, " Magic:", dealMagic, " Our Magic:", g_MagicNumber);
                
                if(dealMagic == g_MagicNumber)
                {
                    long dealEntry = HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
                    Print("OnTrade: Deal entry type:", dealEntry, " (OUT=", DEAL_ENTRY_OUT, ")");
                    
                    if(dealEntry == DEAL_ENTRY_OUT)
                    {
                        Print("=== FOUND CLOSING DEAL ===");
                        
                        ulong positionTicket = HistoryDealGetInteger(dealTicket, DEAL_POSITION_ID);
                        string symbol = HistoryDealGetString(dealTicket, DEAL_SYMBOL);
                        double closePrice = HistoryDealGetDouble(dealTicket, DEAL_PRICE);
                        double profit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
                        datetime closeTime = (datetime)HistoryDealGetInteger(dealTicket, DEAL_TIME);
                        
                        Print("OnTrade: Position ID:", positionTicket, " Symbol:", symbol, " Profit:", profit);
                        
                        string strategy = "Unknown";
                        double openPrice = 0;
                        ENUM_DEAL_TYPE dealType = (ENUM_DEAL_TYPE)HistoryDealGetInteger(dealTicket, DEAL_TYPE);
                        
                        // Find opening deal to get strategy and open price
                        for(int j = 0; j < totalDeals; j++)
                        {
                            ulong openDealTicket = HistoryDealGetTicket(j);
                            if(HistoryDealGetInteger(openDealTicket, DEAL_POSITION_ID) == positionTicket &&
                               HistoryDealGetInteger(openDealTicket, DEAL_ENTRY) == DEAL_ENTRY_IN &&
                               HistoryDealGetInteger(openDealTicket, DEAL_MAGIC) == g_MagicNumber)
                            {
                                openPrice = HistoryDealGetDouble(openDealTicket, DEAL_PRICE);
                                string comment = HistoryDealGetString(openDealTicket, DEAL_COMMENT);
                                
                                Print("OnTrade: Found opening deal - Price:", openPrice, " Comment:", comment);
                                
                                if(StringFind(comment, "TrendRider") >= 0) strategy = "TrendRider";
                                else if(StringFind(comment, "Reversals") >= 0) strategy = "Reversals";
                                else if(StringFind(comment, "NewsTrading") >= 0) strategy = "NewsTrading";
                                else strategy = "Manual"; // Fallback
                                break;
                            }
                        }
                        
                        // Calculate R-multiple
                        double priceMove = MathAbs(closePrice - openPrice);
                        double slDistance = priceMove; // Simplified - in real scenario we'd get actual SL
                        double rMultiple = 0;
                        bool isWin = profit > 0;
                        
                        if(isWin)
                        {
                            rMultiple = MathMax(0.1, MathMin(5.0, priceMove / (slDistance + 0.00001))); // Prevent division by zero
                            if(rMultiple < 0.1) rMultiple = 0.5; // Default win R
                        }
                        else
                        {
                            rMultiple = -MathMax(0.1, MathMin(2.0, priceMove / (slDistance + 0.00001))); // Negative for losses
                            if(rMultiple > -0.1) rMultiple = -1.0; // Default loss R
                        }
                        
                        Print("=== CALCULATED TRADE RESULT ===");
                        Print("Strategy:", strategy, " R-Multiple:", rMultiple, " IsWin:", isWin, " Profit:", profit);
                        
                        // Record trade result for daily tracking
                        RecordTradeResult(rMultiple, profit, isWin);
                        
                        // Update displays
                        if(g_TradeManager != NULL)
                        {
                            Print("=== CALLING TRADE MANAGER ===");
                            
                            if(InpShowTradeResults)
                            {
                                g_TradeManager.DisplayTradeResult(symbol, closeTime, closePrice,
                                                                  rMultiple, isWin, strategy);
                            }
                            
                            g_TradeManager.RecordClosedTrade(positionTicket, symbol, strategy,
                                                             rMultiple, isWin, profit);
                            
                            Print("=== TRADE MANAGER CALLS COMPLETED ===");
                        }
                        else
                        {
                            Print("ERROR: g_TradeManager is NULL!");
                        }
                        
                        // Update global stats
                        if(isWin)
                        {
                            g_MonthlyWins++;
                            g_CurrentMonthlyR += rMultiple;
                        }
                        else 
                        { 
                            g_MonthlyLosses++; 
                            g_CurrentMonthlyR += rMultiple; // rMultiple is already negative 
                        } 
                        
                        Print("=== TRADE PROCESSED SUCCESSFULLY ===");  // FIXED - removed StringFormat
                        
                        Print(StringFormat("Trade: %s %s %s | Profit: %.2f | R: %.2f | Daily R: %.2f", 
                                           symbol, strategy, isWin ? "WIN" : "LOSS", profit, rMultiple, g_DailyR));                  }
                }
            }
        }
        
        lastHistoryTotal = currentHistoryTotal;
    }
    else
    {
        Print("OnTrade: No new deals to process");
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
    
    if(!g_Strategies.ExecuteTrade(symbol, signal, strategy))
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

//+------------------------------------------------------------------+
//| Calculate stop loss based on settings                            |
//+------------------------------------------------------------------+
double CalculateStopLoss(string symbol, int signal, string strategy, double entryPrice)
{
    double sl = 0;
    double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
    double atr = g_MathLib.CalculateATR(symbol, PERIOD_M15);    
   
    switch(InpSLType)
    {
        case SL_TYPE_FIXED:
        {
            if(signal > 0)
                sl = entryPrice - (InpFixedSLPips * point * 10);
            else
                sl = entryPrice + (InpFixedSLPips * point * 10);
            break;
        }
        
        case SL_TYPE_ATR:
        {
            double atrDistance = atr * InpATRMultiplier * InpSLRDistance;
            if(signal > 0)
                sl = entryPrice - atrDistance;
            else
                sl = entryPrice + atrDistance;
            break;
        }
        
        case SL_TYPE_STRUCTURE:
        {
            // Find swing points
            int lookback = 20;
            if(signal > 0)
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
            else
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
            break;
        }
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

//+------------------------------------------------------------------+
//| Calculate take profit based on SL                               |
//+------------------------------------------------------------------+
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
    // Setup chart with drawing enabled
    g_MathLib.SetupChart(Symbol(), PERIOD_M15, true); // true = main chart for drawing
    g_MathLib.UpdateTechnicalAnalysis(Symbol(), PERIOD_M15);
    g_MathLib.UpdateDrawings(); // Force initial drawing
    ChartRedraw();
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
        Print("Daily Risk Status: ", g_RiskStatus, " | R: ", DoubleToString(g_DailyR, 2), " | Trades: ", g_DailyTradeCount);
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

//+------------------------------------------------------------------+
//| Test Trade Manager (for debugging)                              |
//+------------------------------------------------------------------+
void TestTradeManager()
{
    if(g_TradeManager != NULL)
    {
        Print("=== TESTING TRADE MANAGER ===");
        g_TradeManager.TestTradeResult();
        Print("=== TEST COMPLETED - Check panels ===");
    }
    else
    {
        Print("ERROR: TradeManager is NULL, cannot test");
    }
}