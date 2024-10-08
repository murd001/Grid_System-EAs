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
CPositionInfo  j_position=CPositionInfo();// trade position object
CTrade         j_trade=CTrade();          // trading object

input int BuyStopDistance = 10;          // Distance in pips for buy stop orders
input int SellStopDistance = 10;         // Distance in pips for sell stop orders
bool GridCreateOnce = true;

MqlTick LastTick;//last tick

input double Lot = 0.1;//Lot
input int MagicC = 679034;//Magic

input double TerminationPoint = 1200.0;
input double perTradeExitPips = 0.9;
input int EquityStepProfit = 5;

double initialequity;
int totalClosedOrders = 0;
int totalClosedOdersCheck = 0;

int buyCount = 0,sellCount = 0;
int arraySize;

struct TradeDetails
  {
   ulong             ticket;
   double            takeProfitLevel;
   double            entryPrice;
   bool              isBuyTrade;
  };

// Array to store information about open trades
TradeDetails openTrades[];
TradeDetails closedTrades[];
TradeDetails closedBuys[];
TradeDetails closedSells[];
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+----------------------------------------  --------------------------+
int OnInit()
  {
   ArrayResize(openTrades, 0); // Initialize the array
   ArrayResize(closedTrades, 0);
   ArrayResize(closedBuys, 0);
   ArrayResize(closedSells, 0);
   return(INIT_SUCCEEDED);
  }


//+------------------------------------------------------------------+
void CreateNewGrid()//create a new grid
  {
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double buyStopPrice = currentPrice + BuyStopDistance * Point();
   double sellStopPrice = currentPrice - SellStopDistance * Point();
   j_trade.Buy(Lot, _Symbol, currentPrice, 0, (currentPrice + perTradeExitPips));
   for(int i = 0; i < 137; i++)
     {
      double price = buyStopPrice + i * BuyStopDistance * Point();
      j_trade.BuyStop(Lot, price, _Symbol, 0, (price + perTradeExitPips), 0);
     }

   for(int i = 0; i < 137; i++)
     {
      double price = sellStopPrice - i * SellStopDistance * Point();
      j_trade.SellStop(Lot, price, _Symbol, 0, (price - perTradeExitPips), 0);
     } 
  }


//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
int onTradeAction = 0;
int dealDelete = 0;
string transMessage = "None";
void OnTick()
  {
//create new grid if none
   if(GridCreateOnce)
     {
      CreateNewGrid();
      GridCreateOnce = false;
     }


//checking accounts profits by jeff mutembei

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

   GetOpenPriceOfLastClosedTrade();
// display the account details
   Comment(
      "Account Balance: ", AccountInfoDouble(ACCOUNT_BALANCE), "\n",
      "Account Equity: ", AccountInfoDouble(ACCOUNT_EQUITY) + "\n",
      "Account Profit: ", AccountInfoDouble(ACCOUNT_PROFIT) + "\n",
      ShowTotalOrders() + "\n",
      "Total Trade Opened : ", ArraySize(openTrades), " : closed => ", ArraySize(closedTrades)," [" + ArraySize(closedBuys) + " Buys : " + ArraySize(closedSells) + " Sells]",
      "   Comment : ", transMessage, "\n"
   );

//Enter new Positions based on the number of sells and buys
   ShowTotalOrders();
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(buyCount > sellCount && ifBidIsinRange(bid) && isNewBar())
     {
      transMessage = "More Buys than sells";
      j_trade.Sell(Lot, _Symbol, bid, 0, (bid - perTradeExitPips));
     }
   else
      if(sellCount > buyCount && ifBidIsinRange(bid) && isNewBar())
        {
         transMessage = "More sells than Buys";
         j_trade.Buy(Lot,_Symbol, bid, 0, (bid + perTradeExitPips));
        }
      else
         if(sellCount == buyCount && buyCount >= 1 && isNewBar())
           {
            transMessage = "Equal sells and buys open";
            // j_trade.Buy(Lot,_Symbol, bid, 0, (bid + perTradeExitPips));
           }

  }
//+------------------------------------------------------------------+
//| Trade function                                                   |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction& trans, const MqlTradeRequest& request, const MqlTradeResult& result)
  {

  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//Helper Functions
//+------------------------------------------------------------------+
void GetOpenPriceOfLastClosedTrade()
  {
// Check for new trades
   int currentPositionsTotal = PositionsTotal();
   if(currentPositionsTotal > 0)
     {
      // Loop through the positions to find the new trades
      for(int i = 0; i < currentPositionsTotal; i++)
        {
         ulong ticket = PositionGetTicket(i);

         // Check if the position is new by comparing with the previous count
         if(IsPositionExists(ticket) && !IsPositionExistsInOpenTrades(ticket))
           {
            // Get information about the new trade
            double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            // You can also get other information such as take profit level
            bool isBuyTrade = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY;

            // Create a new TradeDetails object and add it to the array
            TradeDetails newTrade;
            newTrade.ticket = ticket;
            newTrade.entryPrice = entryPrice;
            newTrade.isBuyTrade = isBuyTrade;
            // You can also assign other values such as take profit level

            ArrayResize(openTrades, ArraySize(openTrades) + 1);
            openTrades[ArraySize(openTrades) - 1] = newTrade;

            break; // Exit the loop after processing the new trade
           }
        }
     }

//Check for closed trades
   for(int i = 0; i < ArraySize(openTrades); i++)
     {
      ulong ticket = openTrades[i].ticket;
      if(!IsPositionExists(ticket) && !IsPositionExistsInClosedTrades(ticket))
        {
         // Get information about the closed trade
         double entryPrice = openTrades[i].entryPrice;

         // Move the closed trade from openTrades to closedTrades array
         ArrayResize(closedTrades, ArraySize(closedTrades) + 1);
         closedTrades[ArraySize(closedTrades) - 1] = openTrades[i];

         // Place the opposite stop order based on the type of the last closed order
         if(openTrades[i].isBuyTrade)
           {
            // Place sell stop order at the opening price of the last closed buy order
            //j_trade.SellStop(Lot, entryPrice, Symbol(), 0, (entryPrice - perTradeExitPips));
            Print("Placed a Sell Stop at : " + entryPrice);

            ArrayResize(closedBuys, ArraySize(closedBuys) + 1);
            closedBuys[ArraySize(closedBuys) - 1] = openTrades[i];

           }
         else
           {
            // Place buy stop order at the opening price of the last closed sell order
            //j_trade.BuyStop(Lot, entryPrice, Symbol(), 0, (entryPrice + perTradeExitPips));
            Print("Placed a Buy Stop at : " + entryPrice);

            ArrayResize(closedSells, ArraySize(closedSells) + 1);
            closedSells[ArraySize(closedSells) - 1] = openTrades[i];
           }

         transMessage = "Trade closed: Ticket " + ticket + ", Entry Price: " + entryPrice;

         break;
        }
     }
  }

//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
bool IsPositionExists(ulong ticket)
  {
   for(int i = 0; i < PositionsTotal(); i++)
     {
      if(PositionGetTicket(i) == ticket)
         return true;
     }
   return false;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsPositionExistsInOpenTrades(ulong ticket)
  {
   for(int i = 0; i < ArraySize(openTrades); i++)
     {
      if(openTrades[i].ticket == ticket)
         return true;
     }
   return false;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsPositionExistsInClosedTrades(ulong ticket)
  {
   for(int i = 0; i < ArraySize(closedTrades); i++)
     {
      if(closedTrades[i].ticket == ticket)
         return true;
     }
   return false;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool ifBidIsinRange(double bid)
  {
   for(int i = 0; i < ArraySize(closedTrades); i++)
     {
      if(bid == closedTrades[i].entryPrice)
        {
         Print("Bid is on one of the grid lines");
         DeleteFromArray(closedTrades, i); // Delete the structure at index i
         Print("Remaining Entries:");
         for(int j = 0; j < ArraySize(closedTrades); j++)
           {
            Print("Entry ", j, ": Ticket ", closedTrades[j].ticket, ", Entry Price ", closedTrades[j].entryPrice);
           }
         return true;
        }
     }
   return false;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void DeleteFromArray(TradeDetails& arr[], const int indexToDelete)
  {
   if(indexToDelete < 0 || indexToDelete >= ArraySize(arr))
      return;

   for(int i = indexToDelete; i < ArraySize(arr) - 1; i++)
     {
      arr[i] = arr[i + 1];
     }
   ArrayResize(arr, ArraySize(arr) - 1);
  }


//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
string ShowTotalOrders()
  {
   int buy_count = 0;
   int sell_count = 0;

   buy_count = 0;
   sell_count = 0;                   //#1 initialize counts

   for(int i = PositionsTotal()-1; i >=0; i--)
     {
      PositionGetTicket(i);

      if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
        {
         buy_count+=1;
        }
      if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
        {
         sell_count+=1;
        }

     } // for loop end

   buyCount = buy_count;
   sellCount = sell_count;

   string commentText = "Total Buy Orders: " + IntegerToString(buy_count) +
                        ", Total Sell Orders: " + IntegerToString(sell_count);

   return commentText;
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
bool HLineCreate(const long            chart_ID=0,        // chart's ID
                 const string          name="HLine",      // line name
                 const int             sub_window=0,      // subwindow index
                 double                price=0,           // line price
                 const color           clr=clrBlue,        // line color
                 const ENUM_LINE_STYLE style=STYLE_SOLID, // line style
                 const int             width=1,           // line width
                 const bool            back=false,        // in the background
                 const bool            selection=true,    // highlight to move
                 const bool            hidden=true,       // hidden in the object list
                 const long            z_order=0
                )
  {
//--- if the price is not set, set it at the current Bid price level

//orderClosePrice int
   if(!price)
      //if(!orderClosePrice && !price)
      price = SymbolInfoDouble(Symbol(),SYMBOL_BID);
//price = orderClosePrice;
//--- reset the error value
   ResetLastError();
//--- create a horizontal line
   if(!ObjectCreate(chart_ID,name,OBJ_HLINE,sub_window,0,price))
     {
      Print(__FUNCTION__,
            ": failed to create a horizontal line! Error code = ",GetLastError());
      return(false);
     }
//--- set line color
   ObjectSetInteger(chart_ID,name,OBJPROP_COLOR,clr);
//--- set line display style
   ObjectSetInteger(chart_ID,name,OBJPROP_STYLE,style);
//--- set line width
   ObjectSetInteger(chart_ID,name,OBJPROP_WIDTH,width);
//--- display in the foreground (false) or background (true)
   ObjectSetInteger(chart_ID,name,OBJPROP_BACK,back);
//--- enable (true) or disable (false) the mode of moving the line by mouse
//--- when creating a graphical object using ObjectCreate function, the object cannot be
//--- highlighted and moved by default. Inside this method, selection parameter
//--- is true by default making it possible to highlight and move the object
   ObjectSetInteger(chart_ID,name,OBJPROP_SELECTABLE,selection);
   ObjectSetInteger(chart_ID,name,OBJPROP_SELECTED,selection);
//--- hide (true) or display (false) graphical object name in the object list
   ObjectSetInteger(chart_ID,name,OBJPROP_HIDDEN,hidden);
//--- set the priority for receiving the event of a mouse click in the chart
   ObjectSetInteger(chart_ID,name,OBJPROP_ZORDER,z_order);
//--- successful execution
   return(true);
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
