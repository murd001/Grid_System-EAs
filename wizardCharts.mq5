//+------------------------------------------------------------------+
//|                                                 megaPosition.mq5 |
//|                                  Copyright 2024, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

#include <Trade\PositionInfo.mqh>
#include <Trade\Trade.mqh>

// User defined sizeof macro



//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CPositionInfo  j_position=CPositionInfo();// trade position object
CTrade         j_trade=CTrade();          // trading object


///grid variables
input int MaxChannelSizePoints = 500;//Max Of a+d
// input int MinMoveToClose = 100;//Mininum Move
input int GridStepPoints = 25;//Grid Step In Points
input int BarsI = 999;//Bars To Start Calculate
input double KClose = 3.5;//Asymmetry
input double gridSize = 0.3; //Space between two gridlines
input int numGridLInes = 10; //Number of gridlines one side
input double spaceBetweenB1S1 = 0.2;
bool GridCreateOnce = true;
double BuyPosTps[];
double SellPosTps[];
int atrHandle;
double atrValue[];

MqlTick LastTick;//last tick

input double Lot = 0.1;//Lot
input int MagicC = 679034;//Magic

input double Total_positions_profit = 4.0;
input double TerminationPoint = 120.0;
input double perTradeExitPips = 1;
input int EquityStepProfit = 10;

input int BuyStopDistance = 10; // Distance in pips for buy stop orders
input int SellStopDistance = 10; // Distance in pips for sell stop orders

double initialequity;

//--- day of week
enum dayOfWeek
  {
   S=0,     // Sunday
   M=1,     // Monday
   T=2,     // Tuesday
   W=3,     // Wednesday
   Th=4,    // Thursday
   Fr=5,    // Friday,
   St=6,    // Saturday
  };
//--- input parameters
input dayOfWeek swapday=W;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+----------------------------------------  --------------------------+
int OnInit()
  {
//---
   ParameterSetRange("spaceBetweenB1S1", true, 0.1, 0.1, 0.1, 2.0);
   ParameterSetRange("gridSize", true, 0.2, 0.1, 0.1, 2.0);
   ArrayResize(BuyPosTps,0);
   ArrayResize(SellPosTps,0);
   atrHandle = iATR(_Symbol, PERIOD_CURRENT, 14);
//---
   return(INIT_SUCCEEDED);
  }


// Fix the Start Step and stop from here
void OnTesterInit()
  {
//bool  ParameterSetRange(
//const string  name,          // parameter (input variable) name
//bool          enable,        // parameter optimization enabled
//double        value,         // parameter value
//double        start,         // initial value
//double        step,          // change step
//double        stop           // final value
//);

   return;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTesterDeinit()
  {
   return;
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---

  }



/////working code of the grid
datetime GridStartTime;//grid construction time
double GridStartPrice;//grid starting price
double GridUpPrice;//upper price within the corridor
double GridDownPrice;//lower price within the corridor

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CreateNewGrid()//create a new grid
  {
// Get current market price
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);

// Calculate price levels for buy stop and sell stop orders
   double buyStopPrice = currentPrice + BuyStopDistance * Point();
   double sellStopPrice = currentPrice - SellStopDistance * Point();

// Place buy stop orders
   for(int i = 0; i < 137; i++)
     {
      double price = buyStopPrice + i * BuyStopDistance * Point();
      j_trade.BuyStop(Lot,price,_Symbol,0,(price+perTradeExitPips),0);

     }

// Place sell stop orders
   for(int i = 0; i < 137; i++)
     {
      double price = sellStopPrice - i * SellStopDistance * Point();
      j_trade.SellStop(Lot,price,_Symbol,0,(price-perTradeExitPips),0);

     }

  }


//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   ArraySetAsSeries(atrValue, true);
   CopyBuffer(atrHandle, 0, 0, 3, atrValue);

   if(PositionSelect(_Symbol)==true)
     {
      // count down the number of positions until zero
      for(int i = PositionsTotal()-1; i >=0; i--)
        {
         // calculate the ticket number
         ulong PositionTicket = PositionGetTicket(i);
         // calculate the currency pair
         string PositionSymbol=PositionGetString(POSITION_SYMBOL);
         // calculate the open price for the position
         double PositionPriceOpen = PositionGetDouble(POSITION_PRICE_OPEN);
         // calculate the current position price
         double PositionPriceCurrent = PositionGetDouble(POSITION_PRICE_CURRENT);
         // calculate the current position profit
         double PositionProfit = PositionGetDouble(POSITION_PROFIT);
         // calculate the current position swap
         int PositionSwap=(int) PositionGetDouble(POSITION_SWAP);

         // calculate the current position net profit
         double PositionNetProfit = PositionProfit + PositionSwap;
         //if (PositionSymbol==_Symbol)
         if(false)
           {
            Comment(
               "Position Number: ", i,"\n",
               "Position Ticket: ", PositionTicket+"\n",
               "Position Symbol: ", PositionSymbol+"\n",
               "Position Profit ", PositionProfit, "\n",
               "Position Swap", PositionSwap, "\n",
               "Position NetProfit ", PositionNetProfit, "\n",
               "Position Price Open: ", PositionPriceOpen, "\n",
               "Position Price Current: ", PositionPriceCurrent
            );
           } // if End
        } // for Ende
     }
   else
     {
      Comment(
         "No Open Positions for : ", _Symbol, "\n"
      );

      if(GridCreateOnce)
        {
         CreateNewGrid();
         GridCreateOnce = false;
        }
     }
//checking accounts profits
   double AccountProfit = AccountInfoDouble(ACCOUNT_PROFIT);
   if(AccountProfit >= Total_positions_profit)
     {
      for(int i=PositionsTotal()-1; i>=0; i--)
        {
         j_trade.PositionClose(_Symbol);
         //orderClosePrice = SymbolInfoDouble(Symbol(),SYMBOL_BID);
        }
      for(int i=OrdersTotal()-1; i>=0; i--)
        {
         ulong ticket=OrderGetTicket(i);
         if(ticket!=0)
           {
            j_trade.OrderDelete(ticket);
           }
        }
      //
      double AccountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
      if(AccountBalance < TerminationPoint)
        {
         CreateNewGrid();
         //
        }
      else
        {
         ExpertRemove();
        }
     }
   double currentequity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(currentequity >= (initialequity + EquityStepProfit))
     {
      for(int i=PositionsTotal()-1; i>=0; i--)
        {
         j_trade.PositionClose(_Symbol);
        }
      for(int i=OrdersTotal()-1; i>=0; i--)
        {
         ulong ticket=OrderGetTicket(i);
         if(ticket!=0)
           {
            j_trade.OrderDelete(ticket);
           }
        }
      initialequity = AccountInfoDouble(ACCOUNT_BALANCE);
      double AccountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
      if(AccountBalance < TerminationPoint)
        {
         CreateNewGrid();
        }
      else
        {
         ExpertRemove();
        }
     }
   landMines();
   
// display the account details
   Comment(
      "Account Balance: ", AccountInfoDouble(ACCOUNT_BALANCE), "\n",
      "Account Equity: ", AccountInfoDouble(ACCOUNT_EQUITY) + "\n",
      "Account Profit: ", AccountInfoDouble(ACCOUNT_PROFIT) + "\n",
      "Total Orders : ", OrdersTotal()
   );

  }
//+------------------------------------------------------------------+
//| Trade function                                                   |
//+------------------------------------------------------------------+
void OnTrade()
  {
//---
   Alert("Total Orders : ", OrdersTotal());
  }
//+------------------------------------------------------------------+


//+------------------------------------------------------------------+
void recreatingGrid()
  {
   for(int i=PositionsTotal()-1; i>=0; i--)
     {
      if(PositionSelect(_Symbol) == true)
        {
         ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         if(posType == 0)
           {
            double BuypositionTp = PositionGetDouble(POSITION_TP);
            ArrayResize(BuyPosTps, ArraySize(BuyPosTps) + 1);
            BuyPosTps[ArraySize(BuyPosTps)-1] = BuypositionTp;
           }
         else
            if(posType == 1)
              {
               double SellpositionTp = PositionGetDouble(POSITION_TP);
               ArrayResize(SellPosTps, ArraySize(SellPosTps)+1);
               SellPosTps[ArraySize(SellPosTps)-1] = SellpositionTp;
              }
        }
     }

   double Bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   for(int i=0;i<ArraySize(BuyPosTps);i++)
     {
      if(Bid >= BuyPosTps[i])
        {
         double entryprice = Bid-perTradeExitPips;
         j_trade.SellStop(Lot, entryprice, _Symbol, 0, (entryprice - perTradeExitPips));
        }
     }

   for(int i=0;i<ArraySize(SellPosTps);i++)
     {
      if(Bid <= SellPosTps[i])
        {
         double entryprice = Bid + perTradeExitPips;
         j_trade.BuyStop(Lot, entryprice, _Symbol, 0, (entryprice + perTradeExitPips));
        }
     }
  }
//+------------------------------------------------------------------+
void landMines()
  {
   for(int i=PositionsTotal()-1; i>=0; i--)
     {
      if(PositionSelect(_Symbol) == true)
        {
         double positionProfit = PositionGetDouble(POSITION_PROFIT);
         ENUM_POSITION_TYPE postype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         bool stopset = false;
         double Bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         double stoppositionOpen = Bid - atrValue[0];
         double buyStPositionOpen = Bid + atrValue[0];
         if(postype == 0 && stopset == false && positionProfit >= 2.9)
           {
            j_trade.SellStop(Lot, stoppositionOpen, _Symbol, 0, (stoppositionOpen - perTradeExitPips));
            stopset = true;
           }
         else
            if(postype == 1 && stopset == false)
              {
               j_trade.BuyStop(Lot, buyStPositionOpen, _Symbol, 0, (buyStPositionOpen + perTradeExitPips));
               stopset = true;
              }
        }
     }
  }
//+------------------------------------------------------------------+
