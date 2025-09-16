//+------------------------------------------------------------------+
//|                                                 TL_HL_Math.mqh |
//|                                                    JcampFx Team |
//|                                 Technical Analysis Math Library |
//+------------------------------------------------------------------+
#property copyright "JcampFx Team"
#property link      ""
#property version   "1.00"

// Structure definitions must come first
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
//| Count trendline touches                                          |
//+------------------------------------------------------------------+
int CountTrendLineTouches(double &prices[], datetime &times[],
                          TrendLineData &trendLine, bool isResistance, double tolerance)
{
    int touches = 2; // anchors
    int n = ArraySize(prices);
    for(int i = 0; i < n; i++)
    {
        if(times[i] >= trendLine.startTime && times[i] <= trendLine.endTime)
        {
            double tlPrice = GetTrendLinePriceAtTime(trendLine, times[i]);
            if(MathAbs(prices[i] - tlPrice) <= tolerance)
                touches++;
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
// Pip size across 2/3/4/5-digit symbols
double JCT_PipSizeLocal(const string symbol)
{
   int    digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   double point  = SymbolInfoDouble(symbol, SYMBOL_POINT);
   return (digits == 3 || digits == 5) ? (point * 10.0) : point;
}

// Relative slope (price per second); guard zero span
double JCT_TL_Slope(const TrendLineData &tl)
{
   double dt = (double)(tl.endTime - tl.startTime);
   if(dt == 0.0) return 0.0;
   return (tl.endPrice - tl.startPrice) / dt;
}

// Lines considered similar if slope nearly equal AND price near at recent anchor
bool JCT_IsSimilarTL(TrendLineData &a, TrendLineData &b,
                     double pip, double slopePctTol, double priceTolPips)
{
   double sa = JCT_TL_Slope(a);
   double sb = JCT_TL_Slope(b);
   double denom = MathMax(MathAbs(sa), MathAbs(sb));
   double rel   = (denom > 0.0) ? MathAbs(sa - sb) / denom : 0.0;

   // Compare price at the newer end (align at b.endTime)
   double pa = GetTrendLinePriceAtTime(a, b.endTime);
   double pb = GetTrendLinePriceAtTime(b, b.endTime);
   bool priceClose = (MathAbs(pa - pb) <= priceTolPips * pip);

   return (rel * 100.0 <= slopePctTol) && priceClose;
}

// Sort by strength (touchCount), then recency (endTime)
void JCT_SortTLByStrengthRecency(TrendLineData &arr[])
{
   int n = ArraySize(arr);
   for(int i=0;i<n-1;i++)
   for(int j=i+1;j<n;j++)
   {
      bool better = (arr[j].touchCount > arr[i].touchCount) ||
                    (arr[j].touchCount == arr[i].touchCount && arr[j].endTime > arr[i].endTime);
      if(better)
      {
         TrendLineData t = arr[i];
         arr[i] = arr[j];
         arr[j] = t;
      }
   }
}

// Keep only top N per side; rewrite arr
void JCT_TrimTrendLines(TrendLineData &arr[], int maxPerSide)
{
   if(maxPerSide <= 0) return;

   TrendLineData sup[]; ArrayResize(sup,0);
   TrendLineData res[]; ArrayResize(res,0);

   for(int i=0;i<ArraySize(arr);i++)
   {
      if(arr[i].isSupport) { int s=ArraySize(sup); ArrayResize(sup,s+1); sup[s]=arr[i]; }
      else                 { int r=ArraySize(res); ArrayResize(res,r+1); res[r]=arr[i]; }
   }

   JCT_SortTLByStrengthRecency(sup);
   JCT_SortTLByStrengthRecency(res);
   int keepS = MathMin(ArraySize(sup), maxPerSide);
   int keepR = MathMin(ArraySize(res), maxPerSide);

   ArrayResize(arr, 0);
   for(int i=0;i<keepR;i++){ int k=ArraySize(arr); ArrayResize(arr,k+1); arr[k]=res[i]; }
   for(int i=0;i<keepS;i++){ int k=ArraySize(arr); ArrayResize(arr,k+1); arr[k]=sup[i]; }
}


// ==== [JCT SR/TL Draw Limits & Helpers] ====

// Use constants here (not 'input') because this file is an include.
#define JCT_MAX_SR_OBJECTS   60   // total TL + HL with our prefix
#define JCT_MAX_TL_OBJECTS   30   // cap for trendlines
#define JCT_MAX_HL_OBJECTS   30   // cap for horizontals
#define JCT_SR_BARS_BACK   2000   // ignore anchors older than this (bars)

// Sanitize symbol for object names (handles OANDA suffixes like ".sml")
string JCT_NormalizeSymbol(string sym)
{
   string s = sym;
   // StringReplace modifies in place and returns INT (count of replacements),
   // so DO NOT assign its return value to 's'.
   StringReplace(s, ".", "_");
   StringReplace(s, " ", "_");
   StringReplace(s, "/", "_");
   StringReplace(s, ":", "_");
   StringReplace(s, "\\", "_");
   return s;
}

// Unique prefix per (symbol, timeframe, moduleTag)
string JCT_DrawPrefix(const string symbol, ENUM_TIMEFRAMES tf, const string moduleTag) {
   return StringFormat("JCT_%s_%s_%s_", JCT_NormalizeSymbol(symbol), EnumToString(tf), moduleTag);
}

// Collect all object names with prefix
int JCT_CountObjectsWithPrefix(const string prefix, string &names[]) {
   ArrayResize(names, 0);
   const int total = ObjectsTotal(0, -1, -1);
   for(int i=0; i<total; i++) {
      string n = ObjectName(0, i);
      if(StringFind(n, prefix, 0) == 0) {
         const int sz = ArraySize(names);
         ArrayResize(names, sz+1);
         names[sz] = n;
      }
   }
   return ArraySize(names);
}

// Extract running index at the tail: prefix + "TL_" or "HL_" + 000123
int JCT_ExtractIndex(const string name, const string prefixPlusTag) {
   if(StringFind(name, prefixPlusTag, 0) != 0) return -1;
   string tail = StringSubstr(name, StringLen(prefixPlusTag)); // expect "000123"
   return (int)StringToInteger(tail);
}
// ---- TRENDLINE (OBJ_TREND) with reuse/cap ----
bool JCT_DrawTrendlineCapped(
   const string symbol,
   const ENUM_TIMEFRAMES tf,
   const string moduleTag,
   const datetime t1, const double p1,
   const datetime t2, const double p2,
   const color clr, const int style = STYLE_SOLID, const int width = 1,
   const bool ray = true
){
   // Ignore very old anchors to avoid clutter
   int b1 = iBarShift(symbol, tf, t1, true);
   int b2 = iBarShift(symbol, tf, t2, true);
   if(b1 < 0 || b2 < 0) return false;
   if(b1 > JCT_SR_BARS_BACK || b2 > JCT_SR_BARS_BACK) return false;

   const string prefix = JCT_DrawPrefix(symbol, tf, moduleTag);
   const string tagTL  = "TL_";
   string all[];  JCT_CountObjectsWithPrefix(prefix, all);

   // collect TL only
   string tls[]; ArrayResize(tls,0);
   for(int i=0;i<ArraySize(all);i++) {
      if(StringFind(all[i], prefix+tagTL, 0) == 0) {
         int sz = ArraySize(tls); ArrayResize(tls, sz+1); tls[sz] = all[i];
      }
   }

   // choose name: if under cap -> new name with next index; else reuse oldest
   int nextIdx = 0;
   for(int i=0;i<ArraySize(tls);i++)
      nextIdx = MathMax(nextIdx, JCT_ExtractIndex(tls[i], prefix+tagTL)+1);

   string name;
   if(ArraySize(tls) < JCT_MAX_TL_OBJECTS) {
      name = StringFormat("%s%s%06d", prefix, tagTL, nextIdx);
      if(!ObjectCreate(0, name, OBJ_TREND, 0, t1, p1, t2, p2))
         return false;
   } else {
      // reuse oldest TL
      int oldest = INT_MAX, pos = -1;
      for(int i=0;i<ArraySize(tls);i++){
         int idx = JCT_ExtractIndex(tls[i], prefix+tagTL);
         if(idx >= 0 && idx < oldest) { oldest = idx; pos = i; }
      }
      if(pos < 0) return false;
      name = tls[pos];
      // move anchors
      ObjectMove(0, name, 0, t1, p1);
      ObjectMove(0, name, 1, t2, p2);
   }

   // style (apply both for new/reused)
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_STYLE, style);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, width);
   ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, ray);
   ObjectSetInteger(0, name, OBJPROP_BACK, true);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, false);
   return true;
}

// ---- HORIZONTAL (OBJ_HLINE) with reuse/cap ----
bool JCT_DrawHLineCapped(
   const string symbol,
   const ENUM_TIMEFRAMES tf,
   const string moduleTag,
   const double price,
   const color clr, const int style = STYLE_DOT, const int width = 1
){
   const string prefix = JCT_DrawPrefix(symbol, tf, moduleTag);
   const string tagHL  = "HL_";
   string all[];  JCT_CountObjectsWithPrefix(prefix, all);

   // collect HL only
   string hls[]; ArrayResize(hls,0);
   for(int i=0;i<ArraySize(all);i++) {
      if(StringFind(all[i], prefix+tagHL, 0) == 0) {
         int sz = ArraySize(hls); ArrayResize(hls, sz+1); hls[sz] = all[i];
      }
   }

   // determine next/new or reuse oldest
   int nextIdx = 0;
   for(int i=0;i<ArraySize(hls);i++)
      nextIdx = MathMax(nextIdx, JCT_ExtractIndex(hls[i], prefix+tagHL)+1);

   string name;
   if(ArraySize(hls) < JCT_MAX_HL_OBJECTS) {
      name = StringFormat("%s%s%06d", prefix, tagHL, nextIdx);
      if(!ObjectCreate(0, name, OBJ_HLINE, 0, 0, price))
         return false;
   } else {
      int oldest = INT_MAX, pos = -1;
      for(int i=0;i<ArraySize(hls);i++){
         int idx = JCT_ExtractIndex(hls[i], prefix+tagHL);
         if(idx >= 0 && idx < oldest) { oldest = idx; pos = i; }
      }
      if(pos < 0) return false;
      name = hls[pos];
      ObjectSetDouble(0, name, OBJPROP_PRICE, price);
   }

   // style
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_STYLE, style);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, width);
   ObjectSetInteger(0, name, OBJPROP_BACK, true);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, false);
   return true;
}

// ---- Clear our module's SR drawings safely ----
int JCT_ClearSRForModule(const string symbol, const ENUM_TIMEFRAMES tf, const string moduleTag)
{
   const string prefix = JCT_DrawPrefix(symbol, tf, moduleTag);
   int removed = 0;
   for(int i = ObjectsTotal(0)-1; i >= 0; --i) {
      string n = ObjectName(0, i);
      if(StringFind(n, prefix, 0) == 0) {
         if(ObjectDelete(0, n)) removed++;
      }
   }
   return removed;
}

// ==== [CSM & Indicator Safety Helpers] ====

// Keep only letters and uppercase them (warning-free)
string JCT_StripNonLetters(const string sIn)
{
   string out = "";
   const int len = StringLen(sIn);
   for(int i = 0; i < len; i++)
   {
      int code = (int)StringGetCharacter(sIn, i); // use int to avoid uchar promotions

      // A..Z (65..90) or a..z (97..122)
      if((code >= 65 && code <= 90) || (code >= 97 && code <= 122))
      {
         if(code >= 97) code -= 32; // to uppercase

         // Build one-character string explicitly; avoid '+=' which can promote to uchar
         ushort ucode = (ushort)code;            // 16-bit code unit for CharToString
         string oneChar = StringFormat("%c", (uchar)code);
         out = out + oneChar;                    // explicit concat prevents warning
      }
      // ignore other characters
   }
   return out;
}

// Extract base/quote from any broker symbol (handles suffixes like ".sml")
bool JCT_ExtractCurrencies(const string symbol, string &base, string &quote)
{
   string clean = symbol;          // mutable copy
   StringToUpper(clean);           // in-place; ignore bool return
   clean = JCT_StripNonLetters(clean);

   if(StringLen(clean) < 6)
   {
      if(StringLen(symbol) >= 6)
      {
         base  = StringSubstr(symbol, 0, 3);
         quote = StringSubstr(symbol, 3, 3);
         return true;
      }
      return false;
   }

   base  = StringSubstr(clean, 0, 3);
   quote = StringSubstr(clean, 3, 3);
   return true;
}



// Safe percent change (guards division by zero)
bool JCT_SafePercentChange(const double currentPrice, const double pastPrice, double &outPct) {
   if(pastPrice <= 0.0 || !MathIsValidNumber(pastPrice)) return false;
   outPct = ((currentPrice - pastPrice) / pastPrice) * 100.0;
   return MathIsValidNumber(outPct);
}

// Wrapper for CopyBuffer with logging (reduces silent failures)
bool JCT_CopyBufferSafe(const int handle, const int bufferIndex, const int startPos, const int count, double &out[])
{
   ArrayResize(out, count);
   int got = CopyBuffer(handle, bufferIndex, startPos, count, out);
   if(got != count) {
      Print("ERROR: CopyBuffer failed. handle=", handle, " buf=", bufferIndex,
            " start=", startPos, " count=", count, " got=", got);
      return false;
   }
   return true;
}

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
    
    // Trendline tuning
    double m_TL_TolPipsMin;
    double m_TL_TolATRMult;
    int    m_TL_MaxPerSide;
    double m_TL_DedupeSlopePct;
    double m_TL_DedupePriceTolPips;

    
public:
    // Constructor & Destructor
    CTL_HL_Math();
    ~CTL_HL_Math();
    
    // Initialization
    bool Initialize();
    bool SetupChart(string symbol, ENUM_TIMEFRAMES timeframe, bool isMainChart);
    
    // Main analysis functions
    bool UpdateTechnicalAnalysis(string symbol, ENUM_TIMEFRAMES timeframe);
    void CalculateCSM(string &pairs[], int pairsCount, int lookback);
    
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
    double CalculateCurrencyStrength(string currency, string &pairs[], int pairsCount, int lookback);
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
    
    void SetTrendlineParams(double tolPipsMin, double tolAtrMult, int maxPerSide,
                        double slopePctTol = 7.5, double priceTolPips = 2.0);
   
};

    void CTL_HL_Math::SetTrendlineParams(double tolPipsMin, double tolAtrMult, int maxPerSide,
                                      double slopePctTol, double priceTolPips)
    {
        m_TL_TolPipsMin         = tolPipsMin;
        m_TL_TolATRMult         = tolAtrMult;
        m_TL_MaxPerSide         = maxPerSide;
        m_TL_DedupeSlopePct     = slopePctTol;
        m_TL_DedupePriceTolPips = priceTolPips;
    }  
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
    
    m_TL_TolPipsMin         = 2.0;
    m_TL_TolATRMult         = 0.20;
    m_TL_MaxPerSide         = 6;
    m_TL_DedupeSlopePct     = 7.5;
    m_TL_DedupePriceTolPips = 2.0;

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
    // Volatility-aware touch tolerance
    double pip   = JCT_PipSizeLocal(symbol);
    double atr14 = CalculateATR(symbol, timeframe, 14);
    double tol   = MathMax(m_TL_TolPipsMin * pip, atr14 * m_TL_TolATRMult);

    ArrayResize(m_TrendLines, 0);
   
    int totalBars = Bars(symbol, timeframe);
    if(totalBars < 100) return 0; // not enough data
   
    barsBack = MathMax(50, MathMin(barsBack, totalBars - 10));

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
         if(IsSwingHigh(highs, i, 3) && IsSwingHigh(highs, j, 3))
         {
            TrendLineData trendLine;
            trendLine.startTime  = times[j];           // older anchor
            trendLine.endTime    = times[i];           // newer anchor
            trendLine.startPrice = highs[j];
            trendLine.endPrice   = highs[i];
            trendLine.isSupport  = false;
            trendLine.touchCount = CountTrendLineTouches(highs, times, trendLine, true, tol);
            trendLine.strength   = trendLine.touchCount * 10.0;
            trendLine.objectName = StringFormat("TL_R_%s_%d_%d", symbol, (int)trendLine.startTime, (int)trendLine.endTime);
   
            // reject near-duplicates among resistances
            bool dup = false;
            for(int k = 0; k < ArraySize(m_TrendLines); k++)
            {
               if(!m_TrendLines[k].isSupport)
               {
                  if(JCT_IsSimilarTL(m_TrendLines[k], trendLine, pip, m_TL_DedupeSlopePct, m_TL_DedupePriceTolPips))
                  { dup = true; break; }
               }
            }
   
            if(!dup && trendLine.touchCount >= 2)
            {
               int nz = ArraySize(m_TrendLines);
               ArrayResize(m_TrendLines, nz + 1);
               m_TrendLines[nz] = trendLine;
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
            trendLine.startTime  = times[j];           // older anchor
            trendLine.endTime    = times[i];           // newer anchor
            trendLine.startPrice = lows[j];
            trendLine.endPrice   = lows[i];
            trendLine.isSupport  = true;
            trendLine.touchCount = CountTrendLineTouches(lows, times, trendLine, false, tol);
            trendLine.strength   = trendLine.touchCount * 10.0;
            trendLine.objectName = StringFormat("TL_S_%s_%d_%d", symbol, (int)trendLine.startTime, (int)trendLine.endTime);
   
            // reject near-duplicates among supports
            bool dup = false;
            for(int k = 0; k < ArraySize(m_TrendLines); k++)
            {
               if(m_TrendLines[k].isSupport)
               {
                  if(JCT_IsSimilarTL(m_TrendLines[k], trendLine, pip, m_TL_DedupeSlopePct, m_TL_DedupePriceTolPips))
                  { dup = true; break; }
               }
            }
   
            if(!dup && trendLine.touchCount >= 2)
            {
               int nz = ArraySize(m_TrendLines);
               ArrayResize(m_TrendLines, nz + 1);
               m_TrendLines[nz] = trendLine;
            }
         }
      }
   }  
    // Keep only the top N per side (support/resistance)
    JCT_TrimTrendLines(m_TrendLines, m_TL_MaxPerSide); 
   
    return ArraySize(m_TrendLines);
}

//+------------------------------------------------------------------+
//| Find horizontal levels                                           |
//+------------------------------------------------------------------+
int CTL_HL_Math::FindHorizontalLevels(string symbol, ENUM_TIMEFRAMES timeframe, int barsBack)
{
    ArrayResize(m_HorizontalLevels, 0);
   
    int totalBars = Bars(symbol, timeframe);
    if(totalBars < 100) return 0;
   
    barsBack = MathMax(50, MathMin(barsBack, totalBars - 10));

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
    
    double rsiBuffer[], stochMain[], stochSignal[], williamsBuffer[];
    
    if(!JCT_CopyBufferSafe(m_HandleRSI,      0, 0, 3, rsiBuffer))      return false;
    if(!JCT_CopyBufferSafe(m_HandleStoch,    0, 0, 3, stochMain))      return false;
    if(!JCT_CopyBufferSafe(m_HandleStoch,    1, 0, 3, stochSignal))    return false;
    if(!JCT_CopyBufferSafe(m_HandleWilliams, 0, 0, 3, williamsBuffer)) return false;
       
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
    
    double macdMain[], macdSignal[];
      
    if(!JCT_CopyBufferSafe(m_HandleMACD, 0, 0, 3, macdMain))   return false;
    if(!JCT_CopyBufferSafe(m_HandleMACD, 1, 0, 3, macdSignal)) return false;
    
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

   // Use capped pool under module tag "SR"
   bool ok = JCT_DrawTrendlineCapped(
      m_CurrentSymbol, m_CurrentTimeframe, "SR",
      trendLine.startTime, trendLine.startPrice,
      trendLine.endTime,   trendLine.endPrice,
      m_TrendLineColor, STYLE_SOLID, m_LineWidth, true
   );

   if(ok) {
      // Optional tooltip on the most recent (not required; attach if needed)
      // Note: pooled names are auto-generated; tooltips are optional
   }
}

//+------------------------------------------------------------------+
//| Draw horizontal level                                            |
//+------------------------------------------------------------------+
void CTL_HL_Math::DrawHorizontalLevel(HorizontalLevelData &level)
{
   if(!m_IsMainChart) return;

   const color c = level.isSupport ? m_SupportColor : m_ResistanceColor;

   bool ok = JCT_DrawHLineCapped(
      m_CurrentSymbol, m_CurrentTimeframe, "SR",
      level.price, c, STYLE_DOT, m_LineWidth
   );

   if(ok) {
      // Optional: attach label objects separately if you need text
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
void CTL_HL_Math::CalculateCSM(string &pairs[], int pairsCount, int lookback)
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
        
      // Get currency codes (suffix-safe)
      string baseCurrency="", quoteCurrency="";
      if(!JCT_ExtractCurrencies(symbol, baseCurrency, quoteCurrency))
         return; // skip this pair if parsing fails
      
      // Price change over lookback period (guard division by zero)
      double currentPrice = SymbolInfoDouble(symbol, SYMBOL_BID);
      double pastPrice    = iClose(symbol, PERIOD_H1, lookback);
      double percentChange;
      if(currentPrice > 0 && JCT_SafePercentChange(currentPrice, pastPrice, percentChange))
      {
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
double CTL_HL_Math::CalculateCurrencyStrength(string currency, string &pairs[], int pairsCount, int lookback)
{
    double totalStrength = 0.0;
    int pairCount = 0;
    
    for(int i = 0; i < pairsCount; i++)
    {
        string symbol = pairs[i];
        string baseCurrency="", quoteCurrency="";
        if(!JCT_ExtractCurrencies(symbol, baseCurrency, quoteCurrency))
           continue;
      
        if(baseCurrency == currency || quoteCurrency == currency)
        {
           double currentPrice = SymbolInfoDouble(symbol, SYMBOL_BID);
           double pastPrice    = iClose(symbol, PERIOD_H1, lookback);
           double percentChange;
           if(currentPrice > 0 && JCT_SafePercentChange(currentPrice, pastPrice, percentChange))
           {
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
    double tolerance = 5 * SymbolInfoDouble(symbol, SYMBOL_POINT);
    
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
    if(symbol == "") return false;
    long value = SymbolInfoInteger(symbol, SYMBOL_SELECT);
    return (value != 0);
}

//+------------------------------------------------------------------+
//| Calculate pip value                                              |
//+------------------------------------------------------------------+
double CTL_HL_Math::CalculatePipValue(string symbol)
{
    double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
    double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
    double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
    
    if(tickSize == 0) return 0;
    
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

