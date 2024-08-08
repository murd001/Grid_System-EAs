//+------------------------------------------------------------------+
//|                                                 witch-doctor.mq5 |
//|                                  Copyright 2023, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
#include <Trade\PositionInfo.mqh>
#include <Trade\Trade.mqh>


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CPositionInfo d_position = CPositionInfo();
CTrade d_trade = CTrade();

input double Lot = 0.01;
input int Ma_Period = 144;
input double GridSpace_Usd = 5.0;
input double EquityStepProfit_Usd = 5.0;
double MaValues[];
int MaHandle;
double open1, open2;
double close1, close2;
double high1, high2;
double low1, low2;
bool Trading;
string Action;
double initialequity;
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
   MaHandle = iMA(_Symbol, PERIOD_CURRENT, Ma_Period, 0, MODE_EMA, PRICE_CLOSE);
   if(PositionsTotal() == 0)
     {
      Trading = false;
     }

   initialequity = AccountInfoDouble(ACCOUNT_BALANCE);
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---

  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//---
   ArraySetAsSeries(MaValues, true);
   CopyBuffer(MaHandle, 0, 0, 3, MaValues);

   open1        = iOpen(_Symbol, PERIOD_CURRENT, 1);
   open2        = iOpen(Symbol(), Period(), 2);
   close1       = iClose(Symbol(), Period(), 1);
   close2       = iClose(Symbol(), Period(), 2);
   low1         = iLow(Symbol(), Period(), 1);
   low2         = iLow(Symbol(), Period(), 2);
   high1        = iHigh(Symbol(), Period(), 1);
   high2        = iHigh(Symbol(), Period(), 2);
   NormalizeDouble(open1, _Digits);
   NormalizeDouble(open2, _Digits);
   NormalizeDouble(close1, _Digits);
   NormalizeDouble(close2, _Digits);
   NormalizeDouble(low1, _Digits);
   NormalizeDouble(low2, _Digits);
   NormalizeDouble(high1, _Digits);
   NormalizeDouble(high2, _Digits);

   Comment("Candle [2] high Price: ", high2, "\n",
           "Candle [2] low Price: ", low2, "\n",
           "Candle [2] M.A Value: ", MaValues[2], "\n",
           "Candle [1] Close Price: ", close1, "\n",
           "Candle [1] M.A Value: ", MaValues[1]
          );

   if(isNewBar())
     {
      if(high2 < MaValues[2] && close1 > MaValues[1])
        {
         Action = "Enter Buy";
        }
      else
         if(low2 > MaValues[2] && close1 < MaValues[1])
           {
            Action = "Enter Sell";
           }
         else
           {
            Action = "Wait";
           }
     }

   if(Action == "Enter Buy" && Trading == false)
     {
      if(PositionsTotal() >= 1)
        {
         for(int i = OrdersTotal() - 1; i >= 0; i--)
           {
            ulong ticket = OrderGetTicket(i);
            if(ticket != 0)
              {
               d_trade.OrderDelete(ticket);
              }
           }
         Buy();
         Trading = true;
        }
      else
        {
         Print("Buy");
         Buy();
         Trading = true;
        }
     }
   if(Action == "Enter Sell" && Trading == false)
     {
      if(PositionsTotal() >= 1)
        {
         for(int i = OrdersTotal() - 1; i >= 0; i--)
           {
            ulong ticket = OrderGetTicket(i);
            if(ticket != 0)
              {
               d_trade.OrderDelete(ticket);
              }
           }
         Sell();
         Trading = true;
        }
      else
        {
         Print("Sell");
         Sell();
         Trading = true;
        }
     }

   EquityStepping();
  }
//+------------------------------------------------------------------+
bool isNewBar()
  {
   static int lastBarsCount = 0;
   int currentBarsCount = Bars(_Symbol, _Period);

   if(currentBarsCount > lastBarsCount)
     {
      lastBarsCount = currentBarsCount;
      Trading = false;
      return true;
     }

   return false;
  }
//+------------------------------------------------------------------+
void Buy()
  {
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double startingPrice = currentPrice;
   d_trade.Buy(Lot, _Symbol, startingPrice);
   for(int i=1;i<10;i++)
     {
      double price = currentPrice - i * GridSpace_Usd;
      d_trade.BuyLimit(Lot, price, _Symbol);
     }
  }
//+------------------------------------------------------------------+
void Sell()
  {
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double startingPrice = currentPrice;
   d_trade.Sell(Lot, _Symbol, startingPrice);
   for(int i=1;i<10;i++)
     {
      double price = currentPrice + i * GridSpace_Usd;
      d_trade.SellLimit(Lot, price, _Symbol);
     }
  }
//+------------------------------------------------------------------+
void EquityStepping()
  {
   double currentequity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(currentequity >= (initialequity + EquityStepProfit_Usd))
     {
      for(int i = PositionsTotal() - 1; i >= 0; i--)
        {
         d_trade.PositionClose(_Symbol);
         Trading = false;
        }
      for(int i = OrdersTotal() - 1; i >= 0; i--)
        {
         ulong ticket = OrderGetTicket(i);
         if(ticket != 0)
           {
            d_trade.OrderDelete(ticket);
           }
        }
      double AccountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
      Print("Account Balance (",AccountBalance,") - Initial Equity (",initialequity,") = ",(AccountBalance - initialequity));
      initialequity = AccountInfoDouble(ACCOUNT_BALANCE);
      Print("New Initial Equity: ", initialequity);
     }
  }
//+------------------------------------------------------------------+
void CleanStrayOrders()
  {
   if(PositionsTotal() == 0 && OrdersTotal() >= 1)
     {
      for(int i = OrdersTotal() - 1; i >= 0; i--)
        {
         ulong ticket = OrderGetTicket(i);
         if(ticket != 0)
           {
            d_trade.OrderDelete(ticket);
           }
        }
     }
  }
//+------------------------------------------------------------------+
