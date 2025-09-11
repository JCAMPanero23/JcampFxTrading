//+------------------------------------------------------------------+
//|                                                 TL_HL_Math.mqh |
//|                                                    JcampFx Team |
//|                                 Technical Analysis Math Library |
//+------------------------------------------------------------------+

// Forward declarations of helper functions
bool IsSwingHigh(double &highs[], int index, int period);
bool IsSwingLow(double &lows[], int index, int period);
int CountTrendLineTouches(double &prices[], datetime &times[], TrendLineData &trendLine, bool isResistance);
double GetTrendLinePriceAtTime(TrendLineData &trendLine, datetime time);

struct TrendLineData
{
    datetime startTime;
    datetime endTime;
    double startPrice;
    double endPrice;
    bool isSupport;
    double strength;
    int touchCount;
    string objectName;
};

struct HorizontalLevelData
{
    double price;
    bool isSupport;
    double strength;
    int touchCount;
    datetime lastTouch;
    string objectName;
};

struct OscillatorData
{
    double rsi;
    double stochastic;
    double williams;
    bool oversold;
    bool overbought;
    bool divergence;
};

struct MACDData
{
    double main;
    double signal;
    double histogram;
    bool bullishCrossover;
    bool bearishCrossover;
    bool divergence;
};

struct CSMCurrencyData
{
    string currency;
    double strength;
    int rank;
};

//+------------------------------------------------------------------+
//| Technical Analysis Math Library Class                           |
//+------------------------------------------------------------------+
class CTL_HL_Math
{
private:
    // Arrays for storing technical data
    TrendLineData m_TrendLines[];
    HorizontalLevelData m_HorizontalLevels[];
    OscillatorData m_Oscillators[];
    MACDData m_MACDData[];
    CSMCurrencyData m_CSMData[];
    
    // Indicator handles
    int m_HandleRSI;
    int m_HandleStoch;
    int m_HandleWilliams;
    int m_HandleMACD;
    int m_HandleMA20;
    int m_HandleMA50;
    int m_HandleMA200;
    
    // Settings
    string m_CurrentSymbol;
    ENUM_TIMEFRAMES m_CurrentTimeframe;
    bool m_IsMainChart;
    
    // Drawing settings
    color m_SupportColor;
    color m_ResistanceColor;
    color m_TrendLineColor;
    int m_LineWidth;
    
public:
    // Constructor & Destructor
    CTL_HL_Math();
    ~CTL_HL_Math();
    
    // Initialization
    bool Initialize();
    bool SetupChart(string symbol, ENUM_TIMEFRAMES timeframe, bool isMainChart);
    
    // Main analysis functions
    bool UpdateTechnicalAnalysis(string symbol, ENUM_TIMEFRAMES timeframe);
    void CalculateCSM(string pairs[], int pairsCount, int lookback);
    
    // Trendline functions
    int FindTrendLines(string symbol, ENUM_TIMEFRAMES timeframe, int barsBack = 100);
    bool IsTrendLineValid(TrendLineData &trendLine, datetime currentTime, double currentPrice);
    double GetTrendLinePrice(TrendLineData &trendLine, datetime time);
    int GetTrendLineCount(bool supportOnly = false, bool resistanceOnly = false);
    TrendLineData GetTrendLine(int index);
    
    // Horizontal level functions
    int FindHorizontalLevels(string symbol, ENUM_TIMEFRAMES timeframe, int barsBack = 200);
    bool IsHorizontalLevelValid(HorizontalLevelData &level, double currentPrice, double tolerance);
    int GetHorizontalLevelCount(bool supportOnly = false, bool resistanceOnly = false);
    HorizontalLevelData GetHorizontalLevel(int index);
    double GetNearestSupportLevel(double currentPrice);
    double GetNearestResistanceLevel(double currentPrice);
    
    // Oscillator functions
    bool UpdateOscillators(string symbol, ENUM_TIMEFRAMES timeframe);
    OscillatorData GetOscillatorData();
    bool IsOverboughtCondition();
    bool IsOversoldCondition();
    bool HasBullishDivergence(string symbol, ENUM_TIMEFRAMES timeframe, int barsBack = 20);
    bool HasBearishDivergence(string symbol, ENUM_TIMEFRAMES timeframe, int barsBack = 20);
    
    // MACD functions
    bool UpdateMACD(string symbol, ENUM_TIMEFRAMES timeframe);
    MACDData GetMACDData();
    bool IsMACDBullishCrossover();
    bool IsMACDBearishCrossover();
    
    // Price action functions
    bool IsBullishEngulfing(string symbol, ENUM_TIMEFRAMES timeframe, int barIndex = 1);
    bool IsBearishEngulfing(string symbol, ENUM_TIMEFRAMES timeframe, int barIndex = 1);
    bool IsDoji(string symbol, ENUM_TIMEFRAMES timeframe, int barIndex = 1);
    bool IsHammer(string symbol, ENUM_TIMEFRAMES timeframe, int barIndex = 1);
    bool IsShootingStar(string symbol, ENUM_TIMEFRAMES timeframe, int barIndex = 1);
    
    // Support/Resistance functions
    bool IsPriceNearLevel(double price, double level, double tolerance);
    double CalculateLevelStrength(double level, string symbol, ENUM_TIMEFRAMES timeframe, int barsBack);
    
    // CSM functions
    double CalculateCurrencyStrength(string currency, string pairs[], int pairsCount, int lookback);
    void SortCSMData();
    CSMCurrencyData GetStrongestCurrency();
    CSMCurrencyData GetWeakestCurrency();
    string GetCSMRankings();
    
    // Drawing functions
    void DrawTrendLine(TrendLineData &trendLine);
    void DrawHorizontalLevel(HorizontalLevelData &level);
    void ClearDrawings();
    void UpdateDrawings();
    
    // Utility functions
    double NormalizePrice(double price, string symbol);
    double CalculateATR(string symbol, ENUM_TIMEFRAMES timeframe, int period = 14);
    double CalculatePipValue(string symbol);
    bool IsNewBar(string symbol, ENUM_TIMEFRAMES timeframe);
    
    // Validation functions
    bool ValidateSymbol(string symbol);
    bool ValidateTimeframe(ENUM_TIMEFRAMES timeframe);
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CTL_HL_Math::CTL_HL_Math()
{
    m_HandleRSI = INVALID_HANDLE;
    m_HandleStoch = INVALID_HANDLE;
    m_HandleWilliams = INVALID_HANDLE;
    m_HandleMACD = INVALID_HANDLE;
    m_HandleMA20 = INVALID_HANDLE;
    m_HandleMA50 = INVALID_HANDLE;
    m_HandleMA200 = INVALID_HANDLE;
    
    m_CurrentSymbol = "";
    m_CurrentTimeframe = PERIOD_CURRENT;
    m_IsMainChart = false;
    
    m_SupportColor = clrGreen;
    m_ResistanceColor = clrRed;
    m_TrendLineColor = clrBlue;
    m_LineWidth = 1;
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CTL_HL_Math::~CTL_HL_Math()
{
    // Release indicator handles
    if(m_HandleRSI != INVALID_HANDLE) IndicatorRelease(m_HandleRSI);
    if(m_HandleStoch != INVALID_HANDLE) IndicatorRelease(m_HandleStoch);
    if(m_HandleWilliams != INVALID_HANDLE) IndicatorRelease(m_HandleWilliams);
    if(m_HandleMACD != INVALID_HANDLE) IndicatorRelease(m_HandleMACD);
    if(m_HandleMA20 != INVALID_HANDLE) IndicatorRelease(m_HandleMA20);
    if(m_HandleMA50 != INVALID_HANDLE) IndicatorRelease(m_HandleMA50);
    if(m_HandleMA200 != INVALID_HANDLE) IndicatorRelease(m_HandleMA200);
}

//+------------------------------------------------------------------+
//| Initialize the library                                          |
//+------------------------------------------------------------------+
bool CTL_HL_Math::Initialize()
{
    ArrayResize(m_TrendLines, 0);
    ArrayResize(m_HorizontalLevels, 0);
    ArrayResize(m_Oscillators, 1);
    ArrayResize(m_MACDData, 1);
    ArrayResize(m_CSMData, 8); // 8 major currencies
    
    return true;
}

//+------------------------------------------------------------------+
//| Setup chart with indicators                                      |
//+------------------------------------------------------------------+
bool CTL_HL_Math::SetupChart(string symbol, ENUM_TIMEFRAMES timeframe, bool isMainChart)
{
    m_CurrentSymbol = symbol;
    m_CurrentTimeframe = timeframe;
    m_IsMainChart = isMainChart;
    
    if(!ValidateSymbol(symbol))
    {
        Print("ERROR: Invalid symbol: ", symbol);
        return false;
    }
    
    // Create indicator handles
    m_HandleRSI = iRSI(symbol, timeframe, 14, PRICE_CLOSE);
    m_HandleStoch = iStochastic(symbol, timeframe, 5, 3, 3, MODE_SMA, STO_LOWHIGH);
    m_HandleWilliams = iWPR(symbol, timeframe, 14);
    m_HandleMACD = iMACD(symbol, timeframe, 12, 26, 9, PRICE_CLOSE);
    m_HandleMA20 = iMA(symbol, timeframe, 20, 0, MODE_SMA, PRICE_CLOSE);
    m_HandleMA50 = iMA(symbol, timeframe, 50, 0, MODE_SMA, PRICE_CLOSE);
    m_HandleMA200 = iMA(symbol, timeframe, 200, 0, MODE_SMA, PRICE_CLOSE);
    
    // Verify all handles are valid
    if(m_HandleRSI == INVALID_HANDLE || m_HandleStoch == INVALID_HANDLE || 
       m_HandleWilliams == INVALID_HANDLE || m_HandleMACD == INVALID_HANDLE ||
       m_HandleMA20 == INVALID_HANDLE || m_HandleMA50 == INVALID_HANDLE || 
       m_HandleMA200 == INVALID_HANDLE)
    {
        Print("ERROR: Failed to create indicator handles for ", symbol);
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Update technical analysis for symbol                            |
//+------------------------------------------------------------------+
bool CTL_HL_Math::UpdateTechnicalAnalysis(string symbol, ENUM_TIMEFRAMES timeframe)
{
    if(!ValidateSymbol(symbol)) return false;
    
    // Setup chart if different symbol
    if(symbol != m_CurrentSymbol || timeframe != m_CurrentTimeframe)
    {
        SetupChart(symbol, timeframe, false);
    }
    
    // Find trendlines and horizontal levels
    FindTrendLines(symbol, timeframe);
    FindHorizontalLevels(symbol, timeframe);
    
    // Update oscillators and MACD
    UpdateOscillators(symbol, timeframe);
    UpdateMACD(symbol, timeframe);
    
    // Update drawings if main chart
    if(m_IsMainChart && symbol == m_CurrentSymbol)
    {
        UpdateDrawings();
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Find trendlines                                                  |
//+------------------------------------------------------------------+
int CTL_HL_Math::FindTrendLines(string symbol, ENUM_TIMEFRAMES timeframe, int barsBack)
{
    ArrayResize(m_TrendLines, 0);
    
    if(barsBack > Bars(symbol, timeframe)) 
        barsBack = Bars(symbol, timeframe) - 10;
    
    // Find swing highs and lows
    double highs[];
    double lows[];
    datetime times[];
    
    ArrayResize(highs, barsBack);
    ArrayResize(lows, barsBack);
    ArrayResize(times, barsBack);
    
    // Get OHLC data
    for(int i = 0; i < barsBack; i++)
    {
        highs[i] = iHigh(symbol, timeframe, i + 1);
        lows[i] = iLow(symbol, timeframe, i + 1);
        times[i] = iTime(symbol, timeframe, i + 1);
    }
    
    // Find resistance trendlines (connecting highs)
    for(int i = 0; i < barsBack - 20; i++)
    {
        for(int j = i + 10; j < barsBack - 5; j++)
        {
            // Check if we have at least 2 points for a trendline
            if(IsSwingHigh(highs, i, 3) && IsSwingHigh(highs, j, 3))
            {
                TrendLineData trendLine;
                trendLine.startTime = times[j];
                trendLine.endTime = times[i];
                trendLine.startPrice = highs[j];
                trendLine.endPrice = highs[i];
                trendLine.isSupport = false;
                trendLine.touchCount = CountTrendLineTouches(highs, times, trendLine, true);
                trendLine.strength = trendLine.touchCount * 10; // Simple strength calculation
                trendLine.objectName = StringFormat("TL_R_%s_%d_%d", symbol, (int)trendLine.startTime, (int)trendLine.endTime);
                
                if(trendLine.touchCount >= 2)
                {
                    ArrayResize(m_TrendLines, ArraySize(m_TrendLines) + 1);
                    m_TrendLines[ArraySize(m_TrendLines) - 1] = trendLine;
                }
            }
        }
    }
    
    // Find support trendlines (connecting lows)
    for(int i = 0; i < barsBack - 20; i++)
    {
        for(int j = i + 10; j < barsBack - 5; j++)
        {
            if(IsSwingLow(lows, i, 3) && IsSwingLow(lows, j, 3))
            {
                TrendLineData trendLine;
                trendLine.startTime = times[j];
                trendLine.endTime = times[i];
                trendLine.startPrice = lows[j];
                trendLine.endPrice = lows[i];
                trendLine.isSupport = true;
                trendLine.touchCount = CountTrendLineTouches(lows, times, trendLine, false);
                trendLine.strength = trendLine.touchCount * 10;
                trendLine.objectName = StringFormat("TL_S_%s_%d_%d", symbol, (int)trendLine.startTime, (int)trendLine.endTime);
                
                if(trendLine.touchCount >= 2)
                {
                    ArrayResize(m_TrendLines, ArraySize(m_TrendLines) + 1);
                    m_TrendLines[ArraySize(m_TrendLines) - 1] = trendLine;
                }
            }
        }
    }
    
    return ArraySize(m_TrendLines);
}

//+------------------------------------------------------------------+
//| Find horizontal levels                                           |
//+------------------------------------------------------------------+
int CTL_HL_Math::FindHorizontalLevels(string symbol, ENUM_TIMEFRAMES timeframe, int barsBack)
{
    ArrayResize(m_HorizontalLevels, 0);
    
    if(barsBack > Bars(symbol, timeframe))
        barsBack = Bars(symbol, timeframe) - 10;
    
    double prices[];
    ArrayResize(prices, barsBack * 2); // For both highs and lows
    
    // Collect all significant highs and lows
    int priceCount = 0;
    for(int i = 5; i < barsBack - 5; i++)
    {
        double high = iHigh(symbol, timeframe, i);
        double low = iLow(symbol, timeframe, i);
        
        // Check for swing high
        bool isSwingHigh = true;
        for(int j = i - 3; j <= i + 3; j++)
        {
            if(j != i && iHigh(symbol, timeframe, j) > high)
            {
                isSwingHigh = false;
                break;
            }
        }
        
        if(isSwingHigh)
        {
            prices[priceCount] = high;
            priceCount++;
        }
        
        // Check for swing low
        bool isSwingLow = true;
        for(int j = i - 3; j <= i + 3; j++)
        {
            if(j != i && iLow(symbol, timeframe, j) < low)
            {
                isSwingLow = false;
                break;
            }
        }
        
        if(isSwingLow)
        {
            prices[priceCount] = low;
            priceCount++;
        }
    }
    
    // Find levels with multiple touches
    double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
    double tolerance = 10 * point; // 10 points tolerance
    
    for(int i = 0; i < priceCount; i++)
    {
        int touchCount = 1;
        double levelPrice = prices[i];
        
        // Count touches within tolerance
        for(int j = i + 1; j < priceCount; j++)
        {
            if(MathAbs(prices[j] - levelPrice) <= tolerance)
            {
                touchCount++;
                levelPrice = (levelPrice + prices[j]) / 2; // Average price
            }
        }
        
        // Create level if enough touches
        if(touchCount >= 3)
        {
            HorizontalLevelData level;
            level.price = levelPrice;
            level.isSupport = (levelPrice < iClose(symbol, timeframe, 1));
            level.touchCount = touchCount;
            level.strength = touchCount * 5;
            level.lastTouch = iTime(symbol, timeframe, 1);
            level.objectName = StringFormat("HL_%s_%s_%.5f", 
                                          symbol, 
                                          level.isSupport ? "S" : "R", 
                                          level.price);
            
            // Check if level doesn't already exist
            bool exists = false;
            for(int k = 0; k < ArraySize(m_HorizontalLevels); k++)
            {
                if(MathAbs(m_HorizontalLevels[k].price - level.price) <= tolerance)
                {
                    exists = true;
                    break;
                }
            }
            
            if(!exists)
            {
                ArrayResize(m_HorizontalLevels, ArraySize(m_HorizontalLevels) + 1);
                m_HorizontalLevels[ArraySize(m_HorizontalLevels) - 1] = level;
            }
        }
    }
    
    return ArraySize(m_HorizontalLevels);
}

//+------------------------------------------------------------------+
//| Update oscillators                                               |
//+------------------------------------------------------------------+
bool CTL_HL_Math::UpdateOscillators(string symbol, ENUM_TIMEFRAMES timeframe)
{
    if(m_HandleRSI == INVALID_HANDLE || m_HandleStoch == INVALID_HANDLE || 
       m_HandleWilliams == INVALID_HANDLE)
        return false;
    
    double rsiBuffer[3];
    double stochMain[3], stochSignal[3];
    double williamsBuffer[3];
    
    // Get RSI values
    if(CopyBuffer(m_HandleRSI, 0, 0, 3, rsiBuffer) != 3) return false;
    
    // Get Stochastic values
    if(CopyBuffer(m_HandleStoch, 0, 0, 3, stochMain) != 3) return false;
    if(CopyBuffer(m_HandleStoch, 1, 0, 3, stochSignal) != 3) return false;
    
    // Get Williams %R values
    if(CopyBuffer(m_HandleWilliams, 0, 0, 3, williamsBuffer) != 3) return false;
    
    // Update oscillator data
    m_Oscillators[0].rsi = rsiBuffer[2];
    m_Oscillators[0].stochastic = stochMain[2];
    m_Oscillators[0].williams = williamsBuffer[2];
    
    // Determine conditions
    m_Oscillators[0].overbought = (rsiBuffer[2] > 70 || stochMain[2] > 80 || williamsBuffer[2] > -20);
    m_Oscillators[0].oversold = (rsiBuffer[2] < 30 || stochMain[2] < 20 || williamsBuffer[2] < -80);
    
    // Check for divergences (simplified)
    m_Oscillators[0].divergence = HasBullishDivergence(symbol, timeframe) || HasBearishDivergence(symbol, timeframe);
    
    return true;
}

//+------------------------------------------------------------------+
//| Update MACD                                                      |
//+------------------------------------------------------------------+
bool CTL_HL_Math::UpdateMACD(string symbol, ENUM_TIMEFRAMES timeframe)
{
    if(m_HandleMACD == INVALID_HANDLE) return false;
    
    double macdMain[3], macdSignal[3];
    
    if(CopyBuffer(m_HandleMACD, 0, 0, 3, macdMain) != 3) return false;
    if(CopyBuffer(m_HandleMACD, 1, 0, 3, macdSignal) != 3) return false;
    
    m_MACDData[0].main = macdMain[2];
    m_MACDData[0].signal = macdSignal[2];
    m_MACDData[0].histogram = macdMain[2] - macdSignal[2];
    
    // Check for crossovers
    m_MACDData[0].bullishCrossover = (macdMain[1] <= macdSignal[1] && macdMain[2] > macdSignal[2]);
    m_MACDData[0].bearishCrossover = (macdMain[1] >= macdSignal[1] && macdMain[2] < macdSignal[2]);
    
    return true;
}

//+------------------------------------------------------------------+
//| Get oscillator data                                              |
//+------------------------------------------------------------------+
OscillatorData CTL_HL_Math::GetOscillatorData()
{
    if(ArraySize(m_Oscillators) > 0)
        return m_Oscillators[0];
    
    OscillatorData empty;
    empty.rsi = 50;
    empty.stochastic = 50;
    empty.williams = -50;
    empty.oversold = false;
    empty.overbought = false;
    empty.divergence = false;
    return empty;
}

//+------------------------------------------------------------------+
//| Get MACD data                                                    |
//+------------------------------------------------------------------+
MACDData CTL_HL_Math::GetMACDData()
{
    if(ArraySize(m_MACDData) > 0)
        return m_MACDData[0];
    
    MACDData empty;
    empty.main = 0;
    empty.signal = 0;
    empty.histogram = 0;
    empty.bullishCrossover = false;
    empty.bearishCrossover = false;
    empty.divergence = false;
    return empty;
}

//+------------------------------------------------------------------+
//| Get trendline count                                              |
//+------------------------------------------------------------------+
int CTL_HL_Math::GetTrendLineCount(bool supportOnly, bool resistanceOnly)
{
    if(!supportOnly && !resistanceOnly)
        return ArraySize(m_TrendLines);
    
    int count = 0;
    for(int i = 0; i < ArraySize(m_TrendLines); i++)
    {
        if(supportOnly && m_TrendLines[i].isSupport) count++;
        if(resistanceOnly && !m_TrendLines[i].isSupport) count++;
    }
    return count;
}

//+------------------------------------------------------------------+
//| Get trendline by index                                           |
//+------------------------------------------------------------------+
TrendLineData CTL_HL_Math::GetTrendLine(int index)
{
    if(index >= 0 && index < ArraySize(m_TrendLines))
        return m_TrendLines[index];
    
    TrendLineData empty;
    empty.startTime = 0;
    empty.endTime = 0;
    empty.startPrice = 0;
    empty.endPrice = 0;
    empty.isSupport = true;
    empty.strength = 0;
    empty.touchCount = 0;
    empty.objectName = "";
    return empty;
}

//+------------------------------------------------------------------+
//| Get horizontal level count                                       |
//+------------------------------------------------------------------+
int CTL_HL_Math::GetHorizontalLevelCount(bool supportOnly, bool resistanceOnly)
{
    if(!supportOnly && !resistanceOnly)
        return ArraySize(m_HorizontalLevels);
    
    int count = 0;
    for(int i = 0; i < ArraySize(m_HorizontalLevels); i++)
    {
        if(supportOnly && m_HorizontalLevels[i].isSupport) count++;
        if(resistanceOnly && !m_HorizontalLevels[i].isSupport) count++;
    }
    return count;
}

//+------------------------------------------------------------------+
//| Get horizontal level by index                                    |
//+------------------------------------------------------------------+
HorizontalLevelData CTL_HL_Math::GetHorizontalLevel(int index)
{
    if(index >= 0 && index < ArraySize(m_HorizontalLevels))
        return m_HorizontalLevels[index];
    
    HorizontalLevelData empty;
    empty.price = 0;
    empty.isSupport = true;
    empty.strength = 0;
    empty.touchCount = 0;
    empty.lastTouch = 0;
    empty.objectName = "";
    return empty;
}

//+------------------------------------------------------------------+
//| Check if trendline is valid                                      |
//+------------------------------------------------------------------+
bool CTL_HL_Math::IsTrendLineValid(TrendLineData &trendLine, datetime currentTime, double currentPrice)
{
    // Basic validation
    if(trendLine.touchCount < 2) return false;
    if(trendLine.startTime >= trendLine.endTime) return false;
    
    // Check if trendline is still relevant (not too old)
    datetime maxAge = 30 * 24 * 3600; // 30 days
    if(currentTime - trendLine.endTime > maxAge) return false;
    
    // Check if price is reasonably close to trendline
    double trendLinePrice = GetTrendLinePrice(trendLine, currentTime);
    double maxDeviation = CalculateATR(m_CurrentSymbol, m_CurrentTimeframe) * 5; // 5 ATR max deviation
    
    if(MathAbs(currentPrice - trendLinePrice) > maxDeviation) return false;
    
    return true;
}

//+------------------------------------------------------------------+
//| Get trendline price at current time                             |
//+------------------------------------------------------------------+
double CTL_HL_Math::GetTrendLinePrice(TrendLineData &trendLine, datetime time)
{
    return GetTrendLinePriceAtTime(trendLine, time);
}

//+------------------------------------------------------------------+
//| Check if price is near level                                     |
//+------------------------------------------------------------------+
bool CTL_HL_Math::IsPriceNearLevel(double price, double level, double tolerance)
{
    return MathAbs(price - level) <= tolerance;
}

//+------------------------------------------------------------------+
//| Check for bullish engulfing pattern                             |
//+------------------------------------------------------------------+
bool CTL_HL_Math::IsBullishEngulfing(string symbol, ENUM_TIMEFRAMES timeframe, int barIndex)
{
    double open1 = iOpen(symbol, timeframe, barIndex);
    double close1 = iClose(symbol, timeframe, barIndex);
    double open2 = iOpen(symbol, timeframe, barIndex + 1);
    double close2 = iClose(symbol, timeframe, barIndex + 1);
    
    // Previous candle is bearish, current is bullish and engulfs previous
    return (close2 < open2) && (close1 > open1) && 
           (open1 < close2) && (close1 > open2);
}

//+------------------------------------------------------------------+
//| Check for bearish engulfing pattern                             |
//+------------------------------------------------------------------+
bool CTL_HL_Math::IsBearishEngulfing(string symbol, ENUM_TIMEFRAMES timeframe, int barIndex)
{
    double open1 = iOpen(symbol, timeframe, barIndex);
    double close1 = iClose(symbol, timeframe, barIndex);
    double open2 = iOpen(symbol, timeframe, barIndex + 1);
    double close2 = iClose(symbol, timeframe, barIndex + 1);
    
    // Previous candle is bullish, current is bearish and engulfs previous
    return (close2 > open2) && (close1 < open1) && 
           (open1 > close2) && (close1 < open2);
}

//+------------------------------------------------------------------+
//| Check for hammer pattern                                         |
//+------------------------------------------------------------------+
bool CTL_HL_Math::IsHammer(string symbol, ENUM_TIMEFRAMES timeframe, int barIndex)
{
    double open = iOpen(symbol, timeframe, barIndex);
    double close = iClose(symbol, timeframe, barIndex);
    double high = iHigh(symbol, timeframe, barIndex);
    double low = iLow(symbol, timeframe, barIndex);
    
    double bodySize = MathAbs(close - open);
    double lowerShadow = MathMin(open, close) - low;
    double upperShadow = high - MathMax(open, close);
    
    // Hammer: small body, long lower shadow, small upper shadow
    return (lowerShadow > bodySize * 2) && (upperShadow < bodySize * 0.5) && (bodySize > 0);
}

//+------------------------------------------------------------------+
//| Check for shooting star pattern                                  |
//+------------------------------------------------------------------+
bool CTL_HL_Math::IsShootingStar(string symbol, ENUM_TIMEFRAMES timeframe, int barIndex)
{
    double open = iOpen(symbol, timeframe, barIndex);
    double close = iClose(symbol, timeframe, barIndex);
    double high = iHigh(symbol, timeframe, barIndex);
    double low = iLow(symbol, timeframe, barIndex);
    
    double bodySize = MathAbs(close - open);
    double lowerShadow = MathMin(open, close) - low;
    double upperShadow = high - MathMax(open, close);
    
    // Shooting star: small body, long upper shadow, small lower shadow
    return (upperShadow > bodySize * 2) && (lowerShadow < bodySize * 0.5) && (bodySize > 0);
}

//+------------------------------------------------------------------+
//| Check for doji pattern                                           |
//+------------------------------------------------------------------+
bool CTL_HL_Math::IsDoji(string symbol, ENUM_TIMEFRAMES timeframe, int barIndex)
{
    double open = iOpen(symbol, timeframe, barIndex);
    double close = iClose(symbol, timeframe, barIndex);
    double high = iHigh(symbol, timeframe, barIndex);
    double low = iLow(symbol, timeframe, barIndex);
    
    double bodySize = MathAbs(close - open);
    double totalRange = high - low;
    
    // Doji: very small body relative to total range
    return (bodySize < totalRange * 0.1) && (totalRange > 0);
}

//+------------------------------------------------------------------+
//| Check for bullish divergence                                     |
//+------------------------------------------------------------------+
bool CTL_HL_Math::HasBullishDivergence(string symbol, ENUM_TIMEFRAMES timeframe, int barsBack)
{
    // Simplified divergence detection
    // In a real implementation, this would be more sophisticated
    
    if(m_HandleRSI == INVALID_HANDLE) return false;
    
    double rsi[];
    if(CopyBuffer(m_HandleRSI, 0, 0, barsBack, rsi) != barsBack) return false;
    
    // Find recent lows in price and RSI
    double priceLow1 = iLow(symbol, timeframe, 2);
    double priceLow2 = iLow(symbol, timeframe, barsBack - 2);
    double rsiLow1 = rsi[ArraySize(rsi) - 3];
    double rsiLow2 = rsi[1];
    
    // Bullish divergence: price makes lower low, RSI makes higher low
    return (priceLow1 < priceLow2) && (rsiLow1 > rsiLow2);
}

//+------------------------------------------------------------------+
//| Check for bearish divergence                                     |
//+------------------------------------------------------------------+
bool CTL_HL_Math::HasBearishDivergence(string symbol, ENUM_TIMEFRAMES timeframe, int barsBack)
{
    // Simplified divergence detection
    if(m_HandleRSI == INVALID_HANDLE) return false;
    
    double rsi[];
    if(CopyBuffer(m_HandleRSI, 0, 0, barsBack, rsi) != barsBack) return false;
    
    // Find recent highs in price and RSI
    double priceHigh1 = iHigh(symbol, timeframe, 2);
    double priceHigh2 = iHigh(symbol, timeframe, barsBack - 2);
    double rsiHigh1 = rsi[ArraySize(rsi) - 3];
    double rsiHigh2 = rsi[1];
    
    // Bearish divergence: price makes higher high, RSI makes lower high
    return (priceHigh1 > priceHigh2) && (rsiHigh1 < rsiHigh2);
}

//+------------------------------------------------------------------+
//| Calculate ATR                                                    |
//+------------------------------------------------------------------+
double CTL_HL_Math::CalculateATR(string symbol, ENUM_TIMEFRAMES timeframe, int period)
{
    int handle = iATR(symbol, timeframe, period);
    if(handle == INVALID_HANDLE) return 0;
    
    double atr[];
    if(CopyBuffer(handle, 0, 0, 1, atr) != 1)
    {
        IndicatorRelease(handle);
        return 0;
    }
    
    double result = atr[0];
    IndicatorRelease(handle);
    return result;
}

//+------------------------------------------------------------------+
//| Get nearest support level                                        |
//+------------------------------------------------------------------+
double CTL_HL_Math::GetNearestSupportLevel(double currentPrice)
{
    double nearestSupport = 0;
    double minDistance = DBL_MAX;
    
    for(int i = 0; i < ArraySize(m_HorizontalLevels); i++)
    {
        if(m_HorizontalLevels[i].isSupport && m_HorizontalLevels[i].price < currentPrice)
        {
            double distance = currentPrice - m_HorizontalLevels[i].price;
            if(distance < minDistance)
            {
                minDistance = distance;
                nearestSupport = m_HorizontalLevels[i].price;
            }
        }
    }
    
    return nearestSupport;
}

//+------------------------------------------------------------------+
//| Get nearest resistance level                                     |
//+------------------------------------------------------------------+
double CTL_HL_Math::GetNearestResistanceLevel(double currentPrice)
{
    double nearestResistance = 0;
    double minDistance = DBL_MAX;
    
    for(int i = 0; i < ArraySize(m_HorizontalLevels); i++)
    {
        if(!m_HorizontalLevels[i].isSupport && m_HorizontalLevels[i].price > currentPrice)
        {
            double distance = m_HorizontalLevels[i].price - currentPrice;
            if(distance < minDistance)
            {
                minDistance = distance;
                nearestResistance = m_HorizontalLevels[i].price;
            }
        }
    }
    
    return nearestResistance;
}

//+------------------------------------------------------------------+
//| Draw trendline                                                   |
//+------------------------------------------------------------------+
void CTL_HL_Math::DrawTrendLine(TrendLineData &trendLine)
{
    if(!m_IsMainChart) return;
    
    ObjectDelete(0, trendLine.objectName);
    
    if(ObjectCreate(0, trendLine.objectName, OBJ_TREND, 0, 
                   trendLine.startTime, trendLine.startPrice,
                   trendLine.endTime, trendLine.endPrice))
    {
        ObjectSetInteger(0, trendLine.objectName, OBJPROP_COLOR, m_TrendLineColor);
        ObjectSetInteger(0, trendLine.objectName, OBJPROP_WIDTH, m_LineWidth);
        ObjectSetInteger(0, trendLine.objectName, OBJPROP_RAY_RIGHT, true);
        ObjectSetInteger(0, trendLine.objectName, OBJPROP_SELECTABLE, false);
        ObjectSetString(0, trendLine.objectName, OBJPROP_TOOLTIP, 
                       StringFormat("TrendLine - Touches: %d, Strength: %.1f", 
                                   trendLine.touchCount, trendLine.strength));
    }
}

//+------------------------------------------------------------------+
//| Draw horizontal level                                            |
//+------------------------------------------------------------------+
void CTL_HL_Math::DrawHorizontalLevel(HorizontalLevelData &level)
{
    if(!m_IsMainChart) return;
    
    ObjectDelete(0, level.objectName);
    
    if(ObjectCreate(0, level.objectName, OBJ_HLINE, 0, 0, level.price))
    {
        color lineColor = level.isSupport ? m_SupportColor : m_ResistanceColor;
        ObjectSetInteger(0, level.objectName, OBJPROP_COLOR, lineColor);
        ObjectSetInteger(0, level.objectName, OBJPROP_WIDTH, m_LineWidth);
        ObjectSetInteger(0, level.objectName, OBJPROP_SELECTABLE, false);
        ObjectSetString(0, level.objectName, OBJPROP_TOOLTIP,
                       StringFormat("%s Level - Touches: %d, Strength: %.1f",
                                   level.isSupport ? "Support" : "Resistance",
                                   level.touchCount, level.strength));
    }
}

//+------------------------------------------------------------------+
//| Update drawings                                                  |
//+------------------------------------------------------------------+
void CTL_HL_Math::UpdateDrawings()
{
    if(!m_IsMainChart) return;
    
    // Draw all trendlines
    for(int i = 0; i < ArraySize(m_TrendLines); i++)
    {
        DrawTrendLine(m_TrendLines[i]);
    }
    
    // Draw all horizontal levels
    for(int i = 0; i < ArraySize(m_HorizontalLevels); i++)
    {
        DrawHorizontalLevel(m_HorizontalLevels[i]);
    }
}

//+------------------------------------------------------------------+
//| Remaining methods implementation continues...                    |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Normalize price                                                  |
//+------------------------------------------------------------------+
double CTL_HL_Math::NormalizePrice(double price, string symbol)
{
    int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
    return NormalizeDouble(price, digits);
}

//+------------------------------------------------------------------+
//| Check if new bar                                                 |
//+------------------------------------------------------------------+
bool CTL_HL_Math::IsNewBar(string symbol, ENUM_TIMEFRAMES timeframe)
{
    static datetime lastBarTime = 0;
    datetime currentBarTime = iTime(symbol, timeframe, 0);
    
    if(currentBarTime != lastBarTime)
    {
        lastBarTime = currentBarTime;
        return true;
    }
    return false;
}

//+------------------------------------------------------------------+
//| Validate timeframe                                               |
//+------------------------------------------------------------------+
bool CTL_HL_Math::ValidateTimeframe(ENUM_TIMEFRAMES timeframe)
{
    return (timeframe == PERIOD_M1 || timeframe == PERIOD_M5 || 
            timeframe == PERIOD_M15 || timeframe == PERIOD_M30 ||
            timeframe == PERIOD_H1 || timeframe == PERIOD_H4 ||
            timeframe == PERIOD_D1 || timeframe == PERIOD_W1 ||
            timeframe == PERIOD_MN1);
}

//+------------------------------------------------------------------+
//| Clear all drawings                                               |
//+------------------------------------------------------------------+
void CTL_HL_Math::ClearDrawings()
{
    if(!m_IsMainChart) return;
    
    // Remove all objects created by this library
    int objectsTotal = ObjectsTotal(0);
    for(int i = objectsTotal - 1; i >= 0; i--)
    {
        string objName = ObjectName(0, i);
        if(StringFind(objName, "TL_") >= 0 || StringFind(objName, "HL_") >= 0)
        {
            ObjectDelete(0, objName);
        }
    }
}

//+------------------------------------------------------------------+
//| Calculate CSM for multiple pairs                                 |
//+------------------------------------------------------------------+
void CTL_HL_Math::CalculateCSM(string pairs[], int pairsCount, int lookback)
{
    // Initialize currency data
    string currencies[] = {"EUR", "USD", "GBP", "JPY", "AUD", "CAD", "CHF", "NZD"};
    
    for(int i = 0; i < 8; i++)
    {
        m_CSMData[i].currency = currencies[i];
        m_CSMData[i].strength = 0.0;
        m_CSMData[i].rank = 0;
    }
    
    // Calculate strength for each currency
    for(int i = 0; i < pairsCount; i++)
    {
        string symbol = pairs[i];
        
        // Get currency codes
        string baseCurrency = StringSubstr(symbol, 0, 3);
        string quoteCurrency = StringSubstr(symbol, 3, 3);
        
        // Calculate price change over lookback period
        double currentPrice = SymbolInfoDouble(symbol, SYMBOL_BID);
        double pastPrice = iClose(symbol, PERIOD_H1, lookback);
        
        if(currentPrice > 0 && pastPrice > 0)
        {
            double percentChange = ((currentPrice - pastPrice) / pastPrice) * 100;
            
            // Update currencies strength
            for(int j = 0; j < 8; j++)
            {
                if(m_CSMData[j].currency == baseCurrency)
                    m_CSMData[j].strength += percentChange;
                if(m_CSMData[j].currency == quoteCurrency)
                    m_CSMData[j].strength -= percentChange;
            }
        }
    }
    
    // Sort and rank currencies
    SortCSMData();
}

//+------------------------------------------------------------------+
//| Sort CSM data by strength                                        |
//+------------------------------------------------------------------+
void CTL_HL_Math::SortCSMData()
{
    // Simple bubble sort
    for(int i = 0; i < 7; i++)
    {
        for(int j = i + 1; j < 8; j++)
        {
            if(m_CSMData[j].strength > m_CSMData[i].strength)
            {
                CSMCurrencyData temp = m_CSMData[i];
                m_CSMData[i] = m_CSMData[j];
                m_CSMData[j] = temp;
            }
        }
    }
    
    // Assign ranks
    for(int i = 0; i < 8; i++)
    {
        m_CSMData[i].rank = i + 1;
    }
}

//+------------------------------------------------------------------+
//| Get strongest currency                                           |
//+------------------------------------------------------------------+
CSMCurrencyData CTL_HL_Math::GetStrongestCurrency()
{
    if(ArraySize(m_CSMData) > 0)
        return m_CSMData[0];
    
    CSMCurrencyData empty;
    empty.currency = "";
    empty.strength = 0;
    empty.rank = 0;
    return empty;
}

//+------------------------------------------------------------------+
//| Get weakest currency                                             |
//+------------------------------------------------------------------+
CSMCurrencyData CTL_HL_Math::GetWeakestCurrency()
{
    if(ArraySize(m_CSMData) >= 8)
        return m_CSMData[7];
    
    CSMCurrencyData empty;
    empty.currency = "";
    empty.strength = 0;
    empty.rank = 0;
    return empty;
}

//+------------------------------------------------------------------+
//| Get CSM rankings as string                                       |
//+------------------------------------------------------------------+
string CTL_HL_Math::GetCSMRankings()
{
    string rankings = "CSM Rankings: ";
    for(int i = 0; i < 8; i++)
    {
        rankings += StringFormat("%s(%.2f) ", m_CSMData[i].currency, m_CSMData[i].strength);
    }
    return rankings;
}

//+------------------------------------------------------------------+
//| Calculate individual currency strength                           |
//+------------------------------------------------------------------+
double CTL_HL_Math::CalculateCurrencyStrength(string currency, string pairs[], int pairsCount, int lookback)
{
    double totalStrength = 0.0;
    int pairCount = 0;
    
    for(int i = 0; i < pairsCount; i++)
    {
        string symbol = pairs[i];
        string baseCurrency = StringSubstr(symbol, 0, 3);
        string quoteCurrency = StringSubstr(symbol, 3, 3);
        
        if(baseCurrency == currency || quoteCurrency == currency)
        {
            double currentPrice = SymbolInfoDouble(symbol, SYMBOL_BID);
            double pastPrice = iClose(symbol, PERIOD_H1, lookback);
            
            if(currentPrice > 0 && pastPrice > 0)
            {
                double percentChange = ((currentPrice - pastPrice) / pastPrice) * 100;
                
                if(baseCurrency == currency)
                    totalStrength += percentChange;
                else
                    totalStrength -= percentChange;
                
                pairCount++;
            }
        }
    }
    
    return (pairCount > 0) ? (totalStrength / pairCount) : 0.0;
}

//+------------------------------------------------------------------+
//| Calculate level strength                                          |
//+------------------------------------------------------------------+
double CTL_HL_Math::CalculateLevelStrength(double level, string symbol, ENUM_TIMEFRAMES timeframe, int barsBack)
{
    double strength = 0.0;
    double tolerance = 10 * SymbolInfoDouble(symbol, SYMBOL_POINT);
    
    // Count touches and calculate strength based on multiple factors
    for(int i = 1; i <= barsBack; i++)
    {
        double high = iHigh(symbol, timeframe, i);
        double low = iLow(symbol, timeframe, i);
        
        // Check if this bar touched the level
        if((low <= level + tolerance && low >= level - tolerance) ||
           (high <= level + tolerance && high >= level - tolerance))
        {
            strength += 1.0;
            
            // Bonus for strong rejection (long wick)
            double open = iOpen(symbol, timeframe, i);
            double close = iClose(symbol, timeframe, i);
            double bodySize = MathAbs(close - open);
            double totalRange = high - low;
            
            if(totalRange > bodySize * 2)
                strength += 0.5; // Bonus for rejection
        }
    }
    
    return strength;
}

//+------------------------------------------------------------------+
//| Check overbought condition                                       |
//+------------------------------------------------------------------+
bool CTL_HL_Math::IsOverboughtCondition()
{
    if(ArraySize(m_Oscillators) > 0)
        return m_Oscillators[0].overbought;
    return false;
}

//+------------------------------------------------------------------+
//| Check oversold condition                                         |
//+------------------------------------------------------------------+
bool CTL_HL_Math::IsOversoldCondition()
{
    if(ArraySize(m_Oscillators) > 0)
        return m_Oscillators[0].oversold;
    return false;
}

//+------------------------------------------------------------------+
//| Check MACD bullish crossover                                     |
//+------------------------------------------------------------------+
bool CTL_HL_Math::IsMACDBullishCrossover()
{
    if(ArraySize(m_MACDData) > 0)
        return m_MACDData[0].bullishCrossover;
    return false;
}

//+------------------------------------------------------------------+
//| Check MACD bearish crossover                                     |
//+------------------------------------------------------------------+
bool CTL_HL_Math::IsMACDBearishCrossover()
{
    if(ArraySize(m_MACDData) > 0)
        return m_MACDData[0].bearishCrossover;
    return false;
}

//+------------------------------------------------------------------+
//| Check if horizontal level is valid                               |
//+------------------------------------------------------------------+
bool CTL_HL_Math::IsHorizontalLevelValid(HorizontalLevelData &level, double currentPrice, double tolerance)
{
    // Check if level is still relevant
    if(level.touchCount < 2) return false;
    
    // Check age of level
    datetime maxAge = 60 * 24 * 3600; // 60 days
    if(TimeCurrent() - level.lastTouch > maxAge) return false;
    
    // Check if current price is not too far from level
    double maxDistance = tolerance * 10;
    if(MathAbs(currentPrice - level.price) > maxDistance) return false;
    
    return true;
}

//+------------------------------------------------------------------+
//| Validate symbol                                                  |
//+------------------------------------------------------------------+
bool CTL_HL_Math::ValidateSymbol(string symbol)
{
    return SymbolInfoInteger(symbol, SYMBOL_SELECT);
}

//+------------------------------------------------------------------+
//| Calculate pip value                                              |
//+------------------------------------------------------------------+
double CTL_HL_Math::CalculatePipValue(string symbol)
{
    double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
    double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
    double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
    
    return tickValue * (point * 10) / tickSize;
}

//+------------------------------------------------------------------+
//| Helper function to check swing high                             |
//+------------------------------------------------------------------+
bool IsSwingHigh(double &highs[], int index, int period)
{
    if(index < period || index >= ArraySize(highs) - period)
        return false;
    
    for(int i = index - period; i <= index + period; i++)
    {
        if(i != index && highs[i] > highs[index])
            return false;
    }
    return true;
}

//+------------------------------------------------------------------+
//| Helper function to check swing low                              |
//+------------------------------------------------------------------+
bool IsSwingLow(double &lows[], int index, int period)
{
    if(index < period || index >= ArraySize(lows) - period)
        return false;
    
    for(int i = index - period; i <= index + period; i++)
    {
        if(i != index && lows[i] < lows[index])
            return false;
    }
    return true;
}

//+------------------------------------------------------------------+
//| Count trendline touches                                          |
//+------------------------------------------------------------------+
int CountTrendLineTouches(double &prices[], datetime &times[], TrendLineData &trendLine, bool isResistance)
{
    int touches = 2; // Start with 2 (the original points)
    double tolerance = 10 * SymbolInfoDouble(Symbol(), SYMBOL_POINT);
    
    for(int i = 0; i < ArraySize(prices); i++)
    {
        if(times[i] >= trendLine.startTime && times[i] <= trendLine.endTime)
        {
            double trendLinePrice = GetTrendLinePriceAtTime(trendLine, times[i]);
            if(MathAbs(prices[i] - trendLinePrice) <= tolerance)
            {
                touches++;
            }
        }
    }
    
    return touches;
}

//+------------------------------------------------------------------+
//| Get trendline price at specific time                            |
//+------------------------------------------------------------------+
double GetTrendLinePriceAtTime(TrendLineData &trendLine, datetime time)
{
    if(trendLine.startTime == trendLine.endTime)
        return trendLine.startPrice;
    
    double timeDiff = (double)(time - trendLine.startTime);
    double totalTimeDiff = (double)(trendLine.endTime - trendLine.startTime);
    double priceDiff = trendLine.endPrice - trendLine.startPrice;
    
    return trendLine.startPrice + (priceDiff * timeDiff / totalTimeDiff);
}

//+------------------------------------------------------------------+