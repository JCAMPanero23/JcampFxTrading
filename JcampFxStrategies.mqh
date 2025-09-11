//+------------------------------------------------------------------+
//|                                           JcampFxStrategies.mqh |
//|                                                    JcampFx Team |
//|                                     Trading Strategies Library  |
//+------------------------------------------------------------------+

#include <Trade\Trade.mqh>

// Trade management structure
struct TradeInfo
{
    ulong ticket;
    string symbol;
    string strategy;
    datetime openTime;
    double openPrice;
    double initialSL;
    double initialTP;
    double riskAmount;
    double currentR;
    bool beActivated;
    bool slTrailActivated;
    bool tpTrailActivated;
    ENUM_POSITION_TYPE type;
};

// News event structure
struct NewsEvent
{
    datetime time;
    string currency;
    string event;
    int impact; // 1=Low, 2=Medium, 3=High
    bool processed;
};

//+------------------------------------------------------------------+
//| Trading Strategies Class                                         |
//+------------------------------------------------------------------+
class CJcampFxStrategies
{
private:
    CTL_HL_Math* m_MathLib;
    CTrade m_Trade;
    
    // Strategy settings
    double m_RiskPercent;
    double m_TPRDistance;
    double m_SLRDistance;
    double m_BEStartRDistance;
    double m_SLStartRDistance;
    double m_TPStartRDistance;
    int m_MagicNumber;
    
    // Trade management
    TradeInfo m_Trades[];
    int m_TradeCount;
    
    // News trading
    NewsEvent m_NewsEvents[];
    int m_NewsCount;
    datetime m_LastNewsCheck;
    
    // Performance tracking
    double m_MonthlyR;
    int m_MonthlyWins;
    int m_MonthlyLosses;
    int m_MonthlyCancels;
    
    // Internal methods
    bool ValidateTradeEntry(string symbol, int signal, string strategy);
    double CalculatePositionSize(string symbol, double riskAmount, double slDistance);
    bool CheckNewsFilter(string symbol, datetime tradeTime);
    void UpdateTradeR(TradeInfo &trade);
    bool IsWeekend();
    bool IsMarketClosed(string symbol);
    
public:
    // Constructor & Destructor
    CJcampFxStrategies();
    ~CJcampFxStrategies();
    
    // Initialization
    bool Initialize(CTL_HL_Math* mathLib, double riskPercent, double tpRDistance, 
                   double slRDistance, double beStartR, double slStartR, 
                   double tpStartR, int magicNumber);
    
    // Strategy scanning methods
    int ScanTrendRider(string symbol);
    int ScanReversals(string symbol);
    int ScanNewsTrading(string symbol);
    
    // Trade execution and management
    bool ExecuteTrade(string symbol, int signal, string strategy);
    void ManageTrades();
    void CheckBreakEven(TradeInfo &trade);
    void TrailStopLoss(TradeInfo &trade);
    void TrailTakeProfit(TradeInfo &trade);
    
    // News trading methods
    void UpdateNewsEvents();
    bool IsNewsTime(string symbol);
    bool IsHighImpactNews(string currency, datetime time, int minutesBefore = 30, int minutesAfter = 60);
    
    // Utility methods
    double GetAccountRiskAmount();
    double CalculatePipValue(string symbol);
    double NormalizeLots(string symbol, double lots);
    string GetBaseCurrency(string symbol);
    string GetQuoteCurrency(string symbol);
    
    // Performance tracking
    void LogTradeResult(TradeInfo &trade, string result, double rMultiple);
    void ResetMonthlyStats();
    double GetMonthlyR();
    int GetMonthlyWins();
    int GetMonthlyLosses();
    int GetMonthlyCancels();
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CJcampFxStrategies::CJcampFxStrategies()
{
    m_MathLib = NULL;
    m_RiskPercent = 2.0;
    m_TPRDistance = 2.0;
    m_SLRDistance = 1.0;
    m_BEStartRDistance = 0.8;
    m_SLStartRDistance = 0.5;
    m_TPStartRDistance = 1.5;
    m_MagicNumber = 0;
    m_TradeCount = 0;
    m_NewsCount = 0;
    m_LastNewsCheck = 0;
    m_MonthlyR = 0.0;
    m_MonthlyWins = 0;
    m_MonthlyLosses = 0;
    m_MonthlyCancels = 0;
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CJcampFxStrategies::~CJcampFxStrategies()
{
    // Cleanup handled automatically
}

//+------------------------------------------------------------------+
//| Initialize strategies                                            |
//+------------------------------------------------------------------+
bool CJcampFxStrategies::Initialize(CTL_HL_Math* mathLib, double riskPercent, 
                                   double tpRDistance, double slRDistance, 
                                   double beStartR, double slStartR, 
                                   double tpStartR, int magicNumber)
{
    if(mathLib == NULL) return false;
    
    m_MathLib = mathLib;
    m_RiskPercent = riskPercent;
    m_TPRDistance = tpRDistance;
    m_SLRDistance = slRDistance;
    m_BEStartRDistance = beStartR;
    m_SLStartRDistance = slStartR;
    m_TPStartRDistance = tpStartR;
    m_MagicNumber = magicNumber;
    
    m_Trade.SetExpertMagicNumber(m_MagicNumber);
    m_Trade.SetDeviationInPoints(10);
    m_Trade.SetTypeFilling(ORDER_FILLING_IOC);
    
    ArrayResize(m_Trades, 100); // Max 100 concurrent trades
    ArrayResize(m_NewsEvents, 50); // Max 50 news events
    
    return true;
}

//+------------------------------------------------------------------+
//| TrendRider Strategy Scanner                                      |
//+------------------------------------------------------------------+
int CJcampFxStrategies::ScanTrendRider(string symbol)
{
    if(m_MathLib == NULL) return 0;
    
    double currentPrice = SymbolInfoDouble(symbol, SYMBOL_BID);
    double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
    
    // Get current market data
    double high1 = iHigh(symbol, PERIOD_M15, 1);
    double low1 = iLow(symbol, PERIOD_M15, 1);
    double close1 = iClose(symbol, PERIOD_M15, 1);
    double open1 = iOpen(symbol, PERIOD_M15, 1);
    
    double high2 = iHigh(symbol, PERIOD_M15, 2);
    double low2 = iLow(symbol, PERIOD_M15, 2);
    double close2 = iClose(symbol, PERIOD_M15, 2);
    
    // Check for valid trendlines
    int trendLineCount = m_MathLib.GetTrendLineCount();
    if(trendLineCount == 0) return 0;
    
    // Look for trendline bounces with support/resistance awareness
    for(int i = 0; i < trendLineCount; i++)
    {
        TrendLineData trendLine = m_MathLib.GetTrendLine(i);
        
        if(!m_MathLib.IsTrendLineValid(trendLine, TimeCurrent(), currentPrice))
            continue;
        
        double trendLinePrice = m_MathLib.GetTrendLinePrice(trendLine, TimeCurrent());
        double tolerance = 20 * point; // 20 points tolerance
        
        // Check for bullish setup (support trendline bounce)
        if(trendLine.isSupport && 
           low2 <= trendLinePrice + tolerance && low2 >= trendLinePrice - tolerance &&
           close1 > trendLinePrice + tolerance)
        {
            // Confirm with oscillators - not overbought
            OscillatorData osc = m_MathLib.GetOscillatorData();
            if(!osc.overbought)
            {
                // Check support/resistance levels don't block the move
                double nearestResistance = m_MathLib.GetNearestResistanceLevel(currentPrice);
                double atr = m_MathLib.CalculateATR(symbol, PERIOD_M15);
                
                if(nearestResistance == 0 || (nearestResistance - currentPrice) > (m_TPRDistance * atr))
                {
                    return 1; // Buy signal
                }
            }
        }
        
        // Check for bearish setup (resistance trendline rejection)
        if(!trendLine.isSupport && 
           high2 >= trendLinePrice - tolerance && high2 <= trendLinePrice + tolerance &&
           close1 < trendLinePrice - tolerance)
        {
            // Confirm with oscillators - not oversold
            OscillatorData osc = m_MathLib.GetOscillatorData();
            if(!osc.oversold)
            {
                // Check support/resistance levels don't block the move
                double nearestSupport = m_MathLib.GetNearestSupportLevel(currentPrice);
                double atr = m_MathLib.CalculateATR(symbol, PERIOD_M15);
                
                if(nearestSupport == 0 || (currentPrice - nearestSupport) > (m_TPRDistance * atr))
                {
                    return -1; // Sell signal
                }
            }
        }
    }
    
    return 0; // No signal
}

//+------------------------------------------------------------------+
//| Reversal Strategy Scanner                                        |
//+------------------------------------------------------------------+
int CJcampFxStrategies::ScanReversals(string symbol)
{
    if(m_MathLib == NULL) return 0;
    
    double currentPrice = SymbolInfoDouble(symbol, SYMBOL_BID);
    double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
    double tolerance = 15 * point; // 15 points tolerance
    
    // Get horizontal levels
    int levelCount = m_MathLib.GetHorizontalLevelCount();
    if(levelCount == 0) return 0;
    
    // Get oscillator and MACD data
    OscillatorData osc = m_MathLib.GetOscillatorData();
    MACDData macd = m_MathLib.GetMACDData();
    
    // Current and previous candle data
    double high1 = iHigh(symbol, PERIOD_M15, 1);
    double low1 = iLow(symbol, PERIOD_M15, 1);
    double close1 = iClose(symbol, PERIOD_M15, 1);
    double open1 = iOpen(symbol, PERIOD_M15, 1);
    
    // Look for reversal at support/resistance levels
    for(int i = 0; i < levelCount; i++)
    {
        HorizontalLevelData level = m_MathLib.GetHorizontalLevel(i);
        
        // Check for bullish reversal at support
        if(level.isSupport && 
           m_MathLib.IsPriceNearLevel(currentPrice, level.price, tolerance))
        {
            // Multiple confirmation criteria
            bool priceAction = m_MathLib.IsHammer(symbol, PERIOD_M15, 1) || 
                              m_MathLib.IsBullishEngulfing(symbol, PERIOD_M15, 1);
            bool oscillatorOversold = osc.oversold || osc.divergence;
            bool macdBullish = macd.bullishCrossover || (macd.main > macd.signal && macd.histogram > 0);
            bool volumeConfirm = true; // Placeholder for volume analysis
            
            // Require at least 2 confirmations
            int confirmations = 0;
            if(priceAction) confirmations++;
            if(oscillatorOversold) confirmations++;
            if(macdBullish) confirmations++;
            
            if(confirmations >= 2)
            {
                return 1; // Buy signal
            }
        }
        
        // Check for bearish reversal at resistance
        if(!level.isSupport && 
           m_MathLib.IsPriceNearLevel(currentPrice, level.price, tolerance))
        {
            // Multiple confirmation criteria
            bool priceAction = m_MathLib.IsShootingStar(symbol, PERIOD_M15, 1) || 
                              m_MathLib.IsBearishEngulfing(symbol, PERIOD_M15, 1);
            bool oscillatorOverbought = osc.overbought || osc.divergence;
            bool macdBearish = macd.bearishCrossover || (macd.main < macd.signal && macd.histogram < 0);
            bool volumeConfirm = true; // Placeholder for volume analysis
            
            // Require at least 2 confirmations
            int confirmations = 0;
            if(priceAction) confirmations++;
            if(oscillatorOverbought) confirmations++;
            if(macdBearish) confirmations++;
            
            if(confirmations >= 2)
            {
                return -1; // Sell signal
            }
        }
    }
    
    return 0; // No signal
}

//+------------------------------------------------------------------+
//| News Trading Strategy Scanner                                    |
//+------------------------------------------------------------------+
int CJcampFxStrategies::ScanNewsTrading(string symbol)
{
    if(m_MathLib == NULL) return 0;
    
    // Update news events if needed
    if(TimeCurrent() - m_LastNewsCheck > 3600) // Check every hour
    {
        UpdateNewsEvents();
        m_LastNewsCheck = TimeCurrent();
    }
    
    // Check if we're in a news event window
    if(!IsNewsTime(symbol)) return 0;
    
    string baseCurrency = GetBaseCurrency(symbol);
    string quoteCurrency = GetQuoteCurrency(symbol);
    
    // Check for high impact news affecting our currencies
    if(!IsHighImpactNews(baseCurrency, TimeCurrent()) && 
       !IsHighImpactNews(quoteCurrency, TimeCurrent()))
        return 0;
    
    // Wait for volatility spike and momentum
    double atr = m_MathLib.CalculateATR(symbol, PERIOD_M15);
    double currentATR = m_MathLib.CalculateATR(symbol, PERIOD_M5, 3); // Short-term ATR
    
    // Look for volatility expansion
    if(currentATR < atr * 1.5) return 0; // Need at least 50% ATR expansion
    
    // Analyze momentum direction
    double close1 = iClose(symbol, PERIOD_M5, 1);
    double close5 = iClose(symbol, PERIOD_M5, 5);
    double momentum = (close1 - close5) / close5 * 100;
    
    // MACD confirmation
    MACDData macd = m_MathLib.GetMACDData();
    
    // Strong upward momentum
    if(momentum > 0.1 && macd.histogram > 0 && macd.main > macd.signal)
    {
        return 1; // Buy signal
    }
    
    // Strong downward momentum
    if(momentum < -0.1 && macd.histogram < 0 && macd.main < macd.signal)
    {
        return -1; // Sell signal
    }
    
    return 0; // No signal
}

//+------------------------------------------------------------------+
//| Execute trade                                                    |
//+------------------------------------------------------------------+
bool CJcampFxStrategies::ExecuteTrade(string symbol, int signal, string strategy)
{
    if(!ValidateTradeEntry(symbol, signal, strategy))
        return false;
    
    double currentPrice = (signal > 0) ? SymbolInfoDouble(symbol, SYMBOL_ASK) : SymbolInfoDouble(symbol, SYMBOL_BID);
    double atr = m_MathLib.CalculateATR(symbol, PERIOD_M15);
    
    // Calculate stop loss and take profit
    double stopLoss, takeProfit;
    if(signal > 0) // Buy
    {
        stopLoss = currentPrice - (m_SLRDistance * atr);
        takeProfit = currentPrice + (m_TPRDistance * atr);
    }
    else // Sell
    {
        stopLoss = currentPrice + (m_SLRDistance * atr);
        takeProfit = currentPrice - (m_TPRDistance * atr);
    }
    
    // Calculate position size
    double riskAmount = GetAccountRiskAmount();
    double slDistance = MathAbs(currentPrice - stopLoss);
    double lotSize = CalculatePositionSize(symbol, riskAmount, slDistance);
    lotSize = NormalizeLots(symbol, lotSize);
    
    // Execute the trade
    bool success = false;
    ulong ticket = 0;
    
    if(signal > 0)
    {
        success = m_Trade.Buy(lotSize, symbol, currentPrice, stopLoss, takeProfit, 
                             StringFormat("JcampFx-%s", strategy));
        ticket = m_Trade.ResultOrder();
    }
    else
    {
        success = m_Trade.Sell(lotSize, symbol, currentPrice, stopLoss, takeProfit, 
                              StringFormat("JcampFx-%s", strategy));
        ticket = m_Trade.ResultOrder();
    }
    
    if(success && ticket > 0)
    {
        // Add to trade management
        TradeInfo trade;
        trade.ticket = ticket;
        trade.symbol = symbol;
        trade.strategy = strategy;
        trade.openTime = TimeCurrent();
        trade.openPrice = currentPrice;
        trade.initialSL = stopLoss;
        trade.initialTP = takeProfit;
        trade.riskAmount = riskAmount;
        trade.currentR = 0.0;
        trade.beActivated = false;
        trade.slTrailActivated = false;
        trade.tpTrailActivated = false;
        trade.type = (signal > 0) ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
        
        // Add to trades array
        if(m_TradeCount < ArraySize(m_Trades))
        {
            m_Trades[m_TradeCount] = trade;
            m_TradeCount++;
        }
        
        return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Manage all active trades                                         |
//+------------------------------------------------------------------+
void CJcampFxStrategies::ManageTrades()
{
    for(int i = m_TradeCount - 1; i >= 0; i--)
    {
        // Check if position still exists
        if(!PositionSelectByTicket(m_Trades[i].ticket))
        {
            // Position closed, remove from management
            for(int j = i; j < m_TradeCount - 1; j++)
            {
                m_Trades[j] = m_Trades[j + 1];
            }
            m_TradeCount--;
            continue;
        }
        
        // Update current R level
        UpdateTradeR(m_Trades[i]);
        
        // Apply trade management rules
        CheckBreakEven(m_Trades[i]);
        TrailStopLoss(m_Trades[i]);
        TrailTakeProfit(m_Trades[i]);
    }
}

//+------------------------------------------------------------------+
//| Check and apply breakeven                                        |
//+------------------------------------------------------------------+
void CJcampFxStrategies::CheckBreakEven(TradeInfo &trade)
{
    if(trade.beActivated) return;
    if(trade.currentR < m_BEStartRDistance) return;
    
    if(!PositionSelectByTicket(trade.ticket)) return;
    
    double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
    double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
    
    // Calculate breakeven with small profit to cover broker fees
    double spread = SymbolInfoInteger(trade.symbol, SYMBOL_SPREAD) * SymbolInfoDouble(trade.symbol, SYMBOL_POINT);
    double commission = 0; // Estimate commission if needed
    double swapPerDay = SymbolInfoDouble(trade.symbol, SYMBOL_SWAP_LONG);
    if(trade.type == POSITION_TYPE_SELL)
        swapPerDay = SymbolInfoDouble(trade.symbol, SYMBOL_SWAP_SHORT);
    
    // Breakeven price to cover costs
    double breakeven = openPrice;
    if(trade.type == POSITION_TYPE_BUY)
        breakeven = openPrice + spread + commission;
    else
        breakeven = openPrice - spread - commission;
    
    // Modify stop loss to breakeven
    if(m_Trade.PositionModify(trade.ticket, breakeven, PositionGetDouble(POSITION_TP)))
    {
        trade.beActivated = true;
        Print(StringFormat("Breakeven activated for %s %s at %.5f (R: %.2f)", 
                          trade.strategy, trade.symbol, breakeven, trade.currentR));
    }
}

//+------------------------------------------------------------------+
//| Trail stop loss                                                  |
//+------------------------------------------------------------------+
void CJcampFxStrategies::TrailStopLoss(TradeInfo &trade)
{
    if(trade.currentR < m_SLStartRDistance) return;
    
    if(!PositionSelectByTicket(trade.ticket)) return;
    
    double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
    double currentSL = PositionGetDouble(POSITION_SL);
    double atr = m_MathLib.CalculateATR(trade.symbol, PERIOD_M15);
    
    double newSL = 0;
    bool shouldUpdate = false;
    
    if(trade.type == POSITION_TYPE_BUY)
    {
        // Trail stop loss below current price
        double trailSL = currentPrice - (m_SLRDistance * atr);
        if(trailSL > currentSL)
        {
            newSL = trailSL;
            shouldUpdate = true;
        }
    }
    else
    {
        // Trail stop loss above current price
        double trailSL = currentPrice + (m_SLRDistance * atr);
        if(trailSL < currentSL || currentSL == 0)
        {
            newSL = trailSL;
            shouldUpdate = true;
        }
    }
    
    if(shouldUpdate)
    {
        if(m_Trade.PositionModify(trade.ticket, newSL, PositionGetDouble(POSITION_TP)))
        {
            trade.slTrailActivated = true;
            Print(StringFormat("Stop loss trailed for %s %s to %.5f (R: %.2f)", 
                              trade.strategy, trade.symbol, newSL, trade.currentR));
        }
    }
}

//+------------------------------------------------------------------+
//| Trail take profit                                                |
//+------------------------------------------------------------------+
void CJcampFxStrategies::TrailTakeProfit(TradeInfo &trade)
{
    if(trade.currentR < m_TPStartRDistance) return;
    
    if(!PositionSelectByTicket(trade.ticket)) return;
    
    double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
    double currentTP = PositionGetDouble(POSITION_TP);
    double atr = m_MathLib.CalculateATR(trade.symbol, PERIOD_M15);
    
    double newTP = 0;
    bool shouldUpdate = false;
    
    if(trade.type == POSITION_TYPE_BUY)
    {
        // Trail take profit above current price
        double trailTP = currentPrice + (m_TPRDistance * atr);
        if(trailTP > currentTP)
        {
            newTP = trailTP;
            shouldUpdate = true;
        }
    }
    else
    {
        // Trail take profit below current price
        double trailTP = currentPrice - (m_TPRDistance * atr);
        if(trailTP < currentTP)
        {
            newTP = trailTP;
            shouldUpdate = true;
        }
    }
    
    if(shouldUpdate)
    {
        if(m_Trade.PositionModify(trade.ticket, PositionGetDouble(POSITION_SL), newTP))
        {
            trade.tpTrailActivated = true;
            Print(StringFormat("Take profit trailed for %s %s to %.5f (R: %.2f)", 
                              trade.strategy, trade.symbol, newTP, trade.currentR));
        }
    }
}

//+------------------------------------------------------------------+
//| Update trade R level                                             |
//+------------------------------------------------------------------+
void CJcampFxStrategies::UpdateTradeR(TradeInfo &trade)
{
    if(!PositionSelectByTicket(trade.ticket)) return;
    
    double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
    double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
    double slDistance = MathAbs(openPrice - trade.initialSL);
    
    if(slDistance == 0) return;
    
    if(trade.type == POSITION_TYPE_BUY)
    {
        trade.currentR = (currentPrice - openPrice) / slDistance;
    }
    else
    {
        trade.currentR = (openPrice - currentPrice) / slDistance;
    }
}

//+------------------------------------------------------------------+
//| Validate trade entry                                             |
//+------------------------------------------------------------------+
bool CJcampFxStrategies::ValidateTradeEntry(string symbol, int signal, string strategy)
{
    // Check market conditions
    if(IsWeekend() || IsMarketClosed(symbol))
        return false;
    
    // Check spread
    double spread = SymbolInfoInteger(symbol, SYMBOL_SPREAD) * SymbolInfoDouble(symbol, SYMBOL_POINT);
    double maxSpread = 30 * SymbolInfoDouble(symbol, SYMBOL_POINT); // Max 3 pips
    if(spread > maxSpread)
        return false;
    
    // Check news filter for non-news strategies
    if(strategy != "NewsTrading" && CheckNewsFilter(symbol, TimeCurrent()))
        return false;
    
    // Check account equity
    if(AccountInfoDouble(ACCOUNT_EQUITY) < AccountInfoDouble(ACCOUNT_BALANCE) * 0.8)
        return false; // Don't trade if equity is down 20%
    
    return true;
}

//+------------------------------------------------------------------+
//| Calculate position size                                          |
//+------------------------------------------------------------------+
double CJcampFxStrategies::CalculatePositionSize(string symbol, double riskAmount, double slDistance)
{
    double pipValue = CalculatePipValue(symbol);
    double slPips = slDistance / (SymbolInfoDouble(symbol, SYMBOL_POINT) * 10);
    
    if(slPips == 0 || pipValue == 0) return 0;
    
    double lotSize = riskAmount / (slPips * pipValue);
    return lotSize;
}

//+------------------------------------------------------------------+
//| Get account risk amount                                          |
//+------------------------------------------------------------------+
double CJcampFxStrategies::GetAccountRiskAmount()
{
    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    return balance * (m_RiskPercent / 100.0);
}

//+------------------------------------------------------------------+
//| Calculate pip value                                              |
//+------------------------------------------------------------------+
double CJcampFxStrategies::CalculatePipValue(string symbol)
{
    double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
    double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
    double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
    
    return tickValue * (point * 10) / tickSize;
}

//+------------------------------------------------------------------+
//| Normalize lot size                                               |
//+------------------------------------------------------------------+
double CJcampFxStrategies::NormalizeLots(string symbol, double lots)
{
    double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
    double stepLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
    
    if(lots < minLot) return minLot;
    if(lots > maxLot) return maxLot;
    
    return NormalizeDouble(MathRound(lots / stepLot) * stepLot, 2);
}

//+------------------------------------------------------------------+
//| Get base currency from symbol                                    |
//+------------------------------------------------------------------+
string CJcampFxStrategies::GetBaseCurrency(string symbol)
{
    return StringSubstr(symbol, 0, 3);
}

//+------------------------------------------------------------------+
//| Get quote currency from symbol                                   |
//+------------------------------------------------------------------+
string CJcampFxStrategies::GetQuoteCurrency(string symbol)
{
    return StringSubstr(symbol, 3, 3);
}

//+------------------------------------------------------------------+
//| Check if weekend                                                 |
//+------------------------------------------------------------------+
bool CJcampFxStrategies::IsWeekend()
{
    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);
    return (dt.day_of_week == 0 || dt.day_of_week == 6);
}

//+------------------------------------------------------------------+
//| Check if market is closed                                        |
//+------------------------------------------------------------------+
bool CJcampFxStrategies::IsMarketClosed(string symbol)
{
    return !SymbolInfoInteger(symbol, SYMBOL_SELECT);
}

//+------------------------------------------------------------------+
//| Update news events (placeholder implementation)                  |
//+------------------------------------------------------------------+
void CJcampFxStrategies::UpdateNewsEvents()
{
    // Placeholder for news event updates
    // In a real implementation, this would fetch from economic calendar API
    // or parse news feeds
    
    m_NewsCount = 0; // Reset for now
    
    // Example: Add some dummy news events for testing
    // This should be replaced with actual news feed integration
}

//+------------------------------------------------------------------+
//| Check if it's news time                                          |
//+------------------------------------------------------------------+
bool CJcampFxStrategies::IsNewsTime(string symbol)
{
    // Simple implementation - check if within 30 minutes of high impact news
    string baseCurrency = GetBaseCurrency(symbol);
    string quoteCurrency = GetQuoteCurrency(symbol);
    
    return IsHighImpactNews(baseCurrency, TimeCurrent(), 30, 60) ||
           IsHighImpactNews(quoteCurrency, TimeCurrent(), 30, 60);
}

//+------------------------------------------------------------------+
//| Check for high impact news                                       |
//+------------------------------------------------------------------+
bool CJcampFxStrategies::IsHighImpactNews(string currency, datetime time, int minutesBefore = 30, int minutesAfter = 60)
{
    // Placeholder implementation
    // In real implementation, check against loaded news events
    
    for(int i = 0; i < m_NewsCount; i++)
    {
        if(m_NewsEvents[i].currency == currency && m_NewsEvents[i].impact >= 2)
        {
            datetime newsTime = m_NewsEvents[i].time;
            if(time >= (newsTime - minutesBefore * 60) && 
               time <= (newsTime + minutesAfter * 60))
            {
                return true;
            }
        }
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Check news filter                                                |
//+------------------------------------------------------------------+
bool CJcampFxStrategies::CheckNewsFilter(string symbol, datetime tradeTime)
{
    // Return true if we should avoid trading due to news
    string baseCurrency = GetBaseCurrency(symbol);
    string quoteCurrency = GetQuoteCurrency(symbol);
    
    // Avoid trading 15 minutes before and 30 minutes after high impact news
    return IsHighImpactNews(baseCurrency, tradeTime, 15, 30) ||
           IsHighImpactNews(quoteCurrency, tradeTime, 15, 30);
}