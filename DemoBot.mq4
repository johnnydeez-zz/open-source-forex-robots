// CHFJPY 30M w/ 2 pip spread


#property strict
string BotName = "Demo Bot";

/********** SETTINGS *************/
extern int Magic = 12345;

int MaxCloseSpreadPips = 7;
int MaxTrades = 1; // was 10
int AcceptableSpread = 2;
double LotsToTrade = 2.0;     // 0.1
double StopLoss = -3700;   // 3800
double ProfitTarget = 280.00;  // $280 at 2.0 trade size

int SMAFast = 145; //145 @16188
int SMASlow = 250; //250

int MaxOpenOrderDurationSeconds = (5 * 24 * 60 * 60); // 5 days was profitable 
int TradeDelayTimeSeconds = (10 * 24 * 60 * 60); // 10 Days
int PendingOrderExpirationSeconds = (4 * 24 * 60 * 60); // 4 Days
datetime LastTradePlacedTimestamp = 0;


int OnInit()
{
   return(INIT_SUCCEEDED);
}


void OnDeinit(const int reason)
{
 
}

// MAIN LOOP
void OnTick()
{  
   if (MarketInfo(Symbol(), MODE_SPREAD) > AcceptableSpread) return;
   
   double SlowMovingAverage = iMA(NULL, 0, SMASlow,0, MODE_SMA, PRICE_CLOSE, 0);
   double FastMovingAverage = iMA(NULL, 0, SMAFast,0, MODE_SMA, PRICE_CLOSE, 0);
   
   // Should we place a trade?
   if (GetTotalOpenTrades() < MaxTrades)
   {
      if ( (TimeCurrent() - LastTradePlacedTimestamp) > TradeDelayTimeSeconds ) 
      {
         
         // long
         if ( (FastMovingAverage > SlowMovingAverage) )
         {
        
            if (CheckForTradeSetup() == "long-setup") 
            {
               PlacePendingOrder("long", LotsToTrade, FastMovingAverage, PendingOrderExpirationSeconds);
               LastTradePlacedTimestamp = TimeCurrent();
            }
         }
      
         // short
         if ( (FastMovingAverage < SlowMovingAverage) )
         {
            if (CheckForTradeSetup() == "short-setup" )
            {
               PlacePendingOrder("short", LotsToTrade, FastMovingAverage, PendingOrderExpirationSeconds);
               LastTradePlacedTimestamp = TimeCurrent();
            }

         }
      
      } 
      
   }
   
   if (GetTotalOpenTrades() > 0) 
   {
      CloseTradeAfterAge(MaxOpenOrderDurationSeconds);
      CheckForOrderClose(ProfitTarget, StopLoss);
   }
     
} // end OnTick()


string CheckForTradeSetup()
{
   double SlowMovingAverage[4];
   double FastMovingAverage[4];
   
   SlowMovingAverage[1] = iMA(NULL, 0, SMASlow,0, MODE_SMA, PRICE_CLOSE, 3);
   SlowMovingAverage[2] = iMA(NULL, 0, SMASlow,0, MODE_SMA, PRICE_CLOSE, 15);
   SlowMovingAverage[3] = iMA(NULL, 0, SMASlow,0, MODE_SMA, PRICE_CLOSE, 30);
   
   FastMovingAverage[1] = iMA(NULL, 0, SMAFast,0, MODE_SMA, PRICE_CLOSE, 3);
   FastMovingAverage[2] = iMA(NULL, 0, SMAFast,0, MODE_SMA, PRICE_CLOSE, 15);
   FastMovingAverage[3] = iMA(NULL, 0, SMAFast,0, MODE_SMA, PRICE_CLOSE, 30);

   // long setup check
   if ( 
      (FastMovingAverage[1] < SlowMovingAverage[1]) && 
      (FastMovingAverage[2] < SlowMovingAverage[2]) && 
      (FastMovingAverage[3] < SlowMovingAverage[3]) )
   {
      return "long-setup";
   }
   
   // short setup check
   if ( 
      (FastMovingAverage[1] > SlowMovingAverage[1]) && 
      (FastMovingAverage[2] > SlowMovingAverage[2]) && 
      (FastMovingAverage[3] > SlowMovingAverage[3]) )
   {
      return "short-setup";
   }
   
   return "no-setup";

}


void PlacePendingOrder(string Trade_Type, double Lots, double At_Price, int Expiration_Seconds)
{
   int TicketResult = 0;
   datetime Expiration_Time = (TimeCurrent() + Expiration_Seconds);
   double Price = NormalizeDouble(At_Price, Digits);
   
   if (Trade_Type == "long")
   {   
      if (Ask < At_Price) return;
      double StopPrice = CalculateStopLossPrice(Price, Lots, StopLoss, Trade_Type);
      TicketResult = OrderSend(Symbol(), OP_BUYLIMIT, Lots, Price, 10, StopPrice, 0, " Buy", Magic, Expiration_Time, clrGreen); 
   }
   if (Trade_Type == "short")
   {
      if (Bid > At_Price) return;
      double StopPrice = CalculateStopLossPrice(Price, Lots, StopLoss, Trade_Type);
      TicketResult = OrderSend(Symbol(),OP_SELLLIMIT, Lots, NormalizeDouble(At_Price, Digits), 10, StopPrice, 0, " Sell", Magic, Expiration_Time, clrRed);
   }
   
   
   if(TicketResult < 0)
   {
      Print("OrderSend failed with error #",GetLastError());
   }
   else
   {
      Print("OrderSend placed successfully");
   }
}


double CalculateStopLossPrice(double OrderPrice, double TradeSize, double StopLossDollars, string PositionType)
{  
   // Convert stop loss dollars to positive number
   double CurrentSpread = MarketInfo(Symbol(), MODE_SPREAD);
   Print("*** CurrentSpread: ", CurrentSpread);
   if (StopLossDollars < 0) StopLossDollars = (StopLossDollars * -1);
   
   double PipValue = (TradeSize * 10);
   double StopLossPips = (StopLossDollars / PipValue);
   
   double StopLossPriceAdjust = (StopLossPips / 100);
   
   if (PositionType == "long")
   {
      double StopLossPrice = NormalizeDouble((OrderPrice - StopLossPriceAdjust), Digits );
      StopLossPrice = StopLossPrice - CurrentSpread; // adjust for spread
      return StopLossPrice;
   }
   if (PositionType == "short") 
   {
      double StopLossPrice = NormalizeDouble((OrderPrice + StopLossPriceAdjust), Digits );
      StopLossPrice = StopLossPrice + (CurrentSpread/100); // adjust for spread
      return StopLossPrice;
   }
   
   return 0.0;
}


void CloseAllTrades()
{
   int CloseResult = 0;
    
   for(int t=0; t<OrdersTotal(); t++)
   {
      if(OrderSelect(t, SELECT_BY_POS,MODE_TRADES))
      {
         if(OrderMagicNumber() != Magic) continue;
         if(OrderSymbol() != Symbol()) continue;
         
         if(OrderType() == OP_BUY)  CloseResult = OrderClose(OrderTicket(), OrderLots(), Bid, MaxCloseSpreadPips, clrRed);
         if(OrderType() == OP_SELL) CloseResult = OrderClose(OrderTicket(), OrderLots(), Ask, MaxCloseSpreadPips, clrGreen);
         
         t--;       
      }
   }
   
   if(CloseResult < 0)
   {
      Print("OrderSend failed with error #", GetLastError());
   }
   else
   {
      Print("OrderSend placed successfully");
   }

   return;
}


int GetTotalOpenTrades()
{
   int TotalTrades = 0;
   for (int t=0; t<OrdersTotal(); t++)
   {
      if(OrderSelect(t, SELECT_BY_POS, MODE_TRADES))
      {
         if(OrderSymbol() != Symbol()) continue;
         if(OrderMagicNumber() != Magic) continue;
         if(OrderCloseTime() != 0) continue;
         
         TotalTrades = (TotalTrades + 1);
      }
   }
   return TotalTrades;
}


double GetTotalProfits()
{
   double TotalProfits = 0.0;
   
   for (int t=0; t<OrdersTotal(); t++)
   {
      if(OrderSelect(t, SELECT_BY_POS, MODE_TRADES))
      {
         if(OrderSymbol() != Symbol()) continue;
         if(OrderMagicNumber() != Magic) continue;
         if(OrderCloseTime() != 0) continue;
         
         TotalProfits = (TotalProfits + OrderProfit());
      }
   }
   
   return TotalProfits;
}


// Close all trades if we are at profit or loss
void CheckForOrderClose(double Target, double Stop)
{
   // check for profit or loss
   if (GetTotalProfits() > Target)
   {
      CloseAllTrades();
   }
}


// Close if trade is more than (n) seconds old
string CloseTradeAfterAge(int MaxOpenTradeAgeSeconds)
{
   for(int t=0; t < OrdersTotal(); t++)
   {
      if(OrderSelect(t, SELECT_BY_POS, MODE_TRADES))
      {
         if(OrderSymbol() != Symbol()) return "wrong symbol";
         if(OrderMagicNumber() != Magic) return "magic number does not match";
         if(OrderCloseTime() != 0) return "order already closed";      
         
         datetime OrderOpenTime = OrderOpenTime();
         
         string Now = (TimeToStr(TimeCurrent(), TIME_DATE|TIME_SECONDS));
         datetime NowTimeStamp = (StrToTime(Now));
         
         if ((NowTimeStamp - OrderOpenTime) > MaxOpenTradeAgeSeconds) // 1 * 24 * 60 * 60
         {
            if ((OrderType() == 0) || (OrderType() == 1)) // Only close orders that are live (not limit ordes)
            {
               CloseAllTrades();
               return "all trades closed";
            }
         }
         
      }
   }
   return "trades not closed"; 
}

