//+------------------------------------------------------------------+
//|                                           JcampFxIndicator.mq5 |
//|                                                    JcampFx Team |
//|                    Indicator EA for Multi-Pair Chart Analysis   |
//+------------------------------------------------------------------+
#property copyright "JcampFx Team"
#property link      ""
#property version   "1.00"
#property description "Indicator EA that draws trendlines and horizontal levels on individual pair charts"

#include "..\\..\\Experts\\JcampFxTrading\\TL_HL_Math.mqh"

//--- Input Parameters
input group "=== INDICATOR SETTINGS ==="
input bool InpDrawTrendlines = true;                   // Draw Trendlines
input bool InpDrawHorizontalLevels = true;             // Draw Horizontal Levels  
input bool InpUpdateOnNewBar = true;                   // Update Only on New Bar
input int InpTrendlineBars = 100;                      // Trendline Lookback Bars
input int InpHorizontalBars = 200;                     // Horizontal Level Lookback Bars

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

//--- Global Variables
CTL_HL_Math* g_MathLib;
datetime g_LastUpdate = 0;
datetime g_LastBarTime = 0;
string g_CurrentSymbol = "";
bool g_IsInitialized = false;

//--- Info panel variables
string g_InfoObjects[];
int g_InfoObjectCount = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    Print("=== JcampFx Indicator EA Starting on ", Symbol(), " ===");
    
    g_CurrentSymbol = Symbol();
    
    // Initialize math library
    g_MathLib = new CTL_HL_Math();
    if(!g_MathLib.Initialize())
    {
        Print("ERROR: Failed to initialize Math Library for ", g_CurrentSymbol);
        return INIT_FAILED;
    }
    
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
    
    // Delete math library
    if(g_MathLib != NULL)
    {
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
        DrawTrendlines();
    }
    
    // Draw horizontal levels if enabled
    if(InpDrawHorizontalLevels)
    {
        DrawHorizontalLevels();
    }
    
    // Redraw chart
    ChartRedraw();
}

//+------------------------------------------------------------------+
//| Draw all trendlines                                              |
//+------------------------------------------------------------------+
void DrawTrendlines()
{
    int trendlineCount = g_MathLib.GetTrendLineCount();
    
    for(int i = 0; i < trendlineCount; i++)
    {
        TrendLineData trendLine = g_MathLib.GetTrendLine(i);
        
        // Validate trendline
        if(!g_MathLib.IsTrendLineValid(trendLine, TimeCurrent(), SymbolInfoDouble(g_CurrentSymbol, SYMBOL_BID)))
            continue;
        
        // Create unique object name
        string objName = StringFormat("JcampTL_%s_%d_%s", 
                                     g_CurrentSymbol, 
                                     i, 
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
            
            // Set tooltip
            ObjectSetString(0, objName, OBJPROP_TOOLTIP, 
                           StringFormat("%s Trendline - Touches: %d, Strength: %.1f", 
                                       trendLine.isSupport ? "Support" : "Resistance",
                                       trendLine.touchCount, trendLine.strength));
        }
    }
}

//+------------------------------------------------------------------+
//| Draw all horizontal levels                                       |
//+------------------------------------------------------------------+
void DrawHorizontalLevels()
{
    int levelCount = g_MathLib.GetHorizontalLevelCount();
    
    for(int i = 0; i < levelCount; i++)
    {
        HorizontalLevelData level = g_MathLib.GetHorizontalLevel(i);
        
        // Create unique object name
        string objName = StringFormat("JcampHL_%s_%d_%s", 
                                     g_CurrentSymbol, 
                                     i, 
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
            
            // Set tooltip
            ObjectSetString(0, objName, OBJPROP_TOOLTIP,
                           StringFormat("%s Level - Price: %.5f, Touches: %d, Strength: %.1f",
                                       level.isSupport ? "Support" : "Resistance",
                                       level.price, level.touchCount, level.strength));
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
    ArrayResize(g_InfoObjects, 20); // Max 20 info objects
    g_InfoObjectCount = 0;
    
    // Create background panel
    string bgName = "JcampInfo_BG_" + g_CurrentSymbol;
    ObjectDelete(0, bgName);
    
    if(ObjectCreate(0, bgName, OBJ_RECTANGLE_LABEL, 0, 0, 0))
    {
        ObjectSetInteger(0, bgName, OBJPROP_CORNER, InpInfoCorner);
        ObjectSetInteger(0, bgName, OBJPROP_XDISTANCE, InpInfoXOffset - 5);
        ObjectSetInteger(0, bgName, OBJPROP_YDISTANCE, InpInfoYOffset - 5);
        ObjectSetInteger(0, bgName, OBJPROP_XSIZE, 200);
        ObjectSetInteger(0, bgName, OBJPROP_YSIZE, 120);
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
    
    // Add levels info
    int supportCount = g_MathLib.GetHorizontalLevelCount(true, false);
    int resistanceCount = g_MathLib.GetHorizontalLevelCount(false, true);
    int trendlineCount = g_MathLib.GetTrendLineCount();
    
    CreateInfoLabel(StringFormat("S/R: %d/%d", supportCount, resistanceCount), yOffset);
    yOffset += 12;
    
    CreateInfoLabel(StringFormat("Trendlines: %d", trendlineCount), yOffset);
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
    // Remove all JcampTL and JcampHL objects
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
            break;
    }
}

//+------------------------------------------------------------------+
//| Timer event handler                                              |
//+------------------------------------------------------------------+
void OnTimer()
{
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