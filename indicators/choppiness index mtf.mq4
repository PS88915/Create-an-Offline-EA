//+------------------------------------------------------------------+
//|                                             Choppiness index.mq4 |
//|                                                           mladen |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "mladen"
#property link      "mladenfx@gmail.com"

#property indicator_separate_window
#property indicator_buffers 5
#property indicator_level1  61.8
#property indicator_level2  38.2
#property strict


//
//
//
//
//

extern ENUM_TIMEFRAMES TimeFrame    = PERIOD_CURRENT; // Time frame
extern int             CILength     = 14;             // Chopines index period
extern double          LevelUp      = 61.8;           // Level up
extern double          LevelDn      = 38.2;           // Level down
extern color           ColorNu      = clrSilver;      // Color for nuetral
extern color           ColorUp      = clrSandyBrown;  // Color for chopy
extern color           ColorDown    = clrLimeGreen;   // Color for trending
extern int             LineWidth    = 2;              // Main line width
input bool             Interpolate  = true;           // Interpolate in multi time frame mode?

double chop[],chopDa[],chopDb[],chopUa[],chopUb[],trend[],count[];
string indicatorFileName;
#define _mtfCall(_buff,_ind) iCustom(NULL,TimeFrame,indicatorFileName,PERIOD_CURRENT,CILength,LevelUp,LevelDn,ColorNu,ColorUp,ColorDown,LineWidth,_buff,_ind)

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
   IndicatorBuffers(7);
   SetIndexBuffer(0, chop);     SetIndexStyle(0,EMPTY,EMPTY,LineWidth,ColorNu);
   SetIndexBuffer(1, chopUa);   SetIndexStyle(1,EMPTY,EMPTY,LineWidth,ColorUp);
   SetIndexBuffer(2, chopUb);   SetIndexStyle(2,EMPTY,EMPTY,LineWidth,ColorUp);
   SetIndexBuffer(3, chopDa);   SetIndexStyle(3,EMPTY,EMPTY,LineWidth,ColorDown);
   SetIndexBuffer(4, chopDb);   SetIndexStyle(4,EMPTY,EMPTY,LineWidth,ColorDown);
   SetIndexBuffer(5, trend);
   SetIndexBuffer(6, count);
      SetLevelValue(0,LevelUp);
      SetLevelValue(1,LevelDn);
      
      indicatorFileName = WindowExpertName();
      TimeFrame         = fmax(TimeFrame,_Period); 
   IndicatorShortName(timeFrameToString(TimeFrame)+" Choppiness index ("+(string)CILength+")");
return(0);
}
int deinit(){   return(0);}

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
   }         
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
