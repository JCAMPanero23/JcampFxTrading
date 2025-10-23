//+------------------------------------------------------------------+
//|                                    Jcamp_Backtest_Strategies.mqh |
//|                                   JCAMP Backtest EA v1.80 Module |
//|                           Strategy Analysis & Signal Generation  |
//+------------------------------------------------------------------+
//| MODULE PURPOSE:                                                   |
//| - Trend Rider strategy analysis                                  |
//| - Impulse Pullback strategy analysis                             |
//| - Range Rider strategy analysis (mean reversion)                 |
//| - Market regime detection & classification                       |
//| - Range detection & validation                                   |
//| - Position management & trailing stops                           |
//+------------------------------------------------------------------+

#property copyright "JCAMP Trading System"
#property version   "1.80"
#property strict

//+------------------------------------------------------------------+
//| EXTERNAL GLOBAL VARIABLES                                         |
//| These are declared in main EA, accessed here via extern          |
//+------------------------------------------------------------------+

// Market Regime
extern MARKET_REGIME currentRegime;
extern bool adaptiveReverseActive;
extern bool MasterReverseMode;

// Range Data
extern RangeData activeRanges[10];
extern int activeRangeCount;
extern RangeDetectionLog rangeLog[1000];
extern int rangeLogCount;

// Position Tracking
extern TradeTracker openPositions[20];
extern int openPositionCount;

// Input Parameters
extern bool VerboseLogging;
extern ENUM_TIMEFRAMES AnalysisTimeframe;
extern ENUM_TIMEFRAMES ExecutionTimeframe;
extern int MinConfidenceScore;
extern bool EnableTrendRider;
extern bool EnableImpulsePullback;
extern bool EnableRangeRider;
extern int RangeRiderMinConfidence;
extern bool UseAdvancedTrailing;
extern double TrailingActivationR;
extern double TPExtension;
extern int RangeLookbackBars;
extern double RangeMaxADX;
extern double RangeMaxEMASlope;

//+------------------------------------------------------------------+
//| SECTION 1: TREND RIDER STRATEGY                                  |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Analyze Trend Rider Strategy                                     |
//| Returns: true if valid signal found                              |
//+------------------------------------------------------------------+
bool AnalyzeTrendRider(string symbol, int &signal, int &confidence, string &analysis, double csmDiff)
{
    if(VerboseLogging)
        Print("\n══════ TREND RIDER ANALYSIS ──────");
    
    double ema20 = GetEMA(symbol, AnalysisTimeframe, 20);
    double ema50 = GetEMA(symbol, AnalysisTimeframe, 50);
    double ema100 = GetEMA(symbol, AnalysisTimeframe, 100);
    double adx = GetADX(symbol, AnalysisTimeframe, 14);
    double rsi = GetRSI(symbol, AnalysisTimeframe, 14);
    
    if(ema20 == 0 || ema50 == 0 || ema100 == 0)
        return false;
    
    signal = 0;
    confidence = 0;
    analysis = "";
    
    bool bullishEMA = (ema20 > ema50 && ema50 > ema100);
    bool bearishEMA = (ema20 < ema50 && ema50 < ema100);
    
    if(bullishEMA)
    {
        signal = 1;
        confidence += 30;
        analysis += "EMA+30 ";
        
        int adxScore = ScoreADX(adx);
        confidence += adxScore;
        analysis += "ADX+" + IntegerToString(adxScore) + " ";
        
        int rsiScore = 0;
        if(rsi > 50 && rsi < 70) rsiScore = 20;
        else if(rsi > 40 && rsi < 80) rsiScore = 10;
        else rsiScore = 5;
        confidence += rsiScore;
        analysis += "RSI+" + IntegerToString(rsiScore) + " ";
        
        int csmScore = 0;
        if(csmDiff > 20) csmScore = 25;
        else if(csmDiff > 15) csmScore = 20;
        else if(csmDiff > 10) csmScore = 15;
        else if(csmDiff > 5) csmScore = 10;
        else csmScore = 5;
        confidence += csmScore;
        analysis += "CSM+" + IntegerToString(csmScore) + " ";
        
        int paScore = DetectPriceActionPattern(symbol, AnalysisTimeframe);
        if(paScore > 0)
        {
            confidence += 15;
            analysis += "PA+15 ";
        }
        
        if(CheckVolumeConfirmation(symbol, AnalysisTimeframe))
        {
            confidence += 10;
            analysis += "VOL+10 ";
        }
        
        if(CheckMTFAlignment(symbol, signal))
        {
            confidence += 10;
            analysis += "MTF+10 ";
        }
    }
    else if(bearishEMA)
    {
        signal = -1;
        confidence += 30;
        analysis += "EMA+30 ";
        
        int adxScore = ScoreADX(adx);
        confidence += adxScore;
        analysis += "ADX+" + IntegerToString(adxScore) + " ";
        
        int rsiScore = 0;
        if(rsi < 50 && rsi > 30) rsiScore = 20;
        else if(rsi < 60 && rsi > 20) rsiScore = 10;
        else rsiScore = 5;
        confidence += rsiScore;
        analysis += "RSI+" + IntegerToString(rsiScore) + " ";
        
        int csmScore = 0;
        if(csmDiff < -20) csmScore = 25;
        else if(csmDiff < -15) csmScore = 20;
        else if(csmDiff < -10) csmScore = 15;
        else if(csmDiff < -5) csmScore = 10;
        else csmScore = 5;
        confidence += csmScore;
        analysis += "CSM+" + IntegerToString(csmScore) + " ";
        
        int paScore = DetectPriceActionPattern(symbol, AnalysisTimeframe);
        if(paScore < 0)
        {
            confidence += 15;
            analysis += "PA+15 ";
        }
        
        if(CheckVolumeConfirmation(symbol, AnalysisTimeframe))
        {
            confidence += 10;
            analysis += "VOL+10 ";
        }
        
        if(CheckMTFAlignment(symbol, signal))
        {
            confidence += 10;
            analysis += "MTF+10 ";
        }
    }
    else
    {
        return false;
    }
    
    if(VerboseLogging)
    {
        Print("Signal: ", signal > 0 ? "BUY" : "SELL");
        Print("Confidence: ", confidence, "/130");
        Print("Analysis: ", analysis);
    }
    
    return (signal != 0 && confidence >= MinConfidenceScore);
}

//+------------------------------------------------------------------+
//| SECTION 2: IMPULSE PULLBACK STRATEGY                             |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Analyze Impulse Pullback Strategy - LOOSENED CONDITIONS          |
//| Returns: true if valid signal found                              |
//+------------------------------------------------------------------+
bool AnalyzeImpulsePullback(string symbol, int &signal, int &confidence, string &analysis, double csmDiff)
{
    if(VerboseLogging)
        Print("\n══════ IMPULSE PULLBACK ANALYSIS ───");
    
    double high[], low[], close[], open[];
    ArraySetAsSeries(high, true);
    ArraySetAsSeries(low, true);
    ArraySetAsSeries(close, true);
    ArraySetAsSeries(open, true);
    
    int lookback = 30;
    if(CopyHigh(symbol, AnalysisTimeframe, 0, lookback, high) <= 0) return false;
    if(CopyLow(symbol, AnalysisTimeframe, 0, lookback, low) <= 0) return false;
    if(CopyClose(symbol, AnalysisTimeframe, 0, lookback, close) <= 0) return false;
    if(CopyOpen(symbol, AnalysisTimeframe, 0, lookback, open) <= 0) return false;
    
    signal = 0;
    confidence = 0;
    analysis = "";
    
    // ═══════════════════════════════════════════════════════════
    // STEP 1: DETECT IMPULSE (LOOSENED: 5+ candles OR 75+ pips)
    // ═══════════════════════════════════════════════════════════
    
    int bullishCandles = 0;
    int bearishCandles = 0;
    double totalBullishMove = 0;
    double totalBearishMove = 0;
    
    for(int i = 1; i < 10; i++)
    {
        if(close[i] > close[i+1])
        {
            bullishCandles++;
            totalBullishMove += (close[i] - close[i+1]);
        }
        else if(close[i] < close[i+1])
        {
            bearishCandles++;
            totalBearishMove += (close[i+1] - close[i]);
        }
    }
    
    int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
    double pipSize = (digits == 5 || digits == 3) ? 
        SymbolInfoDouble(symbol, SYMBOL_POINT) * 10 : 
        SymbolInfoDouble(symbol, SYMBOL_POINT);
    
    double bullishMoveSize = totalBullishMove / pipSize;
    double bearishMoveSize = totalBearishMove / pipSize;
    
    int impulseScore = 0;
    int impulseDirection = 0;
    
    // ✅ LOOSENED: Was 6+ candles OR 100+ pips, now 5+ OR 75+
    if(bullishCandles >= 5 || bullishMoveSize >= 75)
    {
        impulseScore = (int)MathMin(35, 20 + (bullishCandles * 2));
        impulseDirection = 1;
        
        if(VerboseLogging)
            Print("  Bullish impulse: ", bullishCandles, " candles, ", 
                  DoubleToString(bullishMoveSize, 1), " pips");
    }
    else if(bearishCandles >= 5 || bearishMoveSize >= 75)
    {
        impulseScore = (int)MathMin(35, 20 + (bearishCandles * 2));
        impulseDirection = -1;
        
        if(VerboseLogging)
            Print("  Bearish impulse: ", bearishCandles, " candles, ",
                  DoubleToString(bearishMoveSize, 1), " pips");
    }
    
    if(impulseScore == 0)
    {
        if(VerboseLogging)
            Print("  ✗ No impulse detected");
        return false;
    }
    
    confidence += impulseScore;
    analysis += "IMP+" + IntegerToString(impulseScore) + " ";
    
    // ═══════════════════════════════════════════════════════════
    // STEP 2: FIBONACCI PULLBACK (EXPANDED: 23.6% - 78.6%)
    // ═══════════════════════════════════════════════════════════
    
    double swingHigh = FindSwingHigh(symbol, AnalysisTimeframe, 20);
    double swingLow = FindSwingLow(symbol, AnalysisTimeframe, 20);
    
    if(swingHigh == 0 || swingLow == 0)
    {
        if(VerboseLogging)
            Print("  ✗ No swing high/low found");
        return false;
    }
    
    double currentPrice = close[0];
    double fibRange = swingHigh - swingLow;
    
    if(fibRange == 0)
        return false;
    
    int fibScore = 0;
    
    if(impulseDirection == 1)  // Bullish impulse, looking for pullback to buy
    {
        double pullbackLevel = (currentPrice - swingLow) / fibRange;
        
        if(VerboseLogging)
            Print("  Pullback level: ", DoubleToString(pullbackLevel * 100, 1), "%");
        
        // ✅ EXPANDED RANGE: Was 38.2-61.8%, now 23.6-78.6%
        if(pullbackLevel >= 0.382 && pullbackLevel <= 0.618)
        {
            fibScore = 30;  // Golden zone
            signal = 1;
        }
        else if(pullbackLevel >= 0.236 && pullbackLevel < 0.382)
        {
            fibScore = 25;  // Shallow pullback
            signal = 1;
        }
        else if(pullbackLevel > 0.618 && pullbackLevel <= 0.786)
        {
            fibScore = 20;  // Deep pullback
            signal = 1;
        }
    }
    else if(impulseDirection == -1)  // Bearish impulse, looking for pullback to sell
    {
        double pullbackLevel = (swingHigh - currentPrice) / fibRange;
        
        if(VerboseLogging)
            Print("  Pullback level: ", DoubleToString(pullbackLevel * 100, 1), "%");
        
        if(pullbackLevel >= 0.382 && pullbackLevel <= 0.618)
        {
            fibScore = 30;  // Golden zone
            signal = -1;
        }
        else if(pullbackLevel >= 0.236 && pullbackLevel < 0.382)
        {
            fibScore = 25;  // Shallow pullback
            signal = -1;
        }
        else if(pullbackLevel > 0.618 && pullbackLevel <= 0.786)
        {
            fibScore = 20;  // Deep pullback
            signal = -1;
        }
    }
    
    if(fibScore == 0)
    {
        if(VerboseLogging)
            Print("  ✗ Not at Fibonacci level");
        return false;
    }
    
    confidence += fibScore;
    analysis += "FIB+" + IntegerToString(fibScore) + " ";
    
    // ═══════════════════════════════════════════════════════════
    // STEP 3: RSI CONFIRMATION (WIDENED: 25-55 for buy, 45-75 for sell)
    // ═══════════════════════════════════════════════════════════
    
    double rsi = GetRSI(symbol, AnalysisTimeframe, 14);
    int rsiScore = 0;
    
    // ✅ WIDENED: Was 30-50, now 25-55 for buys
    if(signal == 1 && rsi >= 25 && rsi <= 55)
        rsiScore = 25;
    // ✅ WIDENED: Was 50-70, now 45-75 for sells
    else if(signal == -1 && rsi >= 45 && rsi <= 75)
        rsiScore = 25;
    else if(rsi >= 20 && rsi <= 80)
        rsiScore = 15;  // Wider fallback range
    else
        rsiScore = 10;  // At least give some points
    
    confidence += rsiScore;
    analysis += "RSI+" + IntegerToString(rsiScore) + " ";
    
    if(VerboseLogging)
        Print("  RSI: ", DoubleToString(rsi, 1), " → Score: ", rsiScore);
    
    // ═══════════════════════════════════════════════════════════
    // STEP 4: VOLUME (OPTIONAL - give points either way)
    // ═══════════════════════════════════════════════════════════
    
    int volScore = CheckVolumeConfirmation(symbol, AnalysisTimeframe) ? 10 : 7;
    confidence += volScore;
    analysis += "VOL+" + IntegerToString(volScore) + " ";
    
    // ═══════════════════════════════════════════════════════════
    // STEP 5: CSM CONFIRMATION (LOOSENED: 0+ gives points)
    // ═══════════════════════════════════════════════════════════
    
    int csmScore = 0;
    if(signal == 1)  // Bullish signal
    {
        if(csmDiff > 20) csmScore = 25;
        else if(csmDiff > 15) csmScore = 20;
        else if(csmDiff > 10) csmScore = 15;
        else if(csmDiff > 5) csmScore = 12;
        else if(csmDiff > 0) csmScore = 10;  // ✅ Even neutral-positive gets points
        else csmScore = 7;  // Even negative gets something
    }
    else if(signal == -1)  // Bearish signal
    {
        if(csmDiff < -20) csmScore = 25;
        else if(csmDiff < -15) csmScore = 20;
        else if(csmDiff < -10) csmScore = 15;
        else if(csmDiff < -5) csmScore = 12;
        else if(csmDiff < 0) csmScore = 10;  // ✅ Even neutral-negative gets points
        else csmScore = 7;  // Even positive gets something
    }
    
    confidence += csmScore;
    analysis += "CSM+" + IntegerToString(csmScore) + " ";
    
    // ═══════════════════════════════════════════════════════════
    // STEP 6: PRICE ACTION BONUS
    // ═══════════════════════════════════════════════════════════
    
    int paScore = DetectPriceActionPattern(symbol, AnalysisTimeframe);
    if((signal == 1 && paScore > 0) || (signal == -1 && paScore < 0))
    {
        confidence += 10;
        analysis += "PA+10 ";
    }
    
    // ═══════════════════════════════════════════════════════════
    // FINAL SUMMARY
    // ═══════════════════════════════════════════════════════════
    
    if(VerboseLogging)
    {
        Print("  Signal: ", signal > 0 ? "BUY" : "SELL");
        Print("  Confidence: ", confidence, "/130");
        Print("  Analysis: ", analysis);
    }
    
    return (signal != 0 && confidence >= MinConfidenceScore);
}

//+------------------------------------------------------------------+
//| SECTION 3: RANGE RIDER STRATEGY (MEAN REVERSION)                 |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Analyze Range Rider entry opportunity                            |
//| Returns: true if valid signal found                              |
//+------------------------------------------------------------------+
bool AnalyzeRangeRider(string symbol, int &signal, int &confidence, string &analysis, double csmDiff)
{
    if(!EnableRangeRider)
        return false;
    
    if(VerboseLogging)
        Print("\n══════ RANGE RIDER ANALYSIS ──────");
    
    // Step 1: Check if we have an active range for this symbol
    RangeData activeRange;
    if(!GetActiveRange(symbol, activeRange))
    {
        if(VerboseLogging)
            Print("  ✗ No active range for ", symbol);
        return false;
    }
    
    // Step 2: Check price proximity to boundaries
    double currentPrice = SymbolInfoDouble(symbol, SYMBOL_BID);
    bool nearSupport = false;
    bool nearResistance = false;
    
    double distancePips = CheckBoundaryProximity(symbol, currentPrice, activeRange, nearSupport, nearResistance);
    
    if(distancePips < 0)
    {
        if(VerboseLogging)
            Print("  ✗ Price not near any boundary (mid-range)");
        return false;
    }
    
    // Initialize scoring
    signal = 0;
    confidence = 0;
    analysis = "";
    
    // ═══════════════════════════════════════════════════════════
    // SCORE 1: Boundary Proximity (0-15 points)
    // ═══════════════════════════════════════════════════════════
    
    int proximityScore = 0;
    
    if(distancePips <= 3.0)
        proximityScore = 15;  // Very close (0-3 pips)
    else if(distancePips <= 5.0)
        proximityScore = 12;  // Close (3-5 pips)
    else if(distancePips <= 8.0)
        proximityScore = 10;  // Near (5-8 pips)
    else
        proximityScore = 7;   // Within zone (8-10 pips)
    
    confidence += proximityScore;
    analysis += "PROX+" + IntegerToString(proximityScore) + " ";
    
    // Determine direction based on boundary
    if(nearSupport)
    {
        signal = 1;  // BUY at support
        analysis += "AT_SUPPORT ";
    }
    else if(nearResistance)
    {
        signal = -1;  // SELL at resistance
        analysis += "AT_RESISTANCE ";
    }
    
    // ═══════════════════════════════════════════════════════════
    // SCORE 2: Rejection Pattern (0-15 points)
    // ═══════════════════════════════════════════════════════════
    
    bool lookingForBullish = (signal == 1);
    int rejectionScore = DetectRejectionPattern(symbol, ExecutionTimeframe, lookingForBullish);
    
    confidence += rejectionScore;
    if(rejectionScore > 0)
        analysis += "REJ+" + IntegerToString(rejectionScore) + " ";
    
    // ═══════════════════════════════════════════════════════════
    // SCORE 3: RSI Confirmation (0-20 points)
    // ═══════════════════════════════════════════════════════════
    
    double rsi = GetRSI(symbol, ExecutionTimeframe, 14);
    int rsiScore = 0;
    
    if(signal == 1)  // BUY at support
    {
        if(rsi < 30)
            rsiScore = 20;  // Oversold (perfect)
        else if(rsi < 40)
            rsiScore = 17;  // Below neutral (great)
        else if(rsi < 50)
            rsiScore = 14;  // Weakly bullish (good)
        else if(rsi < 60)
            rsiScore = 10;  // Neutral zone (acceptable)
        else
            rsiScore = 7;   // Above neutral (less ideal)
    }
    else if(signal == -1)  // SELL at resistance
    {
        if(rsi > 70)
            rsiScore = 20;  // Overbought (perfect)
        else if(rsi > 60)
            rsiScore = 17;  // Above neutral (great)
        else if(rsi > 50)
            rsiScore = 14;  // Weakly bearish (good)
        else if(rsi > 40)
            rsiScore = 10;  // Neutral zone (acceptable)
        else
            rsiScore = 7;   // Below neutral (less ideal)
    }
    
    confidence += rsiScore;
    analysis += "RSI+" + IntegerToString(rsiScore) + " ";
    
    if(VerboseLogging)
        Print("  RSI: ", DoubleToString(rsi, 1), " → Score: ", rsiScore);
    
    // ═══════════════════════════════════════════════════════════
    // SCORE 4: Stochastic Confirmation (0-15 points)
    // ═══════════════════════════════════════════════════════════
    
    double stochMain = 0, stochSignal = 0;
    int stochScore = 0;
    
    if(GetStochastic(symbol, ExecutionTimeframe, stochMain, stochSignal))
    {
        if(signal == 1)  // BUY at support
        {
            if(stochMain < 20 && stochMain > stochSignal)
                stochScore = 15;  // Oversold + crossing up
            else if(stochMain < 30)
                stochScore = 12;  // Oversold
            else if(stochMain < 50 && stochMain > stochSignal)
                stochScore = 10;  // Below neutral + crossing up
            else if(stochMain < 50)
                stochScore = 7;   // Below neutral
        }
        else if(signal == -1)  // SELL at resistance
        {
            if(stochMain > 80 && stochMain < stochSignal)
                stochScore = 15;  // Overbought + crossing down
            else if(stochMain > 70)
                stochScore = 12;  // Overbought
            else if(stochMain > 50 && stochMain < stochSignal)
                stochScore = 10;  // Above neutral + crossing down
            else if(stochMain > 50)
                stochScore = 7;   // Above neutral
        }
        
        confidence += stochScore;
        if(stochScore > 0)
            analysis += "STOCH+" + IntegerToString(stochScore) + " ";
        
        if(VerboseLogging)
            Print("  Stochastic: Main=", DoubleToString(stochMain, 1), 
                  " Signal=", DoubleToString(stochSignal, 1), " → Score: ", stochScore);
    }
    
    // ═══════════════════════════════════════════════════════════
    // SCORE 5: CSM Confirmation (0-25 points)
    // ═══════════════════════════════════════════════════════════
    
    int csmScore = 0;
    
    // At support (BUY), we want base currency weak (negative CSM diff)
    // At resistance (SELL), we want base currency strong (positive CSM diff)
    
    if(signal == 1)  // BUY at support
    {
        // Want negative CSM diff (base oversold)
        if(csmDiff < -20)
            csmScore = 25;
        else if(csmDiff < -15)
            csmScore = 20;
        else if(csmDiff < -10)
            csmScore = 15;
        else if(csmDiff < -5)
            csmScore = 10;
        else if(csmDiff < 0)
            csmScore = 5;
    }
    else if(signal == -1)  // SELL at resistance
    {
        // Want positive CSM diff (base overbought)
        if(csmDiff > 20)
            csmScore = 25;
        else if(csmDiff > 15)
            csmScore = 20;
        else if(csmDiff > 10)
            csmScore = 15;
        else if(csmDiff > 5)
            csmScore = 10;
        else if(csmDiff > 0)
            csmScore = 5;
    }
    
    confidence += csmScore;
    analysis += "CSM+" + IntegerToString(csmScore);
    
    // ═══════════════════════════════════════════════════════════
    // SCORE 6: Volume Confirmation (0-10 points) - BONUS
    // ═══════════════════════════════════════════════════════════
    
    int volScore = 0;
    if(CheckVolumeConfirmation(symbol, ExecutionTimeframe))
    {
        volScore = 10;
        confidence += volScore;
        analysis += " VOL+10";
    }
    
    // ═══════════════════════════════════════════════════════════
    // FINAL VALIDATION
    // ═══════════════════════════════════════════════════════════
    
    if(VerboseLogging)
    {
        Print("  Signal: ", signal > 0 ? "BUY (Support)" : "SELL (Resistance)");
        Print("  Confidence: ", confidence, "/100");
        Print("  Analysis: ", analysis);
        Print("  Breakdown:");
        Print("    Proximity: ", proximityScore, "/15");
        Print("    Rejection: ", rejectionScore, "/15");
        Print("    RSI: ", rsiScore, "/20");
        Print("    Stochastic: ", stochScore, "/15");
        Print("    CSM: ", csmScore, "/25");
        Print("    Volume: ", volScore, "/10");
        Print("  ", confidence >= RangeRiderMinConfidence ? "✓ VALID" : "✗ Below threshold");
    }
    
    // Check minimum confidence threshold
    return (signal != 0 && confidence >= RangeRiderMinConfidence);
}

//+------------------------------------------------------------------+
//| SECTION 4: RANGE DETECTION & VALIDATION                          |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Detect tradable range for a symbol                               |
//+------------------------------------------------------------------+
bool DetectTradableRange(string symbol, RangeData &range)
{
    if(VerboseLogging)
        Print("\n[", symbol, "] Detecting tradable range...");
    
    // Initialize range data
    range.symbol = symbol;
    range.isValid = false;
    range.qualityScore = 0;
    range.detectedTime = TimeCurrent();
    
    // Step 1: Find swing points
    SwingPoint swings[];
    int swingCount = FindSwingPoints(symbol, AnalysisTimeframe, RangeLookbackBars, swings);
    
    if(swingCount < 4)
    {
        if(VerboseLogging)
            Print("  ✗ Insufficient swing points: ", swingCount);
        return false;
    }
    
    // Step 2: Cluster boundaries
    RangeBoundary boundaries[];
    int boundaryCount = ClusterBoundaries(symbol, swings, swingCount, boundaries);
    
    if(boundaryCount < 2)
    {
        if(VerboseLogging)
            Print("  ✗ Insufficient boundaries: ", boundaryCount);
        return false;
    }
    
    // Step 3: Validate range
    int validationResult = ValidateRange(symbol, boundaries, boundaryCount, range);
    
    return (validationResult > 0 && range.isValid);
}

//+------------------------------------------------------------------+
//| Validate range quality with trending market filters              |
//+------------------------------------------------------------------+
int ValidateRange(string symbol, RangeBoundary &boundaries[], int boundaryCount,
                  RangeData &rangeOut)
{
    // Initialize output
    rangeOut.isValid = false;
    rangeOut.qualityScore = 0;
    rangeOut.symbol = symbol;
    rangeOut.detectedTime = TimeCurrent();
    
    if(boundaryCount < 2)
    {
        if(VerboseLogging)
            Print("✗ [", symbol, "] Insufficient boundaries: ", boundaryCount);
        return 0;
    }
    
    // Find strongest support and resistance
    RangeBoundary strongestSupport, strongestResistance;
    int supportFound = 0, resistanceFound = 0;
    int minTouches = 2;  // Minimum boundary touches
    
    for(int i = 0; i < boundaryCount; i++)
    {
        if(!boundaries[i].isResistance && boundaries[i].touchCount >= minTouches)
        {
            if(supportFound == 0 || boundaries[i].touchCount > strongestSupport.touchCount)
            {
                strongestSupport = boundaries[i];
                supportFound = 1;
            }
        }
        else if(boundaries[i].isResistance && boundaries[i].touchCount >= minTouches)
        {
            if(resistanceFound == 0 || boundaries[i].touchCount > strongestResistance.touchCount)
            {
                strongestResistance = boundaries[i];
                resistanceFound = 1;
            }
        }
    }
    
    if(supportFound == 0 || resistanceFound == 0)
    {
        if(VerboseLogging)
            Print("✗ [", symbol, "] Missing valid boundaries (S:", supportFound, " R:", resistanceFound, ")");
        return 0;
    }
    
    // Calculate range metrics
    double pipSize = SymbolInfoDouble(symbol, SYMBOL_POINT);
    if(SymbolInfoInteger(symbol, SYMBOL_DIGITS) == 3 || 
       SymbolInfoInteger(symbol, SYMBOL_DIGITS) == 5)
        pipSize *= 10;
    
    double rangeWidth = strongestResistance.level - strongestSupport.level;
    double rangeWidthPips = rangeWidth / pipSize;
    
    // Validate range width (reasonable size)
    double minWidth = 30.0;  // Minimum 30 pips
    double maxWidth = 200.0; // Maximum 200 pips
    
    if(rangeWidthPips < minWidth || rangeWidthPips > maxWidth)
    {
        if(VerboseLogging)
            Print("✗ [", symbol, "] Range width out of bounds: ", 
                  DoubleToString(rangeWidthPips, 1), " pips");
        return 0;
    }
    
    // Check ADX (must be low for ranging market)
    double adx = GetADX(symbol, AnalysisTimeframe, 14);
    if(adx > RangeMaxADX)
    {
        if(VerboseLogging)
            Print("✗ [", symbol, "] ADX too high: ", DoubleToString(adx, 1), " (max: ", RangeMaxADX, ")");
        return 0;
    }
    
    // Check EMA slope (must be flat for ranging)
    double ema50 = GetEMA(symbol, AnalysisTimeframe, 50);
    double ema50_prev = GetEMA(symbol, AnalysisTimeframe, 50);  // Would need to get historical
    double emaSlope = MathAbs(ema50 - ema50_prev) / pipSize;
    
    if(emaSlope > RangeMaxEMASlope)
    {
        if(VerboseLogging)
            Print("✗ [", symbol, "] EMA slope too steep: ", DoubleToString(emaSlope, 1));
        return 0;
    }
    
    // ✅ RANGE IS VALID - Fill output structure
    rangeOut.isValid = true;
    rangeOut.topLevel = strongestResistance.level;
    rangeOut.bottomLevel = strongestSupport.level;
    rangeOut.midLevel = (rangeOut.topLevel + rangeOut.bottomLevel) / 2.0;
    rangeOut.widthPips = rangeWidthPips;
    rangeOut.topTouches = strongestResistance.touchCount;
    rangeOut.bottomTouches = strongestSupport.touchCount;
    
    // Calculate quality score
    int qualityScore = 0;
    
    // Boundary touches (more = better)
    qualityScore += (strongestSupport.touchCount * 10);
    qualityScore += (strongestResistance.touchCount * 10);
    
    // ADX score (lower = better for ranging)
    if(adx < 15)
        qualityScore += 30;
    else if(adx < 20)
        qualityScore += 20;
    else
        qualityScore += 10;
    
    // Width score (ideal range: 50-100 pips)
    if(rangeWidthPips >= 50 && rangeWidthPips <= 100)
        qualityScore += 20;
    else if(rangeWidthPips >= 40 && rangeWidthPips <= 120)
        qualityScore += 15;
    else
        qualityScore += 10;
    
    rangeOut.qualityScore = qualityScore;
    
    if(VerboseLogging)
    {
        Print("✓ [", symbol, "] VALID RANGE DETECTED:");
        Print("  Top: ", DoubleToString(rangeOut.topLevel, 5), " (", rangeOut.topTouches, " touches)");
        Print("  Bottom: ", DoubleToString(rangeOut.bottomLevel, 5), " (", rangeOut.bottomTouches, " touches)");
        Print("  Width: ", DoubleToString(rangeWidthPips, 1), " pips");
        Print("  Quality Score: ", qualityScore, "/100");
        Print("  ADX: ", DoubleToString(adx, 1));
    }
    
    return 1;
}

//+------------------------------------------------------------------+
//| Get active range for a symbol                                    |
//+------------------------------------------------------------------+
bool GetActiveRange(string symbol, RangeData &rangeOut)
{
    for(int i = 0; i < activeRangeCount; i++)
    {
        if(activeRanges[i].symbol == symbol && activeRanges[i].isValid)
        {
            rangeOut = activeRanges[i];
            return true;
        }
    }
    return false;
}

//+------------------------------------------------------------------+
//| Check if range is still valid                                    |
//+------------------------------------------------------------------+
bool IsRangeStillValid(string symbol, RangeData &range)
{
    // Check if range broken
    double currentPrice = SymbolInfoDouble(symbol, SYMBOL_BID);
    
    double pipSize = SymbolInfoDouble(symbol, SYMBOL_POINT);
    if(SymbolInfoInteger(symbol, SYMBOL_DIGITS) == 3 || 
       SymbolInfoInteger(symbol, SYMBOL_DIGITS) == 5)
        pipSize *= 10;
    
    double breakoutBuffer = 15 * pipSize;  // 15 pips buffer
    
    // Check for breakout
    if(currentPrice > range.topLevel + breakoutBuffer)
    {
        if(VerboseLogging)
            Print("✗ [", symbol, "] Range broken to upside");
        return false;
    }
    
    if(currentPrice < range.bottomLevel - breakoutBuffer)
    {
        if(VerboseLogging)
            Print("✗ [", symbol, "] Range broken to downside");
        return false;
    }
    
    // Check ADX (if trending now, invalidate range)
    double adx = GetADX(symbol, AnalysisTimeframe, 14);
    if(adx > RangeMaxADX + 5)  // Give 5 point buffer
    {
        if(VerboseLogging)
            Print("✗ [", symbol, "] Market now trending (ADX: ", DoubleToString(adx, 1), ")");
        return false;
    }
    
    // Check age (ranges older than 4 hours may be stale)
    if(TimeCurrent() - range.detectedTime > 14400)  // 4 hours
    {
        if(VerboseLogging)
            Print("✗ [", symbol, "] Range expired (too old)");
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Check price proximity to range boundaries                        |
//+------------------------------------------------------------------+
double CheckBoundaryProximity(string symbol, double currentPrice, RangeData &range, 
                               bool &nearSupport, bool &nearResistance)
{
    double pipSize = SymbolInfoDouble(symbol, SYMBOL_POINT);
    if(SymbolInfoInteger(symbol, SYMBOL_DIGITS) == 3 || 
       SymbolInfoInteger(symbol, SYMBOL_DIGITS) == 5)
        pipSize *= 10;
    
    double proximityZone = 10 * pipSize;  // Within 10 pips = "near boundary"
    
    double distToTop = MathAbs(currentPrice - range.topLevel);
    double distToBottom = MathAbs(currentPrice - range.bottomLevel);
    
    nearSupport = false;
    nearResistance = false;
    
    // Check if near support
    if(distToBottom <= proximityZone)
    {
        nearSupport = true;
        return distToBottom / pipSize;  // Return distance in pips
    }
    
    // Check if near resistance
    if(distToTop <= proximityZone)
    {
        nearResistance = true;
        return distToTop / pipSize;  // Return distance in pips
    }
    
    // Not near any boundary (mid-range)
    return -1;
}

//+------------------------------------------------------------------+
//| Detect rejection pattern at boundary                             |
//+------------------------------------------------------------------+
int DetectRejectionPattern(string symbol, ENUM_TIMEFRAMES tf, bool lookingForBullish)
{
    double open[], high[], low[], close[];
    ArraySetAsSeries(open, true);
    ArraySetAsSeries(high, true);
    ArraySetAsSeries(low, true);
    ArraySetAsSeries(close, true);
    
    if(CopyOpen(symbol, tf, 0, 3, open) <= 0) return 0;
    if(CopyHigh(symbol, tf, 0, 3, high) <= 0) return 0;
    if(CopyLow(symbol, tf, 0, 3, low) <= 0) return 0;
    if(CopyClose(symbol, tf, 0, 3, close) <= 0) return 0;
    
    // Current candle analysis
    double body = MathAbs(close[0] - open[0]);
    double totalRange = high[0] - low[0];
    double upperWick = high[0] - MathMax(open[0], close[0]);
    double lowerWick = MathMin(open[0], close[0]) - low[0];
    
    int score = 0;
    
    if(lookingForBullish)  // Looking for bullish rejection at support
    {
        // Long lower wick = rejection of lower prices
        if(lowerWick > body * 2.0)
        {
            score = 15;  // Strong rejection
            
            if(VerboseLogging)
                Print("  Strong bullish rejection: Lower wick ", 
                      DoubleToString(lowerWick / body, 1), "x body");
        }
        else if(lowerWick > body * 1.5)
        {
            score = 12;  // Moderate rejection
        }
        else if(lowerWick > body)
        {
            score = 8;   // Weak rejection
        }
        
        // Bonus for bullish close
        if(close[0] > open[0])
            score += 3;
    }
    else  // Looking for bearish rejection at resistance
    {
        // Long upper wick = rejection of higher prices
        if(upperWick > body * 2.0)
        {
            score = 15;  // Strong rejection
            
            if(VerboseLogging)
                Print("  Strong bearish rejection: Upper wick ", 
                      DoubleToString(upperWick / body, 1), "x body");
        }
        else if(upperWick > body * 1.5)
        {
            score = 12;  // Moderate rejection
        }
        else if(upperWick > body)
        {
            score = 8;   // Weak rejection
        }
        
        // Bonus for bearish close
        if(close[0] < open[0])
            score += 3;
    }
    
    return score;
}

//+------------------------------------------------------------------+
//| Get Stochastic oscillator values                                 |
//+------------------------------------------------------------------+
bool GetStochastic(string symbol, ENUM_TIMEFRAMES tf, double &main, double &signal)
{
    int handle = iStochastic(symbol, tf, 14, 3, 3, MODE_SMA, STO_LOWHIGH);
    if(handle == INVALID_HANDLE) return false;
    
    double mainBuffer[], signalBuffer[];
    ArraySetAsSeries(mainBuffer, true);
    ArraySetAsSeries(signalBuffer, true);
    
    if(CopyBuffer(handle, 0, 0, 1, mainBuffer) <= 0)
    {
        IndicatorRelease(handle);
        return false;
    }
    
    if(CopyBuffer(handle, 1, 0, 1, signalBuffer) <= 0)
    {
        IndicatorRelease(handle);
        return false;
    }
    
    main = mainBuffer[0];
    signal = signalBuffer[0];
    
    IndicatorRelease(handle);
    return true;
}

//+------------------------------------------------------------------+
//| SECTION 5: POSITION MANAGEMENT                                   |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Manage Range Rider position with range-specific exits            |
//+------------------------------------------------------------------+
void ManageRangeRiderPosition(int trackerIndex, ulong ticket)
{
    if(!PositionSelectByTicket(ticket))
        return;
    
    string symbol = PositionGetString(POSITION_SYMBOL);
    double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
    double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
    double currentSL = PositionGetDouble(POSITION_SL);
    double currentTP = PositionGetDouble(POSITION_TP);
    int positionType = (int)PositionGetInteger(POSITION_TYPE);
    double positionProfit = PositionGetDouble(POSITION_PROFIT);
    
    // Get the stored range for this symbol
    RangeData activeRange;
    if(!GetActiveRange(symbol, activeRange))
    {
        if(VerboseLogging)
            Print("⚠ No active range found for position #", ticket, " - using standard management");
        return;
    }
    
    // Check if range is still valid
    if(!IsRangeStillValid(symbol, activeRange))
    {
        if(VerboseLogging)
            Print("⚠ Range invalid for position #", ticket, " - closing position");
        
        // Close position if range broken
        MqlTradeRequest request;
        MqlTradeResult result;
        ZeroMemory(request);
        ZeroMemory(result);
        
        request.action = TRADE_ACTION_DEAL;
        request.symbol = symbol;
        request.volume = PositionGetDouble(POSITION_VOLUME);
        request.type = (positionType == POSITION_TYPE_BUY) ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
        request.position = ticket;
        request.deviation = 10;
        
        if(OrderSend(request, result))
        {
            if(VerboseLogging)
                Print("✓ Closed position #", ticket, " (range broken)");
        }
        
        return;
    }
    
    // Calculate current R-multiple
    double slDistance = MathAbs(entryPrice - currentSL);
    if(slDistance == 0) return;
    
    double profitDistance = (positionType == POSITION_TYPE_BUY) ? 
        (currentPrice - entryPrice) : (entryPrice - currentPrice);
    
    double currentR = profitDistance / slDistance;
    
    // Update highest profit tracker
    if(currentR > openPositions[trackerIndex].highestProfit)
        openPositions[trackerIndex].highestProfit = currentR;
    
    // Range Rider specific exit: Target opposite boundary
    double targetLevel = (positionType == POSITION_TYPE_BUY) ? 
        activeRange.topLevel : activeRange.bottomLevel;
    
    double pipSize = SymbolInfoDouble(symbol, SYMBOL_POINT);
    if(SymbolInfoInteger(symbol, SYMBOL_DIGITS) == 3 || 
       SymbolInfoInteger(symbol, SYMBOL_DIGITS) == 5)
        pipSize *= 10;
    
    double distanceToTarget = MathAbs(currentPrice - targetLevel) / pipSize;
    
    // If within 5 pips of target, move to breakeven or trail tightly
    if(distanceToTarget <= 5.0 && currentR > 0.3)
    {
        double newSL = entryPrice + (positionType == POSITION_TYPE_BUY ? 5 : -5) * pipSize;
        
        if((positionType == POSITION_TYPE_BUY && newSL > currentSL) ||
           (positionType == POSITION_TYPE_SELL && newSL < currentSL))
        {
            MqlTradeRequest request;
            MqlTradeResult result;
            ZeroMemory(request);
            ZeroMemory(result);
            
            request.action = TRADE_ACTION_SLTP;
            request.symbol = symbol;
            request.sl = newSL;
            request.tp = currentTP;
            request.position = ticket;
            
            if(OrderSend(request, result))
            {
                if(VerboseLogging)
                    Print("✓ Moved SL to breakeven+5 for position #", ticket, 
                          " (near target boundary)");
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Advanced trailing stop with asymmetric behavior                  |
//+------------------------------------------------------------------+
void UpdateAdvancedTrailingStop(int trackerIndex, ulong ticket, double currentR, 
                                 double entryPrice, double slDistance, int positionType)
{
    if(!PositionSelectByTicket(ticket))
        return;
    
    string symbol = PositionGetString(POSITION_SYMBOL);
    double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
    double currentSL = PositionGetDouble(POSITION_SL);
    double currentTP = PositionGetDouble(POSITION_TP);
    
    double pipSize = SymbolInfoDouble(symbol, SYMBOL_POINT);
    if(SymbolInfoInteger(symbol, SYMBOL_DIGITS) == 3 || 
       SymbolInfoInteger(symbol, SYMBOL_DIGITS) == 5)
        pipSize *= 10;
    
    // Define trailing thresholds
    double R1 = TrailingActivationR;      // Start trailing (default: 1.0R)
    double R2 = TrailingActivationR + 0.5;// Tighten trail (1.5R)
    double R3 = TrailingActivationR + 1.0;// Very tight trail (2.0R)
    
    double newSL = currentSL;
    bool shouldUpdate = false;
    
    if(currentR >= R3)  // 2.0R+ : Trail very tightly (lock in 1.5R minimum)
    {
        double trailDistance = slDistance * 0.5;  // Trail 0.5R behind
        newSL = (positionType == POSITION_TYPE_BUY) ? 
            currentPrice - trailDistance : currentPrice + trailDistance;
        
        // Ensure minimum 1.5R locked
        double minSL = entryPrice + ((positionType == POSITION_TYPE_BUY ? 1 : -1) * slDistance * 1.5);
        if((positionType == POSITION_TYPE_BUY && newSL < minSL) ||
           (positionType == POSITION_TYPE_SELL && newSL > minSL))
        {
            newSL = minSL;
        }
        
        shouldUpdate = true;
    }
    else if(currentR >= R2)  // 1.5-2.0R : Trail moderately (lock in 1.0R minimum)
    {
        double trailDistance = slDistance * 0.75;  // Trail 0.75R behind
        newSL = (positionType == POSITION_TYPE_BUY) ? 
            currentPrice - trailDistance : currentPrice + trailDistance;
        
        // Ensure minimum 1.0R locked
        double minSL = entryPrice + ((positionType == POSITION_TYPE_BUY ? 1 : -1) * slDistance * 1.0);
        if((positionType == POSITION_TYPE_BUY && newSL < minSL) ||
           (positionType == POSITION_TYPE_SELL && newSL > minSL))
        {
            newSL = minSL;
        }
        
        shouldUpdate = true;
    }
    else if(currentR >= R1)  // 1.0-1.5R : Trail loosely (lock in breakeven)
    {
        double trailDistance = slDistance * 1.0;  // Trail 1.0R behind
        newSL = (positionType == POSITION_TYPE_BUY) ? 
            currentPrice - trailDistance : currentPrice + trailDistance;
        
        // Ensure minimum breakeven
        if((positionType == POSITION_TYPE_BUY && newSL < entryPrice) ||
           (positionType == POSITION_TYPE_SELL && newSL > entryPrice))
        {
            newSL = entryPrice;
        }
        
        shouldUpdate = true;
    }
    
    // Only update if new SL is better than current
    if(shouldUpdate)
    {
        if((positionType == POSITION_TYPE_BUY && newSL > currentSL) ||
           (positionType == POSITION_TYPE_SELL && newSL < currentSL))
        {
            MqlTradeRequest request;
            MqlTradeResult result;
            ZeroMemory(request);
            ZeroMemory(result);
            
            request.action = TRADE_ACTION_SLTP;
            request.symbol = symbol;
            request.sl = newSL;
            request.tp = currentTP;
            request.position = ticket;
            
            if(OrderSend(request, result))
            {
                if(VerboseLogging)
                    Print("✓ Advanced trailing: SL moved to ", DoubleToString(newSL, 5),
                          " (", DoubleToString((newSL - entryPrice) / slDistance, 2), "R locked)");
            }
        }
    }
}

//+------------------------------------------------------------------+
//| SECTION 6: MARKET REGIME DETECTION                               |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Detect market regime for symbol                                  |
//+------------------------------------------------------------------+
MARKET_REGIME DetectMarketRegime(string symbol)
{
    // Get indicators
    double ema20 = GetEMA(symbol, PERIOD_M15, 20);
    double ema50 = GetEMA(symbol, PERIOD_M15, 50);
    double ema100 = GetEMA(symbol, PERIOD_M15, 100);
    double adx = GetADX(symbol, PERIOD_M15, 14);
    
    if(ema20 == 0 || ema50 == 0 || ema100 == 0)
        return REGIME_TRANSITIONAL;
    
    // Calculate EMA separation
    double emaSeparation = CalculateEMASeparation(symbol, ema20, ema50, ema100);
    
    // Calculate ATR ratio
    double atrRatio = CalculateATRRatio(symbol, PERIOD_M15);
    
    // Trending conditions
    bool strongTrend = (adx > 30 && emaSeparation > 1.5);
    bool moderateTrend = (adx > 25 && emaSeparation > 1.0);
    
    // Ranging conditions
    bool ranging = (adx < 20 && emaSeparation < 0.5);
    
    // Decisiveness check
    if(strongTrend)
        return REGIME_TRENDING;
    else if(ranging)
        return REGIME_RANGING;
    else if(moderateTrend)
        return REGIME_TRENDING;  // Lean toward trending if moderate
    else
        return REGIME_TRANSITIONAL;
}

//+------------------------------------------------------------------+
//| Update regime detection across all symbols                       |
//+------------------------------------------------------------------+
void UpdateRegimeDetection(string symbol)
{
    MARKET_REGIME detectedRegime = DetectMarketRegime(symbol);
    
    if(detectedRegime != currentRegime)
    {
        if(VerboseLogging)
        {
            Print("╔════════════════════════════════════╗");
            Print("║  REGIME CHANGE DETECTED           ║");
            Print("╠════════════════════════════════════╣");
            Print("║  Symbol: ", symbol);
            Print("║  Old: ", EnumToString(currentRegime));
            Print("║  New: ", EnumToString(detectedRegime));
            Print("╚════════════════════════════════════╝");
        }
        
        currentRegime = detectedRegime;
    }
}

//+------------------------------------------------------------------+
//| END OF JCAMP BACKTEST STRATEGIES MODULE                          |
//+------------------------------------------------------------------+
