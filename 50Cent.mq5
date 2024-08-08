//+------------------------------------------------------------------+
//|                                                       50Cent.mq5 |
//|                                  Copyright 2023, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, MetaQuotes Ltd."
//copyright ya MURD pia inakuja
#property link      "https://www.mql5.com"
#property version   "1.00"
#include <Trade\PositionInfo.mqh>
#include <Trade\Trade.mqh>

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CPositionInfo d_position = CPositionInfo();
CTrade d_trade = CTrade();


input double Lot = 0.1;
input double termination_USD = 5.0;
input double perTradeExitPips = 50.0;
input double equityStepProfit_USD = 5.0;
bool startingBuy;
bool termination;
double initialequity;

MqlDateTime currentTime;
MqlDateTime tradeDateTime;
int hour;
int minutes;
int month;
int day;
int tradeMonth;
int tradeDay;
string MarketState;
int Lwma300;
double lwma_300_values[];
double lwma_100_values[];
int lwma100_arraySize = 0;
double oldLwma100Value = 0;
double lwma100Value;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
   startingBuy = false;
   termination = false;
   initialequity = AccountInfoDouble(ACCOUNT_BALANCE);
   Lwma300 = iMA(_Symbol, PERIOD_CURRENT, 300, 0, MODE_LWMA, PRICE_WEIGHTED);
   ArrayResize(lwma_100_values, lwma100_arraySize);
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
   ArraySetAsSeries(lwma_300_values, true);
   CopyBuffer(Lwma300, 0, 1, 100, lwma_300_values);
   lwma100Value = LinearWeightedMovingAverage(lwma_300_values, 100);
   if(oldLwma100Value != lwma100Value && isNewBar())
     {
      lwma100_arraySize = lwma100_arraySize + 1;
      ArraySetAsSeries(lwma_100_values, true);
      ArrayResize(lwma_100_values, lwma100_arraySize);
      lwma_100_values[0] = lwma100Value;
      oldLwma100Value = lwma100Value;
      ManageLWMAArraySize();
     }

   Comment("Linear Weighted Moving Average 300 period: ", lwma_300_values[0], "\n",
           "Linear Weighted Moving Average 100 period: ", lwma_100_values[0]
          );

   TimeToStruct(TimeLocal(),currentTime);
   hour = currentTime.hour;
   minutes = currentTime.min;
   month = currentTime.mon;
   day = currentTime.day;

//Print("Local Time: ",hour," : ",minutes);
   if(hour == 07 && minutes == 59 && PositionsTotal() == 0)
     {
      startingBuy = false;
      termination = false;
     }

   if(hour >= 08 && minutes >= 00)
     {
      if(termination == false && startingBuy == false)
        {
         if(isBullish())
           {
            Print("Starting EA");
            Buying();
            datetime tradeTime = TimeCurrent();
            TimeToStruct(tradeTime, tradeDateTime);
            tradeMonth = tradeDateTime.mon;
            tradeDay = tradeDateTime.day;
            startingBuy = true;
            //Print("Trade Date: ", tradeDateTime.hour, ": ", tradeDateTime.min);
           }
         else
            if(isBearish())
              {
               Print("Starting EA");
               Selling();
               datetime tradeTime = TimeCurrent();
               TimeToStruct(tradeTime, tradeDateTime);
               tradeMonth = tradeDateTime.mon;
               tradeDay = tradeDateTime.day;
               startingBuy = true;
               //Print("Trade Date: ", tradeDateTime.hour, ": ", tradeDateTime.min);
              }

        }
     }
   Equitysteping();
   //stopLoss();
   CheckTpHit();
   SL();
//checkIfNextDay();
//Print("Current Open trades, open date: ",tradeMonth,"/",tradeDay);
//Print("Current Date: ",month,"/",day);
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void Buying()
  {
   if(termination == false && isBullish())
     {
      double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double startingPrice = currentPrice;
      d_trade.Buy(Lot, _Symbol, startingPrice);
      for(int i=1;i<10;i++)
        {
         double price = currentPrice - i * perTradeExitPips;
         d_trade.BuyLimit(Lot, price, _Symbol);
        }
     }
  }
//+------------------------------------------------------------------+
void Selling()
  {
   if(termination == false && isBearish())
     {
      double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double startingPrice = currentPrice;
      d_trade.Sell(Lot, _Symbol, startingPrice);
      for(int i=1;i<10;i++)
        {
         double price = currentPrice + i * perTradeExitPips;
         d_trade.SellLimit(Lot, price, _Symbol);
        }
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void Equitysteping()
  {
   double currentequity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(currentequity >= (initialequity + equityStepProfit_USD))
     {
      for(int i = PositionsTotal() - 1; i >= 0; i--)
        {
         d_trade.PositionClose(_Symbol);
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
      if((AccountBalance - initialequity) < termination_USD)
        {
         double BID = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         if(isBullish() && BID > lwma_300_values[0])
           {
            Buying();
           }
         else
            if(isBearish() && BID < lwma_300_values[0])
              {
               Selling();
              }
        }
      else
        {
         termination = true;
         //initialequity = AccountInfoDouble(ACCOUNT_BALANCE);
         //Print("New Initial Equity: ", initialequity);
        }
      initialequity = AccountInfoDouble(ACCOUNT_BALANCE);
      Print("New Initial Equity: ", initialequity);
     }
  }
//+------------------------------------------------------------------+
void CheckTpHit()
  {
   const int TAKE_PROFIT_HIT_REASON = DEAL_REASON_TP;
   ulong last_deal = GetLastDealTicket();

   if(HistoryDealSelect(last_deal))
     {
      int deal_reason = HistoryDealGetInteger(last_deal, DEAL_REASON);
      if(deal_reason == TAKE_PROFIT_HIT_REASON)
        {
         ulong position_entry_ticket = GetPositionEntryTicket(last_deal);
         if(position_entry_ticket != 0)
           {
            Buying();
           }
         else
           {
            Print("Failed to find position entry ticket for deal #", last_deal);
           }
        }
     }
  }
//+------------------------------------------------------------------+
ulong GetLastDealTicket()
  {
// Request history for the last 7 days
   if(!GetTradeHistory(7))
     {
      // Print an error message and return -1 if history request fails
      Print("GetTradeHistory() returned false");
      return -1;
     }
// Get the ticket of the last deal
   ulong last_deal = HistoryDealGetTicket(HistoryDealsTotal() - 1);
   return last_deal;
  }
//+------------------------------------------------------------------+
ulong GetPositionEntryTicket(ulong deal_ticket)
  {
   long position_id = HistoryDealGetInteger(deal_ticket, DEAL_POSITION_ID);
   if(position_id == -1)
     {
      Print("Failed to get position ID for deal #", deal_ticket);
      return 0;
     }
   for(int i = 0; i < HistoryDealsTotal(); i++)
     {
      ulong current_deal_ticket = HistoryDealGetTicket(i);
      long current_position_id = HistoryDealGetInteger(current_deal_ticket, DEAL_POSITION_ID);
      if(current_position_id == position_id)
        {
         int deal_entry = HistoryDealGetInteger(current_deal_ticket, DEAL_ENTRY);
         if(deal_entry == DEAL_ENTRY_IN)
           {
            return current_deal_ticket;
           }
        }
     }
// If no position entry deal found, return 0
   return 0;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool GetTradeHistory(int days)
  {
// Set a week period to request trade history
   datetime to = TimeCurrent();
   datetime from = to - days * PeriodSeconds(PERIOD_D1);
   ResetLastError();
   if(!HistorySelect(from, to))
     {
      Print("GetTradeHistory() - HistorySelect=false. Error code=", GetLastError());
      return false;
     }
   return true;
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
void SL()
  {
   if(PositionsTotal() >= 4)
     {
      double ProfitNow = AccountInfoDouble(ACCOUNT_PROFIT);
      if(ProfitNow > -5)
        {
         for(int i = PositionsTotal() - 1; i >= 0; i--)
           {
            d_trade.PositionClose(_Symbol);
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
         if((AccountBalance - initialequity) < termination_USD)
           {
            double BID = SymbolInfoDouble(_Symbol, SYMBOL_BID);
            if(isBullish() && BID > lwma_300_values[0])
              {
               Buying();
              }
            else
               if(isBearish() && BID < lwma_300_values[0])
                 {
                  Selling();
                 }
           }
         else
           {
            termination = true;
            //initialequity = AccountInfoDouble(ACCOUNT_BALANCE);
            //print("New Initial Equity: ", initialequity);
           }
         initialequity = AccountInfoDouble(ACCOUNT_BALANCE);
         Print("New Initial Equity: ", initialequity);
        }
     }
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
void checkIfNextDay()
  {
   if(tradeDay != day)
     {
      if(PositionsTotal() >= 1)
        {
         double profitNow = AccountInfoDouble(ACCOUNT_PROFIT);
         if(profitNow >= 0)
           {
            for(int i = PositionsTotal() - 1; i >= 0; i--)
              {
               d_trade.PositionClose(_Symbol);
              }
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
     }
  }
//+------------------------------------------------------------------+
double LinearWeightedMovingAverage(const double& values[], const int period)
  {
   double lwma = 0;
   int weightSum = period * (period + 1) / 2;

   for(int i = 0; i < period; i++)
     {
      lwma += values[i] * (i + 1);
     }

   lwma /= weightSum;
   return lwma;
  }
//+------------------------------------------------------------------+
bool isNewBar()
  {
   static int lastBarsCount = 0;
   int currentBarsCount = Bars(_Symbol, _Period);

   if(currentBarsCount > lastBarsCount)
     {
      lastBarsCount = currentBarsCount;
      return true;
     }

   return false;
  }
//+------------------------------------------------------------------+
void ManageLWMAArraySize()
  {
   const int maxSize = 5;
   if(lwma100_arraySize > maxSize)
     {
      int elementsToRemove = lwma100_arraySize - maxSize;
      for(int i = 0; i < lwma100_arraySize - elementsToRemove; i++)
        {
         lwma_100_values[i] = lwma_100_values[i + elementsToRemove];
        }
      ArrayResize(lwma_100_values, maxSize);
      lwma100_arraySize = maxSize;
     }
  }
//+------------------------------------------------------------------+
bool isBullish()
  {
   double BID = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(lwma_300_values[0] > lwma100Value && BID > lwma_300_values[0])
     {
      MarketState = "Bullish";
      Print("Market State: ",MarketState);
      return true;
     }
   return false;
  }
//+------------------------------------------------------------------+
bool isBearish()
  {
   double BID = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(lwma_300_values[0] < lwma100Value && BID < lwma_300_values[0])
     {
      MarketState = "Bearish";
      Print("Market State: ",MarketState);
      return true;
     }
   return false;
  }
//+------------------------------------------------------------------+
void stopLoss()
  {
   double close2 = iClose(_Symbol, PERIOD_CURRENT, 2);
   double close1 = iClose(_Symbol, PERIOD_CURRENT, 1);
   if(lwma_300_values[2] > close2 && close1 > lwma_300_values[1])
     {
      for(int i = PositionsTotal() - 1; i >= 0; i--)
        {
         d_trade.PositionClose(_Symbol);
        }
      for(int i = OrdersTotal() - 1; i >= 0; i--)
        {
         ulong ticket = OrderGetTicket(i);
         if(ticket != 0)
           {
            d_trade.OrderDelete(ticket);
           }
        }
     }
   else
      if(lwma_300_values[2] < close2 && close1 < lwma_300_values[1])
        {
         for(int i = PositionsTotal() - 1; i >= 0; i--)
           {
            d_trade.PositionClose(_Symbol);
           }
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
