//+------------------------------------------------------------------+
//|                                                 TL_HL_Math.mqh |
//|                                                    JcampFx Team |
//|                         Enhanced Technical Analysis Math Library |
//+------------------------------------------------------------------+
#property copyright "JcampFx Team"
#property link      ""
#property version   "2.00"

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
    datetime creationTime;
    double totalRejection;
    bool isValidated;
};

struct HorizontalLevelData
{
    double price;
    bool isSupport;
    double strength;
    int touchCount;
    datetime lastTouch;
    string objectName;
    datetime creationTime;
    double totalRejection;
    bool isValidated;
    bool isBroken;
    bool isPsychological;
    bool isHTFLevel;
};

// NEW: Enhanced swing point structure from 3Point EA
struct SwingPoint
{
    datetime time;
    double price;
    int bar_index;
    bool is_high;
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
#define JCT_MAX_SR_OBJECTS   60   
#define JCT_MAX_TL_OBJECTS   30   
#define JCT_MAX_HL_OBJECTS   30   
#define JCT_SR_BARS_BACK   2000   

// Sanitize symbol for object names (handles OANDA suffixes like ".sml")
string JCT_NormalizeSymbol(string sym)
{
   string s = sym;
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
string JCT_StripNonLetters(const string sIn)
{
   string out = "";
   const int len = StringLen(sIn);
   for(int i = 0; i < len; i++)
   {
      int code = (int)StringGetCharacter(sIn, i); 
      if((code >= 65 && code <= 90) || (code >= 97 && code <= 122))
      {
         if(code >= 97) code -= 32; // to uppercase
         ushort ucode = (ushort)code;            
         string oneChar = StringFormat("%c", (uchar)code);
         out = out + oneChar;                    
      }
   }
   return out;
}

// Extract base/quote from any broker symbol (handles suffixes like ".sml")
bool JCT_ExtractCurrencies(const string symbol, string &base, string &quote)
{
   string clean = symbol;          
   StringToUpper(clean);           
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
//| Enhanced Technical Analysis Math Library Class                  |
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
    
    // NEW: Enhanced swing point arrays from 3Point EA
    SwingPoint m_SwingPoints[];      // For trendlines (5 bar confirmation)
    SwingPoint m_SRSwingPoints[];    // For S/R levels (7-10 bar confirmation)
    
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
    color m_NeutralLevelColor;
    color m_PsychologicalColor;
    int m_LineWidth;
    
    // NEW: Enhanced settings from 3Point EA
    int m_SwingBars;                    // Number of bars for trendline swing detection
    int m_SRSwingBars;                  // Number of bars for S/R swing detection  
    int m_MaxTrendlines;                // Maximum trendlines on chart
    int m_MaxSRLevels;                  // Maximum S/R levels on chart
    double m_SRTolerance;               // Tolerance for S/R level grouping (pips)
    int m_MinSRTouches;                 // Minimum touches for S/R validation
    double m_MinSRRejection;            // Minimum S/R rejection strength (pips)
    double m_MaxSRDistance;             // Maximum distance from current price (pips)
    bool m_ShowPsychological;           // Show psychological levels
    bool m_ShowHTFLevels;               // Show higher timeframe levels
    ENUM_TIMEFRAMES m_HigherTF;         // Higher timeframe for confirmation
    bool m_RequireHTFAlignment;         // Require HTF confirmation
    double m_HTFAlignmentTolerance;     // HTF alignment tolerance (pips)
    int m_MinTouches;                   // Minimum touches for trendline validation
    double m_MinRejectionPips;          // Minimum rejection strength (pips)
    int m_ValidationBars;               // Bars to check for validation
    
    // Trendline tuning
    double m_TL_TolPipsMin;
    double m_TL_TolATRMult;
    int    m_TL_MaxPerSide;
    double m_TL_DedupeSlopePct;
    double m_TL_DedupePriceTolPips;

    // NEW: Enhanced private methods from 3Point EA
    void DetectSwingPoints();
    void DetectSRSwingPoints();
    bool SwingPointExists(datetime time, double price, bool isHigh);
    bool SRSwingPointExists(datetime time, double price, bool isHigh);
    void AddSwingPoint(datetime time, double price, int barIndex, bool isHigh);
    void AddSRSwingPoint(datetime time, double price, int barIndex, bool isHigh);
    void Create3PointTrendlines();
    void CreateResistanceTrendline(SwingPoint &highs[]);
    void CreateSupportTrendline(SwingPoint &lows[]);
    void CreateEnhancedSRLevels();
    void CreatePsychologicalLevels();
    void CreateHTFSRLevels();
    void CreateSRLevel(double price, int initialTouches, datetime lastTouch, bool fromHigh);
    void CreatePsychologicalSRLevel(double price);
    void CreateHTFSRLevel(double price, bool isResistance);
    bool CheckHTFAlignment(double price1, double price2, bool isResistance);
    void ValidateExistingTrendlines();
    void ValidateExistingSRLevels();
    void CountTouchesAndRejection(int dataIndex);
    void CountSRTouchesAndRejection(int levelIndex);
    bool SRLevelExists(double price);
    void CleanupOldLevels();
    
public:
    // Constructor & Destructor
    CTL_HL_Math();
    ~CTL_HL_Math();
    
    // Initialization
    bool Initialize();
    bool SetupChart(string symbol, ENUM_TIMEFRAMES timeframe, bool isMainChart);
    
    // NEW: Enhanced configuration methods
    void SetEnhancedSettings(int swingBars = 5, int srSwingBars = 8, int maxTrendlines = 4,
                            int maxSRLevels = 6, double srTolerance = 15, int minSRTouches = 4,
                            double minSRRejection = 25, double maxSRDistance = 200,
                            bool showPsychological = true, bool showHTFLevels = true);
    
    void SetHTFSettings(ENUM_TIMEFRAMES higherTF = PERIOD_H1, bool requireAlignment = true,
                       double alignmentTolerance = 50);
    
    void SetValidationSettings(int minTouches = 3, double minRejectionPips = 20,
                              int validationBars = 50);
    
    // Main analysis functions
    bool UpdateTechnicalAnalysis(string symbol, ENUM_TIMEFRAMES timeframe);
    void CalculateCSM(string &pairs[], int pairsCount, int lookback);
    
    // Enhanced trendline functions
    int FindTrendLines(string symbol, ENUM_TIMEFRAMES timeframe, int barsBack = 100);
    bool IsTrendLineValid(TrendLineData &trendLine, datetime currentTime, double currentPrice);
    double GetTrendLinePrice(TrendLineData &trendLine, datetime time);
    int GetTrendLineCount(bool supportOnly = false, bool resistanceOnly = false);
    TrendLineData GetTrendLine(int index);
    
    // Enhanced horizontal level functions
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
    m_NeutralLevelColor = clrGold;
    m_PsychologicalColor = clrDarkGray;
    m_LineWidth = 1;
    
    // NEW: Initialize enhanced settings with 3Point defaults
    m_SwingBars = 5;
    m_SRSwingBars = 8;
    m_MaxTrendlines = 4;
    m_MaxSRLevels = 6;
    m_SRTolerance = 15;
    m_MinSRTouches = 4;
    m_MinSRRejection = 25;
    m_MaxSRDistance = 200;
    m_ShowPsychological = true;
    m_ShowHTFLevels = true;
    m_HigherTF = PERIOD_H1;
    m_RequireHTFAlignment = true;
    m_HTFAlignmentTolerance = 50;
    m_MinTouches = 3;
    m_MinRejectionPips = 20;
    m_ValidationBars = 50;
    
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
    
    // NEW: Initialize swing point arrays
    ArrayResize(m_SwingPoints, 0);
    ArrayResize(m_SRSwingPoints, 0);
    
    return true;
}

//+------------------------------------------------------------------+
//| NEW: Set enhanced settings                                       |
//+------------------------------------------------------------------+
void CTL_HL_Math::SetEnhancedSettings(int swingBars, int srSwingBars, int maxTrendlines,
                                     int maxSRLevels, double srTolerance, int minSRTouches,
                                     double minSRRejection, double maxSRDistance,
                                     bool showPsychological, bool showHTFLevels)
{
    m_SwingBars = swingBars;
    m_SRSwingBars = srSwingBars;
    m_MaxTrendlines = maxTrendlines;
    m_MaxSRLevels = maxSRLevels;
    m_SRTolerance = srTolerance;
    m_MinSRTouches = minSRTouches;
    m_MinSRRejection = minSRRejection;
    m_MaxSRDistance = maxSRDistance;
    m_ShowPsychological = showPsychological;
    m_ShowHTFLevels = showHTFLevels;
}

//+------------------------------------------------------------------+
//| NEW: Set HTF settings                                           |
//+------------------------------------------------------------------+
void CTL_HL_Math::SetHTFSettings(ENUM_TIMEFRAMES higherTF, bool requireAlignment,
                                 double alignmentTolerance)
{
    m_HigherTF = higherTF;
    m_RequireHTFAlignment = requireAlignment;
    m_HTFAlignmentTolerance = alignmentTolerance;
}

//+------------------------------------------------------------------+
//| NEW: Set validation settings                                     |
//+------------------------------------------------------------------+
void CTL_HL_Math::SetValidationSettings(int minTouches, double minRejectionPips,
                                        int validationBars)
{
    m_MinTouches = minTouches;
    m_MinRejectionPips = minRejectionPips;
    m_ValidationBars = validationBars;
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
    
    // NEW: Enhanced swing detection and analysis
    DetectSwingPoints();
    DetectSRSwingPoints();
    
    // NEW: Create trendlines and S/R levels using 3Point method
    Create3PointTrendlines();
    CreateEnhancedSRLevels();
    
    // Add psychological and HTF levels
    if(m_ShowPsychological) CreatePsychologicalLevels();
    if(m_ShowHTFLevels) CreateHTFSRLevels();
    
    // Validate existing levels
    ValidateExistingTrendlines();
    ValidateExistingSRLevels();
    
    // Cleanup old levels
    CleanupOldLevels();
    
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
//| NEW: Enhanced swing point detection for trendlines              |
//+------------------------------------------------------------------+
void CTL_HL_Math::DetectSwingPoints()
{
    int bars = iBars(m_CurrentSymbol, m_CurrentTimeframe);
    if(bars < m_SwingBars * 2 + 1) return;
    
    // Clear old swing points (keep recent ones for trendline calculation)
    if(ArraySize(m_SwingPoints) > 100)
        ArrayResize(m_SwingPoints, 50);
    
    // Check for swing highs and lows
    for(int i = m_SwingBars; i < bars - m_SwingBars - 1; i++)
    {
        double high = iHigh(m_CurrentSymbol, m_CurrentTimeframe, i);
        double low = iLow(m_CurrentSymbol, m_CurrentTimeframe, i);
        datetime time = iTime(m_CurrentSymbol, m_CurrentTimeframe, i);
        
        // Check for swing high
        bool isSwingHigh = true;
        for(int j = 1; j <= m_SwingBars; j++)
        {
            if(high <= iHigh(m_CurrentSymbol, m_CurrentTimeframe, i - j) || 
               high <= iHigh(m_CurrentSymbol, m_CurrentTimeframe, i + j))
            {
                isSwingHigh = false;
                break;
            }
        }
        
        // Check for swing low
        bool isSwingLow = true;
        for(int j = 1; j <= m_SwingBars; j++)
        {
            if(low >= iLow(m_CurrentSymbol, m_CurrentTimeframe, i - j) || 
               low >= iLow(m_CurrentSymbol, m_CurrentTimeframe, i + j))
            {
                isSwingLow = false;
                break;
            }
        }
        
        // Add swing points to array
        if(isSwingHigh && !SwingPointExists(time, high, true))
        {
            AddSwingPoint(time, high, i, true);
        }
        
        if(isSwingLow && !SwingPointExists(time, low, false))
        {
            AddSwingPoint(time, low, i, false);
        }
    }
}

//+------------------------------------------------------------------+
//| NEW: Enhanced swing point detection for S/R levels              |
//+------------------------------------------------------------------+
void CTL_HL_Math::DetectSRSwingPoints()
{
    int bars = iBars(m_CurrentSymbol, m_CurrentTimeframe);
    if(bars < m_SRSwingBars * 2 + 1) return;
    
    // Clear old S/R swing points (keep recent ones, limit memory usage)
    if(ArraySize(m_SRSwingPoints) > 150)
        ArrayResize(m_SRSwingPoints, 75);
    
    // Check for swing highs and lows using higher confirmation
    for(int i = m_SRSwingBars; i < bars - m_SRSwingBars - 1; i++)
    {
        double high = iHigh(m_CurrentSymbol, m_CurrentTimeframe, i);
        double low = iLow(m_CurrentSymbol, m_CurrentTimeframe, i);
        datetime time = iTime(m_CurrentSymbol, m_CurrentTimeframe, i);
        
        // Check for swing high (more stringent)
        bool isSwingHigh = true;
        for(int j = 1; j <= m_SRSwingBars; j++)
        {
            if(high <= iHigh(m_CurrentSymbol, m_CurrentTimeframe, i - j) || 
               high <= iHigh(m_CurrentSymbol, m_CurrentTimeframe, i + j))
            {
                isSwingHigh = false;
                break;
            }
        }
        
        // Check for swing low (more stringent)
        bool isSwingLow = true;
        for(int j = 1; j <= m_SRSwingBars; j++)
        {
            if(low >= iLow(m_CurrentSymbol, m_CurrentTimeframe, i - j) || 
               low >= iLow(m_CurrentSymbol, m_CurrentTimeframe, i + j))
            {
                isSwingLow = false;
                break;
            }
        }
        
        // Add swing points to S/R array
        if(isSwingHigh && !SRSwingPointExists(time, high, true))
        {
            AddSRSwingPoint(time, high, i, true);
        }
        
        if(isSwingLow && !SRSwingPointExists(time, low, false))
        {
            AddSRSwingPoint(time, low, i, false);
        }
    }
}

//+------------------------------------------------------------------+
//| NEW: Create 3-point trendlines                                  |
//+------------------------------------------------------------------+
void CTL_HL_Math::Create3PointTrendlines()
{
    // Separate swing highs and lows
    SwingPoint highs[];
    SwingPoint lows[];
    
    ArrayResize(highs, 0);
    ArrayResize(lows, 0);
    
    for(int i = 0; i < ArraySize(m_SwingPoints); i++)
    {
        if(m_SwingPoints[i].is_high)
        {
            int size = ArraySize(highs);
            ArrayResize(highs, size + 1);
            highs[size] = m_SwingPoints[i];
        }
        else
        {
            int size = ArraySize(lows);
            ArrayResize(lows, size + 1);
            lows[size] = m_SwingPoints[i];
        }
    }
    
    // Sort arrays by time (most recent first)
    // Sort highs
    int highsSize = ArraySize(highs);
    for(int i = 0; i < highsSize - 1; i++)
    {
        for(int j = i + 1; j < highsSize; j++)
        {
            if(highs[i].time < highs[j].time)
            {
                SwingPoint temp = highs[i];
                highs[i] = highs[j];
                highs[j] = temp;
            }
        }
    }
    
    // Sort lows
    int lowsSize = ArraySize(lows);
    for(int i = 0; i < lowsSize - 1; i++)
    {
        for(int j = i + 1; j < lowsSize; j++)
        {
            if(lows[i].time < lows[j].time)
            {
                SwingPoint temp = lows[i];
                lows[i] = lows[j];
                lows[j] = temp;
            }
        }
    }
    
    // Create trendlines from swing points
    if(ArraySize(highs) >= 3)
    {
        CreateResistanceTrendline(highs);
    }
    
    if(ArraySize(lows) >= 3)
    {
        CreateSupportTrendline(lows);
    }
}

//+------------------------------------------------------------------+
//| NEW: Create resistance trendline from swing highs               |
//+------------------------------------------------------------------+
void CTL_HL_Math::CreateResistanceTrendline(SwingPoint &highs[])
{
    int pointsSize = ArraySize(highs);
    if(pointsSize < 3) return;
    
    // Take the 3 most recent points
    SwingPoint p1 = highs[0]; // Most recent
    SwingPoint p2 = highs[1]; // Second most recent  
    SwingPoint p3 = highs[2]; // Third most recent
    
    // Check if points form a valid trendline (should be roughly aligned)
    double slope12 = (p2.price - p1.price) / (double)(p2.time - p1.time);
    double slope23 = (p3.price - p2.price) / (double)(p3.time - p2.time);
    double point = SymbolInfoDouble(m_CurrentSymbol, SYMBOL_POINT);
    
    // Allow some tolerance in slope difference
    if(MathAbs(slope12 - slope23) > point * 100)
        return;
    
    // HTF confirmation
    if(m_RequireHTFAlignment && !CheckHTFAlignment(p1.price, p3.price, true))
    {
        return;
    }
    
    // Create trendline data
    TrendLineData trendLine;
    trendLine.startTime = p3.time;
    trendLine.endTime = p1.time;
    trendLine.startPrice = p3.price;
    trendLine.endPrice = p1.price;
    trendLine.isSupport = false;
    trendLine.touchCount = 3; // Start with 3 (the swing points)
    trendLine.strength = 30.0; // 3 touches * 10
    trendLine.creationTime = TimeCurrent();
    trendLine.totalRejection = 0;
    trendLine.isValidated = false;
    trendLine.objectName = StringFormat("Resistance_%d", (int)TimeCurrent());
    
    // Check if we have too many trendlines
    if(ArraySize(m_TrendLines) >= m_MaxTrendlines * 2)
    {
        // Remove oldest trendline
        ArrayResize(m_TrendLines, m_MaxTrendlines * 2 - 1);
    }
    
    // Add to array
    int newSize = ArraySize(m_TrendLines) + 1;
    ArrayResize(m_TrendLines, newSize);
    m_TrendLines[newSize - 1] = trendLine;
    
    Print("Created 3-point resistance trendline at ", DoubleToString(p1.price, 5));
}

//+------------------------------------------------------------------+
//| NEW: Create support trendline from swing lows                   |
//+------------------------------------------------------------------+
void CTL_HL_Math::CreateSupportTrendline(SwingPoint &lows[])
{
    int pointsSize = ArraySize(lows);
    if(pointsSize < 3) return;
    
    // Take the 3 most recent points
    SwingPoint p1 = lows[0]; // Most recent
    SwingPoint p2 = lows[1]; // Second most recent  
    SwingPoint p3 = lows[2]; // Third most recent
    
    // Check if points form a valid trendline
    double slope12 = (p2.price - p1.price) / (double)(p2.time - p1.time);
    double slope23 = (p3.price - p2.price) / (double)(p3.time - p2.time);
    double point = SymbolInfoDouble(m_CurrentSymbol, SYMBOL_POINT);
    
    // Allow some tolerance in slope difference
    if(MathAbs(slope12 - slope23) > point * 100)
        return;
    
    // HTF confirmation
    if(m_RequireHTFAlignment && !CheckHTFAlignment(p1.price, p3.price, false))
    {
        return;
    }
    
    // Create trendline data
    TrendLineData trendLine;
    trendLine.startTime = p3.time;
    trendLine.endTime = p1.time;
    trendLine.startPrice = p3.price;
    trendLine.endPrice = p1.price;
    trendLine.isSupport = true;
    trendLine.touchCount = 3;
    trendLine.strength = 30.0;
    trendLine.creationTime = TimeCurrent();
    trendLine.totalRejection = 0;
    trendLine.isValidated = false;
    trendLine.objectName = StringFormat("Support_%d", (int)TimeCurrent());
    
    // Check if we have too many trendlines
    if(ArraySize(m_TrendLines) >= m_MaxTrendlines * 2)
    {
        ArrayResize(m_TrendLines, m_MaxTrendlines * 2 - 1);
    }
    
    // Add to array
    int newSize = ArraySize(m_TrendLines) + 1;
    ArrayResize(m_TrendLines, newSize);
    m_TrendLines[newSize - 1] = trendLine;
    
    Print("Created 3-point support trendline at ", DoubleToString(p1.price, 5));
}

//+------------------------------------------------------------------+
//| NEW: Create enhanced S/R levels                                 |
//+------------------------------------------------------------------+
void CTL_HL_Math::CreateEnhancedSRLevels()
{
    double tolerancePips = m_SRTolerance * SymbolInfoDouble(m_CurrentSymbol, SYMBOL_POINT);
    double currentPrice = iClose(m_CurrentSymbol, m_CurrentTimeframe, 0);
    double maxDistance = m_MaxSRDistance * SymbolInfoDouble(m_CurrentSymbol, SYMBOL_POINT);
    
    // Only analyze recent swing points (last 200 bars max)
    int maxAnalysisPoints = MathMin(ArraySize(m_SRSwingPoints), 200);
    
    // Analyze recent S/R swing points for S/R levels
    for(int i = 0; i < maxAnalysisPoints - 1; i++)
    {
        double currentSwingPrice = m_SRSwingPoints[i].price;
        bool currentIsHigh = m_SRSwingPoints[i].is_high;
        
        // Filter 1: Only analyze swing points near current price
        if(MathAbs(currentSwingPrice - currentPrice) > maxDistance)
            continue;
        
        // Count similar price levels within tolerance
        int touchCount = 1;
        double totalPrice = currentSwingPrice;
        datetime lastTouch = m_SRSwingPoints[i].time;
        
        for(int j = i + 1; j < maxAnalysisPoints; j++)
        {
            if(MathAbs(m_SRSwingPoints[j].price - currentSwingPrice) <= tolerancePips)
            {
                touchCount++;
                totalPrice += m_SRSwingPoints[j].price;
                if(m_SRSwingPoints[j].time > lastTouch)
                    lastTouch = m_SRSwingPoints[j].time;
            }
        }
        
        // Create S/R level if sufficient touches found
        if(touchCount >= 3 && !SRLevelExists(currentSwingPrice))
        {
            double avgPrice = totalPrice / touchCount;
            
            // Filter 2: Double-check proximity before creating
            if(MathAbs(avgPrice - currentPrice) <= maxDistance)
            {
                CreateSRLevel(avgPrice, touchCount, lastTouch, currentIsHigh);
            }
        }
    }
}

//+------------------------------------------------------------------+
//| NEW: Create S/R level                                           |
//+------------------------------------------------------------------+
void CTL_HL_Math::CreateSRLevel(double price, int initialTouches, datetime lastTouch, bool fromHigh)
{
    // Check if we need to remove oldest S/R level first
    if(ArraySize(m_HorizontalLevels) >= m_MaxSRLevels)
    {
        ArrayResize(m_HorizontalLevels, m_MaxSRLevels - 1);
    }
    
    HorizontalLevelData level;
    level.price = price;
    level.isSupport = !fromHigh;
    level.strength = initialTouches * 5.0;
    level.touchCount = initialTouches;
    level.lastTouch = lastTouch;
    level.objectName = StringFormat("SR_Level_%d_%.5f", (int)TimeCurrent(), price);
    level.creationTime = TimeCurrent();
    level.totalRejection = 0;
    level.isValidated = false;
    level.isBroken = false;
    level.isPsychological = false;
    level.isHTFLevel = false;
    
    // Add to array
    int newSize = ArraySize(m_HorizontalLevels) + 1;
    ArrayResize(m_HorizontalLevels, newSize);
    m_HorizontalLevels[newSize - 1] = level;
    
    Print("Created S/R level at ", DoubleToString(price, 5), " with ", initialTouches, " touches");
}

//+------------------------------------------------------------------+
//| NEW: Create psychological levels                                 |
//+------------------------------------------------------------------+
void CTL_HL_Math::CreatePsychologicalLevels()
{
    double currentPrice = iClose(m_CurrentSymbol, m_CurrentTimeframe, 0);
    int digits = (int)SymbolInfoInteger(m_CurrentSymbol, SYMBOL_DIGITS);
    double point = SymbolInfoDouble(m_CurrentSymbol, SYMBOL_POINT);
    
    double range = m_MaxSRDistance * point;
    double psychLevel;
    
    if(digits == 5 || digits == 3) // 5-digit or 3-digit broker
    {
        // Round numbers (1.1000, 1.1050, 1.1100, etc.)
        double baseLevel = MathFloor(currentPrice * 10000) / 10000;
        
        for(double level = baseLevel - range; level <= baseLevel + range; level += 50 * point)
        {
            psychLevel = NormalizeDouble(level, digits);
            
            // Check if it's a significant psychological level (00 or 50)
            int lastTwoDigits = (int)MathRound((psychLevel - MathFloor(psychLevel * 100) / 100) * 10000) % 100;
            
            if((lastTwoDigits == 0 || lastTwoDigits == 50) && 
               !SRLevelExists(psychLevel) && 
               MathAbs(psychLevel - currentPrice) >= 20 * point && // Minimum distance
               MathAbs(psychLevel - currentPrice) <= range)          // Maximum distance
            {
                CreatePsychologicalSRLevel(psychLevel);
            }
        }
    }
}

//+------------------------------------------------------------------+
//| NEW: Create psychological S/R level                             |
//+------------------------------------------------------------------+
void CTL_HL_Math::CreatePsychologicalSRLevel(double price)
{
    // Check if we have space for psychological levels
    if(ArraySize(m_HorizontalLevels) >= m_MaxSRLevels)
        return;
    
    HorizontalLevelData level;
    level.price = price;
    level.isSupport = false; // Neutral
    level.strength = 10.0; // Base strength for psychological levels
    level.touchCount = 0;
    level.lastTouch = 0;
    level.objectName = StringFormat("Psych_Level_%.5f", price);
    level.creationTime = TimeCurrent();
    level.totalRejection = 0;
    level.isValidated = false;
    level.isBroken = false;
    level.isPsychological = true;
    level.isHTFLevel = false;
    
    // Add to array
    int newSize = ArraySize(m_HorizontalLevels) + 1;
    ArrayResize(m_HorizontalLevels, newSize);
    m_HorizontalLevels[newSize - 1] = level;
    
    Print("Created psychological level at ", DoubleToString(price, 5));
}

//+------------------------------------------------------------------+
//| NEW: Create higher timeframe S/R levels                         |
//+------------------------------------------------------------------+
void CTL_HL_Math::CreateHTFSRLevels()
{
    int htfBars = iBars(m_CurrentSymbol, m_HigherTF);
    if(htfBars < 20) return;
    
    double currentPrice = iClose(m_CurrentSymbol, m_CurrentTimeframe, 0);
    double maxDistance = m_MaxSRDistance * SymbolInfoDouble(m_CurrentSymbol, SYMBOL_POINT);
    
    // Get recent HTF swing highs and lows (limit to last 100 HTF bars)
    int maxHTFBars = MathMin(htfBars - 3, 100);
    
    for(int i = 3; i < maxHTFBars; i++)
    {
        double htfHigh = iHigh(m_CurrentSymbol, m_HigherTF, i);
        double htfLow = iLow(m_CurrentSymbol, m_HigherTF, i);
        
        // Filter: Only analyze HTF levels near current price
        if(MathAbs(htfHigh - currentPrice) <= maxDistance)
        {
            // Check for HTF swing high
            bool isHTFSwingHigh = true;
            for(int j = 1; j <= 2; j++)
            {
                if(htfHigh <= iHigh(m_CurrentSymbol, m_HigherTF, i - j) || 
                   htfHigh <= iHigh(m_CurrentSymbol, m_HigherTF, i + j))
                {
                    isHTFSwingHigh = false;
                    break;
                }
            }
            
            if(isHTFSwingHigh && !SRLevelExists(htfHigh))
            {
                CreateHTFSRLevel(htfHigh, true);
            }
        }
        
        // Filter: Only analyze HTF levels near current price
        if(MathAbs(htfLow - currentPrice) <= maxDistance)
        {
            // Check for HTF swing low
            bool isHTFSwingLow = true;
            for(int j = 1; j <= 2; j++)
            {
                if(htfLow >= iLow(m_CurrentSymbol, m_HigherTF, i - j) || 
                   htfLow >= iLow(m_CurrentSymbol, m_HigherTF, i + j))
                {
                    isHTFSwingLow = false;
                    break;
                }
            }
            
            if(isHTFSwingLow && !SRLevelExists(htfLow))
            {
                CreateHTFSRLevel(htfLow, false);
            }
        }
    }
}

//+------------------------------------------------------------------+
//| NEW: Create HTF S/R level                                       |
//+------------------------------------------------------------------+
void CTL_HL_Math::CreateHTFSRLevel(double price, bool isResistance)
{
    // Check if we have space for HTF levels
    if(ArraySize(m_HorizontalLevels) >= m_MaxSRLevels)
        return;
    
    HorizontalLevelData level;
    level.price = price;
    level.isSupport = !isResistance;
    level.strength = 20.0; // Higher strength for HTF levels
    level.touchCount = 1;
    level.lastTouch = 0;
    level.objectName = StringFormat("HTF_%s_%.5f", isResistance ? "Res" : "Sup", price);
    level.creationTime = TimeCurrent();
    level.totalRejection = 0;
    level.isValidated = true; // HTF levels start validated
    level.isBroken = false;
    level.isPsychological = false;
    level.isHTFLevel = true;
    
    // Add to array
    int newSize = ArraySize(m_HorizontalLevels) + 1;
    ArrayResize(m_HorizontalLevels, newSize);
    m_HorizontalLevels[newSize - 1] = level;
    
    Print("Created HTF ", (isResistance ? "resistance" : "support"), " level at ", DoubleToString(price, 5));
}

//+------------------------------------------------------------------+
//| NEW: Check HTF alignment                                        |
//+------------------------------------------------------------------+
bool CTL_HL_Math::CheckHTFAlignment(double price1, double price2, bool isResistance)
{
    // Get higher timeframe swing points
    int htfBars = iBars(m_CurrentSymbol, m_HigherTF);
    if(htfBars < 20) return true; // Not enough data, allow trendline
    
    double htfSwings[];
    ArrayResize(htfSwings, 0);
    double point = SymbolInfoDouble(m_CurrentSymbol, SYMBOL_POINT);
    
    // Find HTF swing highs or lows
    for(int i = 5; i < htfBars - 5; i++)
    {
        if(isResistance)
        {
            // Check for HTF swing highs
            double htfHigh = iHigh(m_CurrentSymbol, m_HigherTF, i);
            bool isHTFSwingHigh = true;
            
            for(int j = 1; j <= 3; j++)
            {
                if(htfHigh <= iHigh(m_CurrentSymbol, m_HigherTF, i - j) || 
                   htfHigh <= iHigh(m_CurrentSymbol, m_HigherTF, i + j))
                {
                    isHTFSwingHigh = false;
                    break;
                }
            }
            
            if(isHTFSwingHigh)
            {
                int size = ArraySize(htfSwings);
                ArrayResize(htfSwings, size + 1);
                htfSwings[size] = htfHigh;
            }
        }
        else
        {
            // Check for HTF swing lows
            double htfLow = iLow(m_CurrentSymbol, m_HigherTF, i);
            bool isHTFSwingLow = true;
            
            for(int j = 1; j <= 3; j++)
            {
                if(htfLow >= iLow(m_CurrentSymbol, m_HigherTF, i - j) || 
                   htfLow >= iLow(m_CurrentSymbol, m_HigherTF, i + j))
                {
                    isHTFSwingLow = false;
                    break;
                }
            }
            
            if(isHTFSwingLow)
            {
                int size = ArraySize(htfSwings);
                ArrayResize(htfSwings, size + 1);
                htfSwings[size] = htfLow;
            }
        }
    }
    
    // Check if our trendline prices are near HTF swing levels
    double tolerancePips = m_HTFAlignmentTolerance * point;
    double avgPrice = (price1 + price2) / 2;
    
    for(int i = 0; i < ArraySize(htfSwings); i++)
    {
        if(MathAbs(htfSwings[i] - avgPrice) <= tolerancePips)
        {
            return true; // HTF alignment found
        }
    }
    
    return false; // No HTF alignment
}

// NEW: Helper functions for swing point management
bool CTL_HL_Math::SwingPointExists(datetime time, double price, bool isHigh)
{
    double point = SymbolInfoDouble(m_CurrentSymbol, SYMBOL_POINT);
    for(int i = 0; i < ArraySize(m_SwingPoints); i++)
    {
        if(m_SwingPoints[i].time == time && 
           MathAbs(m_SwingPoints[i].price - price) < point &&
           m_SwingPoints[i].is_high == isHigh)
            return true;
    }
    return false;
}

bool CTL_HL_Math::SRSwingPointExists(datetime time, double price, bool isHigh)
{
    double point = SymbolInfoDouble(m_CurrentSymbol, SYMBOL_POINT);
    for(int i = 0; i < ArraySize(m_SRSwingPoints); i++)
    {
        if(m_SRSwingPoints[i].time == time && 
           MathAbs(m_SRSwingPoints[i].price - price) < point &&
           m_SRSwingPoints[i].is_high == isHigh)
            return true;
    }
    return false;
}

void CTL_HL_Math::AddSwingPoint(datetime time, double price, int barIndex, bool isHigh)
{
    int size = ArraySize(m_SwingPoints);
    ArrayResize(m_SwingPoints, size + 1);
    
    m_SwingPoints[size].time = time;
    m_SwingPoints[size].price = price;
    m_SwingPoints[size].bar_index = barIndex;
    m_SwingPoints[size].is_high = isHigh;
}

void CTL_HL_Math::AddSRSwingPoint(datetime time, double price, int barIndex, bool isHigh)
{
    int size = ArraySize(m_SRSwingPoints);
    ArrayResize(m_SRSwingPoints, size + 1);
    
    m_SRSwingPoints[size].time = time;
    m_SRSwingPoints[size].price = price;
    m_SRSwingPoints[size].bar_index = barIndex;
    m_SRSwingPoints[size].is_high = isHigh;
}

bool CTL_HL_Math::SRLevelExists(double price)
{
    double tolerancePips = m_SRTolerance * SymbolInfoDouble(m_CurrentSymbol, SYMBOL_POINT);
    
    for(int i = 0; i < ArraySize(m_HorizontalLevels); i++)
    {
        if(MathAbs(m_HorizontalLevels[i].price - price) <= tolerancePips)
            return true;
    }
    return false;
}

// NEW: Enhanced validation methods
void CTL_HL_Math::ValidateExistingTrendlines()
{
    for(int i = 0; i < ArraySize(m_TrendLines); i++)
    {
        if(m_TrendLines[i].isValidated) continue;
        
        // Count touches and measure rejection strength
        CountTouchesAndRejection(i);
        
        // Check if meets validation criteria
        if(m_TrendLines[i].touchCount >= m_MinTouches && 
           m_TrendLines[i].totalRejection >= m_MinRejectionPips)
        {
            m_TrendLines[i].isValidated = true;
            m_TrendLines[i].strength = m_TrendLines[i].touchCount * 15.0; // Higher strength for validated
            
            Print("Trendline VALIDATED: ", m_TrendLines[i].objectName, 
                  " - Touches: ", m_TrendLines[i].touchCount, 
                  ", Rejection: ", DoubleToString(m_TrendLines[i].totalRejection, 1), " pips");
        }
        else
        {
            // Check if enough time has passed for validation
            if(TimeCurrent() - m_TrendLines[i].creationTime > m_ValidationBars * PeriodSeconds(m_CurrentTimeframe))
            {
                // Remove weak trendlines
                if(m_TrendLines[i].touchCount < m_MinTouches || 
                   m_TrendLines[i].totalRejection < m_MinRejectionPips)
                {
                    Print("Removing weak trendline: ", m_TrendLines[i].objectName);
                    
                    // Remove from array
                    for(int j = i; j < ArraySize(m_TrendLines) - 1; j++)
                    {
                        m_TrendLines[j] = m_TrendLines[j + 1];
                    }
                    ArrayResize(m_TrendLines, ArraySize(m_TrendLines) - 1);
                    i--; // Adjust index
                }
            }
        }
    }
}

void CTL_HL_Math::ValidateExistingSRLevels()
{
    double currentPrice = iClose(m_CurrentSymbol, m_CurrentTimeframe, 0);
    double maxDistance = m_MaxSRDistance * SymbolInfoDouble(m_CurrentSymbol, SYMBOL_POINT);
    double tolerance = m_SRTolerance * SymbolInfoDouble(m_CurrentSymbol, SYMBOL_POINT);
    
    for(int i = 0; i < ArraySize(m_HorizontalLevels); i++)
    {
        double levelPrice = m_HorizontalLevels[i].price;
        
        // Remove levels that are now too far from current price
        if(MathAbs(levelPrice - currentPrice) > maxDistance && !m_HorizontalLevels[i].isPsychological)
        {
            Print("Removing distant S/R level: ", DoubleToString(levelPrice, 5));
            
            // Remove from array
            for(int j = i; j < ArraySize(m_HorizontalLevels) - 1; j++)
            {
                m_HorizontalLevels[j] = m_HorizontalLevels[j + 1];
            }
            ArrayResize(m_HorizontalLevels, ArraySize(m_HorizontalLevels) - 1);
            i--; // Adjust index
            continue;
        }
        
        // Skip validation for psychological and HTF levels
        if(!m_HorizontalLevels[i].isPsychological && !m_HorizontalLevels[i].isHTFLevel)
        {
            // Check for new touches and rejections
            CountSRTouchesAndRejection(i);
            
            // Remove weak levels after validation period
            if(!m_HorizontalLevels[i].isValidated && 
               TimeCurrent() - m_HorizontalLevels[i].creationTime > m_ValidationBars * PeriodSeconds(m_CurrentTimeframe))
            {
                if(m_HorizontalLevels[i].touchCount < m_MinSRTouches || 
                   m_HorizontalLevels[i].totalRejection < m_MinSRRejection)
                {
                    Print("Removing weak S/R level: ", DoubleToString(levelPrice, 5));
                    
                    // Remove from array
                    for(int j = i; j < ArraySize(m_HorizontalLevels) - 1; j++)
                    {
                        m_HorizontalLevels[j] = m_HorizontalLevels[j + 1];
                    }
                    ArrayResize(m_HorizontalLevels, ArraySize(m_HorizontalLevels) - 1);
                    i--; // Adjust index
                    continue;
                }
            }
        }
        
        // Check if level is broken
        bool wasBroken = false;
        if(!m_HorizontalLevels[i].isSupport && currentPrice > levelPrice + tolerance)
        {
            wasBroken = true;
        }
        else if(m_HorizontalLevels[i].isSupport && currentPrice < levelPrice - tolerance)
        {
            wasBroken = true;
        }
        
        if(wasBroken && !m_HorizontalLevels[i].isBroken)
        {
            m_HorizontalLevels[i].isBroken = true;
            Print("S/R Level BROKEN: ", DoubleToString(levelPrice, 5));
        }
        
        // Validate strong levels
        if(!m_HorizontalLevels[i].isValidated && 
           !m_HorizontalLevels[i].isPsychological && 
           !m_HorizontalLevels[i].isHTFLevel &&
           m_HorizontalLevels[i].touchCount >= m_MinSRTouches && 
           m_HorizontalLevels[i].totalRejection >= m_MinSRRejection)
        {
            m_HorizontalLevels[i].isValidated = true;
            m_HorizontalLevels[i].strength = m_HorizontalLevels[i].touchCount * 10.0;
            
            Print("S/R Level VALIDATED: ", DoubleToString(levelPrice, 5));
        }
    }
}

void CTL_HL_Math::CountTouchesAndRejection(int dataIndex)
{
    // Get trendline coordinates
    double slope = (m_TrendLines[dataIndex].endPrice - m_TrendLines[dataIndex].startPrice) / 
                   (double)(m_TrendLines[dataIndex].endTime - m_TrendLines[dataIndex].startTime);
    
    int touches = 0;
    double totalRejection = 0;
    
    // Check bars since creation
    datetime creationTime = m_TrendLines[dataIndex].creationTime;
    int startBar = iBarShift(m_CurrentSymbol, m_CurrentTimeframe, creationTime);
    
    for(int i = 0; i <= startBar && i < m_ValidationBars; i++)
    {
        datetime barTime = iTime(m_CurrentSymbol, m_CurrentTimeframe, i);
        double high = iHigh(m_CurrentSymbol, m_CurrentTimeframe, i);
        double low = iLow(m_CurrentSymbol, m_CurrentTimeframe, i);
        double close = iClose(m_CurrentSymbol, m_CurrentTimeframe, i);
        double open = iOpen(m_CurrentSymbol, m_CurrentTimeframe, i);
        
        // Calculate trendline price at this time
        double trendlinePrice = m_TrendLines[dataIndex].startPrice + 
                               slope * (barTime - m_TrendLines[dataIndex].startTime);
        
        double touchTolerance = SymbolInfoDouble(m_CurrentSymbol, SYMBOL_POINT) * 20; // 20 pips tolerance
        
        if(!m_TrendLines[dataIndex].isSupport) // Resistance
        {
            // Check if price touched resistance and rejected
            if(high >= trendlinePrice - touchTolerance && high <= trendlinePrice + touchTolerance)
            {
                if(close < open) // Rejection candle (bearish)
                {
                    touches++;
                    double rejection = (high - close) / SymbolInfoDouble(m_CurrentSymbol, SYMBOL_POINT);
                    totalRejection += rejection;
                }
            }
        }
        else // Support
        {
            // Check if price touched support and rejected
            if(low >= trendlinePrice - touchTolerance && low <= trendlinePrice + touchTolerance)
            {
                if(close > open) // Rejection candle (bullish)
                {
                    touches++;
                    double rejection = (close - low) / SymbolInfoDouble(m_CurrentSymbol, SYMBOL_POINT);
                    totalRejection += rejection;
                }
            }
        }
    }
    
    m_TrendLines[dataIndex].touchCount = touches;
    m_TrendLines[dataIndex].totalRejection = totalRejection;
}

void CTL_HL_Math::CountSRTouchesAndRejection(int levelIndex)
{
    double levelPrice = m_HorizontalLevels[levelIndex].price;
    double tolerance = m_SRTolerance * SymbolInfoDouble(m_CurrentSymbol, SYMBOL_POINT);
    
    int touches = 0;
    double totalRejection = 0;
    datetime lastTouch = m_HorizontalLevels[levelIndex].lastTouch;
    
    // Check recent bars for touches
    for(int i = 1; i <= 100; i++) // Check last 100 bars
    {
        datetime barTime = iTime(m_CurrentSymbol, m_CurrentTimeframe, i);
        if(barTime <= m_HorizontalLevels[levelIndex].creationTime)
            break;
        
        double high = iHigh(m_CurrentSymbol, m_CurrentTimeframe, i);
        double low = iLow(m_CurrentSymbol, m_CurrentTimeframe, i);
        double close = iClose(m_CurrentSymbol, m_CurrentTimeframe, i);
        double open = iOpen(m_CurrentSymbol, m_CurrentTimeframe, i);
        
        // Check for touches and rejections
        if(high >= levelPrice - tolerance && low <= levelPrice + tolerance)
        {
            touches++;
            lastTouch = barTime;
            
            // Measure rejection strength
            if(levelPrice > (high + low) / 2) // Acting as resistance
            {
                if(close < open) // Bearish rejection
                {
                    totalRejection += (high - close) / SymbolInfoDouble(m_CurrentSymbol, SYMBOL_POINT);
                }
            }
            else // Acting as support
            {
                if(close > open) // Bullish rejection
                {
                    totalRejection += (close - low) / SymbolInfoDouble(m_CurrentSymbol, SYMBOL_POINT);
                }
            }
        }
    }
    
    m_HorizontalLevels[levelIndex].touchCount += touches;
    m_HorizontalLevels[levelIndex].totalRejection += totalRejection;
    if(lastTouch > m_HorizontalLevels[levelIndex].lastTouch)
        m_HorizontalLevels[levelIndex].lastTouch = lastTouch;
}

void CTL_HL_Math::CleanupOldLevels()
{
    // Remove levels older than a certain age to prevent memory issues
    datetime maxAge = 7 * 24 * 3600; // 7 days
    datetime currentTime = TimeCurrent();
    
    // Clean up old trendlines
    for(int i = ArraySize(m_TrendLines) - 1; i >= 0; i--)
    {
        if(currentTime - m_TrendLines[i].creationTime > maxAge && !m_TrendLines[i].isValidated)
        {
            for(int j = i; j < ArraySize(m_TrendLines) - 1; j++)
            {
                m_TrendLines[j] = m_TrendLines[j + 1];
            }
            ArrayResize(m_TrendLines, ArraySize(m_TrendLines) - 1);
        }
    }
    
    // Clean up old S/R levels (except psychological and HTF levels)
    for(int i = ArraySize(m_HorizontalLevels) - 1; i >= 0; i--)
    {
        if(!m_HorizontalLevels[i].isPsychological && !m_HorizontalLevels[i].isHTFLevel &&
           currentTime - m_HorizontalLevels[i].creationTime > maxAge && 
           !m_HorizontalLevels[i].isValidated)
        {
            for(int j = i; j < ArraySize(m_HorizontalLevels) - 1; j++)
            {
                m_HorizontalLevels[j] = m_HorizontalLevels[j + 1];
            }
            ArrayResize(m_HorizontalLevels, ArraySize(m_HorizontalLevels) - 1);
        }
    }
}

// Rest of the class implementation remains the same as the original...
// (Including all the existing methods like UpdateOscillators, GetOscillatorData, etc.)

//+------------------------------------------------------------------+
//| Find trendlines (now uses enhanced 3-point method)              |
//+------------------------------------------------------------------+
int CTL_HL_Math::FindTrendLines(string symbol, ENUM_TIMEFRAMES timeframe, int barsBack)
{
    // The enhanced method is now called from UpdateTechnicalAnalysis
    // This method now just returns the current count
    return ArraySize(m_TrendLines);
}

//+------------------------------------------------------------------+
//| Find horizontal levels (now uses enhanced SR method)            |
//+------------------------------------------------------------------+
int CTL_HL_Math::FindHorizontalLevels(string symbol, ENUM_TIMEFRAMES timeframe, int barsBack)
{
    // The enhanced method is now called from UpdateTechnicalAnalysis
    // This method now just returns the current count
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
    empty.creationTime = 0;
    empty.totalRejection = 0;
    empty.isValidated = false;
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
    empty.creationTime = 0;
    empty.totalRejection = 0;
    empty.isValidated = false;
    empty.isBroken = false;
    empty.isPsychological = false;
    empty.isHTFLevel = false;
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

   color c = m_NeutralLevelColor; // Default color
   
   // NEW: Enhanced color selection based on level type
   if(level.isPsychological) {
      c = m_PsychologicalColor;
   } else if(level.isHTFLevel) {
      c = level.isSupport ? m_SupportColor : m_ResistanceColor;
   } else if(level.isValidated) {
      c = level.isSupport ? m_SupportColor : m_ResistanceColor;
   }

   int style = STYLE_DOT;
   int width = m_LineWidth;
   
   // NEW: Enhanced visual styling based on level properties
   if(level.isHTFLevel) {
      style = STYLE_DASH;
      width = 2;
   } else if(level.isValidated) {
      style = STYLE_SOLID;
      width = 2;
   } else if(level.isPsychological) {
      style = STYLE_DOT;
      width = 1;
   }

   bool ok = JCT_DrawHLineCapped(
      m_CurrentSymbol, m_CurrentTimeframe, "SR",
      level.price, c, style, width
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
    
    // Clear using the enhanced clearing method
    JCT_ClearSRForModule(m_CurrentSymbol, m_CurrentTimeframe, "SR");
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
    
    // Check age of level (skip for psychological and HTF levels)
    if(!level.isPsychological && !level.isHTFLevel)
    {
        datetime maxAge = 60 * 24 * 3600; // 60 days
        if(TimeCurrent() - level.lastTouch > maxAge) return false;
    }
    
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