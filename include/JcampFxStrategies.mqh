// =============================
// file: Experts/JcampFxTrading/include/JcampFxStrategies.mqh
// =============================
#ifndef __JCAMP_FX_STRATEGIES_MQH__
#define __JCAMP_FX_STRATEGIES_MQH__

#include <Trade/Trade.mqh>
#include <Trade/PositionInfo.mqh>
#include <Trade/OrderInfo.mqh>

// ─────────────────────────────────────────────────────────────────────────────
// Config/state carried from EA inputs
// ─────────────────────────────────────────────────────────────────────────────
namespace JFS
{
   // Inputs snapshot
   bool    gVerbose=false, gCsv=false;
   double  gRiskPct=2.0, gTP_R=2.5, gSL_R=1.0, gBE_R=0.5, gSLTrail_R=1.0, gTPTrail_R=2.0, gRStep=0.25;
   int     gSpreadMaxPts=30, gDailyKillNegR=-3;
   bool    gNewsEnable=true; int gNewsBlkBefore=15, gNewsBlkAfter=15;
   ENUM_TIMEFRAMES gCsmTF=PERIOD_H1; int gCsmLb=48;

   string  gCsvFolder="JcampFxTrading";

   // R accounting
   double  gDayR=0.0, gMonthR=0.0;

   CTrade  tr;
}
using namespace JFS;

// ─────────────────────────────────────────────────────────────────────────────
// CSV IO
// ─────────────────────────────────────────────────────────────────────────────
string CsvPathCurrentMonth()
{
   MqlDateTime dt; TimeToStruct(TimeCurrent(),dt);
   string folder = StringFormat("%s/", gCsvFolder);
   return folder + StringFormat("JcampFxTrading_%04d-%02d.csv", dt.year, dt.mon);
}

void EnsureCsvHeader()
{
   if(!gCsv) return;
   string p = CsvPathCurrentMonth();
   int f = FileOpen(p, FILE_CSV|FILE_COMMON|FILE_READ|FILE_WRITE, ';');
   if(f==INVALID_HANDLE) return;
   if(FileSize(f)==0)
   {
      FileWrite(f, "time","symbol","strategy","dir","entry","sl","tp","lots","R_target","R_outcome","fees","note");
   }
   FileClose(f);
}

void CsvAppendTrade(const string strategy, const string sym, const string dir, double entry, double sl, double tp, double lots, double Rtarget, double Routcome, double fees, const string note)
{
   if(!gCsv) return;
   EnsureCsvHeader();
   string p = CsvPathCurrentMonth();
   int f = FileOpen(p, FILE_CSV|FILE_COMMON|FILE_READ|FILE_WRITE, ';');
   if(f==INVALID_HANDLE) return;
   FileSeek(f,0,SEEK_END);
   FileWrite(f, TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS), sym, strategy, dir, DoubleToString(entry,_Digits), DoubleToString(sl,_Digits), DoubleToString(tp,_Digits), DoubleToString(lots,2), DoubleToString(Rtarget,2), DoubleToString(Routcome,2), DoubleToString(fees,2), note);
   FileClose(f);
}

// ─────────────────────────────────────────────────────────────────────────────
// Utilities
// ─────────────────────────────────────────────────────────────────────────────
double PointVal(const string sym){ double pt; SymbolInfoDouble(sym,SYMBOL_POINT,pt); return pt; }
int SpreadPts(const string sym){ long sp; SymbolInfoInteger(sym,SYMBOL_SPREAD,sp); return (int)sp; }

bool GetSpreadOk(const string sym, int maxPts)
{
   int spr = SpreadPts(sym);
   return spr <= maxPts;
}

bool HasOpenOrPending(const string sym, ulong magic)
{
   // Check positions
   for(int i=0;i<PositionsTotal();++i)
   {
      if(!PositionSelectByIndex(i)) continue;
      if((ulong)PositionGetInteger(POSITION_MAGIC)==magic && PositionGetString(POSITION_SYMBOL)==sym) return true;
   }
   // Check orders (pending)
   for(int j=0;j<OrdersTotal();++j)
   {
      if(!OrderSelect(j, SELECT_BY_POS, MODE_TRADES)) continue;
      if((ulong)OrderGetInteger(ORDER_MAGIC)==magic && OrderGetString(ORDER_SYMBOL)==sym) return true;
   }
   return false;
}

// Simple CSM over provided list (H1 default):
// 1) compute instrument return over LB bars; 2) add to base currency, subtract from quote; 3) rank
struct CurScore { string cur; double v; };

void CsmFromList(const string &syms[], ENUM_TIMEFRAMES tf, int lb, CurScore &out[], string &strong, string &weak)
{
   // Collect unique currencies
   string curs[24]; int cc=0;
   for(int i=0;i<ArraySize(syms);++i)
   {
      string b,q; if(!ExtractBaseQuote(syms[i],b,q)) continue;
      bool found=false; for(int k=0;k<cc;k++) if(curs[k]==b){ found=true; break; } if(!found){ curs[cc++]=b; }
      found=false; for(int k=0;k<cc;k++) if(curs[k]==q){ found=true; break; } if(!found){ curs[cc++]=q; }
   }
   ArrayResize(out,cc); for(int i=0;i<cc;i++){ out[i].cur=curs[i]; out[i].v=0.0; }

   // Aggregate
   for(int i=0;i<ArraySize(syms);++i)
   {
      string s=syms[i];
      MqlRates r[]; if(CopyRates(s,tf,0,lb+1,r)<=0) continue; ArraySetAsSeries(r,true);
      if(ArraySize(r)<=lb) continue;
      double c0=r[lb].close, c1=r[0].close; if(c0<=0) continue; 
      double ret = (c1-c0)/c0; // close-to-close pct change
      string b,q; if(!ExtractBaseQuote(s,b,q)) continue;
      // add to base, subtract from quote
      for(int k=0;k<cc;k++){ if(out[k].cur==b) out[k].v += ret; if(out[k].cur==q) out[k].v -= ret; }
   }
   // Rank
   int maxI=0, minI=0; for(int i=1;i<cc;i++){ if(out[i].v>out[maxI].v) maxI=i; if(out[i].v<out[minI].v) minI=i; }
   strong = out[maxI].cur; weak = out[minI].cur;
}

// Pick prioritized pairs (from provided list) matching strong vs weak currencies
int PrioritizedPairsStrongWeak(const string &syms[], const string strong, const string weak, string &out[])
{
   ArrayResize(out,0);
   for(int i=0;i<ArraySize(syms);++i)
   {
      string b,q; if(!ExtractBaseQuote(syms[i],b,q)) continue;
      if(b==strong && q==weak) { int n=ArraySize(out); ArrayResize(out,n+1); out[n]= syms[i]; }
   }
   // If none directly match, relax to pairs containing strong or weak
   if(ArraySize(out)==0)
   {
      for(int i=0;i<ArraySize(syms);++i)
      {
         string b,q; if(!ExtractBaseQuote(syms[i],b,q)) continue;
         if(b==strong || q==weak){ int n=ArraySize(out); ArrayResize(out,n+1); out[n]= syms[i]; }
      }
   }
   return ArraySize(out);
}

// ─────────────────────────────────────────────────────────────────────────────
// Strategy stubs – pending orders for TrendRider & Reversals; News uses straddle
// ─────────────────────────────────────────────────────────────────────────────

bool ComputeRiskLots(const string sym, double entry, double sl, double riskPct, double &outLots)
{
   double riskPrice = MathAbs(entry - sl);
   if(riskPrice<=0) return false;
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double riskAmt = equity * (riskPct/100.0);
   double tickVal = 0.0, tickSize = 0.0; SymbolInfoDouble(sym,SYMBOL_TRADE_TICK_VALUE,tickVal); SymbolInfoDouble(sym,SYMBOL_TRADE_TICK_SIZE,tickSize);
   if(tickVal<=0||tickSize<=0) return false;
   double moneyPerLotPerPoint = tickVal / tickSize; // approx
   double point; SymbolInfoDouble(sym,SYMBOL_POINT,point);
   double points = riskPrice / point;
   if(points<=0) return false;
   double lots = riskAmt / (moneyPerLotPerPoint * points);
   // clamp to symbol limits
   double minL=0, maxL=0, step=0; SymbolInfoDouble(sym,SYMBOL_VOLUME_MIN,minL); SymbolInfoDouble(sym,SYMBOL_VOLUME_MAX,maxL); SymbolInfoDouble(sym,SYMBOL_VOLUME_STEP,step);
   if(step<=0) step=0.01;
   lots = MathMax(minL, MathMin(maxL, MathFloor(lots/step)*step));
   outLots = lots; return lots>=minL;
}

bool PlacePending(const string strategy, const string sym, bool isBuy, double entry, double sl, double tp, ulong magic)
{
   if(gVerbose) Print("ORDER | ",strategy," | ",sym," | ",(isBuy?"BUY":"SELL")," stop/limit pending");
   MqlTradeRequest req; MqlTradeResult res; ZeroMemory(req); ZeroMemory(res);
   req.action = TRADE_ACTION_PENDING;
   req.magic  = magic;
   req.symbol = sym;

   MqlTick tk; SymbolInfoTick(sym,tk);
   if(isBuy) req.type = (entry>tk.ask? ORDER_TYPE_BUY_STOP: ORDER_TYPE_BUY_LIMIT);
   else      req.type = (entry<tk.bid? ORDER_TYPE_SELL_STOP: ORDER_TYPE_SELL_LIMIT);

   req.price  = entry;
   req.sl     = sl;
   req.tp     = tp;
   req.deviation = 10;
   double lots; if(!ComputeRiskLots(sym,entry,sl,gRiskPct,lots)) return false; req.volume = lots;
   bool ok = OrderSend(req,res);
   if(ok){ if(gCsv) CsvAppendTrade(strategy,sym,(isBuy?"BUY":"SELL"),entry,sl,tp,lots, gTP_R, 0.0, 0.0, "pending"); }
   else   { Print("ORDER_FAIL | ",sym," | ",res.retcode); }
   return ok;
}

bool Strategy_TrendRider(const string sym, ENUM_TIMEFRAMES execTf, ulong magic)
{
   // Trend following using auto TL + SR awareness; place stop pending in trend direction
   datetime t1,t2; double y1,y2; bool bullish=false;
   // Decide trend: use MACD histogram or last HH/HL vs LH/LL; here simple MACD
   double macd,signal,hist; if(!GetMACD(sym,execTf,12,26,9,macd,signal,hist)) return false;
   bullish = (hist>0);
   if(!BuildTrendlineFromSwings(sym,execTf,bullish,t1,y1,t2,y2)) return false;

   double atr = ATR(sym,execTf,14); if(atr<=0) return false;
   double buffer = atr*0.5; // safe buffer

   MqlTick tk; SymbolInfoTick(sym,tk);
   bool isBuy = bullish;
   double entry = isBuy ? (tk.ask + buffer) : (tk.bid - buffer);

   // SL at opposite SR with buffer; TP by R multiple relative to SL distance
   double sr; if(!NearestSR(sym,execTf, !isBuy, 0.3, sr)) return false; // 0.3 ATR buffer at SR
   double sl = sr;
   double risk = MathAbs(entry - sl);
   double point; SymbolInfoDouble(sym,SYMBOL_POINT,point);
   if(risk<=point) return false;
   double tp = isBuy ? (entry + gTP_R * risk) : (entry - gTP_R * risk);

   return PlacePending("TrendRider", sym, isBuy, entry, sl, tp, magic);
}

bool Strategy_Reversal(const string sym, ENUM_TIMEFRAMES execTf, ulong magic)
{
   // Fade into S/R reversal with oscillator confirmation; place limit pending at SR ± buffer
   double rsi; if(!GetRSI(sym,execTf,14,rsi)) return false;
   bool wantBuy = (rsi<=30.0); bool wantSell = (rsi>=70.0);
   if(!wantBuy && !wantSell) return false;

   double atr=ATR(sym,execTf,14); if(atr<=0) return false; double buf=atr*0.4;
   double lvl; if(wantBuy){ if(!NearestSR(sym,execTf,false,0.2,lvl)) return false; }
   else       { if(!NearestSR(sym,execTf,true ,0.2,lvl)) return false; }

   bool isBuy = wantBuy;
   double entry = isBuy? (lvl + buf*0.2) : (lvl - buf*0.2); // small offset into level
   double sl    = isBuy? (lvl - buf)     : (lvl + buf);
   double point; SymbolInfoDouble(sym,SYMBOL_POINT,point);
   double risk  = MathAbs(entry - sl); if(risk<=point) return false;
   double tp    = isBuy? (entry + gTP_R * risk) : (entry - gTP_R * risk);

   return PlacePending("Reversals", sym, isBuy, entry, sl, tp, magic);
}

bool Strategy_News(const string sym, ENUM_TIMEFRAMES execTf, ulong magic)
{
   // Best practice: straddle with stop pendings placed shortly before event,
   // with blackout window before/after. Stubbed until CSV parameters finalized.
   if(!gNewsEnable) return false;
   if(!News_BlackoutPass(sym)) return false; // ensures we're not in blackout; also handles CSV loading
   return false; // stub for v0.1
}

// News blackout / CSV (portable, broker-agnostic – works with OANDA too)
// Expected CSV path: Common\\Files\\JcampFxTrading\\calendar.csv
// Columns: datetime(YYYY-MM-DD HH:MM),currency,impact(LOW|MED|HIGH),title
// If a symbol contains a CSV currency (base or quote), blackout = [before, after] mins around the event
bool News_BlackoutPass(const string sym)
{
   if(!gNewsEnable) return true;
   string b,q; if(!ExtractBaseQuote(sym,b,q)) return true; // if unknown, skip

   string path = gCsvFolder+"/calendar.csv";
   int f = FileOpen(path, FILE_CSV|FILE_COMMON|FILE_READ, ';');
   if(f==INVALID_HANDLE) return true; // no file = no blackout

   datetime now = TimeCurrent();
   bool pass = true;
   while(!FileIsEnding(f))
   {
      string ds = FileReadString(f); string cur = FileReadString(f); string imp = FileReadString(f); string title = FileReadString(f);
      if(StringLen(ds)==0){ continue; }
      datetime evt = StringToTime(ds);
      int diff = (int)MathAbs((long)(now - evt))/60; // minutes
      if( (cur==b || cur==q) && diff <= ( (now<=evt)? gNewsBlkBefore : gNewsBlkAfter ) )
      {
         // inside the window → blackout
         pass = false; break;
      }
   }
   FileClose(f);
   return pass;
}

// ─────────────────────────────────────────────────────────────────────────────
// Management loop
// ─────────────────────────────────────────────────────────────────────────────

void JFS_Init(const string csvFolder, bool csvLogs, bool verbose,
              double riskPct, double tpR, double slR, double beR,
              double slTrailR, double tpTrailR, double rStep,
              int spreadMaxPts, int dailyKillNegR,
              bool newsEnable, int newsBlkBefore, int newsBlkAfter,
              ENUM_TIMEFRAMES csmTF, int csmLb)
{
   gCsvFolder = csvFolder; gCsv = csvLogs; gVerbose=verbose;
   gRiskPct=riskPct; gTP_R=tpR; gSL_R=slR; gBE_R=beR; gSLTrail_R=slTrailR; gTPTrail_R=tpTrailR; gRStep=rStep;
   gSpreadMaxPts=spreadMaxPts; gDailyKillNegR=dailyKillNegR;
   gNewsEnable=newsEnable; gNewsBlkBefore=newsBlkBefore; gNewsBlkAfter=newsBlkAfter;
   gCsmTF=csmTF; gCsmLb=csmLb;
   EnsureCsvHeader();
}

void JFS_Shutdown()
{
   // noop for now
}

void JFS_GetRStats(double &dayR, double &monthR){ dayR=gDayR; monthR=gMonthR; }

string JFS_ScanSummaryFor(const string sym, ENUM_TIMEFRAMES execTf, ENUM_TIMEFRAMES csmTf, int csmLb)
{
   // Compact per-bar note: MACD/RSI snapshot + spread ok?
   double macd,sgn,h; bool ok1=GetMACD(sym,execTf,12,26,9,macd,sgn,h);
   double rsi=0; bool ok2=GetRSI(sym,execTf,14,rsi);
   int spr = SpreadPts(sym);
   return StringFormat("RSI=%.1f MACDhist=%.4f | spr=%dpts", (ok2?rsi:0), (ok1?h:0.0), spr);
}

void JFS_RunCycle(string &symbols[], bool allowMulti, ENUM_TIMEFRAMES execTf)
{
   // Daily kill switch
   if(gDayR <= (double)gDailyKillNegR){ if(gVerbose) Print("HALT | Daily R cap reached"); return; }

   // Compute CSM on provided list
   CurScore scores[]; string strong, weak; CsmFromList(symbols, gCsmTF, gCsmLb, scores, strong, weak);
   string prio[]; PrioritizedPairsStrongWeak(symbols,strong,weak,prio);

   // Iterate prioritized symbols
   for(int i=0;i<ArraySize(prio);++i)
   {
     string s = prio[i];
     ulong magic = (ulong)(77001337 + i); // stable per list position; alt: a hash per symbol

     if(!GetSpreadOk(s,gSpreadMaxPts)) { if(gVerbose) Print("SKIP | SPREAD_HIGH | ",s); continue; }
     if(HasOpenOrPending(s,magic)) continue; // one-at-a-time per pair

     // News blackout (D)
     if(!News_BlackoutPass(s)) { if(gVerbose) Print("SKIP | NEWS_BLACKOUT | ",s); continue; }

     // Try strategies in order: TrendRider, Reversals, News
     if(Strategy_TrendRider(s,execTf,magic)) continue;
     if(Strategy_Reversal (s,execTf,magic)) continue;
     if(Strategy_News     (s,execTf,magic)) continue;
   }

   // Manage open trades: trail in R steps from exec TF closes (approx via OnTimer)
   ManageOpen(execTf);
}

void UpdateRAccount(const string sym, double Routcome)
{
   // Update day and month R
   gDayR   += Routcome;
   gMonthR += Routcome;
}

void ManageOpen(ENUM_TIMEFRAMES execTf)
{
   // Trail logic sketch: for each position with our magic, compute current R vs entry/SL and move SL/TP in gRStep increments
   for(int i=0;i<PositionsTotal();++i)
   {
      if(!PositionSelectByIndex(i)) continue;
      string sym = PositionGetString(POSITION_SYMBOL);
      long   mg  = PositionGetInteger(POSITION_MAGIC);
      if(mg<77000000 || mg>78000000) continue; // crude filter for our EAs by magic range

      double entry=PositionGetDouble(POSITION_PRICE_OPEN);
      double sl=PositionGetDouble(POSITION_SL); double tp=PositionGetDouble(POSITION_TP);
      long   type=PositionGetInteger(POSITION_TYPE);

      MqlTick tk; SymbolInfoTick(sym,tk);
      double cur = (type==POSITION_TYPE_BUY? tk.bid : tk.ask);
      double risk = MathAbs(entry - sl); if(risk<=0) continue;
      double gain = (type==POSITION_TYPE_BUY? (cur-entry):(entry-cur));
      double Rnow = gain / risk;

      // Move to BE (cover spread only; commission assumed 0 for OANDA)
      if(Rnow>=gBE_R)
      {
         long spread_pts_l; SymbolInfoInteger(sym,SYMBOL_SPREAD,spread_pts_l);
         double point; SymbolInfoDouble(sym,SYMBOL_POINT,point);
         double bePrice = (type==POSITION_TYPE_BUY? entry + spread_pts_l*point : entry - spread_pts_l*point);
         if( (type==POSITION_TYPE_BUY && sl<bePrice) || (type==POSITION_TYPE_SELL && sl>bePrice) )
         {
            tr.PositionModify(sym, bePrice, tp);
         }
      }

      // Trail SL every R step after start
      if(Rnow>=gSLTrail_R)
      {
         double steps = MathFloor((Rnow - gSLTrail_R)/gRStep);
         if(steps>=1)
         {
            double newSL = (type==POSITION_TYPE_BUY? entry + (gSLTrail_R + steps*gRStep)*risk : entry - (gSLTrail_R + steps*gRStep)*risk);
            // keep below/above current price
            if( (type==POSITION_TYPE_BUY && newSL<cur) || (type==POSITION_TYPE_SELL && newSL>cur) )
               tr.PositionModify(sym, newSL, tp);
         }
      }

      // Optional: trail TP upward in steps after start (turns into runner)
      if(Rnow>=gTPTrail_R && tp>0)
      {
         double steps = MathFloor((Rnow - gTPTrail_R)/gRStep);
         if(steps>=1)
         {
            double baseTP = entry + ( (type==POSITION_TYPE_BUY? 1:-1) * gTP_R * risk );
            double newTP  = (type==POSITION_TYPE_BUY? baseTP + steps*gRStep*risk : baseTP - steps*gRStep*risk);
            tr.PositionModify(sym, sl, newTP);
         }
      }
   }
}

#endif // __JCAMP_FX_STRATEGIES_MQH__
