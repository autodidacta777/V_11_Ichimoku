//+------------------------------------------------------------------+
//|        EA Ichimoku - Solo Ventas con Trailing Dinámico           |
//+------------------------------------------------------------------+
#property strict

input double Lote = 0.01;
input double SL_USD = 1.0;
input double TP_USD = 8.0;
input double TrailingStart = 3.0;   // activar trailing a +3 USD
input double TrailingStep = 1.0;    // trailing de 1 USD
input int    MaxTrades = 8;

//--------------------------------------------------------------------
// Calcular valor pip aproximado
double ValorPip()
{
   double tickValue = MarketInfo(Symbol(), MODE_TICKVALUE);
   if(tickValue <= 0) tickValue = 0.0001;
   return tickValue * Lote * 100000 / 10.0;
}

//--------------------------------------------------------------------
// Contar trades del símbolo actual
int ContarOperaciones()
{
   int c = 0;
   for(int i=0; i<OrdersTotal(); i++)
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         if(OrderSymbol() == Symbol())
            c++;
   return c;
}

//--------------------------------------------------------------------
void OnTick()
{
   if(ContarOperaciones() >= MaxTrades) return;

   //--- valores Ichimoku
   double tenkan0 = iIchimoku(NULL,0,9,26,52,MODE_TENKANSEN,0);
   double kijun0  = iIchimoku(NULL,0,9,26,52,MODE_KIJUNSEN,0);
   double tenkan1 = iIchimoku(NULL,0,9,26,52,MODE_TENKANSEN,1);
   double kijun1  = iIchimoku(NULL,0,9,26,52,MODE_KIJUNSEN,1);

   //--- solo si tendencia bajista (Tenkan < Kijun)
   bool tendenciaBajista = (tenkan0 < kijun0);

   //--- Rebote en Tenkan-Sen
   double close1 = iClose(NULL,0,1); // cierre anterior
   double open0  = iOpen(NULL,0,0);
   bool reboteTenkan = (close1 > tenkan1 && Ask >= tenkan0);

   double pipValue = ValorPip();
   if(pipValue <= 0) pipValue = 1;

   double sl_pips = SL_USD / pipValue / Point;
   double tp_pips = TP_USD / pipValue / Point;

   //-----------------------------------------------------------------
   // VENTA por rebote en Tenkan-Sen (solo si Tenkan < Kijun)
   //-----------------------------------------------------------------
   if(tendenciaBajista && reboteTenkan)
   {
      double sl = Ask + sl_pips * Point;
      double tp = Ask - tp_pips * Point;
      int ticket = OrderSend(Symbol(), OP_SELL, Lote, Bid, 3, sl, tp, "Sell Tenkan Rebound", 22346, 0, clrRed);
      if(ticket < 0)
         Print("Error al abrir venta: ", GetLastError());
      else
         Print("Venta abierta en rebote Tenkan ", DoubleToString(Bid, Digits));
   }

   //-----------------------------------------------------------------
   // Trailing dinámico
   //-----------------------------------------------------------------
   for(int i=0; i<OrdersTotal(); i++)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         if(OrderSymbol()!=Symbol()) continue;
         if(OrderType()!=OP_SELL) continue;

         double profitUSD = OrderProfit() + OrderSwap() + OrderCommission();

         if(profitUSD >= TrailingStart)
         {
            double pipValue2 = MarketInfo(Symbol(), MODE_TICKVALUE);
            if(pipValue2<=0) pipValue2=0.0001;
            double newStop = Ask + (TrailingStep / pipValue2) * Point * 10;

            if(newStop < OrderStopLoss() || OrderStopLoss()==0)
            {
               bool mod = OrderModify(OrderTicket(), OrderOpenPrice(), newStop, OrderTakeProfit(), 0, clrBlue);
               if(mod)
                  Print("Trailing Stop actualizado: ", DoubleToString(newStop, Digits));
               else
                  Print("Error trailing: ", GetLastError());
            }
         }
      }
   }
}
