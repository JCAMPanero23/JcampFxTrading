// =============================
// file: Experts/JcampFxTrading/JcampFxTrading.mq5
// =============================
#property strict
#property version   "0.1"
#property description "JcampFxTrading – CSM-driven, TL/SR-aware multi-pair EA (pending orders, timer-managed)."

#include <Trade/Trade.mqh>
#include <Trade/SymbolInfo.mqh>
#include <Trade/PositionInfo.mqh>
#include <Trade/OrderInfo.mqh>

#include "include/TL_HL_Math.mqh"
#include "include/JcampFxStrategies.mqh"

// ─────────────────────────────────────────────────────────────────────────────
// Inputs
// ─────────────────────────────────────────────────────────────────────────────
input bool   InpEnableMultiFx      = true;   // Allow multi-symbol trading
input string InpFxPairs            = "EURUSD.sml,AUDCAD,CHFJPY,GBPUSD.sml,USDJPY.sml,EURGBP.sml"; // Comma-separated list

input ENUM_TIMEFRAMES InpExecTF    = PERIOD_M15;  // Execution/management timeframe
input ENUM_TIMEFRAMES InpCsmTF     = PERIOD_H1;   // CSM timeframe
input int    InpCsmLookback        = 48;          // CSM lookback bars

input double InpRiskPercent        = 2.0;         // % of equity risk per trade
input double InpTP_R               = 2.5;         // TP in R
input double InpSL_R               = 1.0;         // SL in R (base)
input double InpBE_Start_R         = 0.5;         // Move BE after R reached
input double InpSL_Trail_Start_R   = 1.0;         // Start SL trailing at R
input double InpTP_Trail_Start_R   = 2.0;         // Start TP trailing at R
input double InpR_Step             = 0.25;        // R step for trails / partials

input bool   InpVerbose            = false;       // Verbose logs
input bool   InpCsvLogs            = true;        // Write CSV logs

input bool   InpNewsEnable         = true;        // Enable NewsTrades + blackout
input int    InpNewsBlackoutBefore = 15;          // minutes before event (blackout)
input int    InpNewsBlackoutAfter  = 15;          // minutes after event (blackout)

input int    InpSpreadMaxPoints    = 30;          // Skip trading if spread > X points

input int    InpDailyKillNegR      = -3;          // Daily R cap (shutdown at ≤ value)

input ulong  InpBaseMagic          = 77001337;    // Base magic; per-symbol hash added

// ─────────────────────────────────────────────────────────────────────────────
// Globals
// ─────────────────────────────────────────────────────────────────────────────
CTrade          gTrade;
CSymbolInfo     gSym;
MqlTick         gTick;

string          gSymbols[];              // Parsed symbols from input
int             gExecTFSeconds = 0;      // Seconds per ExecTF bar
int             gLastSlice     = -1;     // Last processed slice index within ExecTF
int             gSlices        = 15;     // Manage every 1/15 of Exec TF

datetime        gLastBarTime   = 0;      // For bar-close scan logs on attached chart only

// R accounting per day/month
int             gCurDay = 0, gCurMonth = 0, gCurYear = 0;
double          gDayR = 0.0, gMonthR = 0.0;

// CSV base folder
string          gCsvFolder = "JcampFxTrading";

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────
int TfSeconds(ENUM_TIMEFRAMES tf)
{
   switch(tf)
   {
      case PERIOD_M1:  return 60;
      case PERIOD_M5:  return 300;
      case PERIOD_M15: return 900;
      case PERIOD_M30: return 1800;
      case PERIOD_H1:  return 3600;
      case PERIOD_H4:  return 14400;
      case PERIOD_D1:  return 86400;
      default:         return 900; // fallback M15
   }
}

string TrimBoth(string s){
   while(StringLen(s)>0 && (StringGetCharacter(s,0)==' ' || StringGetCharacter(s,0)=='\t' || StringGetCharacter(s,0)=='\n' || StringGetCharacter(s,0)=='\r')) s=StringSubstr(s,1);
   while(StringLen(s)>0){
      int i=StringLen(s)-1; int c=StringGetCharacter(s,i);
      if(c==' '||c=='\t'||c=='\n'||c=='\r') s=StringSubstr(s,0,i); else break;
   }
   return s;
}

void SplitCsv(const string s, const string delim, string &out[])
{
   ArrayResize(out,0);
   int start=0; int p=StringFind(s,delim,0);
   while(p!=-1)
   {
      string tok=StringSubstr(s,start,p-start);
      tok=TrimBoth(tok);
      if(StringLen(tok)>0){ int n=ArraySize(out); ArrayResize(out,n+1); out[n]=tok; }
      start=p+StringLen(delim);
      p=StringFind(s,delim,start);
   }
   string last = TrimBoth(StringSubstr(s,start));
   if(StringLen(last)>0){ int n=ArraySize(out); ArrayResize(out,n+1); out[n]=last; }
}

ulong MagicFor(const string sym)
{
   // Simple hash (deterministic)
   uint h=2166136261;
   for(int i=0;i<StringLen(sym);++i){ h = (h ^ (uchar)StringGetCharacter(sym,i)) * 16777619; }
   return (ulong)(InpBaseMagic + h);
}

bool SpreadOk(const string sym, int maxPts)
{
   MqlTick t; if(!SymbolInfoTick(sym,t)) return false;
   double pt; SymbolInfoDouble(sym,SYMBOL_POINT,pt);
   double sprPts = (t.ask - t.bid) / pt; // points
   return (sprPts <= maxPts);
}

void EnsureSymbolReady(const string sym)
{
   SymbolSelect(sym,true);
   // preload rates for CSM timeframe
   MqlRates r[]; int need=InpCsmLookback+10;
   CopyRates(sym,InpCsmTF,0,need,r);
}

void ResetDayMonthIfNeeded()
{
   datetime now=TimeCurrent();
   MqlDateTime dt; TimeToStruct(now,dt);
   if(gCurDay==0){ gCurDay=dt.day; gCurMonth=dt.mon; gCurYear=dt.year; }

   if(dt.day!=gCurDay){ gDayR=0.0; gCurDay=dt.day; }
   if(dt.mon!=gCurMonth || dt.year!=gCurYear){ gMonthR=0.0; gCurMonth=dt.mon; gCurYear=dt.year; }
}

void LogScanIfNewBar()
{
   // Only for attached chart symbol
   string sym = _Symbol;
   datetime bt = iTime(sym, InpExecTF, 0);
   if(bt!=0 && bt!=gLastBarTime)
   {
      gLastBarTime = bt;
      // Ask strategies module for a compact scan summary for this symbol
      string summary = JFS_ScanSummaryFor(sym, InpExecTF, InpCsmTF, InpCsmLookback);
      if(summary!="") Print("SCAN | ",sym," | ",summary);
   }
}

// ─────────────────────────────────────────────────────────────────────────────
// MT5 lifecycle
// ─────────────────────────────────────────────────────────────────────────────
int OnInit()
{
   ResetDayMonthIfNeeded();

   SplitCsv(InpFxPairs, ",", gSymbols);
   if(ArraySize(gSymbols)==0){ Print("ERROR: No symbols in InpFxPairs"); return(INIT_PARAMETERS_INCORRECT); }
   for(int i=0;i<ArraySize(gSymbols);++i) EnsureSymbolReady(gSymbols[i]);

   gExecTFSeconds = TfSeconds(InpExecTF);
   EventSetTimer(1); // 1s tick; we gate by slices

   // Initialize strategies module
   JFS_Init(gCsvFolder, InpCsvLogs, InpVerbose,
            InpRiskPercent, InpTP_R, InpSL_R, InpBE_Start_R,
            InpSL_Trail_Start_R, InpTP_Trail_Start_R, InpR_Step,
            InpSpreadMaxPoints, InpDailyKillNegR,
            InpNewsEnable, InpNewsBlackoutBefore, InpNewsBlackoutAfter,
            InpCsmTF, InpCsmLookback);

   Print("JcampFxTrading v0.1 initialized. Symbols=",ArraySize(gSymbols));
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   EventKillTimer();
   JFS_Shutdown();
}

void OnTick()
{
   // Intentionally lightweight. All logic is timer-driven.
}

void OnTimer()
{
   ResetDayMonthIfNeeded();

   datetime now = TimeCurrent();
   int slice = (int)( (now % gExecTFSeconds) / MathMax(1, gExecTFSeconds / gSlices) );
   if(slice==gLastSlice) { LogScanIfNewBar(); return; }
   gLastSlice = slice;

   // Run a management+signal cycle across prioritized pairs
   JFS_RunCycle(gSymbols, InpEnableMultiFx, InpExecTF);

   // Update running R stats from strategies module
   double dayR, monR; JFS_GetRStats(dayR, monR);
   gDayR = dayR; gMonthR = monR;

   // Optional: show small HUD line on attached chart (non-spam)
   static datetime lastHud=0; if(now-lastHud>=5)
   {
      lastHud = now;
      string hud = StringFormat("R(day)=%.2f | R(month)=%.2f", gDayR, gMonthR);
      Comment(hud);
   }
}
