#include <ioavr.h>
#include <inavr.h>
#include <stdio.h>
#include <pgmspace.h>
#include "rtc_simple.h"
#include "hd44780.h"
#include "queue.h"
#include "keyb_drv.h"

#define CLOCK_INC	0x03
#define CLOCK_SET       0x04


/// 4 5 6 7 ///
/// 0 1 2 3 ///
typedef union TSysRq {
    unsigned char msg;
    struct {
		unsigned char rq_data	: 4;
		unsigned char rq_id 	: 4;
    };
} TSysRq;

//---------------------------------------------------------
// Constants declaration
//---------------------------------------------------------

static const char __flash LCDUserChar[] = {
    0x1F, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x1F,
    0x1F, 0x00, 0x10, 0x10, 0x10, 0x10, 0x00, 0x1F,
    0x1F, 0x00, 0x18, 0x18, 0x18, 0x18, 0x00, 0x1F,
    0x1F, 0x00, 0x1C, 0x1C, 0x1C, 0x1C, 0x00, 0x1F,
    0x1F, 0x00, 0x1E, 0x1E, 0x1E, 0x1E, 0x00, 0x1F,
    0x1F, 0x00, 0x1F, 0x1F, 0x1F, 0x1F, 0x00, 0x1F,
    0x03, 0x02, 0x02, 0x02, 0x02, 0x02, 0x02, 0x03,
    0x18, 0x08, 0x08, 0x08, 0x08, 0x08, 0x08, 0x18 };

static const char __flash sSun[] = "Sun";
static char const __flash sMon[] = "Mon";
static char const __flash sTue[] = "Tue";
static char const __flash sWed[] = "Wed";
static char const __flash sThu[] = "Thu";
static char const __flash sFri[] = "Fri";
static char const __flash sSat[] = "Sat";
static const char __flash sCl[] = "%02d:%02d:%02d %s";

__flash const char __flash* sWDay[] = {
	sSun, sMon, sTue, sWed, sThu, sFri, sSat
 };

//---------------------------------------------------------
// Global variables declaration
//---------------------------------------------------------
TClock rtc;
TQueue event_queue;
unsigned char ev_q_buf[16];
char tmp_buf[4];
TSysRq rq;

//This function is used by printf function to transfer data to STDIO device
int putchar(int ch)
{
	LCDPutChar(ch);
	return ch;
}

void onClockSet()
{
    LCDGoTo(LINE_0 + 0);
    LCDPutChar('S');
    int currCurPos=9;
    LCDGoTo(LINE_1 + currCurPos);
    
    
  
}
static char currPos = '0';

void cInc()
{
  if(currPos == '0')
    if(rtc.sec == 60){
      rtc.sec=0;
    } else{
      rtc.sec++;
    }
  else if(currPos == '1')
       if(rtc.min == 60){
      rtc.min=0;
    } else{
      rtc.min++;
    }
  else if(currPos == '2')
    rtc.hr++;
}

void cDec()
{
  if(currPos == '0')
    if(rtc.sec != 0)
      rtc.sec--;
  else if(currPos == '1')
    if(rtc.min != 0)
      rtc.min--;
  else if(currPos == '2')
    if(rtc.hr != 0)
      rtc.hr--;
}

void onKeyDown()
{
        if(rq.rq_data == 0){ //INCREMENT KEY
          LCDGoTo(LINE_1 + 4 + rq.rq_data);
          cInc();
          LCDPutChar('I');
        }
        else if (rq.rq_data == 1){ //DECREMENT KEY
          LCDGoTo(LINE_1 + 4 + rq.rq_data);
          cDec();
        }
        else if (rq.rq_data == 2){ //NEXT KEY
          LCDGoTo(LINE_1 + 4 + rq.rq_data);
          if(currPos == '2')
            currPos = '0';
          else if(currPos == '1' || currPos == '0')
            currPos++;
          
          LCDPutChar(currPos);
         
        }
        else if (rq.rq_data == 3){ //PREVIOUS KEY
          LCDGoTo(LINE_1 + 4 + rq.rq_data);
          if(currPos == '0')
            currPos = '2';
          else if(currPos == '1' || currPos == '2')
            currPos--;
          LCDPutChar(currPos);
          
        }
        else if (rq.rq_data == 4){ //ESCAPE KEY
          LCDGoTo(LINE_1 + 4 + rq.rq_data);
          LCDPutChar('E');
        }
        else if (rq.rq_data == 5){ //ACCEPT KEY
          LCDGoTo(LINE_1 + 4 + rq.rq_data);
          LCDPutChar('A');
        }
        else if (rq.rq_data == 6){ //CLOCK SET MODE KEY
          LCDGoTo(LINE_1 + 4 + rq.rq_data);
          LCDPutChar('C');
          onClockSet();
        }
        else if (rq.rq_data == 7){ //ALARM SET MODE KEY
          LCDGoTo(LINE_1 + 4 + rq.rq_data);
          LCDPutChar('a');
        }
        else
        {
          
        }
}

void onKeyUp()
{
	LCDGoTo(LINE_1 + 4 + rq.rq_data);
	LCDPutChar(' ');
}

void onClockInc()
{
	LCDGoTo(LINE_0 + 2);
	printf_P(
		sCl,
		rtc.hr,
		rtc.min,
		rtc.sec,
		memcpy_P(tmp_buf, sWDay[rtc.wday], sizeof(sSun)));
}

static void InitDevices()
{
    LCDInit();
    LCDLoadUserCharP(LCDUserChar, 0, sizeof(LCDUserChar));
    LCDClear();
    //T0 start
    TCNT0 = 0;
    OCR0 = 71;

    TCCR0 = (1 << WGM01) | (1 << CS02) | (1 << CS01) | (1 << CS00);
    //dvt = 50;
    //Timers interrupt mask
    TIMSK = (1 << OCIE0);
    __enable_interrupt();	
}

#pragma vector = TIMER0_COMP_vect
__interrupt void ISR_OCR0()
{
static unsigned char pre_dv = 100;
	kbService(&event_queue);
	if(--pre_dv) return;
	pre_dv = 100;
	rtcInc(&rtc);	
	qAdd(&event_queue, MSG(CLOCK_INC, 0));
}

void main()
{	
	InitDevices();
	qInit(&event_queue, ev_q_buf, sizeof(ev_q_buf));
	qAdd(&event_queue, MSG(CLOCK_INC, 0));
	for(;;)
	{
		while(!qGet(&event_queue, &rq.msg));
		switch(rq.rq_id) {
		case KEY_DOWN:
			onKeyDown();
			break;
		case KEY_UP:
			onKeyUp();
			break;
		case CLOCK_INC:
			onClockInc();
			break;
                case CLOCK_SET:
                        onClockSet();
                        break;
		}
	}
}

