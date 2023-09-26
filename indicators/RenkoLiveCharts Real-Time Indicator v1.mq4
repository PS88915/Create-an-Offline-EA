//+------------------------------------------------------------------+
//|                          RenkoLiveCharts Real-Time Indicator.mq4 |
//|                                  Copyright 2023, Gallo Samuel    |
//|                                             https://             |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, Gallo Samuel"
#property link      "https://"
#property version   "1.00"
#property indicator_separate_window
//#property indicator_level1  0
#property indicator_buffers 9
#property strict

#include <stdlib.mqh>
//+------------------------------------------------------------------+
//| Chart Software Setting                                           |
//+------------------------------------------------------------------+
input int   Bars_Limit     =  2000; //Bars Limit For Calculation (0=Off) //TODO
extern int RenkoTimeframe = 3;
extern bool ShowWicks = true;                                      
input int Renko_Bar_Size = 6;              // Renko Box Size Main
input int Renko_Bar_Size_2 = 5;            // Renko Box Size Main 2
input double Renko_Bar_Size_Alternate = 1; //Renko Box Size Alternate(%)

//+------------------------------------------------------------------+
//| Custom Variables                                                 |
//+------------------------------------------------------------------+
int DepthLimit = 2000;
double BoxSize = 0;
datetime bartime;
int      start_pos,periodseconds;
string   c_symbol=Symbol();
int      i_period=RenkoTimeframe;
int      i_digits=Digits;
MqlRates rate;
MqlRates record_rate;
double   upwick = 0;
double   dnwick = DBL_MAX;
double   last_open_price = 0;
double   pt = 0;
double   ClosePriceArray[];
double   OpenPriceArray[];
double   red_alternate_values[], blue_alternate_values[], red_main_candle_1_values[], blue_main_candle_1_values[], red_main_candle_2_values[], blue_main_candle_2_values[],
         buy_trade_mark[], sell_trade_mark[], benchmarkPoints[];

double candles[], candle_types[];

bool Initialized = false;
//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- indicator buffers mapping
     if(Digits == 3 || Digits == 5){
        pt = 10 * Point;
     }   
     else{
        pt = Point;
     }    
     
     IndicatorBuffers(9);
       
     SetIndexBuffer(0, red_alternate_values);   SetIndexStyle(0, DRAW_HISTOGRAM, STYLE_SOLID, 7, clrRed);
     SetIndexBuffer(1, blue_alternate_values);  SetIndexStyle(1, DRAW_HISTOGRAM, STYLE_SOLID, 7, clrGreen);
     SetIndexBuffer(2, red_main_candle_1_values);  SetIndexStyle(2, DRAW_HISTOGRAM, STYLE_SOLID, 2, clrRed);
     SetIndexBuffer(3, blue_main_candle_1_values);  SetIndexStyle(3, DRAW_HISTOGRAM, STYLE_SOLID, 2, clrGreen);
     SetIndexBuffer(4, red_main_candle_2_values);  SetIndexStyle(4, DRAW_HISTOGRAM, STYLE_SOLID, 4, clrRed);
     SetIndexBuffer(5, blue_main_candle_2_values);  SetIndexStyle(5, DRAW_HISTOGRAM, STYLE_SOLID, 4, clrGreen);
     SetIndexBuffer(6, buy_trade_mark);         SetIndexStyle(6, DRAW_ARROW, STYLE_SOLID, 2, clrBlue);
     SetIndexBuffer(7, sell_trade_mark);        SetIndexStyle(7, DRAW_ARROW, STYLE_SOLID, 2, clrRed);
     SetIndexArrow(6,236);
     SetIndexArrow(7,238);
     SetIndexBuffer(8, benchmarkPoints);  SetIndexStyle(8, DRAW_HISTOGRAM, STYLE_SOLID, 5, clrYellow);

//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int start()
  {
   int counted_bars = IndicatorCounted();
   if(!Initialized)
   {
      Initialized = true;
      buildRenko();
   }
   
   if(counted_bars < 0) return(-1);
   if(Bars - counted_bars == 2) buildLastRenko();
   
   return(0);
 }
//+------------------------------------------------------------------+

void buildRenko() {   
   int i;
   BoxSize = GetBoxSize();
   periodseconds = i_period * 60;
   
   start_pos = MathMin(Bars - 1, Bars_Limit - 1);
   
   rate.open = Open[start_pos];
   rate.low = Low[start_pos];
   rate.high = High[start_pos];
   rate.tick_volume = (long)Volume[start_pos];
   rate.spread = 0;
   rate.real_volume = 0;
   
   //--- normalize open time
   rate.time = Time[start_pos] / periodseconds;
   rate.time *= periodseconds;
      
   for(i = start_pos; i >= 1; i--) {
      benchmarkPoints[i] = 0;
      bartime = Time[i];
      upwick = MathMax(0, High[i]);
      dnwick = MathMin(DBL_MAX, Low[i]);
      bool is_uptrend = MathAbs(Close[i] - High[i]) < MathAbs(Close[i] - Low[i]);
          
      while(Low[i] <= rate.open - BoxSize) {    // DOWNTREND
         rate.close = rate.open - BoxSize;
         rate.high = rate.open;
         rate.low = rate.close;
         if(rate.time < bartime)
            rate.time = bartime;
         else
            rate.time++;
         if(ShowWicks && is_uptrend && rate.low - BoxSize < dnwick)
            rate.low = Low[i];
         AddCandle(BoxSize, -1);
         DrawCandle(i);
         CheckTradePoint(i);
         last_open_price = rate.open;
         rate.open = rate.close;
         AddPrice(rate.close, last_open_price);
         BoxSize = GetBoxSize();
      }
        
      if(Close[i] >= rate.open + BoxSize) {
         while(Close[i] >= rate.open + BoxSize) {
            rate.close = rate.open + BoxSize;
            rate.high = rate.close;
            rate.low = rate.open;
            if(rate.time < bartime)
               rate.time = bartime;
            else
               rate.time++; 
            AddCandle(BoxSize, 1);
            DrawCandle(i);
            CheckTradePoint(i);
            last_open_price = rate.open;
            rate.open = rate.close;
            AddPrice(rate.close, last_open_price);
            BoxSize = GetBoxSize();
         }
      }
      else {
         while(Close[i] <= rate.open - BoxSize) {
            rate.close = rate.open - BoxSize;
            rate.low = rate.close;
            rate.high = rate.open;
            if(rate.time < bartime)
               rate.time = bartime;
            else
               rate.time++;
            AddCandle(BoxSize, -1);
            DrawCandle(i);
            CheckTradePoint(i);
            last_open_price = rate.open;
            rate.open = rate.close;
            AddPrice(rate.close, last_open_price);
            BoxSize = GetBoxSize();
         }
      }
        
      while(is_uptrend && High[i] >= rate.open + BoxSize) {     /// UPTREND
         rate.close = rate.open + BoxSize;
         rate.high = rate.close;
         rate.low = rate.open;
         if(rate.time < bartime)
            rate.time = bartime;
         else
            rate.time++;
         AddCandle(BoxSize, 1); 
         DrawCandle(i);
         CheckTradePoint(i);            
         last_open_price = rate.open;
         rate.open = rate.close;
         AddPrice(rate.close, last_open_price);
         BoxSize = GetBoxSize();
      }
      while(!is_uptrend && High[i] >= rate.open + BoxSize) {  
         rate.close = rate.open + BoxSize;
         rate.high = rate.close;
         rate.low = rate.open;
         if(rate.time < bartime)
            rate.time = bartime;
         else
            rate.time++;
         if(ShowWicks && rate.high + BoxSize > upwick)
            rate.high = High[i];
         AddCandle(BoxSize, 1);
         DrawCandle(i);
         CheckTradePoint(i);
         last_open_price = rate.open;
         rate.open = rate.close;
         AddPrice(rate.close, last_open_price);
         BoxSize = GetBoxSize();
      }        
   }  
}

/////////////////////// for Real Time
void buildLastRenko() {
   BoxSize = GetBoxSize();
   periodseconds = i_period * 60;
   
   //--- normalize open time
   rate.time = Time[start_pos] / periodseconds;
   rate.time *= periodseconds;
      
   
   benchmarkPoints[1] = 0;
   bartime = Time[1];
   upwick = MathMax(0, High[1]);
   dnwick = MathMin(DBL_MAX, Low[1]);
   bool is_uptrend = MathAbs(Close[1] - High[1]) < MathAbs(Close[1] - Low[1]);
       
   while(Low[1] <= rate.open - BoxSize) {    // DOWNTREND
      rate.close = rate.open - BoxSize;
      rate.high = rate.open;
      rate.low = rate.close;
      if(rate.time < bartime)
         rate.time = bartime;
      else
         rate.time++;
      if(ShowWicks && is_uptrend && rate.low - BoxSize < dnwick)
         rate.low = Low[1];
      AddCandle(BoxSize, -1);
      DrawCandle(1);
      CheckTradePoint(1);
      last_open_price = rate.open;
      rate.open = rate.close;
      AddPrice(rate.close, last_open_price);
      BoxSize = GetBoxSize();
   }
     
   if(Close[1] >= rate.open + BoxSize) {
      while(Close[1] >= rate.open + BoxSize) {
         rate.close = rate.open + BoxSize;
         rate.high = rate.close;
         rate.low = rate.open;
         if(rate.time < bartime)
            rate.time = bartime;
         else
            rate.time++; 
         AddCandle(BoxSize, 1);
         DrawCandle(1);
         CheckTradePoint(1);
         last_open_price = rate.open;
         rate.open = rate.close;
         AddPrice(rate.close, last_open_price);
         BoxSize = GetBoxSize();
      }
   }
   else {
      while(Close[1] <= rate.open - BoxSize) {
         rate.close = rate.open - BoxSize;
         rate.low = rate.close;
         rate.high = rate.open;
         if(rate.time < bartime)
            rate.time = bartime;
         else
            rate.time++;
         AddCandle(BoxSize, -1);
         DrawCandle(1);
         CheckTradePoint(1);
         last_open_price = rate.open;
         rate.open = rate.close;
         AddPrice(rate.close, last_open_price);
         BoxSize = GetBoxSize();
      }
   }
     
   while(is_uptrend && High[1] >= rate.open + BoxSize) {     /// UPTREND
      rate.close = rate.open + BoxSize;
      rate.high = rate.close;
      rate.low = rate.open;
      if(rate.time < bartime)
         rate.time = bartime;
      else
         rate.time++;
      AddCandle(BoxSize, 1); 
      DrawCandle(1);
      CheckTradePoint(1);            
      last_open_price = rate.open;
      rate.open = rate.close;
      AddPrice(rate.close, last_open_price);
      BoxSize = GetBoxSize();
   }
   while(!is_uptrend && High[1] >= rate.open + BoxSize) {  
      rate.close = rate.open + BoxSize;
      rate.high = rate.close;
      rate.low = rate.open;
      if(rate.time < bartime)
         rate.time = bartime;
      else
         rate.time++;
      if(ShowWicks && rate.high + BoxSize > upwick)
         rate.high = High[1];
      AddCandle(BoxSize, 1);
      DrawCandle(1);
      CheckTradePoint(1);
      last_open_price = rate.open;
      rate.open = rate.close;
      AddPrice(rate.close, last_open_price);
      BoxSize = GetBoxSize();
   }
}

//+--------------------- Utilities ----------------------+

void AddPrice(double newcloseprice, double newopenprice)
{
   int c = ArraySize(ClosePriceArray);
   int o = ArraySize(OpenPriceArray);
   
   ArrayResize(ClosePriceArray,c+1,10000);
   ArrayResize(OpenPriceArray,o+1,10000);
   
   ClosePriceArray[c] = NormalizeDouble(newcloseprice, Digits);
   OpenPriceArray[o] = NormalizeDouble(newopenprice, Digits);
}

void RemoveOneFromCandle(int index) {
   int c = ArraySize(candles);
   
   if(c <= 0) return;
   
   if(index >= c) return;
   
   for(int i = 0; i < c - 2; i++) {
      if(i >= index) {
         candles[i] = candles[i + 1];
         candle_types[i] = candle_types[i + 1];
      }   
   }
   ArrayResize(candles, c - 1);
   ArrayResize(candle_types, c - 1);
}

void DrawCandle(int index) {
   int c = ArraySize(candles);
   if(c <= 0) return;
   
   if(candle_types[0] == 1 && candles[0] == 0.001)
      blue_alternate_values[index] = candles[0];
   else if(candle_types[0] == 1 && candles[0] == 0.06)
      blue_main_candle_1_values[index] = candles[0];
   else if(candle_types[0] == 1 && candles[0] == 0.05)
      blue_main_candle_2_values[index] = candles[0];
   else if(candle_types[0] == -1 && candles[0] == 0.001)
      red_alternate_values[index] = candles[0];
   else if(candle_types[0] == -1 && candles[0] == 0.06)
      red_main_candle_1_values[index] = candles[0];
   else
      red_main_candle_2_values[index] = candles[0];
}

void AddCandle(double newCandleVal, int type) {
   int c = ArraySize(candles);
   ArrayResize(candles, c + 1, 0);
   ArrayResize(candle_types, c + 1, 0);
   
   for(int i = c; i > 0; i--) {
      candles[i] = candles[i - 1];
      candle_types[i] = candle_types[i - 1];
   }
   
   candles[0] = newCandleVal;
   candle_types[0] = type;
}

void CheckTradePoint(int index) {
   int cnt = ArraySize(candles);
   if(cnt <= 0) return;
   
   if(candles[0] != 0.05) return;
   
   int alterType = candle_types[0] * -1;
   
   if(cnt <= 1 || candle_types[1] != alterType ||candles[1] != 0.06) return;
   
   if(cnt < 8) return;
   int alterCandleCnt = 0;
   for(int i = 2; i < 8; i++)
   {
      if(candle_types[i] == alterType && candles[i] == 0.001) alterCandleCnt++;
      else break;
   }
   
   if(alterCandleCnt < 6) return;
   
   if(alterType == 1)
      sell_trade_mark[index] = 0.065;
   else
      buy_trade_mark[index] = 0.065;
}

double GetBoxSize()
{ 
   int bullish_count = 0;
   int bearish_count = 0;
   
   int bullish_count_2 = 0;
   int bearish_count_2 = 0;
   double size = 0;
   int s = ArraySize(OpenPriceArray);
   double normal_size = Renko_Bar_Size * pt;
   double normal_size_2 = Renko_Bar_Size_2 * pt;
   double local_close_price = 0;
   double local_open_price = 0;
   
   int main_bar_index = 0;
   
   if(s > 6){
     
      for(int k = 1; k <= 6; k++){
         double candle_size = MathAbs(ClosePriceArray[s - k] - OpenPriceArray[s - k]);
         if(CompareDoubles(candle_size, normal_size_2)){
            break;
         }
         if(CompareDoubles(candle_size, normal_size)){
            main_bar_index = k;
            break;
         }   
         if(ClosePriceArray[s - k] > OpenPriceArray[s - k])
            bullish_count++;
         if(ClosePriceArray[s - k] < OpenPriceArray[s - k])
            bearish_count++;
      }
      
   }
    if(s > 7){
      for(int k = 1; k <= 7; k++){
         if(ClosePriceArray[s - k] > OpenPriceArray[s - k])
            bullish_count_2++;
         if(ClosePriceArray[s - k] < OpenPriceArray[s - k])
            bearish_count_2++;
      }
      
   }
   if(main_bar_index == 1 && (bullish_count_2 == 7 || bearish_count_2 == 7)){
      size = Renko_Bar_Size_2 * pt;
   }
   else if(bearish_count == 6 || bullish_count == 6)
      size = Renko_Bar_Size * pt;
   else
      size = NormalizeDouble((Renko_Bar_Size_Alternate * Renko_Bar_Size * pt)/100, Digits);
      
   return size;
}

