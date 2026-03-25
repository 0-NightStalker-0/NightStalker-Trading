//+------------------------------------------------------------------+
//|                                                 NightStalker.mq5 |
//|                                  Copyright 2026, NightStalker    |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, NightStalker"
#property version   "1.00"

input double BaseLot = 0.01;
input double GridATRMultiplier = 1.5;
input double ProfitTarget = 10;
input int ATRPeriod = 14;
input double ExposureLimit = 0.5;
input double MaxDrawdownPercent = 30;

#include <Trade/Trade.mqh>
CTrade trade;

int atrHandle;
double atr[];

double lastGridPrice = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    // load configuration

    // initialize indicators
    atrHandle = iATR(_Symbol, PERIOD_CURRENT, ATRPeriod);
    ArrayResize(atr, 1);

    // initialize engines

    return(INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
}
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    // update market data
    // detect market regime
    // run signal engine
    // run grid engine
    // run hedge engine
    // manage basket
    // apply risk rules

    ManageRisk();
    ManageBasket();
    ManageGrid();
    ManageHedge();
}
//+------------------------------------------------------------------+
// 2. Basket Profit Manager
// Grid EAs close all trades together
//
double BasketProfit()
{
   double profit = 0;

   for(int i=0;i<PositionsTotal();i++)
   {
      ulong ticket = PositionGetTicket(i);

      if(PositionSelectByTicket(ticket))
         profit += PositionGetDouble(POSITION_PROFIT);
   }

   return profit;
}

void ManageBasket()
{
   if(BasketProfit() >= ProfitTarget)
      CloseAll();
}
//+------------------------------------------------------------------+
// 3. Grid Expansion Engine
// Grid spacing adapts to the Average True Range.
//
double GridStep()
{
   CopyBuffer(atrHandle, 0, 0, 1, atr); // Get the latest ATR value
   return atr[0] * GridATRMultiplier;
}

// Grid trigger
void ManageGrid()
{
   if(PositionsTotal()==0)
   {
      trade.Buy(BaseLot,_Symbol);
      lastGridPrice = SymbolInfoDouble(_Symbol,SYMBOL_BID);
      return;
   }

   double price = SymbolInfoDouble(_Symbol,SYMBOL_BID);
   double priceDiff = MathAbs(price-lastGridPrice);
   double atr_value = GridStep();

   if(priceDiff >= atr_value)
   {
      double lot = BaseLot + PositionsTotal() * 0.02;
      trade.Buy(lot,_Symbol);
      lastGridPrice = price;
   }
}
//+------------------------------------------------------------------+
// 4. Hedge Engine
// This keeps buy/sell exposure balanced.
//
double NetExposure()
{
   double buy=0;
   double sell=0;

   for(int i=0;i<PositionsTotal();i++)
   {
      ulong ticket = PositionGetTicket(i);

      if(PositionSelectByTicket(ticket))
      {
         double lot = PositionGetDouble(POSITION_VOLUME);

         if(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY)
            buy+=lot;
         else
            sell+=lot;
      }
   }

   return buy-sell;
}

// Hedge trigger
void ManageHedge()
{
   double exposure = NetExposure();

   if(MathAbs(exposure)>ExposureLimit)
   {
      double lot = MathAbs(exposure);

      if(exposure>0)
         trade.Sell(lot,_Symbol);
      else
         trade.Buy(lot,_Symbol);
   }
}
//+------------------------------------------------------------------+
// 5. Risk Control Engine
// Grid systems must monitor equity drawdown.
//
void ManageRisk()
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);

   double dd = (balance-equity) / balance * 100;

   if(dd>MaxDrawdownPercent)
      CloseAll();
}
//+------------------------------------------------------------------+
// 6. Close All Positions
//
void CloseAll()
{
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong ticket = PositionGetTicket(i);
      trade.PositionClose(ticket);
   }
}
//+------------------------------------------------------------------+
