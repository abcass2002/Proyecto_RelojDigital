; Archivo:	mainmu.s
; Dispositivo:	PIC16F887
; Autor:	Abner Casasola
; Compilador:	pic-as (v2.35), MPLABX V6.00
;                
; Programa:	Contador binario 8 BITS	
;
; Creado:	22 feb 2022
; Última modificación: 26 feb 2022
    
PROCESSOR 16F887
    
; PIC16F887 Configuration Bit Settings

; Assembly source line config statements

; CONFIG1
  CONFIG  FOSC = INTRC_NOCLKOUT ; Oscillator Selection bits (INTOSCIO oscillator: I/O function on RA6/OSC2/CLKOUT pin, I/O function on RA7/OSC1/CLKIN)
  CONFIG  WDTE = OFF            ; Watchdog Timer Enable bit (WDT disabled and can be enabled by SWDTEN bit of the WDTCON register)
  CONFIG  PWRTE = OFF            ; Power-up Timer Enable bit (PWRT enabled)
  CONFIG  MCLRE = OFF           ; RE3/MCLR pin function select bit (RE3/MCLR pin function is digital input, MCLR internally tied to VDD)
  CONFIG  CP = OFF              ; Code Protection bit (Program memory code protection is disabled)
  CONFIG  CPD = OFF             ; Data Code Protection bit (Data memory code protection is disabled)
  CONFIG  BOREN = OFF           ; Brown Out Reset Selection bits (BOR disabled)
  CONFIG  IESO = OFF            ; Internal External Switchover bit (Internal/External Switchover mode is disabled)
  CONFIG  FCMEN = OFF           ; Fail-Safe Clock Monitor Enabled bit (Fail-Safe Clock Monitor is disabled)
  CONFIG  LVP = OFF              ; Low Voltage Programming Enable bit (RB3/PGM pin has PGM function, low voltage programming enabled)

; CONFIG2
  CONFIG  BOR4V = BOR40V        ; Brown-out Reset Selection bit (Brown-out Reset set to 4.0V)
  CONFIG  WRT = OFF             ; Flash Program Memory Self Write Enable bits (Write protection off)

// config statements should precede project file includes.
#include <xc.inc>

UP   EQU 0
DOWN EQU 7
 
RESET_TMR0 MACRO TMR_VAR
    BANKSEL TMR0	    ; cambiamos de banco
    MOVLW   TMR_VAR
    MOVWF   TMR0	    ; configuramos tiempo de retardo
    BCF	    T0IF	    ; limpiamos bandera de interrupción
    ENDM
    
PSECT udata_bank0
    valor:		DS 1	; Contiene valor a mostrar en los displays de 7-seg
    banderas:		DS 1	; Indica que display hay que encender
    nibbles:		DS 2	; Contiene los nibbles alto y bajo de valor
    display:		DS 2	; Representación de cada nibble en el display de 7-seg
    contador:           DS 1
    unidades:           DS 1
    decenas:            DS 1
    centenas:           DS 1

; ------- VARIABLES EN MEMORIA --------
PSECT udata_shr		    ; Memoria compartida
    W_TEMP:		DS 1
    STATUS_TEMP:	DS 1

PSECT resVect, class=CODE, abs, delta=2
ORG 00h			    ; posición 0000h para el reset
;------------ VECTOR RESET --------------
resetVec:
    PAGESEL MAIN	    ; Cambio de pagina
    GOTO    MAIN
    
PSECT intVect, class=CODE, abs, delta=2
ORG 04h	

PUSH:
    MOVWF   W_TEMP	    ; Guardamos W
    SWAPF   STATUS, W
    MOVWF   STATUS_TEMP	    ; Guardamos STATUS
    
ISR:
    BTFSC   T0IF		; Fue interrupción del TMR0? No=0 Si=1
    CALL    INT_TMR0		; Si -> Subrutina de interrupción de TMR0
    
    BTFSC   RBIF
    CALL    INT_IOCB
 
POP:
    SWAPF   STATUS_TEMP, W  
    MOVWF   STATUS	    ; Recuperamos el valor de reg STATUS
    SWAPF   W_TEMP, F	    
    SWAPF   W_TEMP, W	    ; Recuperamos valor de W
    RETFIE		    ; Regresamos a ciclo principal
    
INT_TMR0:
    RESET_TMR0 
    
    ; Reiniciamos TMR0 para 50ms
    CALL    MOSTRAR_VALOR	; Mostramos valor en hexadecimal en los displays
    RETURN  
INT_IOCB:
    BANKSEL  PORTB
    BTFSS    PORTB, UP
    INCF     PORTA
    
    BTFSS    PORTB, DOWN
    DECF     PORTA
    BCF	     RBIF
    RETURN
    
PSECT code, delta=2, abs
ORG 100h
 
MAIN:
    CALL    CONFIG_IO	    ; PORTA salida, RB7 Y RB0 entradas
    CALL    CONFIG_IOC
    CALL    CONFIG_INT	    ; Configuración de interrupciones
    CALL    CONFIG_RELOJ	; Configuración de Oscilador
    CALL    CONFIG_TMR0		; Configuración de TMR0
    BANKSEL PORTB	    ; Cambio a banco 00
    
    
LOOP:
    MOVF    PORTA, W		; Valor del PORTA a W
    MOVWF   unidades		; Movemos W a variable valor
    CALL    uni
    CALL    dece
    CALL    OBTENER_NIBBLE	; Guardamos nibble alto y bajo de valor
    CALL    SET_DISPLAY		; Guardamos los valores a enviar en PORTC para mostrar valor en hex
    GOTO    LOOP
uni:
    
    MOVLW 10
    SUBWF unidades, W
    BTFSS STATUS, 2
    RETURN
    CLRF unidades
    INCF decenas
    RETURN
    
dece:
    MOVLW 10
    SUBWF decenas, W
    BTFSS STATUS, 2
    RETURN
    CLRF decenas
    INCF centenas
    RETURN
cent:
    MOVLW 10
    SUBWF decenas, W
    BTFSS STATUS, 2
    RETURN
    CLRF centenas
    INCF centenas
    RETURN
    
CONFIG_RELOJ:
    BANKSEL OSCCON		; cambiamos a banco 1
    BSF	    OSCCON, 0		; SCS -> 1, Usamos reloj interno
    BCF	    OSCCON, 6
    BCF	    OSCCON, 5
    BCF	    OSCCON, 4		; IRCF<2:0> -> 110 1MHz
    RETURN
    
CONFIG_TMR0:
    BANKSEL OPTION_REG		; cambiamos de banco
    BCF	    T0CS		; TMR0 como temporizador
    BCF	    PSA			; prescaler a TMR0
    BSF	    PS2
    BCF	    PS1
    BCF	    PS0			; PS<2:0> -> 100 prescaler 1 : 3
    RESET_TMR0 132		; Reiniciamos TMR0 para 2ms
    RETURN 
    
CONFIG_IO:
    BANKSEL ANSEL
    CLRF    ANSEL
    CLRF    ANSELH	    ; I/O digitales
    BANKSEL TRISA
    CLRF    TRISA	    ; PORTA como salida
    BSF     TRISB, UP
    BSF     TRISB, DOWN
    CLRF    TRISC		; PORTC como salida
    BCF	    TRISD, 0		; RD0 como salida / display nibble alto
    BCF	    TRISD, 1		; RD1 como salida / display nibble bajo
    BCF	    TRISD, 2		; RD2 como salida / indicador de estado
    
    BANKSEL OPTION_REG
    BCF	    OPTION_REG, 7
    BANKSEL WPUB
    BSF	    WPUB, UP
    BSF	    WPUB, DOWN
    
    BANKSEL PORTD
    CLRF    PORTC		; Apagamos PORTC
    BCF	    PORTD, 0		; Apagamos RD0
    BCF	    PORTD, 1		; Apagamos RD1
    BCF	    PORTD, 2		; Apagamos RD2
    CLRF    PORTA		; Apagamos PORTA
    CLRF    unidades
    CLRF    decenas
    CLRF    centenas
    CLRF    banderas		; Limpiamos GPR
    
    RETURN
   
  CONFIG_INT:
    BANKSEL INTCON
    BSF	    GIE		
    BSF	    RBIE	    
    BCF	    RBIF	
    BSF	    T0IE	    ; Habilitamos interrupcion TMR0
    BCF	    T0IF	    ; Limpiamos bandera de TMR0
    RETURN
    
  CONFIG_IOC:
    BANKSEL TRISA
    BSF	    IOCB, UP
    BSF	    IOCB, DOWN
    BANKSEL PORTA
    MOVF    PORTB, W
    BCF	    RBIF
    RETURN
    
    
  OBTENER_NIBBLE:			;    Ejemplo:
				; Obtenemos nibble bajo
    MOVF    unidades, W
    MOVWF   nibbles		;	     0000 0101	
				; Obtenemos nibble alto
    MOVF    decenas, W
    MOVWF   nibbles+1		;	      1101 0000
    RETURN
    
SET_DISPLAY:
    MOVF    nibbles, W		; Movemos nibble bajo a W
    CALL    TABLA_7SEG		; Buscamos valor a cargar en PORT
    MOVWF   display		; Guardamos en display
    
    MOVLW   0    
    ;MOVF    nibbles+1, W	; Movemos nibble alto a W
    CALL    TABLA_7SEG		; Buscamos valor a cargar en PORTC
    MOVWF   display+1		; Guardamos en display+1
   
    RETURN
    
  MOSTRAR_VALOR:
    clrf    PORTC
    BCF	    PORTD, 0		; Apagamos display de nibble alto
    BCF	    PORTD, 1		; Apagamos display de nibble bajo
    BTFSC   banderas, 0		; Verificamos bandera
    GOTO    DISPLAY_1		;  
    GOTO    DISPLAY_0
    
    DISPLAY_0:			
	MOVF    display, W	; Movemos display a W
	MOVWF   PORTC		; Movemos Valor de tabla a PORTC
	BSF	PORTD, 1	; Encendemos display de nibble bajo
	BSF	banderas, 0	; Cambiamos bandera para cambiar el otro display en la siguiente interrupción
    RETURN

    DISPLAY_1:
	MOVF    display+1, W	; Movemos display+1 a W
	MOVWF   PORTC		; Movemos Valor de tabla a PORTC
	BSF	PORTD, 0	; Encendemos display de nibble alto
	BCF	banderas, 0	; Cambiamos bandera para cambiar el otro display en la siguiente interrupción
    RETURN
    
	
    
 
    ORG 200h
TABLA_7SEG:
    CLRF    PCLATH		; Limpiamos registro PCLATH
    BSF	    PCLATH, 1		; Posicionamos el PC en dirección 02xxh
    ANDLW   0x0F		; no saltar más del tamaño de la tabla
    ADDWF   PCL
    RETLW   00111111B	;0
    RETLW   00000110B	;1
    RETLW   01011011B	;2
    RETLW   01001111B	;3
    RETLW   01100110B	;4
    RETLW   01101101B	;5
    RETLW   01111101B	;6
    RETLW   00000111B	;7
    RETLW   01111111B	;8
    RETLW   01101111B	;9
    RETLW   01110111B	;A
    RETLW   01111100B	;b
    RETLW   00111001B	;C
    RETLW   01011110B	;d
    RETLW   01111001B	;E
    RETLW   01110001B	;F