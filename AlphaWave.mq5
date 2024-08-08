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

input double gridSize = 0.3; //Space between two gridlines
input int numGridLInes = 10; //Number of gridlines one side
input double spaceBetweenB1S1 = 0.2;
bool GridCreateOnce = true;

MqlTick LastTick;//last tick

input double Lot = 0.01;//Lot
input int MagicC = 679034;//Magic

input double Total_positions_profit = 4.0;
input double TerminationPoint = 120.0;
input double perTradeExitPips = 0.2;
input int EquityStepProfit = 10;

double initialequity;
int totalClosedOrders = 0;
int totalClosedOdersCheck = 0;

//--- day of week, idk just testing enums
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
input dayOfWeek swapday=W;

struct TradeDetails
  {
   ulong             ticket;
   double            takeProfitLevel;
   double            entryPrice;
   bool   isBuyTrade;
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
  
  
  // Fix the Start Step and stop from here
void OnTesterInit()
{
   ParameterSetRange("spaceBetweenB1S1", true, 0.1, 0.1, 0.1, 2.0);
   ParameterSetRange("gridSize", true, 0.2, 0.1, 0.1, 2.0);
   return;
}

void OnTesterDeinit()
{
   return;
}
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   
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
   SymbolInfoTick(Symbol(),LastTick);
   GridStartTime = TimeCurrent();
   GridStartPrice = LastTick.bid;
   GridUpPrice = GridStartPrice;
   GridDownPrice = GridStartPrice;
   
    HLineCreate(0,"Lewiih New ST",0,GridStartPrice);  //line where we enter to create a new grid
   
   
   //create my grid
   //double SummUp = LastTick.ask + double(GridStepPoints)*_Point + spaceBetweenB1S1;
   double SummUp = GridStartPrice;
   double SummDown = SummUp - (spaceBetweenB1S1/2.0);
   
   for(int i=0; i < numGridLInes;i++)
    {
         j_trade.BuyStop(Lot,SummUp,Symbol(),0,(SummUp + perTradeExitPips));
         //j_trade.BuyStop(Lot,SummUp,Symbol(),0,0.0);
         SummUp += gridSize;
         
         j_trade.SellStop(Lot,SummDown,Symbol(),0,(SummDown - perTradeExitPips));
         //j_trade.SellStop(Lot,SummDown,Symbol(),0,0.0);
         SummDown -= gridSize;
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
      "Total Trade Opened : ", ArraySize(openTrades), " : closed => ", ArraySize(closedTrades), "   Comment : ", transMessage, "\n"
   );
     
      
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
    if (currentPositionsTotal > 0)
    {
        // Loop through the positions to find the new trades
        for (int i = 0; i < currentPositionsTotal; i++)
        {
            ulong ticket = PositionGetTicket(i);

            // Check if the position is new by comparing with the previous count
            if (!IsPositionExists(ticket))
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
    for (int i = 0; i < ArraySize(openTrades); i++)
    {
        ulong ticket = openTrades[i].ticket;
        if (!IsPositionExistsInOpenTrades(ticket) && !IsPositionExistsInClosedTrades(ticket))
        {
            // Get information about the closed trade
            double entryPrice = openTrades[i].entryPrice;
            // You can also get other information such as take profit level

            // Move the closed trade from openTrades to closedTrades array
            ArrayResize(closedTrades, ArraySize(closedTrades) + 1);
            closedTrades[ArraySize(closedTrades) - 1] = openTrades[i];
            
            bool isBuyTrade = openTrades[i].isBuyTrade;
            
            //track the number of closed buys and sells
            if(isBuyTrade)
              {
                  ArrayResize(closedBuys, ArraySize(closedBuys) + 1);
                  closedBuys[ArraySize(closedBuys) - 1] = openTrades[i];
              }
              else
              {
                  ArrayResize(closedSells, ArraySize(closedSells) + 1);
                  closedSells[ArraySize(closedSells) - 1] = openTrades[i];
              }
              
              //to access kitu kama entry price ya last closed buy trade 
              closedBuys[ArraySize(closedSells) - 1].entryPrice;
            
            int lineNumber = ArraySize(closedTrades) - 1;
            
            // Place the opposite stop order based on the type of the last closed order
                if (isBuyTrade ) {
                     //entryPrice -= perTradeExitPips;
                    // Place sell stop order at the opening price of the last closed buy order
                    j_trade.SellStop(Lot, entryPrice, Symbol(), 0, (entryPrice - perTradeExitPips));
                    //HLineCreate(0,StringFormat("We are at line Number : %i ",lineNumber),0,entryPrice,clrAqua);  //line where we enter to create a new grid
                    Print("Placed a Sell Stop at : " + entryPrice);
                    
                } else {
                     //entryPrice += perTradeExitPips;
                    // Place buy stop order at the opening price of the last closed sell order
                    j_trade.BuyStop(Lot, entryPrice, Symbol(), 0, (entryPrice + perTradeExitPips));
                    //HLineCreate(0,StringFormat("We are at line Number : %i ",lineNumber),0,entryPrice,clrDarkGray);  //line where we enter to create a new grid
                    Print("Placed a Buy Stop at : " + entryPrice);
                    
                }

                // Print a message indicating the new trade
                Print("New trade opened: Ticket ", ticket, ", Entry Price: ", entryPrice);
            

            // Print a message indicating the closed trade
            transMessage = "Trade closed: Ticket " + ticket + ", Entry Price: " + entryPrice;

            // Remove the closed trade from the openTrades array
            //ArrayRemove(openTrades, i);

            // Exit the loop after processing the closed trade
            break;
        }
    }
}

bool IsPositionExistsInOpenTrades(ulong ticket)
{
    for (int i = 0; i < PositionsTotal(); i++)
    {
        if (PositionGetTicket(i) == ticket)
            return true;
    }
    return false;
}
bool IsPositionExists(ulong ticket)
{
    for (int i = 0; i < ArraySize(openTrades); i++)
    {
        if (openTrades[i].ticket == ticket)
            return true;
    }
    return false;
}
bool IsPositionExistsInClosedTrades(ulong ticket)
{
    for (int i = 0; i < ArraySize(closedTrades); i++)
    {
        if (closedTrades[i].ticket == ticket)
            CheckClosePosition();
        return true;
    }
    return false;
}
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
string CheckClosePosition() {
   int buy_count = 0;
   int sell_count = 0;

   buy_count = 0;   sell_count = 0;                   //#1 initialize counts

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
     
     ulong last_ticket = closedTrades[ArraySize(closedTrades) - 1 ].ticket;
     string commentText = "About to Close Trade";
      
      if(buy_count > sell_count)
       {
            
       }
       
      return commentText;
}


//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
string ShowTotalOrders() {
   int buy_count = 0;
   int sell_count = 0;

   buy_count = 0;   sell_count = 0;                   //#1 initialize counts

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