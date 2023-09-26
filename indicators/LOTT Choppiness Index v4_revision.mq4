//+------------------------------------------------------------------+
//|                            LOTT Choppiness Index v4_revision.mq4 |
//|                                  Copyright 2023, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023,Gallo"
#property link      "xavi.biz.buzz@gmail.com"
#property version   "4.01"
#property strict
#property indicator_separate_window

#property indicator_buffers 13
//#property indicator_level1 0
//#property indicator_levelcolor clrBlack
//#property indicator_maximum 100
//#property indicator_minimum 0

extern ENUM_TIMEFRAMES TimeFrame    = PERIOD_CURRENT; // Time frame
extern int             CILength     = 2;             // Chopines index period
extern double          LevelUp      = 61.8;           // Level up
extern double          LevelDn      = 38.2;           // Level down
extern color           ColorNu      = clrSilver;      // Color for nuetral
extern color           ColorUp      = clrSandyBrown;  // Color for chopy
extern color           ColorDown    = clrLimeGreen;   // Color for trending
extern int             LineWidth    = 2;              // Main line width
input bool             Interpolate  = true;           // Interpolate in multi time frame mode?
//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+

double chop[],chopDa[],chopDb[],chopUa[],chopUb[],trend[],count[];
string indicatorFileName;
#define _mtfCall(_buff,_ind) iCustom(NULL,TimeFrame,indicatorFileName,PERIOD_CURRENT,CILength,LevelUp,LevelDn,ColorNu,ColorUp,ColorDown,LineWidth,_buff,_ind)

double green[];
double orange[];
double purple_dot[];

//+------------------------------------------------------------------+
//| Renko Box Calculatioin                                           |
//+------------------------------------------------------------------+
double Lots = 0.5;
input int Renko_Bar_Size = 6;              // Renko Box Size Main
input int Renko_Bar_Size_2 = 5;            // Renko Box Size Main 2
input double Renko_Bar_Size_Alternate = 1; //Renko Box Size Alternate(%)
double pt = 0;
double Renko_main_box_size;
double Renko_main_2_box_size;

bool green_first = false;
bool orange_first = false;
bool gray_first = false;
datetime new_bar = 0;
double green_open_price = 0;
double orange_open_price = 0;
double last_bid_price = 0;

double main_candle_1_sign[], main_candle_2_sign[], bifurcation[];
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
//
//
//
//
//

int init()
{
   IndicatorBuffers(13);
   SetIndexBuffer(0, chop);     SetIndexStyle(0,EMPTY,EMPTY,LineWidth,ColorNu);
   SetIndexBuffer(1, chopUa);   SetIndexStyle(1,EMPTY,EMPTY,LineWidth,ColorUp);
   SetIndexBuffer(2, chopUb);   SetIndexStyle(2,EMPTY,EMPTY,LineWidth,ColorUp);
   SetIndexBuffer(3, chopDa);   SetIndexStyle(3,EMPTY,EMPTY,LineWidth,ColorDown);
   SetIndexBuffer(4, chopDb);   SetIndexStyle(4,EMPTY,EMPTY,LineWidth,ColorDown);
   SetIndexBuffer(5, trend);
   SetIndexBuffer(6, count);
   SetLevelValue(0,LevelUp);
   SetLevelValue(1,LevelDn);
   
   SetIndexBuffer(7,green);       
   SetIndexBuffer(8,orange);    
   SetIndexBuffer(9, purple_dot);

   SetIndexStyle(7,DRAW_HISTOGRAM,STYLE_SOLID,5,clrGreen);
   SetIndexStyle(8,DRAW_HISTOGRAM,STYLE_SOLID,5,clrSandyBrown);
   SetIndexStyle(9,DRAW_ARROW,STYLE_SOLID,2,clrPurple);
   
   SetIndexEmptyValue(7, 0.0);
   SetIndexEmptyValue(8, 0.0);
   SetIndexEmptyValue(9, 0.0);
     
   SetIndexArrow(9,159);
   
   SetIndexBuffer(10,main_candle_1_sign);       
   SetIndexBuffer(11,main_candle_2_sign);    
   SetIndexBuffer(12, bifurcation);
   SetIndexStyle(10,DRAW_ARROW,STYLE_SOLID,1,clrRed);
   SetIndexStyle(11,DRAW_ARROW,STYLE_SOLID,1,clrBlue);
   SetIndexStyle(12,DRAW_ARROW,STYLE_SOLID,2,clrYellow);
   SetIndexArrow(10,226);
   SetIndexArrow(11,226);
   
   if(Digits == 3 || Digits == 5){
      pt = 10 * Point;
   }   
   else{
      pt = Point;
   }
   
   Renko_main_box_size = MarketInfo(OrderSymbol(), MODE_TICKVALUE ) / 0.1 * Lots * Renko_Bar_Size_Alternate / 100 * Renko_Bar_Size;  
   Renko_main_2_box_size = MarketInfo(OrderSymbol(), MODE_TICKVALUE ) / 0.1 * Lots * Renko_Bar_Size_Alternate / 100 * Renko_Bar_Size_2;
       
   indicatorFileName = WindowExpertName();
   TimeFrame         = fmax(TimeFrame,_Period); 
   IndicatorShortName(timeFrameToString(TimeFrame)+" Choppiness index v4_revision("+(string)CILength+")");
   return(0);
}

int deinit()
{ 
  return(0);
}

//
//
//
//
//

int start()
{
   double _log = MathLog(CILength)/100.00;
   int counted_bars = IndicatorCounted();
      if(counted_bars < 0) return(-1); 
      if(counted_bars > 0) counted_bars--;
           int limit = MathMin(Bars-counted_bars,Bars-1); count[0]=limit;
            if (TimeFrame!=_Period)
            {
               limit = (int)fmax(limit,fmin(Bars-1,_mtfCall(6,0)*TimeFrame/_Period));
               if (trend[limit] ==-1) CleanPoint(limit,chopDa,chopDb);
               if (trend[limit] == 1) CleanPoint(limit,chopUa,chopUb);
               for (int i=limit;i>=0 && !_StopFlag; i--)
               {
                  int y = iBarShift(NULL,TimeFrame,Time[i]);
                     chop[i]   = _mtfCall(0,y);
                     trend[i]  = _mtfCall(5,y);
                     chopDa[i] = chopDb[i] = EMPTY_VALUE;
                     chopUa[i] = chopUb[i] = EMPTY_VALUE;
                  
                     //
                     //
                     //
                     //
                     //
                     
                     if (!Interpolate || (i>0 && y==iBarShift(NULL,TimeFrame,Time[i-1]))) continue;
                        #define _interpolate(buff) buff[i+k] = buff[i]+(buff[i+n]-buff[i])*k/n
                        int n,k; datetime time = iTime(NULL,TimeFrame,y);
                           for(n = 1; (i+n)<Bars && Time[i+n] >= time; n++) continue;	
                           for(k = 1; k<n && (i+n)<Bars && (i+k)<Bars; k++)  _interpolate(chop);                                
               }
               for (int i=limit;i>=0;i--)
               {
                  if (trend[i] == 1) PlotPoint(i,chopUa,chopUb,chop);
                  if (trend[i] ==-1) PlotPoint(i,chopDa,chopDb,chop);
               }
               return(0);
            }

   //
   //
   //
   //
   //
   if (trend[limit] ==-1) CleanPoint(limit,chopDa,chopDb);
   if (trend[limit] == 1) CleanPoint(limit,chopUa,chopUb);
   for (int i=limit; i>=0; i--)
   {  
      double atrSum =    0.00;
      double maxHig = High[i];
      double minLow =  Low[i];
               
         for (int k = 0; k < CILength && (i+k+1)<Bars; k++)
         {
            atrSum += MathMax(High[i+k],Close[i+k+1])-MathMin(Low[i+k],Close[i+k+1]);
            maxHig  = MathMax(maxHig,MathMax(High[i+k],Close[i+k+1]));
            minLow  = MathMin(minLow,MathMin( Low[i+k],Close[i+k+1]));
         }
         chop[i]   = (maxHig!=minLow) ? MathLog(atrSum/(maxHig-minLow))/_log : 0;
         chopDa[i] = chopDb[i] = EMPTY_VALUE;
         chopUa[i] = chopUb[i] = EMPTY_VALUE;
         trend[i]  = (chop[i]>LevelUp) ? 1 : (chop[i]<LevelDn) ? -1 : 0;
            if (trend[i] == 1) PlotPoint(i,chopUa,chopUb,chop);
            if (trend[i] ==-1) PlotPoint(i,chopDa,chopDb,chop);
         
         // ---------------------------------------------------- choppiness section ----------------------------------------   
         //double orange_choppiness = chopUa[i];
         //double orange_choppiness_2 = chopUb[i];
         //double green_choppiness = chopDa[i];
         //double green_choppiness_2 = chopDb[i];  
         //
         //if(IsNewBar()){
         //   green_first = false;
         //   orange_first = false;
         //   //gray_first = false;
         //}
         //bool green_choppiness_signal = (green_choppiness  != EMPTY_VALUE || green_choppiness_2 != EMPTY_VALUE);
         //bool orange_choppiness_signal = (orange_choppiness  != EMPTY_VALUE || orange_choppiness_2 != EMPTY_VALUE);
         //
         //if(green_choppiness_signal && orange_choppiness == EMPTY_VALUE && green_first == false && orange_first == false){
         //   green[i] = 10;
         //   green_first = true;
         //   purple_dot[i] = 0;
         //}
         //else if(orange_choppiness_signal && green_choppiness == EMPTY_VALUE && green_first == false && orange_first == false){
         //   orange[i] = 10;
         //   orange_first = true;
         //   purple_dot[i] = true;
         //}
         //
         //if(green_first == true && green[i] == 10 && orange[i] == 0){
         //   if(orange_choppiness_signal && green_choppiness == EMPTY_VALUE){
         //      orange[i] = -10;
         //   }
         //} 
         //else if(orange_first == true && orange[i] == 10 && green[i] ==0){
         //   if(green_choppiness_signal && orange_choppiness == EMPTY_VALUE){
         //      green[i] = -10;
         //   }
         //}
         //if(((orange[i] == 10 && green[i] == 0)|| (green[i] == 10 && orange[i] == 0)) && ((Bid > Open[i] && last_bid_price <= Open[i]) || (Bid < Open[i] && last_bid_price >= Open[i]))){
         //   purple_dot[i] = -1;
         //}
     //
         //last_bid_price = Bid; 
         //----------------------------------------------------- Candle Section ---------------------------------------------
         //if(MathAbs(Open[i] - Close[i]) > Renko_main_box_size) main_candle_1_sign[i] = 10;
         //else if(MathAbs(Open[i] - Close[i]) > Renko_main_2_box_size) main_candle_2_sign[i] = 10;
              
           
   }  
   
     double orange_choppiness = chopUa[0];
     double orange_choppiness_2 = chopUb[0];
     double green_choppiness = chopDa[0];
     double green_choppiness_2 = chopDb[0];
     
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
   
   return(0);
}

//-------------------------------------------------------------------
//                                                                  
//-------------------------------------------------------------------
//
//
//
//
//

void CleanPoint(int i,double& first[],double& second[])
{
   if (i>=Bars-3) return;
   if ((second[i]  != EMPTY_VALUE) && (second[i+1] != EMPTY_VALUE))
        second[i+1] = EMPTY_VALUE;
   else
      if ((first[i] != EMPTY_VALUE) && (first[i+1] != EMPTY_VALUE) && (first[i+2] == EMPTY_VALUE))
          first[i+1] = EMPTY_VALUE;
}

void PlotPoint(int i,double& first[],double& second[],double& from[])
{
   if (i>=Bars-2) return;
   if (first[i+1] == EMPTY_VALUE)
      if (first[i+2] == EMPTY_VALUE) 
            { first[i]  = from[i]; first[i+1]  = from[i+1]; second[i] = EMPTY_VALUE; }
      else  { second[i] = from[i]; second[i+1] = from[i+1]; first[i]  = EMPTY_VALUE; }
   else     { first[i]  = from[i];                          second[i] = EMPTY_VALUE; }
}

//
//
//
//
//

string sTfTable[] = {"M1","M5","M15","M30","H1","H4","D1","W1","MN"};
int    iTfTable[] = {1,5,15,30,60,240,1440,10080,43200};

string timeFrameToString(int tf)
{
   for (int i=ArraySize(iTfTable)-1; i>=0; i--) 
         if (tf==iTfTable[i]) return(sTfTable[i]);
                              return("");
}

double GetBoxSize(int i)
{  
   return MathAbs(Open[i] - Close[i]);
}

bool IsNewBar()
{
   if(new_bar != Time[0]){
      new_bar = Time[0];
      return true;
   }
   return false;
}
