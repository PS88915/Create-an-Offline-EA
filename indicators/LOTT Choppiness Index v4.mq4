//+------------------------------------------------------------------+
//|                                        LOTT Heatmap close v1.mq4 |
//|                        Copyright 2019, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright © 2022 LadyoftheTrade"
#property strict
#property indicator_separate_window
#property indicator_buffers 3
#property indicator_level1 0
#property indicator_levelcolor clrBlack
#property indicator_maximum 50
#property indicator_minimum -50
enum metodo{ K_and_D=1, Middle_Line=2, OBOS=3, Slope=4 };

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
extern string set0 = ">>>>> Indicator Settings <<<<<<";   // ----
extern ENUM_TIMEFRAMES TimeFrame    = PERIOD_CURRENT; // Time frame
extern int             CILength     = 2;             // Chopines index period
extern double          LevelUp      = 61.8;           // Level up
extern double          LevelDn      = 38.2;           // Level down
extern color           ColorNu      = clrSilver;      // Color for nuetral
extern color           ColorUp      = clrSandyBrown;  // Color for chopy
extern color           ColorDown    = clrLimeGreen;   // Color for trending
extern int             LineWidth    = 2;              // Main line width
input bool             Interpolate  = true;           // Interpolate in multi time frame mode?


double green[];
double orange[];
double purple_dot[];


string indicator_name = "//choppiness index mtf.ex4";
bool green_first = false;
bool orange_first = false;
bool gray_first = false;
datetime new_bar = 0;
double green_open_price = 0;
double orange_open_price = 0;
double last_bid_price = 0;

int OnInit()
  {
//--- indicator buffers mapping
     SetIndexBuffer(0,green);       
     SetIndexBuffer(1,orange);    
     SetIndexBuffer(2, purple_dot);
     
//---- drawing settings
     SetIndexStyle(0,DRAW_HISTOGRAM,STYLE_SOLID,5,clrGreen);
     SetIndexStyle(1,DRAW_HISTOGRAM,STYLE_SOLID,5,clrSandyBrown);
     SetIndexStyle(2,DRAW_ARROW,STYLE_SOLID,2,clrPurple);
     
     SetIndexArrow(2,159);
    
//---- name for DataWindow and indicator subwindow label
     IndicatorShortName("LOTT Choppiness Index V3");
     SetIndexLabel(0,"Green");      
     SetIndexLabel(1,"Orange");
     SetIndexLabel(2,"Purple");
      
     SetIndexEmptyValue(0, 0.0);
     SetIndexEmptyValue(1, 0.0);
     SetIndexEmptyValue(2, 0.0);
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
  {
//---
     // BUFFER 0 - GRAY, 1- Orange, 3 green
     //double gray_choppiness = GetChoppinessValue(0,0);
     double orange_choppiness = GetChoppinessValue(1,0);
     double orange_choppiness_2 = GetChoppinessValue(2,0);
     double green_choppiness = GetChoppinessValue(3,0);
     double green_choppiness_2 = GetChoppinessValue(4,0);
     
     //Alert(GetChoppinessValue(0,0));    
     if(IsNewBar()){
        green_first = false;
        orange_first = false;
        //gray_first = false;
     }
     bool green_choppiness_signal = (green_choppiness  != EMPTY_VALUE || green_choppiness_2 != EMPTY_VALUE);
     bool orange_choppiness_signal = (orange_choppiness  != EMPTY_VALUE || orange_choppiness_2 != EMPTY_VALUE);
     
     
     if(green_choppiness_signal && orange_choppiness == EMPTY_VALUE && green_first == false && orange_first == false){
        green[0] = 10;
        green_first = true;
        purple_dot[0] = 0;
     }
     else if(orange_choppiness_signal && green_choppiness == EMPTY_VALUE && green_first == false && orange_first == false){
        orange[0] = 10;
        orange_first = true;
        purple_dot[0] = true;
     }
     
     if(green_first == true && green[0] == 10 && orange[0] == 0){
        if(orange_choppiness_signal && green_choppiness == EMPTY_VALUE){
           orange[0] = -10;
        }
     } 
     else if(orange_first == true && orange[0] == 10 && green[0] ==0){
        if(green_choppiness_signal && orange_choppiness == EMPTY_VALUE){
           green[0] = -10;
        }
     }
     if(((orange[0] == 10 && green[0] == 0)|| (green[0] == 10 && orange[0] == 0)) && ((Bid > Open[0] && last_bid_price <= Open[0]) || (Bid < Open[0] && last_bid_price >= Open[0]))){
        purple_dot[0] = -1;
     }
     
     last_bid_price = Bid;  
     
    
//--- return value of prev_calculated for next call
   return(rates_total);
  }
//+------------------------------------------------------------------+
bool IsNewBar()
{
   if(new_bar != Time[0]){
      new_bar = Time[0];
      return true;
   }
   return false;
}

double GetChoppinessValue(int buffer, int index)
{
   return iCustom(NULL,0,indicator_name,TimeFrame,CILength,LevelUp,LevelDn,ColorNu,ColorDown,LineWidth,Interpolate,buffer,index);
}