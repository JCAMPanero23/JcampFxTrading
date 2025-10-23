//+------------------------------------------------------------------+
//|                                          Jcamp_Backtest_Math.mqh |
//|                                   JCAMP Backtest EA v1.80 Module |
//|                              Mathematical & Indicator Functions  |
//+------------------------------------------------------------------+
//| MODULE PURPOSE:                                                   |
//| - Technical indicator calculations (EMA, ADX, RSI, ATR)          |
//| - Currency Strength Meter (CSM) calculations                     |
//| - Swing point detection and analysis                             |
//| - Pattern recognition functions                                  |
//| - Regime detection mathematics                                   |
//| - Range boundary clustering                                      |
//+------------------------------------------------------------------+

#property copyright "JCAMP Trading System"
#property version   "1.80"
#property strict

//+------------------------------------------------------------------+
//| EXTERNAL GLOBAL VARIABLES                                         |
//| These are declared in main EA, accessed here via extern          |
//+------------------------------------------------------------------+

// CSM Data Structures
extern CurrencyStrengthData csm_data[8];
extern PairData pair_data[15];
extern string currencies[8];
extern string major_pairs[15];

// Input Parameters (used in math calculations)
extern bool VerboseLogging;
extern int BoundaryClusterPips;
extern int MinBoundaryTouches;
extern double MinRangeWidthPips;
extern double MaxRangeWidthPips;
extern double RangeMaxADX;
extern double RangeMaxEMASlope;

//+------------------------------------------------------------------+
//| SECTION 1: TECHNICAL INDICATOR FUNCTIONS                         |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Helper: Get EMA                                                   |
//+------------------------------------------------------------------+
double GetEMA(string symbol, ENUM_TIMEFRAMES tf, int period)
{
    int handle = iMA(symbol, tf, period, 0, MODE_EMA, PRICE_CLOSE);
    if(handle == INVALID_HANDLE) return 0;
    
    double buffer[];
    ArraySetAsSeries(buffer, true);
    
    if(CopyBuffer(handle, 0, 0, 1, buffer) <= 0)
    {
        IndicatorRelease(handle);
        return 0;
    }
    
    IndicatorRelease(handle);
    return buffer[0];
}

//+------------------------------------------------------------------+
//| Helper: Get ADX                                                   |
//+------------------------------------------------------------------+
double GetADX(string symbol, ENUM_TIMEFRAMES tf, int period)
{
    int handle = iADX(symbol, tf, period);
    if(handle == INVALID_HANDLE) return 0;
    
    double buffer[];
    ArraySetAsSeries(buffer, true);
    
    if(CopyBuffer(handle, 0, 0, 1, buffer) <= 0)
    {
        IndicatorRelease(handle);
        return 0;
    }
    
    IndicatorRelease(handle);
    return buffer[0];
}

//+------------------------------------------------------------------+
//| Helper: Get RSI                                                   |
//+------------------------------------------------------------------+
double GetRSI(string symbol, ENUM_TIMEFRAMES tf, int period)
{
    int handle = iRSI(symbol, tf, period, PRICE_CLOSE);
    if(handle == INVALID_HANDLE) return 50;
    
    double buffer[];
    ArraySetAsSeries(buffer, true);
    
    if(CopyBuffer(handle, 0, 0, 1, buffer) <= 0)
    {
        IndicatorRelease(handle);
        return 50;
    }
    
    IndicatorRelease(handle);
    return buffer[0];
}

//+------------------------------------------------------------------+
//| Helper: Get ATR                                                   |
//+------------------------------------------------------------------+
double GetATR(string symbol, ENUM_TIMEFRAMES tf, int period)
{
    int handle = iATR(symbol, tf, period);
    if(handle == INVALID_HANDLE) return 0;
    
    double buffer[];
    ArraySetAsSeries(buffer, true);
    
    if(CopyBuffer(handle, 0, 0, 1, buffer) <= 0)
    {
        IndicatorRelease(handle);
        return 0;
    }
    
    IndicatorRelease(handle);
    return buffer[0];
}

//+------------------------------------------------------------------+
//| SECTION 2: SWING ANALYSIS FUNCTIONS                              |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Helper: Find swing low                                            |
//+------------------------------------------------------------------+
double FindSwingLow(string symbol, ENUM_TIMEFRAMES tf, int bars)
{
    double low[];
    ArraySetAsSeries(low, true);
    
    int copied = CopyLow(symbol, tf, 0, bars + 5, low);
    if(copied <= 0) return 0;
    
    double swingLow = low[0];
    for(int i = 1; i < bars; i++)
    {
        if(low[i] < swingLow)
            swingLow = low[i];
    }
    
    return swingLow;
}

//+------------------------------------------------------------------+
//| Helper: Find swing high                                           |
//+------------------------------------------------------------------+
double FindSwingHigh(string symbol, ENUM_TIMEFRAMES tf, int bars)
{
    double high[];
    ArraySetAsSeries(high, true);
    
    int copied = CopyHigh(symbol, tf, 0, bars + 5, high);
    if(copied <= 0) return 0;
    
    double swingHigh = high[0];
    for(int i = 1; i < bars; i++)
    {
        if(high[i] > swingHigh)
            swingHigh = high[i];
    }
    
    return swingHigh;
}

//+------------------------------------------------------------------+
//| SECTION 3: PATTERN DETECTION FUNCTIONS                           |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Helper: Detect price action pattern                               |
//+------------------------------------------------------------------+
int DetectPriceActionPattern(string symbol, ENUM_TIMEFRAMES tf)
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
    
    double body = MathAbs(close[0] - open[0]);
    double totalRange = high[0] - low[0];
    double upperWick = high[0] - MathMax(open[0], close[0]);
    double lowerWick = MathMin(open[0], close[0]) - low[0];
    
    if(close[0] > open[0])
    {
        if(lowerWick > body * 2 && upperWick < body * 0.3)
            return 1;  // Bullish pin bar
        if(body > totalRange * 0.7)
            return 1;  // Strong bullish candle
    }
    else if(close[0] < open[0])
    {
        if(upperWick > body * 2 && lowerWick < body * 0.3)
            return -1;  // Bearish pin bar
        if(body > totalRange * 0.7)
            return -1;  // Strong bearish candle
    }
    
    return 0;  // No pattern
}

//+------------------------------------------------------------------+
//| Helper: Check volume confirmation                                 |
//+------------------------------------------------------------------+
bool CheckVolumeConfirmation(string symbol, ENUM_TIMEFRAMES tf)
{
    long volume[];
    ArraySetAsSeries(volume, true);
    
    if(CopyTickVolume(symbol, tf, 0, 5, volume) <= 0)
        return true;  // If volume data unavailable, don't use it
    
    double avgVolume = 0;
    for(int i = 1; i < 5; i++)
        avgVolume += volume[i];
    avgVolume /= 4;
    
    return (volume[0] >= avgVolume * 1.2);  // Current volume 20% above average
}

//+------------------------------------------------------------------+
//| Helper: Check multi-timeframe alignment                           |
//+------------------------------------------------------------------+
bool CheckMTFAlignment(string symbol, int signal)
{
    if(signal == 0) return false;
    
    // Get H1 trend (one timeframe higher than M15)
    double ema20_h1 = GetEMA(symbol, PERIOD_H1, 20);
    double ema50_h1 = GetEMA(symbol, PERIOD_H1, 50);
    
    if(ema20_h1 == 0 || ema50_h1 == 0) return false;
    
    bool h1Bullish = (ema20_h1 > ema50_h1);
    
    if(signal > 0 && h1Bullish) return true;   // Buy signal with H1 uptrend
    if(signal < 0 && !h1Bullish) return true;  // Sell signal with H1 downtrend
    
    return false;
}

//+------------------------------------------------------------------+
//| Helper: Score ADX strength                                        |
//+------------------------------------------------------------------+
int ScoreADX(double adx)
{
    if(adx < 20) return 0;       // Weak/no trend
    if(adx < 25) return 1;       // Developing trend
    if(adx < 35) return 2;       // Moderate trend
    if(adx < 45) return 3;       // Strong trend
    return 4;                    // Very strong trend
}

//+------------------------------------------------------------------+
//| SECTION 4: ADVANCED SWING ANALYSIS                               |
//| Identify swing highs and lows for range boundary detection       |
//+------------------------------------------------------------------+

int FindSwingPoints(string symbol, ENUM_TIMEFRAMES tf, int lookbackBars, SwingPoint &swings[])
{
    double high[], low[], close[];
    ArraySetAsSeries(high, true);
    ArraySetAsSeries(low, true);
    ArraySetAsSeries(close, true);
    
    int bars = lookbackBars + 4;  // Need extra bars for swing detection
    
    if(CopyHigh(symbol, tf, 0, bars, high) <= 0) return 0;
    if(CopyLow(symbol, tf, 0, bars, low) <= 0) return 0;
    if(CopyClose(symbol, tf, 0, bars, close) <= 0) return 0;
    
    // ═══════════════════════════════════════════════════════════
    // Calculate ATR for filtering insignificant swings
    // ═══════════════════════════════════════════════════════════
    
    double atr = GetATR(symbol, tf, 14);
    if(atr == 0) atr = (high[0] - low[0]);  // Fallback to current range
    
    double minSwingSize = atr * 0.3;  // Swing must be at least 30% of ATR
    
    double pipSize = SymbolInfoDouble(symbol, SYMBOL_POINT);
    if(SymbolInfoInteger(symbol, SYMBOL_DIGITS) == 3 || 
       SymbolInfoInteger(symbol, SYMBOL_DIGITS) == 5)
        pipSize *= 10;
    
    int swingCount = 0;
    ArrayResize(swings, 0);
    
    int lastSwingHighBar = -999;  // Track last swing to enforce spacing
    int lastSwingLowBar = -999;
    
    int rejectedSmall = 0;  // Count rejected swings for logging
    int rejectedSpacing = 0;
    
    // ═══════════════════════════════════════════════════════════
    // Detect swing highs (bar higher than 2 bars before and 2 after)
    // ═══════════════════════════════════════════════════════════
    
    for(int i = 2; i < bars - 2; i++)
    {
        // ✅ IMPROVEMENT 1: Enforce minimum 5-bar spacing
        if(i - lastSwingHighBar < 3)
        {
            rejectedSpacing++;
            continue;
        }
        
        bool isSwingHigh = true;
        
        // Check if this bar's high is higher than surrounding bars
        for(int j = i - 2; j <= i + 2; j++)
        {
            if(j == i) continue;
            if(high[j] >= high[i])
            {
                isSwingHigh = false;
                break;
            }
        }
        
        if(isSwingHigh)
        {
            // ✅ IMPROVEMENT 2: Filter out insignificant swings
            double swingRange = high[i] - low[i];
            
            if(swingRange < minSwingSize)
            {
                rejectedSmall++;
                continue;
            }
            
            ArrayResize(swings, swingCount + 1);
            swings[swingCount].price = high[i];
            swings[swingCount].time = iTime(symbol, tf, i);
            swings[swingCount].barIndex = i;
            swings[swingCount].isHigh = true;
            swingCount++;
            
            lastSwingHighBar = i;  // Update last swing position
        }
    }
    
    // ═══════════════════════════════════════════════════════════
    // Detect swing lows (bar lower than 2 bars before and 2 after)
    // ═══════════════════════════════════════════════════════════
    
    for(int i = 2; i < bars - 2; i++)
    {
        // ✅ IMPROVEMENT 1: Enforce minimum 5-bar spacing
        if(i - lastSwingLowBar < 3)
        {
            rejectedSpacing++;
            continue;
        }
        
        bool isSwingLow = true;
        
        // Check if this bar's low is lower than surrounding bars
        for(int j = i - 2; j <= i + 2; j++)
        {
            if(j == i) continue;
            if(low[j] <= low[i])
            {
                isSwingLow = false;
                break;
            }
        }
        
        if(isSwingLow)
        {
            // ✅ IMPROVEMENT 2: Filter out insignificant swings
            double swingRange = high[i] - low[i];
            
            if(swingRange < minSwingSize)
            {
                rejectedSmall++;
                continue;
            }
            
            ArrayResize(swings, swingCount + 1);
            swings[swingCount].price = low[i];
            swings[swingCount].time = iTime(symbol, tf, i);
            swings[swingCount].barIndex = i;
            swings[swingCount].isHigh = false;
            swingCount++;
            
            lastSwingLowBar = i;  // Update last swing position
        }
    }
    
    if(VerboseLogging && swingCount > 0)
    {
        Print("📊 [", symbol, "] Swing Point Analysis:");
        Print("   Found: ", swingCount, " significant swings");
        Print("   Filtered out: ", rejectedSmall, " (too small, <", 
              DoubleToString(minSwingSize / pipSize, 1), " pips)");
        Print("   Filtered out: ", rejectedSpacing, " (spacing <5 bars)");
        Print("   Quality: Only swings 5+ bars apart, 30%+ ATR size");
    }
    
    return swingCount;
}

//+------------------------------------------------------------------+
//| SECTION 5: BOUNDARY CLUSTERING                                   |
//| Group swing points into support/resistance clusters              |
//+------------------------------------------------------------------+

int ClusterBoundaries(string symbol, SwingPoint &swings[], int swingCount, 
                      RangeBoundary &boundaries[])
{
    if(swingCount == 0) return 0;
    
    double pipSize = SymbolInfoDouble(symbol, SYMBOL_POINT);
    if(SymbolInfoInteger(symbol, SYMBOL_DIGITS) == 3 || 
       SymbolInfoInteger(symbol, SYMBOL_DIGITS) == 5)
        pipSize *= 10;
    
    double clusterTolerance = BoundaryClusterPips * pipSize;
    
    ArrayResize(boundaries, 0);
    int boundaryCount = 0;
    
    // Process each swing point
    for(int i = 0; i < swingCount; i++)
    {
        bool addedToCluster = false;
        
        // Try to add to existing cluster
        for(int j = 0; j < boundaryCount; j++)
        {
            // Check if swing type matches boundary type
            if(swings[i].isHigh != boundaries[j].isResistance)
                continue;
            
            // Check if price is within cluster tolerance
            if(MathAbs(swings[i].price - boundaries[j].level) <= clusterTolerance)
            {
                // Update cluster (weighted average)
                double totalWeight = boundaries[j].touchCount + 1;
                boundaries[j].level = ((boundaries[j].level * boundaries[j].touchCount) + 
                                      swings[i].price) / totalWeight;
                boundaries[j].touchCount++;
                boundaries[j].lastTouch = swings[i].time;
                addedToCluster = true;
                break;
            }
        }
        
        // Create new cluster if not added to existing
        if(!addedToCluster)
        {
            ArrayResize(boundaries, boundaryCount + 1);
            boundaries[boundaryCount].level = swings[i].price;
            boundaries[boundaryCount].touchCount = 1;
            boundaries[boundaryCount].firstTouch = swings[i].time;
            boundaries[boundaryCount].lastTouch = swings[i].time;
            boundaries[boundaryCount].isResistance = swings[i].isHigh;
            boundaryCount++;
        }
    }
    
    if(VerboseLogging && boundaryCount > 0)
    {
        Print("🎯 [", symbol, "] Clustered into ", boundaryCount, " potential boundaries");
    }
    
    return boundaryCount;
}

//+------------------------------------------------------------------+
//| SECTION 6: CSM (CURRENCY STRENGTH METER) FUNCTIONS               |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Initialize CSM data structures                                    |
//+------------------------------------------------------------------+
void InitializeCSMData()
{
    for(int i = 0; i < 8; i++)
    {
        csm_data[i].currency = currencies[i];
        csm_data[i].current_strength = 50.0;
        csm_data[i].normalized_strength = 50.0;
    }
}

//+------------------------------------------------------------------+
//| Initialize pair data structures                                   |
//+------------------------------------------------------------------+
void InitializePairData()
{
    for(int i = 0; i < 15; i++)
    {
        pair_data[i].symbol = major_pairs[i];
        pair_data[i].available = false;
        pair_data[i].ema_slope_48h = 0;
    }
}

//+------------------------------------------------------------------+
//| Update pair data (EMA slopes for CSM calculation)                |
//+------------------------------------------------------------------+
void UpdatePairData()
{
    for(int i = 0; i < 15; i++)
    {
        string symbol = pair_data[i].symbol;
        
        // Check if symbol exists and is available
        if(!SymbolExists(symbol))
        {
            pair_data[i].available = false;
            continue;
        }
        
        // Get EMA values for slope calculation
        double ema_now = GetEMA(symbol, PERIOD_H4, 12);
        double ema_48h = GetEMA(symbol, PERIOD_H4, 24);  // 24 H4 bars = ~4 days
        
        if(ema_now == 0 || ema_48h == 0)
        {
            pair_data[i].available = false;
            continue;
        }
        
        // Calculate normalized slope (-100 to +100)
        double slope_points = ema_now - ema_48h;
        double atr = GetATR(symbol, PERIOD_H4, 14);
        
        if(atr > 0)
        {
            pair_data[i].ema_slope_48h = (slope_points / atr) * 100;
            pair_data[i].ema_slope_48h = MathMax(-100, MathMin(100, pair_data[i].ema_slope_48h));
        }
        else
        {
            pair_data[i].ema_slope_48h = 0;
        }
        
        pair_data[i].available = true;
    }
}

//+------------------------------------------------------------------+
//| Update Full CSM (48H lookback, 15 pairs, 8 currencies)           |
//+------------------------------------------------------------------+
void UpdateFullCSM()
{
    // Reset all currency strengths to neutral
    for(int i = 0; i < 8; i++)
    {
        csm_data[i].current_strength = 50.0;
    }
    
    // Update pair data first
    UpdatePairData();
    
    // Calculate currency strengths from pair slopes
    CalculateCSMStrengths();
    
    // Normalize to 0-100 scale
    NormalizeStrengthValues();
}

//+------------------------------------------------------------------+
//| Calculate CSM strengths from pair slopes                         |
//+------------------------------------------------------------------+
void CalculateCSMStrengths()
{
    // Count contributions for each currency
    int contributions[8];
    ArrayInitialize(contributions, 0);
    
    // Accumulate strengths from all available pairs
    for(int i = 0; i < 15; i++)
    {
        if(!pair_data[i].available) continue;
        
        string symbol = pair_data[i].symbol;
        double slope = pair_data[i].ema_slope_48h;
        
        // Extract base and quote currencies
        string base = StringSubstr(symbol, 0, 3);
        string quote = StringSubstr(symbol, 3, 3);
        
        int baseIdx = GetCurrencyIndex(base);
        int quoteIdx = GetCurrencyIndex(quote);
        
        if(baseIdx >= 0 && quoteIdx >= 0)
        {
            // Positive slope = base stronger, quote weaker
            // Negative slope = base weaker, quote stronger
            csm_data[baseIdx].current_strength += slope;
            csm_data[quoteIdx].current_strength -= slope;
            
            contributions[baseIdx]++;
            contributions[quoteIdx]++;
        }
    }
    
    // Average the contributions
    for(int i = 0; i < 8; i++)
    {
        if(contributions[i] > 0)
        {
            csm_data[i].current_strength /= contributions[i];
        }
        else
        {
            csm_data[i].current_strength = 50.0;  // No data, stay neutral
        }
    }
}

//+------------------------------------------------------------------+
//| Get currency index from currency code                            |
//+------------------------------------------------------------------+
int GetCurrencyIndex(string currency)
{
    for(int i = 0; i < 8; i++)
    {
        if(currencies[i] == currency)
            return i;
    }
    return -1;
}

//+------------------------------------------------------------------+
//| Normalize strength values to 0-100 scale                         |
//+------------------------------------------------------------------+
void NormalizeStrengthValues()
{
    // Find min and max strengths
    double minStrength = csm_data[0].current_strength;
    double maxStrength = csm_data[0].current_strength;
    
    for(int i = 1; i < 8; i++)
    {
        if(csm_data[i].current_strength < minStrength)
            minStrength = csm_data[i].current_strength;
        if(csm_data[i].current_strength > maxStrength)
            maxStrength = csm_data[i].current_strength;
    }
    
    // Normalize to 0-100 scale
    double range = maxStrength - minStrength;
    
    if(range > 0)
    {
        for(int i = 0; i < 8; i++)
        {
            csm_data[i].normalized_strength = 
                ((csm_data[i].current_strength - minStrength) / range) * 100;
        }
    }
    else
    {
        // All equal, set to neutral
        for(int i = 0; i < 8; i++)
        {
            csm_data[i].normalized_strength = 50.0;
        }
    }
}

//+------------------------------------------------------------------+
//| Get currency strength by currency code                           |
//+------------------------------------------------------------------+
double GetCurrencyStrength(string currency)
{
    for(int i = 0; i < 8; i++)
    {
        if(csm_data[i].currency == currency)
            return csm_data[i].normalized_strength;
    }
    return 50.0;  // Neutral if not found
}

//+------------------------------------------------------------------+
//| Get CSM differential for a symbol                                |
//+------------------------------------------------------------------+
double GetCSMDifferential(string symbol)
{
    if(StringLen(symbol) < 6) return 0;
    
    string base = StringSubstr(symbol, 0, 3);
    string quote = StringSubstr(symbol, 3, 3);
    
    double baseStrength = GetCurrencyStrength(base);
    double quoteStrength = GetCurrencyStrength(quote);
    
    return baseStrength - quoteStrength;
}

//+------------------------------------------------------------------+
//| SECTION 7: REGIME DETECTION MATHEMATICS                          |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Calculate EMA separation (for trending/ranging detection)        |
//+------------------------------------------------------------------+
double CalculateEMASeparation(string symbol, double ema20, double ema50, double ema100)
{
    if(ema20 == 0 || ema50 == 0 || ema100 == 0) return 0;
    
    double atr = GetATR(symbol, PERIOD_M15, 14);
    if(atr == 0) return 0;
    
    // Calculate separation between EMAs as percentage of ATR
    double sep_20_50 = MathAbs(ema20 - ema50) / atr;
    double sep_50_100 = MathAbs(ema50 - ema100) / atr;
    double sep_20_100 = MathAbs(ema20 - ema100) / atr;
    
    // Average separation
    double avgSeparation = (sep_20_50 + sep_50_100 + sep_20_100) / 3.0;
    
    return avgSeparation;
}

//+------------------------------------------------------------------+
//| Calculate ATR ratio (current vs historical)                      |
//+------------------------------------------------------------------+
double CalculateATRRatio(string symbol, ENUM_TIMEFRAMES tf)
{
    double currentATR = GetATR(symbol, tf, 14);
    double historicalATR = GetATR(symbol, tf, 50);
    
    if(historicalATR == 0) return 1.0;
    
    return currentATR / historicalATR;
}

//+------------------------------------------------------------------+
//| END OF JCAMP BACKTEST MATH MODULE                                |
//+------------------------------------------------------------------+
