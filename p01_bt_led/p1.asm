TH0_INIT	EQU		232 ;init value of timer 0
T0_DV_INIT	EQU		100	;vaule of divider of timer 0

TH1_INIT	EQU		251
MAX_DISP	EQU		6
	
KB_IN		EQU		P2

DSEG	AT	30H
	
DISP_MAX	EQU	6	
DISP_BUF:	DS	DISP_MAX
DISP_PTR:	DS	1
	
KB_STATE:	DS	1
KB_TMR:		DS	1
KB_PREV:	DS	1
KB_REG:		DS	1	

T0_DV:		DS	1
CLOCK:	
CL_SEC:		DS	1
CL_MIN:		DS	1
CL_HR:		DS	1
	
BSEG	AT	0
CL_HC:		DBIT	1
RQ_KB:		DBIT	1	
RQ_HS:		DBIT	1

	
CSEG	AT	0
		
RESET:	
	JMP		INIT
ORG 0003H ;external interupt int0
	JMP		INT0_ISR
ORG 00BH  ;timer interrupt t0
	JMP		ON_T0_ISR
ORG 0013H ;external interrupt int1
	JMP		INT1_ISR
ORG 001BH ;timer interrupt t1
	JMP		ON_T1_ISR
	
INIT:
	; Memory clear
	MOV		R7,#120;
	MOV		R0,#8 ;data pointer
	MOV		A,#0;
	MOV 	R4, #0
INIT_LP:
	MOV		@R0,A
	INC		R0
	DJNZ	R7,INIT_LP
INIT_STACK:
	MOV		SP,#7FH
	
INIT_TIMER:
	MOV		TH0,#TH0_INIT ;set TH0 with value under label TH0_INIT, default 232
	MOV		TH1,#TH1_INIT ;set TH1 with value under label TH1_INIT, default 251
	MOV		T0_DV,#T0_DV_INIT;set T0_DV with value under label T0_DV_INIT, default 100
	MOV		TMOD,#00010001B ;timer mode selector
	MOV		TCON,#01010000B ;timer and interrupt control
INIT_INT:
	MOV		IE,#10001010B	;interrupt mask, T1  and T0 interrupts enabled
	MOV		P0 + 6,#0FFH ;Port overdrive, Clear port 0
	MOV		P2 + 6,#1; Clear port 2, assigned as input
	MOV		P3, #0FFH; Clear port 3

	SETB	CL_HC; ;Set bit
	
	
MAIN_LOOP: 					;Main loop 
	JBC		CL_HC,ON_CL_UPD ;If clock has changed, 
	JBC		RQ_KB,ON_KEY
	JBC		RQ_HS,ON_HS		
	SJMP	MAIN_LOOP	
	
ON_CL_UPD:	
	MOV		R0,#CLOCK
	;MOV		R0,#101010101B
	ACALL	PRINT_TIME
	ORL		DISP_BUF + 2,#1
	ORL		DISP_BUF + 4,#1
	SJMP	MAIN_LOOP
	
ON_HS:	
	ANL		DISP_BUF + 2,#0FEH
	ANL		DISP_BUF + 4,#0FEH
	SJMP	MAIN_LOOP
	
ON_KEY:	
	MOV		A,KB_REG
	CJNE	A,#1H,ON_KEY_INC
	CJNE	A,#2H,ON_KEY_DEC
	CJNE	A,#3H,ON_KEY_NEXT	
	CJNE	A,#4H,ON_KEY_PREV	
	CJNE	A,#5H,ON_KEY_ESC
	CJNE	A,#6H,ON_KEY_ENTER		
	SJMP	MAIN_LOOP	
	
ON_KEY_INC:
	MOV		A, R4
	ADD		A,#1
	MOV		R4,A
	SJMP	MAIN_LOOP

ON_KEY_DEC:
	DEC		P3
	SJMP	MAIN_LOOP

ON_KEY_NEXT:
	DEC		P3
	SJMP	MAIN_LOOP
	
ON_KEY_PREV:
	DEC		P3
	SJMP	MAIN_LOOP
	
ON_KEY_ESC:
	DEC		P3
	SJMP	MAIN_LOOP
	
ON_KEY_ENTER:
	DEC		P3
	SJMP	MAIN_LOOP


CLOCK_INC:	
	MOV		A,@R0
	ADD		A,#1
	DA		A
	CJNE	A,#60H,CLOCK_EX ;if one minute passed 
	CLR		A
	MOV		@R0,A
	INC		R0
	MOV		A,@R0
	ADD		A,#1
	DA		A
	CJNE	A,#60H,CLOCK_EX ;if one hour passed
	CLR		A
	MOV		@R0,A
	INC		R0
	MOV		A,@R0
	ADD		A,#1
	DA		A
	CJNE	A,#24H,CLOCK_EX ;if 24 hours passed
	CLR		A
CLOCK_EX:
	MOV		@R0,A	
	RET
	
PRINT_TIME:	
	MOV		R1,#DISP_BUF
	MOV		R7,#2
	MOV		DPTR,#TO_7SEG
	; Wydruk sek i min.
PRT_LP:	
	MOV		A,@R0
	ANL		A,#0FH
	MOVC	A,@A + DPTR
	MOV		@R1,A
	INC		R1
	MOV		A,@R0
	SWAP	A
	ANL		A,#0FH
	MOVC	A,@A + DPTR
	MOV		@R1,A
	INC		R1
	INC		R0
	DJNZ	R7,PRT_LP	
	; Wydruk godzin z usunieciem 
	; zera niznaczacego dla dziesiatek
	MOV		A,@R0
	ANL		A,#0FH
	MOVC	A,@A + DPTR
	MOV		@R1,A
	INC		R1
	MOV		A,@R0
	SWAP	A
	ANL		A,#0FH
	JNZ		PRT_BL
	MOV		A,#0FH
PRT_BL:
	MOVC	A,@A + DPTR
	MOV		@R1,A
	RET
	
;----------------------------------------------------------
; Parametry sterownika klawiatur
;----------------------------------------------------------

KB_DET_DY	EQU	2; 		Liczba cykli do wykrycia klawisza	
KB_TPM_DY	EQU	200;	Liczba cykli do rozp. auto. powt.
KB_REP_DY	EQU	50;		Liczba cykli okresu auto. powt.
KB_REL_DY	EQU	3;		Liczba cykli do wykrycia zwolnienia klaw.	
KB_REP_MASK	EQU	0Fh;	Klawisze powtarzane - maska bitowa	

;----------------------------------------------------------
; Stany automatu sterownika klawiatury
;----------------------------------------------------------
ST_KB_FIRST	EQU	0
ST_KB_NEXT	EQU	1
ST_KB_REP	EQU	2
ST_KB_REL	EQU 3	
	
KB_DRV:	
	MOV		A,KB_IN
	CPL		A		
	MOV		R7,KB_STATE	
KB_FIRST:
	CJNE	R7,#ST_KB_FIRST,KB_NEXT	
	MOV		R6,#8
	MOV		R5,#0
KB_CHK_LP:	
	RL		A
	JNB		ACC.0,KB_CHK_NK
	INC		R5
KB_CHK_NK:	
	DJNZ	R6,KB_CHK_LP
	;Check valid key pattern (only 1-key)
	CJNE	R5,#1,KB_CHK_EX
	MOV		KB_PREV,A
	MOV		KB_TMR,#KB_DET_DY
	MOV		KB_STATE,#ST_KB_NEXT
KB_CHK_EX:	
	RET	
KB_NEXT:
	CJNE	R7,#ST_KB_NEXT,KB_REP
	CJNE	A,KB_PREV, KB_NEXT_REL
	DJNZ	KB_TMR,KB_NEXT_EX
	SETB	RQ_KB
	MOV		KB_REG,KB_PREV
	ANL		A,#KB_REP_MASK
	JZ		KB_NEXT_REL	
KB_NEXT_REP:
	MOV		KB_STATE,#ST_KB_REP
	MOV		KB_TMR,#KB_TPM_DY	
KB_NEXT_EX:		
	RET	
KB_NEXT_REL:	
	MOV		KB_STATE,#ST_KB_REL
	MOV		KB_TMR,#KB_REL_DY
	RET

KB_REP:
	CJNE	R7,#ST_KB_REP,KB_REL
	CJNE	A,KB_PREV,KB_NEXT_REL
	DJNZ	KB_TMR,KB_REP_EX	
	MOV		KB_TMR,#KB_REP_DY
	SETB	RQ_KB
	MOV		KB_REG,KB_PREV
KB_REP_EX:	
	RET

KB_REL:
	CJNE	R7,#ST_KB_REL,KB_ERR
	JZ		KB_REL_CONT
	MOV		KB_TMR,#3
	RET
KB_REL_CONT:	
	DJNZ	KB_TMR,KB_EX
KB_ERR:	
	MOV		KB_STATE,#ST_KB_FIRST	
KB_EX:	
	RET
	
	
;--------------------------------------------
; Przerwanie dedykowane obsludze RTC
; f(T0) = 100Hz
;--------------------------------------------	

ON_T0_ISR:
	MOV		TH0,#TH0_INIT ; TH0 - most significant bit, TL0 least significant bit
	PUSH	PSW
	PUSH	ACC	
	SETB	RS0
	ACALL	KB_DRV
	DJNZ	T0_DV,T0_ISR_EX
	MOV		A,T0_DV
	CJNE	A,#50,T0_NO_HS
	SETB	RQ_HS
T0_NO_HS:	
	MOV		T0_DV,#T0_DV_INIT	
	;Increment clock time
	MOV		R0,#CLOCK
	ACALL	CLOCK_INC
	SETB	CL_HC
T0_ISR_EX:
	POP		ACC	
	POP		PSW
	RETI	

ON_T1_ISR:
	MOV		TH1,#TH1_INIT
	PUSH	PSW
	PUSH 	ACC	
	PUSH 	DPL
	PUSH 	DPH
	SETB	RS0
	MOV P1,#0FFh
	
	MOV A,DISP_PTR
	ADD A,#DISP_BUF
	MOV R0,A
	MOV P0,@R0
	
	MOV A,DISP_PTR
	MOV DPTR,#TO_RING
	MOVC A,@A + DPTR
	MOV P1,A
	
	MOV A,DISP_PTR
	INC A
	CJNE A,#DISP_MAX,T1_ISR_DP_OK
	CLR A
T1_ISR_DP_OK:
	MOV DISP_PTR,A
T1_ISR_EX:	
	POP		DPH
	POP		DPL
	POP		ACC	
	POP		PSW
	RETI
	



INT0_ISR:
INT1_ISR:

TO_7SEG:	
	DB	0xDE, 0x82, 0xEC, 0xE6
	DB	0xB2, 0x76, 0x7E, 0xC2
	DB	0xFE, 0xF6, 0x1C, 0xBA
	DB	0xF8, 0xFA, 0x20, 0x00
		
TO_RING:		
	DB 0xFE, 0xFD, 0xFB, 0xF7, 0xEF, 0xDF,0xBF,0x7F
	
END
	
	