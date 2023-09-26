

#property strict
#define RENKO_VERSION "Treasur Alternate v3"
//+------------------------------------------------------------------+
//|                                                   Renko v1.0.mq4 |
//|                        Copyright 2017, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+

#property strict
#include <WinUser32.mqh>
#include <stdlib.mqh>
#import "user32.dll"
    int RegisterWindowMessageA(string lpString); 
#import

#define forn(i,a,b) for(int i = a; i >= b; i--)


input int   Bars_Limit     =  200; //Bars Limit For Calculation (0=Off) 
extern int RenkoTimeframe = 2;
extern bool ShowWicks = true;                                      
//input double InpRenkoBoxSizeAlt1Pct = 5; //Renko Box Size Alternate 2(in Pips)
input int Renko_Bar_Size = 6;              // Renko Box Size Main
input int Renko_Bar_Size_2 = 5;            // Renko Box Size Main 2
input double Renko_Bar_Size_Alternate = 1; //Renko Box Size Alternate(%)

int Main_Bar_Size = 10;     // MAIN BAR

double BoxSize = 0;
double BoxSizeMain = 0;
double BoxSizeReverse = 0;
 
int ExtHandle = -1;
datetime bartime;
ulong    last_fpos=0;
long     last_volume=0;
int      i,start_pos,periodseconds;
int      cnt=0;
//---- History header
int      file_version=401;
string   c_copyright;
string   c_symbol=Symbol();
int      i_period=RenkoTimeframe;
int      i_digits=Digits;
int      i_unused[13];
datetime last_time;
MqlRates rate;
int      limit = 0;
long     chart_id = -1;
double   upwick = 0;
double   dnwick = DBL_MAX;
datetime last_refresh = 0;
datetime curr_time = 0;
int trenline_num = 0;
int sidewise_count = 0;
bool renko_attach = false; 
datetime CurrentTime = 0;
int ac_num_array[20];
double UpBoxSize = 0;
double DownBoxSize = 0;
int box_down_trend = 0;
int box_up_trend = 0;
double last_open_price = 0;
double pt = 0;
double ClosePriceArray[];
double OpenPriceArray[];


//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
     
     
     
     if(Digits == 3 || Digits == 5){
        pt = 10 * Point;
     }   
     else{
        pt = Point;
     }    
     
     BoxSizeMain = (Main_Bar_Size)*pt;  
        
     BoxSize = GetBoxSize();
     
     OnTick();
     
     
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//--- 
      ///------ RENKO CHART 
      build_renko(); 
      ////------
      
      
     //Alert(ArraySize(ClosePriceArray)," ",(ClosePriceArray[7341]));   
     // if(TimeCurrent() >= last_refresh + 2) {  
         last_refresh = TimeCurrent();
         UpdateChartWindow();
         
    //  } 
  
      
  }
//+------------------------------------------------------------------+

void AddPrice(double newcloseprice, double newopenprice)
{
   int c = ArraySize(ClosePriceArray);
   int o = ArraySize(OpenPriceArray);
   
   ArrayResize(ClosePriceArray,c+1,10000);
   ArrayResize(OpenPriceArray,o+1,10000);
   
   ClosePriceArray[c] = NormalizeDouble(newcloseprice,Digits);
   OpenPriceArray[o] = NormalizeDouble(newopenprice,Digits);
}


void UpdateChartWindow() {
    static int hwnd = 0;
    static int MT4InternalMsg = 0;
    
     if(hwnd == 0) {
        hwnd = WindowHandle(Symbol(), RenkoTimeframe);
        if(hwnd != 0) Print("Chart window detected");
       
    }
 
    if(MT4InternalMsg == 0) 
        MT4InternalMsg = RegisterWindowMessageA("MetaTrader4_Internal_Message");
 
    if(hwnd != 0) if(PostMessageA(hwnd, WM_COMMAND, 0x822c, 0) == 0) hwnd = 0;
    if(hwnd != 0 && MT4InternalMsg != 0) PostMessageA(hwnd, MT4InternalMsg, 2, 1);
 
    return;
}

void build_renko()
{
   // historical bars
   if(ExtHandle < 0) {
      ExtHandle=FileOpenHistory(c_symbol+(string)i_period+".hst",FILE_BIN|FILE_WRITE|FILE_SHARE_WRITE|FILE_SHARE_READ|FILE_ANSI);
      if(ExtHandle<0) {
         PrintFormat("Error: can't open history file %s: %d", c_symbol+(string)i_period+".hst", GetLastError());
         return;
      }   
      c_copyright="(C)opyright 2019, MetaQuotes Software Corp.";
      ArrayInitialize(i_unused,0);
   //--- write history file header
      FileWriteInteger(ExtHandle,file_version,LONG_VALUE);
      FileWriteString(ExtHandle,c_copyright,64);
      FileWriteString(ExtHandle,c_symbol,12);
      FileWriteInteger(ExtHandle,i_period,LONG_VALUE);
      FileWriteInteger(ExtHandle,i_digits,LONG_VALUE);
      FileWriteInteger(ExtHandle,0,LONG_VALUE);
      FileWriteInteger(ExtHandle,0,LONG_VALUE);
      FileWriteArray(ExtHandle,i_unused,0,13);
      periodseconds=i_period*60;
      
      start_pos = Bars-1;
      
      if (Bars_Limit > 0 && Bars - 1 > Bars_Limit) start_pos = MathMin(Bars - 1,Bars_Limit);
        
      rate.open=Open[start_pos];
      rate.low=Low[start_pos];
      rate.high=High[start_pos];
      rate.tick_volume=(long)Volume[start_pos];
      rate.spread=0;
      rate.real_volume=0;
      //--- normalize open time
      rate.time=Time[start_pos]/periodseconds;
      rate.time*=periodseconds;
      
      for(i=start_pos; i>=0; i--) {
         
         bartime=Time[i];
         upwick = MathMax(0, High[i]);
         dnwick = MathMin(DBL_MAX, Low[i]);
         //--- history may be updated
         //if(i==0) {
         //   //--- modify index if history was updated
         //   if(RefreshRates())
         //      i=iBarShift(NULL,0,time0);
         //}
         //---
         if(High[i] < rate.open + BoxSize && Low[i] > rate.open - BoxSize) 
            last_volume += Volume[i];
            
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
            if(BoxSize == Renko_Bar_Size * pt)
               rate.tick_volume = 1;
            else   
               rate.tick_volume = Volume[i] + last_volume;
            
            last_fpos=FileTell(ExtHandle);
            FileWriteStruct(ExtHandle,rate);
            last_open_price = rate.open;
            rate.open = rate.close;
            last_volume = 0;
            box_down_trend++;
            box_up_trend = 0;
            AddPrice(rate.close, last_open_price);
            BoxSize = GetBoxSize();
            cnt++;
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
               if(BoxSize == Renko_Bar_Size * pt)
                  rate.tick_volume = 1;
               else   
                  rate.tick_volume = Volume[i] + last_volume;      
               last_fpos=FileTell(ExtHandle);
               FileWriteStruct(ExtHandle,rate);
               last_open_price = rate.open;
               rate.open = rate.close;
               last_volume = 0;
               AddPrice(rate.close, last_open_price);
               BoxSize = GetBoxSize();
               cnt++;
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
               if(BoxSize == Renko_Bar_Size * pt)
                  rate.tick_volume = 1;
               else   
                  rate.tick_volume = Volume[i] + last_volume;       
               last_fpos=FileTell(ExtHandle);
               FileWriteStruct(ExtHandle,rate);
               last_open_price = rate.open;
               rate.open = rate.close;
               last_volume = 0;
               AddPrice(rate.close, last_open_price);
               BoxSize = GetBoxSize();
               cnt++;
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
            
            if(BoxSize == Renko_Bar_Size * pt)
               rate.tick_volume = 1;
            else   
               rate.tick_volume = Volume[i] + last_volume;      
            last_fpos=FileTell(ExtHandle);
            FileWriteStruct(ExtHandle,rate);
            last_open_price = rate.open;
            rate.open = rate.close;
            last_volume = 0;
            AddPrice(rate.close, last_open_price);
            BoxSize = GetBoxSize();
            cnt++;
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
            if(BoxSize == Renko_Bar_Size * pt)
               rate.tick_volume = 1;
            else   
               rate.tick_volume = Volume[i] + last_volume;      
            last_fpos=FileTell(ExtHandle);
            FileWriteStruct(ExtHandle,rate);
            last_open_price = rate.open;
            rate.open = rate.close;
            last_volume = 0;
            AddPrice(rate.close, last_open_price);
            BoxSize = GetBoxSize();
            cnt++;
         }        
      } 
      
      
    //  Alert(rate.close,"  ",rate.time,"  ",rate.open);
      
      last_volume = 0;
      last_time = rate.time;
      FileFlush(ExtHandle);
      last_fpos=FileTell(ExtHandle);
      rate.time++;
      rate.high = rate.open;
      rate.low = rate.open;
      PrintFormat("%d historical bars formed",cnt);
      
   }   
   // Live Bars
   else {
      bartime = Time[0];
      FileSeek(ExtHandle, last_fpos, SEEK_SET);
      
      if(BoxSize > 0 && Close[0] >= rate.open + BoxSize) {
         rate.close = NormalizeDouble(rate.open + BoxSize, Digits);
         rate.high = MathMax(rate.close, rate.high);
         
         if(!ShowWicks) {
            rate.high = rate.close;
            rate.low = rate.open;
         }   
         if(rate.time < bartime)
            rate.time = bartime;
         
         if(BoxSize == Renko_Bar_Size * pt)
            rate.tick_volume = 1;
         else   
            rate.tick_volume = Volume[0] + last_volume;  
       //  Alert(rate.open,"  ", rate.close, " ", rate.high," ", rate.low, " ",rate.time);        
         FileWriteStruct(ExtHandle,rate);
         FileFlush(ExtHandle);
         Sleep(100);
         
         last_fpos=FileTell(ExtHandle);
         last_open_price = rate.open;
         rate.open = rate.close;
         rate.high = rate.close;
         rate.low = rate.open;
         last_volume = 0;
         AddPrice(rate.close, last_open_price);
         BoxSize = GetBoxSize();
         cnt++;
         rate.time++;
      }
      
      if(BoxSize > 0 && Close[0] <= rate.open - BoxSize) {
         rate.close = NormalizeDouble(rate.open - BoxSize, Digits);
         rate.low = MathMin(rate.close, rate.low);
         
         if(!ShowWicks) {
            rate.low = rate.close;
            rate.high = rate.open;
         }   
         if(rate.time < bartime)
            rate.time = bartime;
         
         if(BoxSize == Renko_Bar_Size * pt)
            rate.tick_volume = 1;
         else   
            rate.tick_volume = Volume[0] + last_volume; 
              
         //Alert(rate.open,"  ", rate.close, " ", rate.high," ", rate.low, " ",rate.time);
         FileWriteStruct(ExtHandle,rate);
         FileFlush(ExtHandle);
         Sleep(100);
         
         last_fpos=FileTell(ExtHandle);
         last_open_price = rate.open;
         rate.open = rate.close;
         rate.high = rate.open;
         rate.low = rate.close;
         last_volume = 0;
         cnt++;
         rate.time++;
         AddPrice(rate.close, last_open_price);
         BoxSize = GetBoxSize();
      }
   
      else {
         
         
         rate.close = Close[0];
         
         //else {
         //   rate.high = rate.open;
         //   rate.low = rate.close;
         //}
         if(ShowWicks) {
            if(rate.close > rate.high && rate.close > rate.open)
               rate.high = NormalizeDouble(rate.close, Digits);
            if(rate.close < rate.low && rate.close < rate.open)
               rate.low = NormalizeDouble(rate.close, Digits);
         }   
         else {
            if(rate.close > rate.open) {
               rate.high = rate.close;
               rate.low = rate.open;
            }
            else {
               rate.high = rate.open;
               rate.low = rate.close;
            }
         }   
         if(last_time < bartime) {
            //last_volume += Volume[1];
            last_time = bartime;
         }   
         if(rate.time < bartime)
            rate.time = bartime;
         if(BoxSize == Renko_Bar_Size * pt)
            rate.tick_volume = 1;
         else   
            rate.tick_volume = Volume[0] + last_volume;   
                
         FileWriteStruct(ExtHandle,rate); 
         FileFlush(ExtHandle);
         Sleep(100);
      } 
     
        
   } 
   
   AddRenkoComment(BoxSize);    
}
void OnDeinit(const int reason)
  {
//---
   if(ExtHandle>=0)
     {
      FileClose(ExtHandle);
      ExtHandle=-1;
     }
    ObjectsDeleteAll(chart_id,"Renko_Trend "); 
//---
  }



double GetBullishSignalStatus(ENUM_TIMEFRAMES tf, int index)
{
   return iOpen(NULL,tf,index) < iClose(NULL,tf,index);
}

double GetBearishSignalStatus(ENUM_TIMEFRAMES tf, int index)
{
   return iOpen(NULL,tf,index) > iClose(NULL,tf,index);
}



void AddRenkoComment(double BP) {

    string text = "\n ========================\n";
    text = text + "   RENKO LIVE CHART " + RENKO_VERSION + " (" + DoubleToStr(BP / pt, 1) + " pips)\n";
    text = text + " ========================\n";

    if (WindowHandle(Symbol(), RenkoTimeframe) == 0) {
        text = text + "   Go to Menu FILE > OPEN OFFLINE\n";
        text = text + "   Select >> " + Symbol() + ",M" + (string) RenkoTimeframe + " <<\n";
        text = text + "   and click OPEN to view chart.";
    } else {
        text = text + "  You can MINIMIZE this window, now!\n";
    }

    Comment(text);
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
      size = NormalizeDouble((Renko_Bar_Size_Alternate*Renko_Bar_Size*pt)/100, Digits);
      
   return size;
}

