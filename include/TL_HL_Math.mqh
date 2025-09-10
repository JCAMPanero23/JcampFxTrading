// =============================
// file: Experts/JcampFxTrading/include/TL_HL_Math.mqh
// =============================
#ifndef __TL_HL_MATH_MQH__
#define __TL_HL_MATH_MQH__

// Lightweight math + drawing helpers used by both EA and Drawer indicator

// Extract base/quote from broker symbol (suffix-aware). Returns true on success.
bool ExtractBaseQuote(const string sym, string &base, string &quote)
{
   // Heuristic: find first non-letter (e.g., '.') and strip suffix; assume 6-letter core
   string core = sym;
   for(int i=0;i<StringLen(sym);++i)
   {
      int ch = StringGetCharacter(sym,i);
      if((ch<'A'||ch>'Z') && (ch<'a'||ch>'z')){ core = StringSubstr(sym,0,i); break; }
   }
   if(StringLen(core)<6) return false;
   base = StringToUpper(StringSubstr(core,0,3));
   quote= StringToUpper(StringSubstr(core,3,3));
   return true;
}

// Simple ATR wrapper
double ATR(const string sym, ENUM_TIMEFRAMES tf, int period)
{
   int h = iATR(sym, tf, period);
   if(h==INVALID_HANDLE) return 0.0;
   double b[]; if(CopyBuffer(h,0,0,period+2,b)<=0) return 0.0;
   return b[0];
}

// RSI wrapper
bool GetRSI(const string sym, ENUM_TIMEFRAMES tf, int period, double &out)
{
   int h=iRSI(sym,tf,period,PRICE_CLOSE); if(h==INVALID_HANDLE) return false;
   double b[]; if(CopyBuffer(h,0,0,3,b)<=0) return false; out=b[0]; return true;
}

// MACD wrapper (12,26,9 typical). Outputs main-signal histogram
bool GetMACD(const string sym, ENUM_TIMEFRAMES tf, int fast, int slow, int sgn, double &macd, double &signal, double &hist)
{
   int h=iMACD(sym,tf,fast,slow,sgn,PRICE_CLOSE); if(h==INVALID_HANDLE) return false;
   double m[], s[], hst[];
   if(CopyBuffer(h,0,0,3,m)<=0) return false;
   if(CopyBuffer(h,1,0,3,s)<=0) return false;
   if(CopyBuffer(h,2,0,3,hst)<=0) return false;
   macd=m[0]; signal=s[0]; hist=hst[0];
   return true;
}

// Fractal(2) swing highs/lows – returns last two swings (indices in bars)
bool FindRecentSwings(const string sym, ENUM_TIMEFRAMES tf, int frac, int &hi1, int &hi2, int &lo1, int &lo2)
{
   int up=iFractals(sym,tf,MODE_UPPER), dn=iFractals(sym,tf,MODE_LOWER);
   if(up==INVALID_HANDLE || dn==INVALID_HANDLE) return false;
   double uh[], lh[]; if(CopyBuffer(up,0,0,500,uh)<=0) return false; if(CopyBuffer(dn,0,0,500,lh)<=0) return false;
   hi1=hi2=lo1=lo2=-1;
   for(int i=2;i<500-2;i++)
   {
      if(!DoubleIsNaN(uh[i])){ hi2=hi1; hi1=i; }
      if(!DoubleIsNaN(lh[i])){ lo2=lo1; lo1=i; }
      if(hi1!=-1 && hi2!=-1 && lo1!=-1 && lo2!=-1) break;
   }
   return (hi1!=-1 && hi2!=-1 && lo1!=-1 && lo2!=-1);
}

// Build an auto trendline from two swing points (returns price y1,y2 and time t1,t2)
bool BuildTrendlineFromSwings(const string sym, ENUM_TIMEFRAMES tf, bool bullish, datetime &t1, double &y1, datetime &t2, double &y2)
{
   int hi1,hi2,lo1,lo2; if(!FindRecentSwings(sym,tf,2,hi1,hi2,lo1,lo2)) return false;
   MqlRates r[]; if(CopyRates(sym,tf,0,600,r)<=0) return false;
   ArraySetAsSeries(r,true);
   if(bullish)
   {  // use lows
      t1=r[lo2].time; y1=r[lo2].low; t2=r[lo1].time; y2=r[lo1].low; return true; }
   else
   {  // use highs
      t1=r[hi2].time; y1=r[hi2].high; t2=r[hi1].time; y2=r[hi1].high; return true; }
}

// Nearest S/R from recent highs/lows + optional ATR buffer
bool NearestSR(const string sym, ENUM_TIMEFRAMES tf, bool above, double atrMult, double &level)
{
   MqlRates r[]; if(CopyRates(sym,tf,0,400,r)<=0) return false; ArraySetAsSeries(r,true);
   double a = ATR(sym,tf,14); if(a<=0) a= (r[0].high - r[0].low)/2.0;
   double shift = a * atrMult;
   double best = 0.0;
   if(above)
   {
      // pick recent swing high then add buffer
      double maxH = r[1].high;
      for(int i=2;i<200;i++) if(r[i].high>maxH) maxH=r[i].high;
      best = maxH + shift;
   }
   else
   {
      double minL = r[1].low;
      for(int i=2;i<200;i++) if(r[i].low<minL) minL=r[i].low;
      best = minL - shift;
   }
   level = best; return true;
}

// Drawing helpers (trendline + horizontal) – only draw on the attached chart symbol
long DrawTrendline(const string name, datetime t1, double y1, datetime t2, double y2, color clr)
{
   if(ObjectFind(0,name)>=0) ObjectDelete(0,name);
   ObjectCreate(0,name,OBJ_TREND,0,t1,y1,t2,y2);
   ObjectSetInteger(0,name,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,name,OBJPROP_WIDTH,2);
   return ObjectGetInteger(0,name,OBJPROP_TIME);
}

long DrawHorizontal(const string name, double price, color clr)
{
   if(ObjectFind(0,name)>=0) ObjectDelete(0,name);
   ObjectCreate(0,name,OBJ_HLINE,0,0,price);
   ObjectSetInteger(0,name,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,name,OBJPROP_WIDTH,2);
   return ObjectGetInteger(0,name,OBJPROP_TIME);
}

#endif // __TL_HL_MATH_MQH__
