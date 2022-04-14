;----------------------------------------------------------
; Polaczenie dwoch zagadnien
; 1. Wyswietlanie multiplekoswane
; 2. Odmierzanie czasu
; 3. Wyswietlanie beizacego czasu
; P0 - Segemnty
; P1 - Cyfry
; P3 - proponowana klawiatura
;
; Zadanie do rozwiazania
; 1. Uzupelnic procedure drukujaca o kropki migajace z 
;    czestotliwoscia 1Hz i wypelnieniem 50%
;    Wykorzystac metode znacznika zadajacego usuniecia
;    kropek z wyswietlania
; 2. Dolaczyc obsluge klawiatury oraz dodac procedury
;    ustawiania zegara
;  - pozycja ustawiana pulsuje z czest. 1Hz 
;    i wypelnieniem 50 %
;  - cyklicznie przemieszczamy sie pomiedzy minutami 
;    i godzinami
;  - zmiana ustawienia minut zeruje sekundy oraz ustawia
;    preskaler T0_DV na wartosc poczatkowa
;----------------------------------------------------------

DSEG 	AT 28H	
; Predefinowane stale
TH0_INIT	EQU	16
T0_DV_INIT	EQU	10	
TH1_INIT	EQU	232

; Wyswietlanie multiplekoswane
DISP_MAX	EQU	6	
DISP_BUF:	DS	DISP_MAX
DISP_PTR:	DS	1

; Struktura zegarowa
CLOCK:	
CL_SEC:		DS	1
CL_MIN:		DS	1
CL_HR:		DS	1

; Dzielnik programowy zegara RTC
T0_DV:		DS	1
	
BSEG	AT	0

; Znacznik zmiany stanu zegara RTC
; CL_HC -> Clock has changed
CL_HC:		DBIT	1


CSEG	AT	0
		
RESET:	
	JMP		INIT
ORG 0003H
	JMP		INT0_ISR
ORG 00BH
	JMP		T0_ISR
ORG 0013H
	JMP		INT1_ISR
ORG 001BH
	JMP		T1_ISR
ORG 0023H
	JMP		UART_ISR
ORG 002BH
	JMP		T2_ISR

INIT:
	; Memory clear
	MOV		R7,#120;
	MOV		R0,#8
	MOV		A,#0;
INIT_LP:
	MOV		@R0,A
	INC		R0
	DJNZ	R7,INIT_LP
INIT_STACK:
	MOV		SP,#7FH
	
INIT_TIMER:
	MOV		TH0,#TH0_INIT
	MOV		TH1,#TH1_INIT

;GATE|C/nT|M1|M0
;MODE 0 - 8bit TH + div 5bit  TL
;MODE 1 - 16 bit TH + TL
;MODE 2 - 8 bit TH ld TL
;MODE 3 - 2 x 8bit TL->T0, TH->T1
	MOV		TMOD,#11H

;TF1|TR1|TF0|TR0|IE1|IT1|IE0|IT1
;TFx - Timer OVF INT trigger
;TRx - Timer Run
;IEx - Ext Interrupt detection (Auto CLR after reception)
;ITx - 0 - Level/ 1 - Edge Int triggering
	MOV		TCON,#50H

INIT_INT:
;EA|-|ET2|ES|ET1|EX1|ET0|EX0
;EA - Global Int Enable
;ET - Timer
;ES - Serial
;EX - External
	MOV		IE,#10001010B
	
	MOV		P0 + 6,#0FFH ;Port overdrive		
	MOV		T0_DV,#T0_DV_INIT
	SETB	CL_HC; Request time printing
MAIN_LOOP:
	JNB		CL_HC,CL_UP_END
	CLR		CL_HC
	MOV		R0,#CLOCK
	ACALL	PRINT_TIME	
CL_UP_END:	
	;--------------------------------------------
	; Inne zadania realizowane w petli glownej
	;--------------------------------------------
	
	SJMP	MAIN_LOOP

;--------------------------------------------
; Inkrementuje czas o 1 sek.
; R0 - wskaznik do struktury czas
;--------------------------------------------

CLOCK_INC:	
	MOV		A,@R0
	ADD		A,#1
	DA		A
	CJNE	A,#60H,CLOCK_EX
	CLR		A
	MOV		@R0,A
	INC		R0
	MOV		A,@R0
	ADD		A,#1
	DA		A
	CJNE	A,#60H,CLOCK_EX
	CLR		A
	MOV		@R0,A
	INC		R0
	MOV		A,@R0
	ADD		A,#1
	DA		A
	CJNE	A,#24H,CLOCK_EX
	CLR		A
CLOCK_EX:
	MOV		@R0,A	
	RET
	
;--------------------------------------------
; Drukuje strukture czas w buforze wysw. LED
; R0 - wskaznik do struktury czas
; Czas zliczany w BCD wystrczy ekspansja
; tetrad
;--------------------------------------------	
		
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
	
;--------------------------------------------
; Przerwanie dedykowane obsludze RTC
; f(T0) = 10Hz
;--------------------------------------------	

T0_ISR:
	MOV		TH0,#10H
	PUSH	PSW
	PUSH	ACC	
	MOV		A,R0
	PUSH	ACC
	DJNZ	T0_DV,T0_ISR_EX
	MOV		T0_DV,#10	
	;Increment clock time
	MOV		R0,#CLOCK
	ACALL	CLOCK_INC
	SETB	CL_HC
T0_ISR_EX:
	POP		ACC
	MOV		R0,A
	POP		ACC
	POP		PSW
	RETI	

;--------------------------------------------
; Przerwanie dedykowane obsludze wysw. LED
; f(T1) = 480Hz
;--------------------------------------------

T1_ISR:
	;Adjust timer to 480Hz -> 1280 cycles only!!!
	MOV		TH1,#251
	PUSH	PSW
	PUSH	ACC
	MOV		A,R0
	PUSH	ACC	
	;Turn off display
	MOV		P1,#0FFh
	;Update segemnts control P0 <- DISP_BUF[DISP_PTR]
	MOV		A,DISP_PTR
	ADD		A,#DISP_BUF
	MOV		R0,A
	MOV		P0,@R0
	;Update ring counter P1 <- TO_RING[DISP_PTR]
	MOV		A,DISP_PTR
	MOV		DPTR,#TO_RING
	MOVC	A,@A + DPTR	
	MOV		P1,A
	;Increment display pointer 
	MOV		A,DISP_PTR
	INC		A
	CJNE	A,#DISP_MAX,T1_ISR_EX
	CLR		A
	MOV		DISP_PTR,A
T1_ISR_EX:	
	POP		ACC
	MOV		R0,ACC
	POP		ACC
	POP		PSW
	RETI

;--------------------------------------------
; Niewykorzystywane przerwania
;--------------------------------------------
INT0_ISR:
INT1_ISR:
UART_ISR:
T2_ISR:
	RETI	
	
TO_7SEG:	
	DB	0xDE, 0x82, 0xEC, 0xE6
	DB	0xB2, 0x76, 0x7E, 0xC2
	DB	0xFE, 0xF6, 0x1C, 0xBA
	DB	0xF8, 0xFA, 0x20, 0x00
		
TO_RING:		
	DB 0xFE, 0xFD, 0xFB, 0xF7, 0xEF, 0xDF


END	
