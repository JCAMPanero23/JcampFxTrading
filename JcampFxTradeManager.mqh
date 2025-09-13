//+------------------------------------------------------------------+
//|                                         JcampFxTradeManager.mqh |
//|                                                    JcampFx Team |
//|                              Trade Management and Display Utils |
//+------------------------------------------------------------------+
#property copyright "JcampFx Team"
#property link      ""
#property version   "1.00"

// Structure for closed trade tracking
struct ClosedTradeData
{
    ulong ticket;
    string symbol;
    string strategy;
    datetime closeTime;
    double closePrice;
    double rMultiple;
    bool isWin;
    double profit;
};

//+------------------------------------------------------------------+
//| Trade Display and Management Class                               |
//+------------------------------------------------------------------+
class CTradeManager
{
private:
    ClosedTradeData m_ClosedTrades[];
    int m_ClosedTradeCount;
    
    // Performance tracking
    double m_TotalR;
    int m_TotalWins;
    int m_TotalLosses;
    
    // Strategy specific tracking
    double m_TrendRiderR;
    double m_ReversalsR;
    double m_NewsTradingR;
    int m_TrendRiderWins;
    int m_TrendRiderLosses;
    int m_ReversalsWins;
    int m_ReversalsLosses;
    int m_NewsTradingWins;
    int m_NewsTradingLosses;
    
    // Private helper method
    void CreatePanelLabel(string name, string text, int x, int y, 
                         color clr, int size, bool bold);
    
public:
    CTradeManager();
    ~CTradeManager();
    
    // Trade result management
    void RecordClosedTrade(ulong ticket, string symbol, string strategy, 
                          double rMultiple, bool isWin, double profit);
    void DisplayTradeResult(string symbol, datetime time, double price, 
                           double rMultiple, bool isWin, string strategy);
    void UpdatePerformanceTally();
    void DisplayPerformanceTally();
    
    // Chart text management
    void CreateTradeLabel(string symbol, datetime time, double price, 
                         string text, color clr);
    void CreatePerformancePanel();
    void UpdatePerformancePanel();
    
    // Getters
    double GetTotalR() { return m_TotalR; }
    int GetTotalWins() { return m_TotalWins; }
    int GetTotalLosses() { return m_TotalLosses; }
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CTradeManager::CTradeManager()
{
    m_ClosedTradeCount = 0;
    m_TotalR = 0;
    m_TotalWins = 0;
    m_TotalLosses = 0;
    
    m_TrendRiderR = 0;
    m_ReversalsR = 0;
    m_NewsTradingR = 0;
    m_TrendRiderWins = 0;
    m_TrendRiderLosses = 0;
    m_ReversalsWins = 0;
    m_ReversalsLosses = 0;
    m_NewsTradingWins = 0;
    m_NewsTradingLosses = 0;
    
    ArrayResize(m_ClosedTrades, 1000); // Max 1000 closed trades to track
    
    CreatePerformancePanel();
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CTradeManager::~CTradeManager()
{
    // Clean up chart objects
    ObjectsDeleteAll(0, "JcampTrade_");
    ObjectsDeleteAll(0, "JcampPerf_");
}

//+------------------------------------------------------------------+
//| Record closed trade                                              |
//+------------------------------------------------------------------+
void CTradeManager::RecordClosedTrade(ulong ticket, string symbol, string strategy, 
                                      double rMultiple, bool isWin, double profit)
{
    if(m_ClosedTradeCount < ArraySize(m_ClosedTrades))
    {
        m_ClosedTrades[m_ClosedTradeCount].ticket = ticket;
        m_ClosedTrades[m_ClosedTradeCount].symbol = symbol;
        m_ClosedTrades[m_ClosedTradeCount].strategy = strategy;
        m_ClosedTrades[m_ClosedTradeCount].closeTime = TimeCurrent();
        m_ClosedTrades[m_ClosedTradeCount].closePrice = SymbolInfoDouble(symbol, SYMBOL_BID);
        m_ClosedTrades[m_ClosedTradeCount].rMultiple = rMultiple;
        m_ClosedTrades[m_ClosedTradeCount].isWin = isWin;
        m_ClosedTrades[m_ClosedTradeCount].profit = profit;
        
        m_ClosedTradeCount++;
        
        // Update totals
        m_TotalR += (isWin ? rMultiple : -MathAbs(rMultiple));
        
        if(isWin)
        {
            m_TotalWins++;
            
            if(strategy == "TrendRider")
            {
                m_TrendRiderWins++;
                m_TrendRiderR += rMultiple;
            }
            else if(strategy == "Reversals")
            {
                m_ReversalsWins++;
                m_ReversalsR += rMultiple;
            }
            else if(strategy == "NewsTrading")
            {
                m_NewsTradingWins++;
                m_NewsTradingR += rMultiple;
            }
        }
        else
        {
            m_TotalLosses++;
            
            if(strategy == "TrendRider")
            {
                m_TrendRiderLosses++;
                m_TrendRiderR -= MathAbs(rMultiple);
            }
            else if(strategy == "Reversals")
            {
                m_ReversalsLosses++;
                m_ReversalsR -= MathAbs(rMultiple);
            }
            else if(strategy == "NewsTrading")
            {
                m_NewsTradingLosses++;
                m_NewsTradingR -= MathAbs(rMultiple);
            }
        }
        
        // Update display
        UpdatePerformancePanel();
    }
}

//+------------------------------------------------------------------+
//| Display trade result on chart                                    |
//+------------------------------------------------------------------+
void CTradeManager::DisplayTradeResult(string symbol, datetime time, double price, 
                                       double rMultiple, bool isWin, string strategy)
{
    // Only display on the correct symbol chart
    if(symbol != Symbol()) return;
    
    string resultText;
    color textColor;
    
    if(isWin)
    {
        resultText = StringFormat("WIN +%.1fR", rMultiple);
        textColor = clrLime;
    }
    else
    {
        resultText = StringFormat("LOSS %.1fR", -MathAbs(rMultiple));
        textColor = clrRed;
    }
    
    // Add strategy abbreviation
    string strategyAbbr = "";
    if(strategy == "TrendRider") strategyAbbr = "TR";
    else if(strategy == "Reversals") strategyAbbr = "RV";
    else if(strategy == "NewsTrading") strategyAbbr = "NT";
    
    resultText = strategyAbbr + ": " + resultText;
    
    CreateTradeLabel(symbol, time, price, resultText, textColor);
}

//+------------------------------------------------------------------+
//| Create trade label on chart                                      |
//+------------------------------------------------------------------+
void CTradeManager::CreateTradeLabel(string symbol, datetime time, double price, 
                                     string text, color clr)
{
    if(symbol != Symbol()) return;
    
    string objName = StringFormat("JcampTrade_%d_%d", (int)time, MathRand());
    
    if(ObjectCreate(0, objName, OBJ_TEXT, 0, time, price))
    {
        ObjectSetString(0, objName, OBJPROP_TEXT, text);
        ObjectSetString(0, objName, OBJPROP_FONT, "Arial");
        ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, 8);
        ObjectSetInteger(0, objName, OBJPROP_COLOR, clr);
        ObjectSetInteger(0, objName, OBJPROP_ANCHOR, ANCHOR_LEFT);
        ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
    }
}

//+------------------------------------------------------------------+
//| Create performance panel                                         |
//+------------------------------------------------------------------+
void CTradeManager::CreatePerformancePanel()
{
    int x = 10;
    int y = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS) - 150;
    
    // Background
    string bgName = "JcampPerf_BG";
    if(ObjectCreate(0, bgName, OBJ_RECTANGLE_LABEL, 0, 0, 0))
    {
        ObjectSetInteger(0, bgName, OBJPROP_CORNER, CORNER_LEFT_LOWER);
        ObjectSetInteger(0, bgName, OBJPROP_XDISTANCE, x);
        ObjectSetInteger(0, bgName, OBJPROP_YDISTANCE, 150);
        ObjectSetInteger(0, bgName, OBJPROP_XSIZE, 250);
        ObjectSetInteger(0, bgName, OBJPROP_YSIZE, 140);
        ObjectSetInteger(0, bgName, OBJPROP_BGCOLOR, C'20,20,20');
        ObjectSetInteger(0, bgName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
        ObjectSetInteger(0, bgName, OBJPROP_COLOR, clrGray);
        ObjectSetInteger(0, bgName, OBJPROP_WIDTH, 1);
        ObjectSetInteger(0, bgName, OBJPROP_BACK, false);
        ObjectSetInteger(0, bgName, OBJPROP_SELECTABLE, false);
    }
    
    // Title
    CreatePanelLabel("JcampPerf_Title", "PERFORMANCE TRACKER", x + 125, 140, clrWhite, 10, true);
    
    // Headers
    CreatePanelLabel("JcampPerf_TotalHeader", "TOTAL:", x + 10, 120, clrYellow, 9, true);
    CreatePanelLabel("JcampPerf_StratHeader", "STRATEGIES:", x + 10, 80, clrYellow, 9, true);
    
    UpdatePerformancePanel();
}

//+------------------------------------------------------------------+
//| Update performance panel                                         |
//+------------------------------------------------------------------+
void CTradeManager::UpdatePerformancePanel()
{
    int x = 10;
    
    // Total performance
    string totalText = StringFormat("R: %.1f | W: %d | L: %d | WR: %.0f%%", 
                                   m_TotalR, m_TotalWins, m_TotalLosses,
                                   m_TotalWins > 0 ? (double)m_TotalWins/(m_TotalWins+m_TotalLosses)*100 : 0);
    
    color totalColor = m_TotalR >= 0 ? clrLime : clrRed;
    CreatePanelLabel("JcampPerf_Total", totalText, x + 10, 105, totalColor, 8, false);
    
    // TrendRider
    string trText = StringFormat("TR: %.1fR (%d/%d)", 
                                m_TrendRiderR, m_TrendRiderWins, m_TrendRiderLosses);
    color trColor = m_TrendRiderR >= 0 ? clrLightGreen : clrLightCoral;
    CreatePanelLabel("JcampPerf_TR", trText, x + 10, 65, trColor, 8, false);
    
    // Reversals
    string rvText = StringFormat("RV: %.1fR (%d/%d)", 
                                m_ReversalsR, m_ReversalsWins, m_ReversalsLosses);
    color rvColor = m_ReversalsR >= 0 ? clrLightGreen : clrLightCoral;
    CreatePanelLabel("JcampPerf_RV", rvText, x + 10, 50, rvColor, 8, false);
    
    // NewsTrading
    string ntText = StringFormat("NT: %.1fR (%d/%d)", 
                                m_NewsTradingR, m_NewsTradingWins, m_NewsTradingLosses);
    color ntColor = m_NewsTradingR >= 0 ? clrLightGreen : clrLightCoral;
    CreatePanelLabel("JcampPerf_NT", ntText, x + 10, 35, ntColor, 8, false);
    
    // Session info
    string sessionText = StringFormat("Session: %s", TimeToString(TimeCurrent(), TIME_DATE));
    CreatePanelLabel("JcampPerf_Session", sessionText, x + 10, 15, clrGray, 7, false);
}

//+------------------------------------------------------------------+
//| Create panel label helper                                        |
//+------------------------------------------------------------------+
void CTradeManager::CreatePanelLabel(string name, string text, int x, int y, 
                                     color clr, int size, bool bold)
{
    ObjectDelete(0, name);
    
    if(ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0))
    {
        ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_LOWER);
        ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
        ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
        ObjectSetString(0, name, OBJPROP_TEXT, text);
        ObjectSetString(0, name, OBJPROP_FONT, bold ? "Arial Bold" : "Arial");
        ObjectSetInteger(0, name, OBJPROP_FONTSIZE, size);
        ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
        ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
    }
}

//+------------------------------------------------------------------+