//+------------------------------------------------------------------+
//|                                           JcampFxIndicator.mq5 |
//|                                                    JcampFx Team |
//|                    Indicator EA for Multi-Pair Chart Analysis   |
//+------------------------------------------------------------------+
#property copyright "JcampFx Team"
#property link      ""
#property version   "1.01"
#property description "Indicator EA that draws trendlines and horizontal levels on individual pair charts - UPDATED WITH LIMITS"

#include "..\\..\\Experts\\JcampFxTrading\\TL_HL_Math.mqh"

//--- Input Parameters
input group "=== INDICATOR SETTINGS ==="
input bool InpDrawTrendlines = true;                   // Draw Trendlines
input bool InpDrawHorizontalLevels = true;             // Draw Horizontal Levels  
input bool InpUpdateOnNewBar = true;                   // Update Only on New Bar
input int InpTrendlineBars = 100;                      // Trendline Lookback Bars
input int InpHorizontalBars = 200;                     // Horizontal Level Lookback Bars

input group "=== DRAWING LIMITS ==="
input int InpMaxSRLevels = 3;                          // Max S/R Levels per Direction
input bool InpShowWeakLevels = false;                  // Show Weak Levels (< 3 touches)

input group "=== VISUAL SETTINGS ==="
input color InpSupportColor = clrGreen;                // Support Color
input color InpResistanceColor = clrRed;               // Resistance Color
input color InpTrendlineColor = clrBlue;               // Trendline Color
input int InpLineWidth = 1;                            // Line Width
input ENUM_LINE_STYLE InpLineStyle = STYLE_SOLID;      // Line Style

input group "=== ANALYSIS SETTINGS ==="
input bool InpShowOscillatorInfo = false;              // Show Oscillator Info
input bool InpShowMACDInfo = false;                    // Show MACD Info
input int InpInfoCorner = CORNER_LEFT_UPPER;           // Info Panel Corner
input int InpInfoXOffset = 10;                         // Info X Offset
input int InpInfoYOffset = 30;                         // Info Y Offset

input group "=== TRENDLINE SETTINGS (Indicator) ==="
input int    InpMaxTrendlines      = 3;    // Max trendlines per side (support/resistance)
input double InpTL_TolPipsMin      = 2.0;  // Minimum touch tolerance (pips)
input double InpTL_TolATRMult      = 0.20; // ATR multiplier for tolerance
input double InpTL_SlopePctTol     = 7.5;  // Lines considered similar if slope diff < this %
input double InpTL_PriceTolPips    = 2.0;  // ...and price at recent anchor within this many pips


//--- Global Variables
CTL_HL_Math* g_MathLib = NULL;
datetime g_LastUpdate = 0;
datetime g_LastBarTime = 0;
string g_CurrentSymbol = "";
bool g_IsInitialized = false;

//--- Info panel variables
string g_InfoObjects[];
int g_InfoObjectCount = 0;

//--- Drawing management
struct TrendLineDrawData
{
    TrendLineData data;
    double strength;
    bool isSupport;
};

struct HorizontalLevelDrawData
{
    HorizontalLevelData data;
    double strength;
    bool isSupport;
};

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    Print("=== JcampFx Indicator EA Starting on ", Symbol(), " (v1.01) ===");
    
    g_CurrentSymbol = Symbol();
    
    // Initialize math library
    g_MathLib = new CTL_HL_Math();
    if(!g_MathLib.Initialize())
    {
        Print("ERROR: Failed to initialize Math Library for ", g_CurrentSymbol);
        return INIT_FAILED;
    }
    
    // Pass indicator-specific TL settings to the shared library
    g_MathLib.SetTrendlineParams(
       InpTL_TolPipsMin,      // min tolerance in pips
       InpTL_TolATRMult,      // ATR multiplier
       InpMaxTrendlines,      // keep best N per side
       InpTL_SlopePctTol,     // slope similarity (%)
       InpTL_PriceTolPips     // price proximity (pips)
    );
   
    // Mark this chart as the drawing surface for the library
    g_MathLib.SetupChart(Symbol(), Period(), true);
   
    // Initial compute + draw
    g_MathLib.UpdateTechnicalAnalysis(Symbol(), Period());
    g_MathLib.UpdateDrawings();
    ChartRedraw();

    // Setup chart for this symbol
    if(!g_MathLib.SetupChart(g_CurrentSymbol, Period(), false)) // false = not main chart
    {
        Print("ERROR: Failed to setup chart for ", g_CurrentSymbol);
        return INIT_FAILED;
    }
    
    // Set visual properties
    SetVisualProperties();
    
    // Initialize info panel
    if(InpShowOscillatorInfo || InpShowMACDInfo)
    {
        InitializeInfoPanel();
    }
    
    // Perform initial analysis
    PerformAnalysis();
    
    g_IsInitialized = true;
    Print("JcampFx Indicator EA initialized successfully for ", g_CurrentSymbol);
    Print("Drawing Limits: Trendlines=", InpMaxTrendlines, " per direction, S/R=", InpMaxSRLevels, " per direction");
    
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    // Clean up drawings
    CleanupDrawings();
    
    // Clean up info panel
    CleanupInfoPanel();
    
    if(g_MathLib != NULL)
    {
       // optional: clear our drawings on deinit
       g_MathLib.ClearDrawings();
       delete g_MathLib;
       g_MathLib = NULL;
    }
    
    Print("JcampFx Indicator EA stopped for ", g_CurrentSymbol, ". Reason: ", reason);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    if(!g_IsInitialized) return;
    
    datetime currentBarTime = iTime(g_CurrentSymbol, Period(), 0);
    bool isNewBar = (currentBarTime != g_LastBarTime);
    
    // Update on new bar or if forced update
    if(!InpUpdateOnNewBar || isNewBar)
    {
        // Don't update too frequently
        if(TimeCurrent() - g_LastUpdate < 60) // Minimum 1 minute between updates
            return;
        
        PerformAnalysis();
        g_LastUpdate = TimeCurrent();
    }
    
    if(isNewBar)
        g_LastBarTime = currentBarTime;
    
    // Update info panel if enabled
    if(InpShowOscillatorInfo || InpShowMACDInfo)
    {
        UpdateInfoPanel();
    }
}

//+------------------------------------------------------------------+
//| Perform technical analysis and update drawings                   |
//+------------------------------------------------------------------+
void PerformAnalysis()
{
    if(g_MathLib == NULL) return;
    
    // Update technical analysis for current symbol
    if(!g_MathLib.UpdateTechnicalAnalysis(g_CurrentSymbol, Period()))
    {
        Print("WARNING: Failed to update technical analysis for ", g_CurrentSymbol);
        return;
    }
    
    // Clean previous drawings
    CleanupDrawings();
    
    // Draw trendlines if enabled
    if(InpDrawTrendlines)
    {
        DrawTrendlinesWithLimits();
    }
    
    // Draw horizontal levels if enabled
    if(InpDrawHorizontalLevels)
    {
        DrawHorizontalLevelsWithLimits();
    }
    
    // Redraw chart
    ChartRedraw();
}

//+------------------------------------------------------------------+
//| Draw trendlines with strength-based limits                      |
//+------------------------------------------------------------------+
void DrawTrendlinesWithLimits()
{
    int trendlineCount = g_MathLib.GetTrendLineCount();
    if(trendlineCount == 0) return;
    
    // Collect all trendlines with their strength
    TrendLineDrawData trendlineArray[];
    ArrayResize(trendlineArray, trendlineCount);
    
    int validCount = 0;
    for(int i = 0; i < trendlineCount; i++)
    {
        TrendLineData trendLine = g_MathLib.GetTrendLine(i);
        
        // Validate trendline
        if(!g_MathLib.IsTrendLineValid(trendLine, TimeCurrent(), SymbolInfoDouble(g_CurrentSymbol, SYMBOL_BID)))
            continue;
        
        // Filter out weak trendlines if not requested
        if(!InpShowWeakLevels && trendLine.touchCount < 3)
            continue;
        
        trendlineArray[validCount].data = trendLine;
        trendlineArray[validCount].strength = trendLine.strength;
        trendlineArray[validCount].isSupport = trendLine.isSupport;
        validCount++;
    }
    
    if(validCount == 0) return;
    
    // Sort by strength (descending)
    SortTrendLinesByStrength(trendlineArray, validCount);
    
    // Draw limited number of strongest trendlines
    int supportDrawn = 0;
    int resistanceDrawn = 0;
    
    for(int i = 0; i < validCount; i++)
    {
        if(trendlineArray[i].isSupport)
        {
            if(supportDrawn >= InpMaxTrendlines) continue;
            supportDrawn++;
        }
        else
        {
            if(resistanceDrawn >= InpMaxTrendlines) continue;
            resistanceDrawn++;
        }
        
        DrawSingleTrendline(trendlineArray[i].data);
    }
    
    // Log drawing summary
    if(supportDrawn > 0 || resistanceDrawn > 0)
    {
        Print(StringFormat("Drew %d support + %d resistance trendlines for %s", 
                          supportDrawn, resistanceDrawn, g_CurrentSymbol));
    }
}

//+------------------------------------------------------------------+
//| Draw horizontal levels with strength-based limits               |
//+------------------------------------------------------------------+
void DrawHorizontalLevelsWithLimits()
{
    int levelCount = g_MathLib.GetHorizontalLevelCount();
    if(levelCount == 0) return;
    
    // Collect all levels with their strength
    HorizontalLevelDrawData levelArray[];
    ArrayResize(levelArray, levelCount);
    
    int validCount = 0;
    double currentPrice = SymbolInfoDouble(g_CurrentSymbol, SYMBOL_BID);
    double tolerance = 20 * SymbolInfoDouble(g_CurrentSymbol, SYMBOL_POINT);
    
    for(int i = 0; i < levelCount; i++)
    {
        HorizontalLevelData level = g_MathLib.GetHorizontalLevel(i);
        
        // Validate level
        if(!g_MathLib.IsHorizontalLevelValid(level, currentPrice, tolerance))
            continue;
        
        // Filter out weak levels if not requested
        if(!InpShowWeakLevels && level.touchCount < 3)
            continue;
        
        levelArray[validCount].data = level;
        levelArray[validCount].strength = level.strength;
        levelArray[validCount].isSupport = level.isSupport;
        validCount++;
    }
    
    if(validCount == 0) return;
    
    // Sort by strength (descending)
    SortHorizontalLevelsByStrength(levelArray, validCount);
    
    // Draw limited number of strongest levels
    int supportDrawn = 0;
    int resistanceDrawn = 0;
    
    for(int i = 0; i < validCount; i++)
    {
        if(levelArray[i].isSupport)
        {
            if(supportDrawn >= InpMaxSRLevels) continue;
            supportDrawn++;
        }
        else
        {
            if(resistanceDrawn >= InpMaxSRLevels) continue;
            resistanceDrawn++;
        }
        
        DrawSingleHorizontalLevel(levelArray[i].data);
    }
    
    // Log drawing summary
    if(supportDrawn > 0 || resistanceDrawn > 0)
    {
        Print(StringFormat("Drew %d support + %d resistance levels for %s", 
                          supportDrawn, resistanceDrawn, g_CurrentSymbol));
    }
}

//+------------------------------------------------------------------+
//| Draw single trendline                                           |
//+------------------------------------------------------------------+
void DrawSingleTrendline(TrendLineData &trendLine)
{
    // Create unique object name
    string objName = StringFormat("JcampTL_%s_%d_%s", 
                                 g_CurrentSymbol, 
                                 (int)trendLine.startTime,
                                 trendLine.isSupport ? "S" : "R");
    
    // Delete existing object
    ObjectDelete(0, objName);
    
    // Create trendline object
    if(ObjectCreate(0, objName, OBJ_TREND, 0, 
                   trendLine.startTime, trendLine.startPrice,
                   trendLine.endTime, trendLine.endPrice))
    {
        // Set visual properties
        ObjectSetInteger(0, objName, OBJPROP_COLOR, InpTrendlineColor);
        ObjectSetInteger(0, objName, OBJPROP_WIDTH, InpLineWidth);
        ObjectSetInteger(0, objName, OBJPROP_STYLE, InpLineStyle);
        ObjectSetInteger(0, objName, OBJPROP_RAY_RIGHT, true);
        ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
        ObjectSetInteger(0, objName, OBJPROP_BACK, false);
        
        // Set tooltip with strength info
        string strengthText = "STRONG";
        if(trendLine.strength < 20) strengthText = "WEAK";
        else if(trendLine.strength < 40) strengthText = "MEDIUM";
        
        ObjectSetString(0, objName, OBJPROP_TOOLTIP, 
                       StringFormat("%s Trendline (%s) - Touches: %d, Strength: %.1f", 
                                   trendLine.isSupport ? "Support" : "Resistance",
                                   strengthText,
                                   trendLine.touchCount, trendLine.strength));
    }
}

//+------------------------------------------------------------------+
//| Draw single horizontal level                                     |
//+------------------------------------------------------------------+
void DrawSingleHorizontalLevel(HorizontalLevelData &level)
{
    // Create unique object name
    string objName = StringFormat("JcampHL_%s_%.5f_%s", 
                                 g_CurrentSymbol, 
                                 level.price,
                                 level.isSupport ? "S" : "R");
    
    // Delete existing object
    ObjectDelete(0, objName);
    
    // Create horizontal line object
    if(ObjectCreate(0, objName, OBJ_HLINE, 0, 0, level.price))
    {
        // Set visual properties
        color lineColor = level.isSupport ? InpSupportColor : InpResistanceColor;
        ObjectSetInteger(0, objName, OBJPROP_COLOR, lineColor);
        ObjectSetInteger(0, objName, OBJPROP_WIDTH, InpLineWidth);
        ObjectSetInteger(0, objName, OBJPROP_STYLE, InpLineStyle);
        ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
        ObjectSetInteger(0, objName, OBJPROP_BACK, false);
        
        // Set tooltip with strength info
        string strengthText = "STRONG";
        if(level.strength < 15) strengthText = "WEAK";
        else if(level.strength < 30) strengthText = "MEDIUM";
        
        ObjectSetString(0, objName, OBJPROP_TOOLTIP,
                       StringFormat("%s Level (%s) - Price: %.5f, Touches: %d, Strength: %.1f",
                                   level.isSupport ? "Support" : "Resistance",
                                   strengthText,
                                   level.price, level.touchCount, level.strength));
    }
}

//+------------------------------------------------------------------+
//| Sort trendlines by strength (descending)                        |
//+------------------------------------------------------------------+
void SortTrendLinesByStrength(TrendLineDrawData &array[], int count)
{
    for(int i = 0; i < count - 1; i++)
    {
        for(int j = i + 1; j < count; j++)
        {
            if(array[j].strength > array[i].strength)
            {
                TrendLineDrawData temp = array[i];
                array[i] = array[j];
                array[j] = temp;
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Sort horizontal levels by strength (descending)                 |
//+------------------------------------------------------------------+
void SortHorizontalLevelsByStrength(HorizontalLevelDrawData &array[], int count)
{
    for(int i = 0; i < count - 1; i++)
    {
        for(int j = i + 1; j < count; j++)
        {
            if(array[j].strength > array[i].strength)
            {
                HorizontalLevelDrawData temp = array[i];
                array[i] = array[j];
                array[j] = temp;
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Set visual properties                                            |
//+------------------------------------------------------------------+
void SetVisualProperties()
{
    // Set chart properties for better visibility
    ChartSetInteger(0, CHART_SHOW_GRID, false);
    ChartSetInteger(0, CHART_SHOW_PERIOD_SEP, true);
    ChartSetInteger(0, CHART_MODE, CHART_CANDLES);
}

//+------------------------------------------------------------------+
//| Initialize info panel                                            |
//+------------------------------------------------------------------+
void InitializeInfoPanel()
{
    ArrayResize(g_InfoObjects, 25); // Increased for more info
    g_InfoObjectCount = 0;
    
    // Create background panel
    string bgName = "JcampInfo_BG_" + g_CurrentSymbol;
    ObjectDelete(0, bgName);
    
    if(ObjectCreate(0, bgName, OBJ_RECTANGLE_LABEL, 0, 0, 0))
    {
        ObjectSetInteger(0, bgName, OBJPROP_CORNER, InpInfoCorner);
        ObjectSetInteger(0, bgName, OBJPROP_XDISTANCE, InpInfoXOffset - 5);
        ObjectSetInteger(0, bgName, OBJPROP_YDISTANCE, InpInfoYOffset - 5);
        ObjectSetInteger(0, bgName, OBJPROP_XSIZE, 220);
        ObjectSetInteger(0, bgName, OBJPROP_YSIZE, 140);
        ObjectSetInteger(0, bgName, OBJPROP_BGCOLOR, clrBlack);
        ObjectSetInteger(0, bgName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
        ObjectSetInteger(0, bgName, OBJPROP_COLOR, clrWhite);
        ObjectSetInteger(0, bgName, OBJPROP_WIDTH, 1);
        ObjectSetInteger(0, bgName, OBJPROP_BACK, true);
        ObjectSetInteger(0, bgName, OBJPROP_SELECTABLE, false);
        
        g_InfoObjects[g_InfoObjectCount] = bgName;
        g_InfoObjectCount++;
    }
}

//+------------------------------------------------------------------+
//| Update info panel                                                |
//+------------------------------------------------------------------+
void UpdateInfoPanel()
{
    if(g_MathLib == NULL) return;
    
    int yOffset = InpInfoYOffset;
    
    // Add symbol header
    CreateInfoLabel("Symbol: " + g_CurrentSymbol, yOffset);
    yOffset += 15;
    
    if(InpShowOscillatorInfo)
    {
        OscillatorData osc = g_MathLib.GetOscillatorData();
        
        CreateInfoLabel(StringFormat("RSI: %.1f", osc.rsi), yOffset);
        yOffset += 12;
        
        CreateInfoLabel(StringFormat("Stoch: %.1f", osc.stochastic), yOffset);
        yOffset += 12;
        
        CreateInfoLabel(StringFormat("Williams: %.1f", osc.williams), yOffset);
        yOffset += 12;
        
        string oscStatus = "";
        if(osc.overbought) oscStatus = "Overbought";
        else if(osc.oversold) oscStatus = "Oversold";
        else oscStatus = "Neutral";
        
        CreateInfoLabel("Status: " + oscStatus, yOffset);
        yOffset += 15;
    }
    
    if(InpShowMACDInfo)
    {
        MACDData macd = g_MathLib.GetMACDData();
        
        CreateInfoLabel(StringFormat("MACD: %.5f", macd.main), yOffset);
        yOffset += 12;
        
        CreateInfoLabel(StringFormat("Signal: %.5f", macd.signal), yOffset);
        yOffset += 12;
        
        CreateInfoLabel(StringFormat("Hist: %.5f", macd.histogram), yOffset);
        yOffset += 12;
        
        string macdStatus = "Neutral";
        if(macd.bullishCrossover) macdStatus = "Bullish Cross";
        else if(macd.bearishCrossover) macdStatus = "Bearish Cross";
        
        CreateInfoLabel("MACD: " + macdStatus, yOffset);
        yOffset += 15;
    }
    
    // Add levels info with drawing limits
    int supportCount = g_MathLib.GetHorizontalLevelCount(true, false);
    int resistanceCount = g_MathLib.GetHorizontalLevelCount(false, true);
    int trendlineCount = g_MathLib.GetTrendLineCount();
    
    CreateInfoLabel(StringFormat("S/R: %d/%d (max %d/%d)", 
                                 MathMin(supportCount, InpMaxSRLevels), 
                                 MathMin(resistanceCount, InpMaxSRLevels),
                                 InpMaxSRLevels, InpMaxSRLevels), yOffset);
    yOffset += 12;
    
    CreateInfoLabel(StringFormat("TL: %d (max %d/%d)", 
                                 MathMin(trendlineCount, InpMaxTrendlines * 2),
                                 InpMaxTrendlines, InpMaxTrendlines), yOffset);
    yOffset += 12;
    
    // Add drawing status
    CreateInfoLabel(StringFormat("Weak Levels: %s", InpShowWeakLevels ? "ON" : "OFF"), yOffset);
}

//+------------------------------------------------------------------+
//| Create info label                                                |
//+------------------------------------------------------------------+
void CreateInfoLabel(string text, int yPos)
{
    if(g_InfoObjectCount >= ArraySize(g_InfoObjects)) return;
    
    string objName = StringFormat("JcampInfo_%s_%d", g_CurrentSymbol, g_InfoObjectCount);
    
    ObjectDelete(0, objName);
    
    if(ObjectCreate(0, objName, OBJ_LABEL, 0, 0, 0))
    {
        ObjectSetInteger(0, objName, OBJPROP_CORNER, InpInfoCorner);
        ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, InpInfoXOffset);
        ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, yPos);
        ObjectSetString(0, objName, OBJPROP_TEXT, text);
        ObjectSetString(0, objName, OBJPROP_FONT, "Arial");
        ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, 8);
        ObjectSetInteger(0, objName, OBJPROP_COLOR, clrWhite);
        ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
        
        g_InfoObjects[g_InfoObjectCount] = objName;
        g_InfoObjectCount++;
    }
}

//+------------------------------------------------------------------+
//| Clean up all drawings                                            |
//+------------------------------------------------------------------+
void CleanupDrawings()
{
    // Remove all JcampTL and JcampHL objects for this symbol
    int objectsTotal = ObjectsTotal(0);
    
    for(int i = objectsTotal - 1; i >= 0; i--)
    {
        string objName = ObjectName(0, i);
        
        if(StringFind(objName, "JcampTL_" + g_CurrentSymbol) >= 0 ||
           StringFind(objName, "JcampHL_" + g_CurrentSymbol) >= 0)
        {
            ObjectDelete(0, objName);
        }
    }
}

//+------------------------------------------------------------------+
//| Clean up info panel                                              |
//+------------------------------------------------------------------+
void CleanupInfoPanel()
{
    // Remove all info objects
    for(int i = 0; i < g_InfoObjectCount; i++)
    {
        ObjectDelete(0, g_InfoObjects[i]);
    }
    
    // Remove background
    ObjectDelete(0, "JcampInfo_BG_" + g_CurrentSymbol);
    
    g_InfoObjectCount = 0;
}

//+------------------------------------------------------------------+
//| Chart event handler                                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long& lparam, const double& dparam, const string& sparam)
{
    // Handle chart events if needed
    switch(id)
    {
        case CHARTEVENT_CHART_CHANGE:
            // Redraw when chart changes
            PerformAnalysis();
            break;
            
        case CHARTEVENT_OBJECT_CLICK:
            // Handle object clicks if needed
            if(StringFind(sparam, "JcampTL_") >= 0 || StringFind(sparam, "JcampHL_") >= 0)
            {
                // Could add level/trendline info display on click
                Print("Clicked on: ", sparam);
            }
            break;
    }
}

//+------------------------------------------------------------------+
//| Timer event handler                                              |
//+------------------------------------------------------------------+
void OnTimer()
{
    // Only recompute/draw on a new bar to reduce flicker/CPU
    if(!g_MathLib.IsNewBar(Symbol(), Period()))
       return;

    g_MathLib.UpdateTechnicalAnalysis(Symbol(), Period());
    g_MathLib.UpdateDrawings();
    ChartRedraw();

    // Periodic updates if needed
    static datetime lastTimerUpdate = 0;
    
    if(TimeCurrent() - lastTimerUpdate >= 300) // Every 5 minutes
    {
        if(InpShowOscillatorInfo || InpShowMACDInfo)
        {
            UpdateInfoPanel();
        }
        lastTimerUpdate = TimeCurrent();
    }
}

//+------------------------------------------------------------------+