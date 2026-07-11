//+------------------------------------------------------------------+
//|                                        StraddleBreakoutEA.mq5    |
//|                        3-Step Straddle Breakout (Raw Version)     |
//|                                                                  |
//|  Strategy Overview:                                              |
//|  - Places dual pending orders (Buy Stop + Sell Stop) around      |
//|    the current price at a configurable distance.                  |
//|  - When one triggers, the opposite pending order is deleted       |
//|    (One-Cancels-Other logic).                                    |
//|  - The active trade is managed by a 3-Step Milestone Trailing    |
//|    Stop with no hard Take Profit.                                |
//|  - After Step 3, the SL continues to trail in fixed increments.  |
//+------------------------------------------------------------------+
#property copyright   "StraddleBreakoutEA"
#property link        ""
#property version     "1.00"
#property strict
//--- Include the standard trade library for order execution
#include <Trade\Trade.mqh>
//+------------------------------------------------------------------+
//| USER INPUTS                                                      |
//+------------------------------------------------------------------+
//--- Lot size for all orders
input double InpLotSize               = 0.01;   // Trade lot size
//--- Straddle distance: how far above Ask / below Bid to place pendings
input int    InpStraddleDistance_Points = 150;   // Straddle distance (points)
//--- Hard Stop Loss attached to pending orders at creation
input int    InpHardSL_Points          = 500;   // Hard SL distance (points)
//--- Step 1 milestone: trigger and lock distances in points
input int    InpStep1_Trigger          = 50;    // Step 1 trigger (points profit)
input int    InpStep1_Lock             = 30;    // Step 1 lock SL (points from entry)
//--- Step 2 milestone
input int    InpStep2_Trigger          = 80;    // Step 2 trigger (points profit)
input int    InpStep2_Lock             = 60;    // Step 2 lock SL (points from entry)
//--- Step 3 milestone
input int    InpStep3_Trigger          = 120;   // Step 3 trigger (points profit)
input int    InpStep3_Lock             = 100;   // Step 3 lock SL (points from entry)
//--- After Step 3 is reached, trail the SL upward by this increment
//--- whenever price moves an additional InpTrailingStep_Points in profit
input int    InpTrailingStep_Points    = 10;    // Trailing step after Step 3 (points)
//--- Magic number to tag all orders/positions from this EA
input int    InpMagicNumber            = 1111;  // EA magic number
//+------------------------------------------------------------------+
//| GLOBAL OBJECTS                                                   |
//+------------------------------------------------------------------+
//--- CTrade instance used for all trade operations
CTrade Trade;
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   //--- Configure the trade object with our magic number and async mode off
   Trade.SetExpertMagicNumber(InpMagicNumber);
   Trade.SetDeviationInPoints(10);             // reasonable default slippage
   Trade.SetTypeFilling(ORDER_FILLING_FOK);    // fill-or-kill (adjust per broker)
   //--- Basic input validation
   if(InpLotSize <= 0.0)
     {
      Print("ERROR: InpLotSize must be > 0");
      return(INIT_PARAMETERS_INCORRECT);
     }
   if(InpStraddleDistance_Points <= 0 || InpHardSL_Points <= 0)
     {
      Print("ERROR: Straddle distance and Hard SL must be > 0");
      return(INIT_PARAMETERS_INCORRECT);
     }
   if(InpStep1_Trigger <= 0 || InpStep2_Trigger <= InpStep1_Trigger ||
      InpStep3_Trigger <= InpStep2_Trigger)
     {
      Print("ERROR: Step triggers must be positive and ascending (Step1 < Step2 < Step3)");
      return(INIT_PARAMETERS_INCORRECT);
     }
   if(InpStep1_Lock < 0 || InpStep2_Lock <= InpStep1_Lock ||
      InpStep3_Lock <= InpStep2_Lock)
     {
      Print("ERROR: Step locks must be non-negative and ascending (Step1 < Step2 < Step3)");
      return(INIT_PARAMETERS_INCORRECT);
     }
   Print("StraddleBreakoutEA initialized on ", _Symbol,
         " | Point=", _Point, " | Digits=", _Digits);
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   Print("StraddleBreakoutEA removed. Reason code: ", reason);
  }
//+------------------------------------------------------------------+
//| Expert tick function — main logic loop                           |
//+------------------------------------------------------------------+
void OnTick()
  {
   //--- Count how many positions and pending orders belong to this EA
   int myPositions = CountMyPositions();
   int myOrders    = CountMyOrders();
   //=========================================================================
   // PHASE 1: OCO — Place straddle if no position and no pending orders
   //=========================================================================
   if(myPositions == 0 && myOrders == 0)
     {
      PlaceStraddleOrders();
      return;  // nothing else to do this tick
     }
   //=========================================================================
   // PHASE 2: OCO — If a position is open but a pending order remains, delete it
   //=========================================================================
   if(myPositions > 0 && myOrders > 0)
     {
      DeleteMyPendingOrders();
     }
   //=========================================================================
   // PHASE 3: Trailing Stop management on the active position
   //=========================================================================
   if(myPositions > 0)
     {
      ManageTrailingStop();
     }
  }
//+------------------------------------------------------------------+
//| Place the Buy Stop and Sell Stop straddle pair                   |
//+------------------------------------------------------------------+
void PlaceStraddleOrders()
  {
   //--- Fetch current prices
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   //--- Convert point-based inputs to price distances
   double straddleDist = InpStraddleDistance_Points * _Point;
   double hardSLDist   = InpHardSL_Points * _Point;
   //--- Calculate Buy Stop price and its SL
   double buyStopPrice = NormalizeDouble(ask + straddleDist, _Digits);
   double buyStopSL    = NormalizeDouble(buyStopPrice - hardSLDist, _Digits);
   //--- Calculate Sell Stop price and its SL
   double sellStopPrice = NormalizeDouble(bid - straddleDist, _Digits);
   double sellStopSL    = NormalizeDouble(sellStopPrice + hardSLDist, _Digits);
   //--- Place Buy Stop (no TP — trailing manages the exit)
   if(!Trade.BuyStop(InpLotSize, buyStopPrice, _Symbol, buyStopSL, 0.0,
                     ORDER_TIME_GTC, 0, "Straddle BuyStop"))
     {
      Print("ERROR placing Buy Stop: ", Trade.ResultRetcode(),
            " — ", Trade.ResultRetcodeDescription());
     }
   else
     {
      Print("Buy Stop placed at ", buyStopPrice, " | SL=", buyStopSL);
     }
   //--- Place Sell Stop (no TP)
   if(!Trade.SellStop(InpLotSize, sellStopPrice, _Symbol, sellStopSL, 0.0,
                      ORDER_TIME_GTC, 0, "Straddle SellStop"))
     {
      Print("ERROR placing Sell Stop: ", Trade.ResultRetcode(),
            " — ", Trade.ResultRetcodeDescription());
     }
   else
     {
      Print("Sell Stop placed at ", sellStopPrice, " | SL=", sellStopSL);
     }
  }
//+------------------------------------------------------------------+
//| Delete all pending orders that belong to this EA (OCO cleanup)   |
//+------------------------------------------------------------------+
void DeleteMyPendingOrders()
  {
   //--- Iterate backwards to safely delete while iterating
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      ulong ticket = OrderGetTicket(i);
      if(ticket == 0)
         continue;
      //--- Only touch orders on our symbol with our magic number
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if(OrderGetInteger(ORDER_MAGIC) != InpMagicNumber)
         continue;
      //--- Delete the pending order
      if(!Trade.OrderDelete(ticket))
        {
         Print("ERROR deleting order #", ticket, ": ", Trade.ResultRetcode(),
               " — ", Trade.ResultRetcodeDescription());
        }
      else
        {
         Print("OCO: Deleted pending order #", ticket);
        }
     }
  }
//+------------------------------------------------------------------+
//| Manage the 3-Step Milestone Trailing Stop on the active position |
//+------------------------------------------------------------------+
void ManageTrailingStop()
  {
   //--- Find our position
   ulong posTicket = 0;
   double openPrice = 0.0;
   double currentSL = 0.0;
   long   posType   = -1;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
         continue;
      //--- Found our position
      posTicket = ticket;
      openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      currentSL = PositionGetDouble(POSITION_SL);
      posType   = PositionGetInteger(POSITION_TYPE);
      break;  // we only manage one position at a time
     }
   //--- Safety check
   if(posTicket == 0)
      return;
   //--- Calculate current profit in points
   //    For a BUY:  profit_points = (Bid - openPrice) / _Point
   //    For a SELL: profit_points = (openPrice - Ask) / _Point
   double profitPoints = 0.0;
   double currentPrice = 0.0;
   if(posType == POSITION_TYPE_BUY)
     {
      currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      profitPoints = (currentPrice - openPrice) / _Point;
     }
   else if(posType == POSITION_TYPE_SELL)
     {
      currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      profitPoints = (openPrice - currentPrice) / _Point;
     }
   else
     {
      return;  // unknown position type
     }
   //--- Determine the new SL based on the highest milestone achieved
   //    We evaluate in DESCENDING order so the highest milestone wins.
   double newSL = 0.0;
   bool   shouldModify = false;
   //---------------------------------------------------------------
   // BEYOND STEP 3: continuous trailing in InpTrailingStep_Points increments
   //---------------------------------------------------------------
   if(profitPoints >= InpStep3_Trigger + InpTrailingStep_Points)
     {
      //--- How many full trailing steps beyond Step 3 trigger?
      //    excessPoints = total points beyond the Step 3 trigger level
      double excessPoints = profitPoints - (double)InpStep3_Trigger;
      //--- Number of complete trailing steps
      int trailingSteps = (int)MathFloor(excessPoints / (double)InpTrailingStep_Points);
      //--- The lock level = Step3_Lock + (trailingSteps * InpTrailingStep_Points)
      double lockPoints = (double)InpStep3_Lock
                        + (double)(trailingSteps * InpTrailingStep_Points);
      if(posType == POSITION_TYPE_BUY)
         newSL = NormalizeDouble(openPrice + lockPoints * _Point, _Digits);
      else
         newSL = NormalizeDouble(openPrice - lockPoints * _Point, _Digits);
      shouldModify = true;
     }
   //---------------------------------------------------------------
   // STEP 3 REACHED
   //---------------------------------------------------------------
   else if(profitPoints >= InpStep3_Trigger)
     {
      if(posType == POSITION_TYPE_BUY)
         newSL = NormalizeDouble(openPrice + InpStep3_Lock * _Point, _Digits);
      else
         newSL = NormalizeDouble(openPrice - InpStep3_Lock * _Point, _Digits);
      shouldModify = true;
     }
   //---------------------------------------------------------------
   // STEP 2 REACHED
   //---------------------------------------------------------------
   else if(profitPoints >= InpStep2_Trigger)
     {
      if(posType == POSITION_TYPE_BUY)
         newSL = NormalizeDouble(openPrice + InpStep2_Lock * _Point, _Digits);
      else
         newSL = NormalizeDouble(openPrice - InpStep2_Lock * _Point, _Digits);
      shouldModify = true;
     }
   //---------------------------------------------------------------
   // STEP 1 REACHED
   //---------------------------------------------------------------
   else if(profitPoints >= InpStep1_Trigger)
     {
      if(posType == POSITION_TYPE_BUY)
         newSL = NormalizeDouble(openPrice + InpStep1_Lock * _Point, _Digits);
      else
         newSL = NormalizeDouble(openPrice - InpStep1_Lock * _Point, _Digits);
      shouldModify = true;
     }
   //--- If no milestone has been reached yet, do nothing
   if(!shouldModify)
      return;
   //=========================================================================
   // FORWARD-ONLY RULE: Only modify if newSL protects MORE profit than currentSL
   //=========================================================================
   bool isBetter = false;
   if(posType == POSITION_TYPE_BUY)
     {
      //--- For a BUY, a higher SL protects more profit
      isBetter = (newSL > currentSL + _Point * 0.5);  // small tolerance for rounding
     }
   else
     {
      //--- For a SELL, a lower SL protects more profit
      //    Also handle the case where currentSL is 0 (no SL set yet)
      if(currentSL == 0.0)
         isBetter = true;
      else
         isBetter = (newSL < currentSL - _Point * 0.5);
     }
   if(!isBetter)
      return;
   //--- Modify the position's SL (keep TP at 0 — no hard TP)
   double currentTP = PositionGetDouble(POSITION_TP);
   if(!Trade.PositionModify(posTicket, newSL, currentTP))
     {
      Print("ERROR modifying SL for position #", posTicket, ": ",
            Trade.ResultRetcode(), " — ", Trade.ResultRetcodeDescription());
     }
   else
     {
      Print("Trailing SL updated: Position #", posTicket,
            " | Profit=", NormalizeDouble(profitPoints, 1), " pts",
            " | Old SL=", currentSL,
            " | New SL=", newSL);
     }
  }
//+------------------------------------------------------------------+
//| Count open positions belonging to this EA on the current symbol  |
//+------------------------------------------------------------------+
int CountMyPositions()
  {
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
         continue;
      count++;
     }
   return count;
  }
//+------------------------------------------------------------------+
//| Count pending orders belonging to this EA on the current symbol  |
//+------------------------------------------------------------------+
int CountMyOrders()
  {
   int count = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      ulong ticket = OrderGetTicket(i);
      if(ticket == 0)
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if(OrderGetInteger(ORDER_MAGIC) != InpMagicNumber)
         continue;
      count++;
     }
   return count;
  }
//+------------------------------------------------------------------+
