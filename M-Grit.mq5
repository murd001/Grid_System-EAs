//+------------------------------------------------------------------+
//|                                                       M-Grit.mq5 |
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

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CPositionInfo d_position = CPositionInfo();
CTrade d_trade = CTrade();
input double Lot = 0.01;
input double GridSize = 1.0;
input double EquityProfit = 5.0;

bool GridCreateOnce = true;
double initialBalance = 0.0;
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
   initialBalance = AccountInfoDouble(ACCOUNT_BALANCE);
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
   if(GridCreateOnce)
     {
      CreateNewGrid();
      GridCreateOnce = false;
     }

   EquityStepping();
  }
//+------------------------------------------------------------------+
void CreateNewGrid()//create a new grid
  {
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double buyStopPrice = currentPrice + GridSize * Point();
   double sellStopPrice = currentPrice - GridSize * Point();
   d_trade.Buy(Lot, _Symbol, currentPrice, 0, (currentPrice + GridSize * 3 * Point()), NULL);
   for(int i = 0; i < 137; i++)
     {
      double price = buyStopPrice + i * GridSize * Point();
      switch(i % 3)
        {
         case 0:
            d_trade.BuyStop(Lot, price, _Symbol, 0, (price + GridSize * 3 * Point()), NULL);
            break;
         case 1:
            d_trade.BuyStop(Lot, price, _Symbol, 0, (price + GridSize * 2 * Point()), NULL);
            break;
         case 2:
            d_trade.BuyStop(Lot, price, _Symbol, 0, (price + GridSize * 1 * Point()), NULL);
            break;
        }
     }

   for(int i = 0; i < 137; i++)
     {
      double price = sellStopPrice - i * GridSize * Point();
      switch(i % 3)
        {
         case 0:
            d_trade.SellStop(Lot, price, _Symbol, 0, (price - GridSize * 3* Point()), NULL);
            break;
         case 1:
            d_trade.SellStop(Lot, price, _Symbol, 0, (price - GridSize * 2 * Point()), NULL);
            break;
         case 2:
            d_trade.SellStop(Lot, price, _Symbol, 0, (price - GridSize * 1 * Point()), NULL);
            break;
        }
     }
  }

//+------------------------------------------------------------------+
void EquityStepping()
  {
   double currentequity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(currentequity >= (initialBalance + EquityProfit))
     {
      for(int i = PositionsTotal() - 1; i >= 0; i--)
        {
         d_trade.PositionClose(_Symbol);
        }
      for(int i=OrdersTotal()-1; i>=0; i--)
        {
         ulong ticket=OrderGetTicket(i);
         if(ticket!=0)
           {
            d_trade.OrderDelete(ticket);
           }
        }
      double AccountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
      Print("Account Balance (",AccountBalance,") - Initial Equity (",initialBalance,") = ",(AccountBalance - initialBalance));
      initialBalance = AccountInfoDouble(ACCOUNT_BALANCE);
      Print("New Initial Balance: ", initialBalance);
      GridCreateOnce = true;
     }
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
