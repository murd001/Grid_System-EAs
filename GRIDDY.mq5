//+------------------------------------------------------------------+
//|                                                       GridEA.mq5 |
//|                        Copyright 2024, MetaQuotes Software Corp. |
//|                                              https://www.mql5.com |
//+------------------------------------------------------------------+
#include <Trade\Trade.mqh>
CTrade trade;

input double GridSize = 10.0;            // Grid size in points
input int GridLevels = 5;                // Number of grid levels above and below
input double LotSize = 0.1;              // Lot size
input double ProfitTarget = 100.0;       // Profit target in account currency

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
void OnInit()
{
    // Set initial stop orders
    SetStopOrders();
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    // Check if there are any open positions
    if(PositionsTotal() == 0)
    {
        // If no positions are open, set new stop orders
        SetStopOrders();
    }
    else
    {
        // Loop through all open positions
        for(int i = 0; i < PositionsTotal(); i++)
        {
            // Check if profit target is reached for any open position
            if(PositionGetDouble(POSITION_PROFIT) >= ProfitTarget)
            {
                // Close position
                trade.PositionClose(_Symbol);
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Function to set stop orders                                      |
//+------------------------------------------------------------------+
void SetStopOrders()
{
    double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    
    // Set buy stop orders above current price
    for(int i = 1; i <= GridLevels; i++)
    {
        double buyStopPrice = price + i * GridSize * _Point;
        double buyStopLot = LotSize * i;
        int ticketBuy = trade.BuyStop(buyStopLot, buyStopPrice, _Symbol, NULL);
        if(ticketBuy < 0)
        {
            Print("Error placing buy stop order: ", GetLastError());
        }
    }

    // Set sell stop orders below current price
    for(int i = 1; i <= GridLevels; i++)
    {
        double sellStopPrice = price - i * GridSize * _Point;
        double sellStopLot = LotSize * i;
        int ticketSell = trade.SellStop(sellStopLot, sellStopPrice, _Symbol, NULL);
        if(ticketSell < 0)
        {
            Print("Error placing sell stop order: ", GetLastError());
        }
    }
}
//+------------------------------------------------------------------+

