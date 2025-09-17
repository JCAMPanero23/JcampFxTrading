//+------------------------------------------------------------------+
//|                                           JcampFxStrategies.mqh |
//|                                                    JcampFx Team |
//|                Enhanced Trading Strategies with 3Point Levels   |
//+------------------------------------------------------------------+
#property copyright "JcampFx Team"
#property link      ""
#property version   "2.00"

#include <Trade\Trade.mqh>
#include "TL_HL_Math.mqh"  // Enhanced math library

// Enhanced trade management structure
struct EnhancedTradeInfo
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
    
    // NEW: Enhanced level interaction tracking
    string entryLevelType;      // "VALIDATED_SR", "HTF_LEVEL", "PSYCH_LEVEL", "TRENDLINE"
    double entryLevelPrice;     // Price of level that triggered entry
    int entryLevelTouches;      // Touch count at entry time
    double entryLevelRejection; // Rejection strength at entry time
    bool htfConfirmation;       // Whether HTF confirmed the setup
};

// Enhanced news event structure
struct NewsEvent
{
    datetime time;
    string currency;
    string event;
    int impact; // 1=Low, 2=Medium, 3=High
    bool processed;
};

//+------------------------------------------------------------------+
//| Enhanced Trading Strategies Class                               |
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
    
    // Enhanced trade management
    EnhancedTradeInfo m_Trades[];
    int m_TradeCount;
    
    // News trading
    NewsEvent m_NewsEvents[];
    int m_NewsCount;
    datetime m_LastNewsCheck;
    
    // Enhanced performance tracking
    double m_MonthlyR;
    int m_MonthlyWins;
    int m_MonthlyLosses;
    int m_MonthlyCancels;
    
    // NEW: Level-based performance tracking
    int m_ValidatedLevelWins;
    int m_ValidatedLevelLosses;
    int m_HTFLevelWins;
    int m_HTFLevelLosses;
    int m_PsychLevelWins;
    int m_PsychLevelLosses;
    int m_TrendlineWins;
    int m_TrendlineLosses;
    
    // Internal methods
    bool ValidateTradeEntry(string symbol, int signal, string strategy);
    double CalculatePositionSize(string symbol, double riskAmount, double slDistance);
    bool CheckNewsFilter(string symbol, datetime tradeTime);
    void UpdateTradeR(EnhancedTradeInfo &trade);
    bool IsWeekend();
    bool IsMarketClosed(string symbol);
    
    // NEW: Enhanced level analysis methods
    HorizontalLevelData GetBestSRLevel(double currentPrice, bool isSupport);
    TrendLineData GetBestTrendline(double currentPrice, bool isSupport);
    double CalculateLevelQualityScore(HorizontalLevelData &level, double currentPrice);
    double CalculateTrendlineQualityScore(TrendLineData &trendline, double currentPrice);
    bool IsLevelTypePreferred(HorizontalLevelData &level);
    bool HasMultipleConfirmations(double price, bool isSupport);
    string m_CurrentSymbol;
    void SetCurrentSymbol(string symbol);
    string GetCurrentSymbol();
    
public:
    // Constructor & Destructor
    CJcampFxStrategies();
    ~CJcampFxStrategies();
    
    // Initialization
    bool Initialize(CTL_HL_Math* mathLib, double riskPercent, double tpRDistance, 
                   double slRDistance, double beStartR, double slStartR, 
                   double tpStartR, int magicNumber);
    
    // Enhanced strategy scanning methods
    int ScanEnhancedTrendRider(string symbol);
    int ScanEnhancedReversals(string symbol);
    int ScanNewsTrading(string symbol);
    
    // Enhanced trade execution and management
    bool ExecuteEnhancedTrade(string symbol, int signal, string strategy, 
                             string levelType, double levelPrice);
    void ManageEnhancedTrades();
    void CheckBreakEven(EnhancedTradeInfo &trade);
    void TrailStopLoss(EnhancedTradeInfo &trade);
    void TrailTakeProfit(EnhancedTradeInfo &trade);
    
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
    
    // Enhanced performance tracking
    void LogEnhancedTradeResult(EnhancedTradeInfo &trade, string result, double rMultiple);
    void ResetMonthlyStats();
    double GetMonthlyR();
    int GetMonthlyWins();
    int GetMonthlyLosses();
    int GetMonthlyCancels();
    
    // NEW: Level-based performance getters
    string GetLevelPerformanceReport();
    double GetValidatedLevelWinRate();
    double GetHTFLevelWinRate();
    double GetTrendlineWinRate();
    int GetTotalLevelTrades();
    //void SetCurrentSymbol(string symbol) { m_CurrentSymbol = symbol; }
    //string GetCurrentSymbol() { return m_CurrentSymbol; }
    
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
    
    // NEW: Initialize level-based performance tracking
    m_ValidatedLevelWins = 0;
    m_ValidatedLevelLosses = 0;
    m_HTFLevelWins = 0;
    m_HTFLevelLosses = 0;
    m_PsychLevelWins = 0;
    m_PsychLevelLosses = 0;
    m_TrendlineWins = 0;
    m_TrendlineLosses = 0;
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
    
    Print("Enhanced JcampFx Strategies initialized with level-based analysis");
    
    return true;
}

//+------------------------------------------------------------------+
//| Enhanced TrendRider Strategy Scanner                            |
//+------------------------------------------------------------------+
int CJcampFxStrategies::ScanEnhancedTrendRider(string symbol)
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
    
    // NEW: Enhanced trendline analysis
    int trendLineCount = m_MathLib.GetTrendLineCount();
    if(trendLineCount == 0) return 0;
    
    // Look for VALIDATED trendline bounces with enhanced filtering
    for(int i = 0; i < trendLineCount; i++)
    {
        TrendLineData trendLine = m_MathLib.GetTrendLine(i);
        
        // Enhanced validation - prioritize validated trendlines
        if(!m_MathLib.IsTrendLineValid(trendLine, TimeCurrent(), currentPrice))
            continue;
            
        // NEW: Quality scoring system
        double qualityScore = CalculateTrendlineQualityScore(trendLine, currentPrice);
        if(qualityScore < 50.0) continue; // Only trade high-quality trendlines
        
        double trendLinePrice = m_MathLib.GetTrendLinePrice(trendLine, TimeCurrent());
        double tolerance = 20 * point; // 20 points tolerance
        
        // Check for bullish setup (support trendline bounce)
        if(trendLine.isSupport && 
           low2 <= trendLinePrice + tolerance && low2 >= trendLinePrice - tolerance &&
           close1 > trendLinePrice + tolerance)
        {
            // Enhanced confirmation system
            OscillatorData osc = m_MathLib.GetOscillatorData();
            if(!osc.overbought)
            {
                // NEW: Check for multiple confirmations
                if(HasMultipleConfirmations(currentPrice, true))
                {
                    // Enhanced resistance check using nearest validated levels
                    HorizontalLevelData nearestResistance = GetBestSRLevel(currentPrice, false);
                    double atr = m_MathLib.CalculateATR(symbol, PERIOD_M15);
                    
                    if(nearestResistance.price == 0 || 
                       (nearestResistance.price - currentPrice) > (m_TPRDistance * atr))
                    {
                        Print(StringFormat("Enhanced TrendRider BUY signal: TL Quality=%.1f, Validated=%s", 
                                          qualityScore, trendLine.isValidated ? "YES" : "NO"));
                        return 1; // Buy signal
                    }
                }
            }
        }
        
        // Check for bearish setup (resistance trendline rejection)
        if(!trendLine.isSupport && 
           high2 >= trendLinePrice - tolerance && high2 <= trendLinePrice + tolerance &&
           close1 < trendLinePrice - tolerance)
        {
            OscillatorData osc = m_MathLib.GetOscillatorData();
            if(!osc.oversold)
            {
                // NEW: Check for multiple confirmations
                if(HasMultipleConfirmations(currentPrice, false))
                {
                    // Enhanced support check
                    HorizontalLevelData nearestSupport = GetBestSRLevel(currentPrice, true);
                    double atr = m_MathLib.CalculateATR(symbol, PERIOD_M15);
                    
                    if(nearestSupport.price == 0 || 
                       (currentPrice - nearestSupport.price) > (m_TPRDistance * atr))
                    {
                        Print(StringFormat("Enhanced TrendRider SELL signal: TL Quality=%.1f, Validated=%s", 
                                          qualityScore, trendLine.isValidated ? "YES" : "NO"));
                        return -1; // Sell signal
                    }
                }
            }
        }
    }
    
    return 0; // No signal
}

//+------------------------------------------------------------------+
//| Enhanced Reversal Strategy Scanner                              |
//+------------------------------------------------------------------+
int CJcampFxStrategies::ScanEnhancedReversals(string symbol)
{
    if(m_MathLib == NULL) return 0;
    
    double currentPrice = SymbolInfoDouble(symbol, SYMBOL_BID);
    double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
    double tolerance = 15 * point; // 15 points tolerance
    
    // NEW: Enhanced level filtering - prioritize validated and HTF levels
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
    
    // NEW: Enhanced level analysis - get best levels by quality
    HorizontalLevelData bestSupportLevel = GetBestSRLevel(currentPrice, true);
    HorizontalLevelData bestResistanceLevel = GetBestSRLevel(currentPrice, false);
    
    // Check for bullish reversal at ENHANCED support levels
    if(bestSupportLevel.price > 0 && 
       m_MathLib.IsPriceNearLevel(currentPrice, bestSupportLevel.price, tolerance))
    {
        // NEW: Enhanced confirmation system with level quality scoring
        double levelQuality = CalculateLevelQualityScore(bestSupportLevel, currentPrice);
        
        // Higher quality threshold for trading
        if(levelQuality >= 70.0)
        {
            // Multiple confirmation criteria with enhanced weighting
            bool priceAction = m_MathLib.IsHammer(symbol, PERIOD_M15, 1) || 
                              m_MathLib.IsBullishEngulfing(symbol, PERIOD_M15, 1);
            bool oscillatorOversold = osc.oversold || osc.divergence;
            bool macdBullish = macd.bullishCrossover || (macd.main > macd.signal && macd.histogram > 0);
            
            // NEW: Level-specific confirmations
            bool htfConfirmation = bestSupportLevel.isHTFLevel;
            bool validatedLevel = bestSupportLevel.isValidated;
            bool strongRejection = bestSupportLevel.totalRejection > 30.0; // Strong historical rejection
            
            // Enhanced scoring system
            int confirmationScore = 0;
            if(priceAction) confirmationScore += 2;
            if(oscillatorOversold) confirmationScore += 1;
            if(macdBullish) confirmationScore += 1;
            if(htfConfirmation) confirmationScore += 2; // HTF levels get bonus
            if(validatedLevel) confirmationScore += 2; // Validated levels get bonus
            if(strongRejection) confirmationScore += 1;
            
            // Higher threshold for high-quality setups
            if(confirmationScore >= 4)
            {
                string levelType = bestSupportLevel.isHTFLevel ? "HTF_SUPPORT" : 
                                  (bestSupportLevel.isPsychological ? "PSYCH_SUPPORT" : "VALIDATED_SUPPORT");
                
                Print(StringFormat("Enhanced Reversals BUY signal: Level=%.5f, Quality=%.1f, Score=%d, Type=%s", 
                                  bestSupportLevel.price, levelQuality, confirmationScore, levelType));
                return 1; // Buy signal
            }
        }
    }
    
    // Check for bearish reversal at ENHANCED resistance levels
    if(bestResistanceLevel.price > 0 && 
       m_MathLib.IsPriceNearLevel(currentPrice, bestResistanceLevel.price, tolerance))
    {
        double levelQuality = CalculateLevelQualityScore(bestResistanceLevel, currentPrice);
        
        if(levelQuality >= 70.0)
        {
            // Multiple confirmation criteria
            bool priceAction = m_MathLib.IsShootingStar(symbol, PERIOD_M15, 1) || 
                              m_MathLib.IsBearishEngulfing(symbol, PERIOD_M15, 1);
            bool oscillatorOverbought = osc.overbought || osc.divergence;
            bool macdBearish = macd.bearishCrossover || (macd.main < macd.signal && macd.histogram < 0);
            
            // Level-specific confirmations
            bool htfConfirmation = bestResistanceLevel.isHTFLevel;
            bool validatedLevel = bestResistanceLevel.isValidated;
            bool strongRejection = bestResistanceLevel.totalRejection > 30.0;
            
            // Enhanced scoring system
            int confirmationScore = 0;
            if(priceAction) confirmationScore += 2;
            if(oscillatorOverbought) confirmationScore += 1;
            if(macdBearish) confirmationScore += 1;
            if(htfConfirmation) confirmationScore += 2;
            if(validatedLevel) confirmationScore += 2;
            if(strongRejection) confirmationScore += 1;
            
            if(confirmationScore >= 4)
            {
                string levelType = bestResistanceLevel.isHTFLevel ? "HTF_RESISTANCE" : 
                                  (bestResistanceLevel.isPsychological ? "PSYCH_RESISTANCE" : "VALIDATED_RESISTANCE");
                
                Print(StringFormat("Enhanced Reversals SELL signal: Level=%.5f, Quality=%.1f, Score=%d, Type=%s", 
                                  bestResistanceLevel.price, levelQuality, confirmationScore, levelType));
                return -1; // Sell signal
            }
        }
    }
    
    return 0; // No signal
}

//+------------------------------------------------------------------+
//| NEW: Get best S/R level by quality scoring                     |
//+------------------------------------------------------------------+
HorizontalLevelData CJcampFxStrategies::GetBestSRLevel(double currentPrice, bool isSupport)
{
    HorizontalLevelData bestLevel;
    bestLevel.price = 0; // Initialize as invalid
    
    double bestScore = 0;
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT); // Use _Symbol
    double maxDistance = 100 * point; // 100 pips max
    
    int levelCount = m_MathLib.GetHorizontalLevelCount();
    for(int i = 0; i < levelCount; i++)
    {
        HorizontalLevelData level = m_MathLib.GetHorizontalLevel(i);
        
        // Filter by support/resistance type and distance
        if(level.isSupport != isSupport) continue;
        
        double distance = MathAbs(level.price - currentPrice);
        if(distance > maxDistance) continue;
        
        // Skip broken levels
        if(level.isBroken) continue;
        
        // Calculate quality score
        double score = CalculateLevelQualityScore(level, currentPrice);
        
        if(score > bestScore)
        {
            bestScore = score;
            bestLevel = level;
        }
    }
    return bestLevel;
}

//+------------------------------------------------------------------+
//| NEW: Calculate level quality score                              |
//+------------------------------------------------------------------+
double CJcampFxStrategies::CalculateLevelQualityScore(HorizontalLevelData &level, double currentPrice)
{
    double score = 0;
    
    // Base score from touch count (0-30 points)
    score += MathMin(level.touchCount * 5.0, 30.0);
    
    // Validation bonus (0-25 points)
    if(level.isValidated) score += 25.0;
    
    // Level type bonuses
    if(level.isHTFLevel) score += 20.0; // HTF levels are strong (0-20 points)
    else if(level.isPsychological) score += 10.0; // Psychological levels are moderate (0-10 points)
    
    // Rejection strength bonus (0-20 points)
    score += MathMin(level.totalRejection / 2.0, 20.0);
    
    // Distance penalty (0-15 points deduction) - FIXED
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT); // Use _Symbol instead
    if(point > 0) // Safety check
    {
        double distance = MathAbs(level.price - currentPrice) / point;
        if(distance > 50) score -= MathMin((distance - 50) / 10.0, 15.0);
    }
    
    // Recency bonus (0-10 points)
    if(level.lastTouch > 0)
    {
        int hoursSinceTouch = (int)((TimeCurrent() - level.lastTouch) / 3600);
        if(hoursSinceTouch < 24) score += 10.0;
        else if(hoursSinceTouch < 168) score += 5.0; // Within a week
    }
    
    return MathMax(score, 0); // Ensure non-negative score
}

//+------------------------------------------------------------------+
//| NEW: Calculate trendline quality score                         |
//+------------------------------------------------------------------+
double CJcampFxStrategies::CalculateTrendlineQualityScore(TrendLineData &trendline, double currentPrice)
{
    double score = 0;
    
    // Base score from touch count (0-30 points)
    score += MathMin(trendline.touchCount * 7.0, 30.0);
    
    // Validation bonus (0-30 points)
    if(trendline.isValidated) score += 30.0;
    
    // Rejection strength bonus (0-25 points)
    score += MathMin(trendline.totalRejection / 2.0, 25.0);
    
    // Distance from trendline (0-10 points deduction) - FIXED
    double trendlinePrice = m_MathLib.GetTrendLinePrice(trendline, TimeCurrent());
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT); // Use _Symbol instead
    if(point > 0) // Safety check
    {
        double distance = MathAbs(trendlinePrice - currentPrice) / point;
        if(distance > 20) score -= MathMin((distance - 20) / 5.0, 10.0);
    }
    
    // Recency bonus (0-15 points)
    int hoursSinceCreation = (int)((TimeCurrent() - trendline.creationTime) / 3600);
    if(hoursSinceCreation < 72) score += 15.0; // Within 3 days
    else if(hoursSinceCreation < 168) score += 8.0; // Within a week
    
    return MathMax(score, 0);
}

//+------------------------------------------------------------------+
//| NEW: Check for multiple confirmations                          |
//+------------------------------------------------------------------+
bool CJcampFxStrategies::HasMultipleConfirmations(double price, bool isSupport)
{
    int confirmations = 0;
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT); // Use _Symbol
    double tolerance = 30 * point; // 30 pips tolerance
    
    // Check if multiple S/R levels are nearby
    int levelCount = m_MathLib.GetHorizontalLevelCount();
    for(int i = 0; i < levelCount; i++)
    {
        HorizontalLevelData level = m_MathLib.GetHorizontalLevel(i);
        if(level.isSupport == isSupport && !level.isBroken)
        {
            if(MathAbs(level.price - price) <= tolerance)
            {
                confirmations++;
                if(level.isHTFLevel || level.isValidated) confirmations++; // Bonus for quality levels
            }
        }
    }
    
    // Check if trendlines are nearby
    int tlCount = m_MathLib.GetTrendLineCount();
    for(int i = 0; i < tlCount; i++)
    {
        TrendLineData tl = m_MathLib.GetTrendLine(i);
        if(tl.isSupport == isSupport)
        {
            double tlPrice = m_MathLib.GetTrendLinePrice(tl, TimeCurrent());
            if(MathAbs(tlPrice - price) <= tolerance)
            {
                confirmations++;
                if(tl.isValidated) confirmations++; // Bonus for validated trendlines
            }
        }
    }
    
    return confirmations >= 2; // Need at least 2 confirmations
}
//+------------------------------------------------------------------+
//| Enhanced trade execution                                         |
//+------------------------------------------------------------------+
bool CJcampFxStrategies::ExecuteEnhancedTrade(string symbol, int signal, string strategy, 
                                             string levelType, double levelPrice)
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
    
    string enhancedComment = StringFormat("JcampFx-%s-%s", strategy, levelType);
    
    if(signal > 0)
    {
        success = m_Trade.Buy(lotSize, symbol, currentPrice, stopLoss, takeProfit, enhancedComment);
        ticket = m_Trade.ResultOrder();
    }
    else
    {
        success = m_Trade.Sell(lotSize, symbol, currentPrice, stopLoss, takeProfit, enhancedComment);
        ticket = m_Trade.ResultOrder();
    }
    
    if(success && ticket > 0)
    {
        // NEW: Enhanced trade tracking with level information
        EnhancedTradeInfo trade;
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
        
        // Enhanced level tracking
        trade.entryLevelType = levelType;
        trade.entryLevelPrice = levelPrice;
        trade.htfConfirmation = (StringFind(levelType, "HTF") >= 0);
        
        // Get level details at entry time
        if(StringFind(levelType, "TRENDLINE") < 0) // If it's an S/R level
        {
            HorizontalLevelData entryLevel = GetBestSRLevel(currentPrice, signal > 0);
            if(entryLevel.price > 0)
            {
                trade.entryLevelTouches = entryLevel.touchCount;
                trade.entryLevelRejection = entryLevel.totalRejection;
            }
        }
        
        // Add to trades array
        if(m_TradeCount < ArraySize(m_Trades))
        {
            m_Trades[m_TradeCount] = trade;
            m_TradeCount++;
            
            Print(StringFormat("Enhanced trade executed: %s %s on %s level at %.5f", 
                              strategy, signal > 0 ? "BUY" : "SELL", levelType, levelPrice));
        }
        
        return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Enhanced trade management                                        |
//+------------------------------------------------------------------+
void CJcampFxStrategies::ManageEnhancedTrades()
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
//| Enhanced trade result logging                                   |
//+------------------------------------------------------------------+
void CJcampFxStrategies::LogEnhancedTradeResult(EnhancedTradeInfo &trade, string result, double rMultiple)
{
    // Standard monthly tracking
    if(result == "WIN")
    {
        m_MonthlyWins++;
        m_MonthlyR += rMultiple;
        
        // NEW: Level-based performance tracking
        if(StringFind(trade.entryLevelType, "VALIDATED") >= 0)
            m_ValidatedLevelWins++;
        else if(StringFind(trade.entryLevelType, "HTF") >= 0)
            m_HTFLevelWins++;
        else if(StringFind(trade.entryLevelType, "PSYCH") >= 0)
            m_PsychLevelWins++;
        else if(StringFind(trade.entryLevelType, "TRENDLINE") >= 0)
            m_TrendlineWins++;
    }
    else if(result == "LOSS")
    {
        m_MonthlyLosses++;
        m_MonthlyR -= MathAbs(rMultiple);
        
        // Level-based loss tracking
        if(StringFind(trade.entryLevelType, "VALIDATED") >= 0)
            m_ValidatedLevelLosses++;
        else if(StringFind(trade.entryLevelType, "HTF") >= 0)
            m_HTFLevelLosses++;
        else if(StringFind(trade.entryLevelType, "PSYCH") >= 0)
            m_PsychLevelLosses++;
        else if(StringFind(trade.entryLevelType, "TRENDLINE") >= 0)
            m_TrendlineLosses++;
    }
    
    Print(StringFormat("Enhanced Trade Result: %s - %s %s - R: %.2f - Level: %s (%.5f) - Touches: %d", 
                      result, trade.strategy, trade.symbol, rMultiple, 
                      trade.entryLevelType, trade.entryLevelPrice, trade.entryLevelTouches));
}

//+------------------------------------------------------------------+
//| NEW: Get level performance report                               |
//+------------------------------------------------------------------+
string CJcampFxStrategies::GetLevelPerformanceReport()
{
    string report = "=== LEVEL-BASED PERFORMANCE ===\n";
    
    // Validated levels
    int validatedTotal = m_ValidatedLevelWins + m_ValidatedLevelLosses;
    double validatedWR = validatedTotal > 0 ? (double)m_ValidatedLevelWins / validatedTotal * 100 : 0;
    report += StringFormat("Validated S/R: %d trades, %.1f%% win rate (%d/%d)\n", 
                          validatedTotal, validatedWR, m_ValidatedLevelWins, m_ValidatedLevelLosses);
    
    // HTF levels
    int htfTotal = m_HTFLevelWins + m_HTFLevelLosses;
    double htfWR = htfTotal > 0 ? (double)m_HTFLevelWins / htfTotal * 100 : 0;
    report += StringFormat("HTF Levels: %d trades, %.1f%% win rate (%d/%d)\n", 
                          htfTotal, htfWR, m_HTFLevelWins, m_HTFLevelLosses);
    
    // Psychological levels
    int psychTotal = m_PsychLevelWins + m_PsychLevelLosses;
    double psychWR = psychTotal > 0 ? (double)m_PsychLevelWins / psychTotal * 100 : 0;
    report += StringFormat("Psychological: %d trades, %.1f%% win rate (%d/%d)\n", 
                          psychTotal, psychWR, m_PsychLevelWins, m_PsychLevelLosses);
    
    // Trendlines
    int tlTotal = m_TrendlineWins + m_TrendlineLosses;
    double tlWR = tlTotal > 0 ? (double)m_TrendlineWins / tlTotal * 100 : 0;
    report += StringFormat("Trendlines: %d trades, %.1f%% win rate (%d/%d)\n", 
                          tlTotal, tlWR, m_TrendlineWins, m_TrendlineLosses);
    
    return report;
}

//+------------------------------------------------------------------+
//| NEW: Get validated level win rate                               |
//+------------------------------------------------------------------+
double CJcampFxStrategies::GetValidatedLevelWinRate()
{
    int total = m_ValidatedLevelWins + m_ValidatedLevelLosses;
    return total > 0 ? (double)m_ValidatedLevelWins / total * 100 : 0;
}

//+------------------------------------------------------------------+
//| NEW: Get HTF level win rate                                     |
//+------------------------------------------------------------------+
double CJcampFxStrategies::GetHTFLevelWinRate()
{
    int total = m_HTFLevelWins + m_HTFLevelLosses;
    return total > 0 ? (double)m_HTFLevelWins / total * 100 : 0;
}

//+------------------------------------------------------------------+
//| NEW: Get trendline win rate                                     |
//+------------------------------------------------------------------+
double CJcampFxStrategies::GetTrendlineWinRate()
{
    int total = m_TrendlineWins + m_TrendlineLosses;
    return total > 0 ? (double)m_TrendlineWins / total * 100 : 0;
}

//+------------------------------------------------------------------+
//| NEW: Get total level trades                                     |
//+------------------------------------------------------------------+
int CJcampFxStrategies::GetTotalLevelTrades()
{
    return m_ValidatedLevelWins + m_ValidatedLevelLosses + 
           m_HTFLevelWins + m_HTFLevelLosses +
           m_PsychLevelWins + m_PsychLevelLosses +
           m_TrendlineWins + m_TrendlineLosses;
}

// Rest of the class methods remain the same as the original implementation...
// (Including UpdateTradeR, CheckBreakEven, TrailStopLoss, etc.)

//+------------------------------------------------------------------+
//| News Trading Strategy Scanner (unchanged)                       |
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

// Include all the remaining original methods (UpdateTradeR, ValidateTradeEntry, etc.)
// These remain unchanged from the original implementation...

//+------------------------------------------------------------------+
//| Update trade R level                                             |
//+------------------------------------------------------------------+
void CJcampFxStrategies::UpdateTradeR(EnhancedTradeInfo &trade)
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
//| Check and apply breakeven                                        |
//+------------------------------------------------------------------+
void CJcampFxStrategies::CheckBreakEven(EnhancedTradeInfo &trade)
{
    if(trade.beActivated) return;
    if(trade.currentR < m_BEStartRDistance) return;
    
    if(!PositionSelectByTicket(trade.ticket)) return;
    
    double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
    double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
    
    // Calculate breakeven with small profit to cover broker fees
    double spread = SymbolInfoInteger(trade.symbol, SYMBOL_SPREAD) * SymbolInfoDouble(trade.symbol, SYMBOL_POINT);
    double commission = 0; // Estimate commission if needed
    
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
void CJcampFxStrategies::TrailStopLoss(EnhancedTradeInfo &trade)
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
void CJcampFxStrategies::TrailTakeProfit(EnhancedTradeInfo &trade)
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

// Include all remaining utility methods from the original class...
// (ValidateTradeEntry, CalculatePositionSize, GetAccountRiskAmount, etc.)

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
    m_NewsCount = 0;
}

//+------------------------------------------------------------------+
//| Check if it's news time                                          |
//+------------------------------------------------------------------+
bool CJcampFxStrategies::IsNewsTime(string symbol)
{
    string baseCurrency = GetBaseCurrency(symbol);
    string quoteCurrency = GetQuoteCurrency(symbol);
    
    return IsHighImpactNews(baseCurrency, TimeCurrent(), 30, 60) ||
           IsHighImpactNews(quoteCurrency, TimeCurrent(), 30, 60);
}

//+------------------------------------------------------------------+
//| Check for high impact news                                       |
//+------------------------------------------------------------------+
bool CJcampFxStrategies::IsHighImpactNews(string currency, datetime time, int minutesBefore, int minutesAfter)
{
    // Placeholder implementation
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
    string baseCurrency = GetBaseCurrency(symbol);
    string quoteCurrency = GetQuoteCurrency(symbol);
    
    return IsHighImpactNews(baseCurrency, tradeTime, 15, 30) ||
           IsHighImpactNews(quoteCurrency, tradeTime, 15, 30);
}

//+------------------------------------------------------------------+
//| Reset monthly stats                                              |
//+------------------------------------------------------------------+
void CJcampFxStrategies::ResetMonthlyStats()
{
    m_MonthlyR = 0.0;
    m_MonthlyWins = 0;
    m_MonthlyLosses = 0;
    m_MonthlyCancels = 0;
    
    // Reset level-based stats
    m_ValidatedLevelWins = 0;
    m_ValidatedLevelLosses = 0;
    m_HTFLevelWins = 0;
    m_HTFLevelLosses = 0;
    m_PsychLevelWins = 0;
    m_PsychLevelLosses = 0;
    m_TrendlineWins = 0;
    m_TrendlineLosses = 0;
}

//+------------------------------------------------------------------+
//| Get monthly R                                                    |
//+------------------------------------------------------------------+
double CJcampFxStrategies::GetMonthlyR()
{
    return m_MonthlyR;
}

//+------------------------------------------------------------------+
//| Get monthly wins                                                 |
//+------------------------------------------------------------------+
int CJcampFxStrategies::GetMonthlyWins()
{
    return m_MonthlyWins;
}

//+------------------------------------------------------------------+
//| Get monthly losses                                               |
//+------------------------------------------------------------------+
int CJcampFxStrategies::GetMonthlyLosses()
{
    return m_MonthlyLosses;
}

//+------------------------------------------------------------------+
//| Get monthly cancels                                              |
//+------------------------------------------------------------------+
int CJcampFxStrategies::GetMonthlyCancels()
{
    return m_MonthlyCancels;
}

//+------------------------------------------------------------------+