; Archivo:	mainlab4.s
; Dispositivo:	PIC16F887
; Autor:	Abner Casasola
; Compilador:	pic-as (v2.35), MPLABX V6.00
;                
; Programa:	Contador binario 4 bits con interrupciones	
;
; Creado:	16 feb 2022
; Última modificación: 19 feb 2022
    
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
RESET_TMR0 MACRO TMR_VAR
    BANKSEL TMR0	    ; cambiamos de banco
    MOVLW   TMR_VAR
    MOVWF   TMR0	    ; configuramos tiempo de retardo
    BCF	    T0IF	    ; limpiamos bandera de interrupción
    ENDM

UP   EQU 0
DOWN EQU 7
; ------- VARIABLES EN MEMORIA --------
PSECT udata_shr		    ; Memoria compartida
    W_TEMP:		DS 1
    STATUS_TEMP:	DS 1
PSECT udata_bank0
    cont: DS 2 //Variable para los 20ms
    var:  DS 2 // Variables para controlar el contador de segundos
    segundos: DS 2 //Variable que almacena los segundos
    DSEG:     DS 2 //Variable que almacena los segundos
    
PSECT resVect, class=CODE, abs, delta=2
ORG 00h			    ; posición 0000h para el reset
    
;------------ VECTOR RESET --------------
resetVec:
    PAGESEL MAIN	    ; Cambio de pagina
    GOTO    MAIN
    
PSECT intVect, class=CODE, abs, delta=2
ORG 04h			    ; posición 0004h para interrupciones
;------- VECTOR INTERRUPCIONES ----------
PUSH:
    MOVWF   W_TEMP	    ; Guardamos W
    SWAPF   STATUS, W
    MOVWF   STATUS_TEMP	    ; Guardamos STATUS
    
ISR:
    
    BTFSC   RBIF
    CALL    INT_IOCB
    RESET_TMR0 99	    ; Reiniciamos TMR0 para 50ms
    INCF    var	    ; Incremento de la variable var
    CALL    CONTROL4_bits
    CALL    ENDGAME
POP:
    SWAPF   STATUS_TEMP, W  
    MOVWF   STATUS	    ; Recuperamos el valor de reg STATUS
    SWAPF   W_TEMP, F	    
    SWAPF   W_TEMP, W	    ; Recuperamos valor de W
    RETFIE		    ; Regresamos a ciclo principal

INT_IOCB:
    BANKSEL  PORTB
    BTFSS    PORTB, UP
    INCF     PORTA
    
    BTFSS    PORTB, DOWN
    DECF     PORTA
    BCF	     RBIF
    CALL     REST4 //Controla el decremento de 4 bits
    CALL     SUM4  //Controla el incremento de 4 bits
    RETURN
    
SUM4:
    BTFSC PORTA, 4
    CLRF PORTA
    return
    
REST4:
    BTFSS PORTA, 7
    return  
    CLRF PORTA
    movlw 15
    movwf PORTA
    return
    
PSECT code, delta=2, abs
ORG 100h		    ; posición 100h para el codigo
 
tabla:
    CLRF PCLATH
    BSF PCLATH, 0
    ANDLW 0x0f
    ADDWF PCL 
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
    RETLW   00111111B	;0
;------------- CONFIGURACION ------------
MAIN:
    CALL    CONFIG_IO	    ; PORTA salida, RB7 Y RB0 entradas
    CALL    CONFIG_RELOJ    ; Configuración de Oscilador 4MHz
    CALL    CONFIG_TMR0
    CALL    CONFIG_IOC      ; Configuración de TMR0
    CALL    CONFIG_INT	    ; Configuración de interrupciones
    BANKSEL PORTD	    ; Cambio a banco 00
    
LOOP:
    ; Código que se va a estar ejecutando mientras no hayan interrupciones
    GOTO    LOOP	    
    
;------------- SUBRUTINAS ---------------
CONFIG_RELOJ:
    BANKSEL OSCCON	    ; cambiamos a banco 1
    BSF	    OSCCON, 0	    ; SCS -> 1, Usamos reloj interno
    BSF	    OSCCON, 6
    BSF	    OSCCON, 5
    BCF	    OSCCON, 4	    ; IRCF<2:0> -> 110 4MHz
    RETURN
    
 CONFIG_IOC:
    BANKSEL TRISA
    BSF	    IOCB, UP
    BSF	    IOCB, DOWN
    BANKSEL PORTA
    MOVF    PORTB, W
    BCF	    RBIF
    
    RETURN
 CONFIG_IO:
    BANKSEL ANSEL
    CLRF    ANSEL
    CLRF    ANSELH	    ; I/O digitales
    BANKSEL TRISA
    CLRF    TRISA	    ; PORTA como salida
    CLRF    TRISD
    CLRF    TRISC
    BSF     TRISB, UP
    BSF     TRISB, DOWN
    
    BANKSEL OPTION_REG
    BCF	    OPTION_REG, 7
    BANKSEL WPUB
    BSF	    WPUB, UP
    BSF	    WPUB, DOWN
    
    BANKSEL PORTD
    CLRF    PORTA	    ; Apagamos PORTA
    CLRF    PORTD
    CLRF    PORTC
    RETURN
    
CONFIG_TMR0:
    BANKSEL OPTION_REG	    ; cambiamos de banco
    BCF	    T0CS	    ; TMR0 como temporizador
    BCF	    PSA		    ; prescaler a TMR0
    BSF	    PS2
    BSF	    PS1
    BCF	    PS0		    ; PS<2:0> -> 110 prescaler 1 : 128
	
    BANKSEL TMR0	    ; cambiamos de banco
    MOVLW   99
    MOVWF   TMR0	    ; 20ms retardo
    BCF	    T0IF	    ; limpiamos bandera de interrupción
    RETURN 
    
CONFIG_INT:
    BANKSEL INTCON
    BSF	    GIE		    
    BSF	    RBIE	    
    BCF	    RBIF	
    BSF	    T0IE	    ; Habilitamos interrupcion TMR0
    BCF	    T0IF	    ; Limpiamos bandera de TMR0
    RETURN
ENDGAME: //Controla el ciclo de de 1 segundo
    MOVLW 5
    SUBWF cont, W
    BTFSS STATUS, 2
    RETURN
    CLRF cont
    INCF segundos
    
    MOVF segundos, W
    CALL tabla
    MOVWF PORTC
    COMF PORTC,F
    CALL CNT_SEG
    RETURN
    //Puerto C tiene los segundos
    //Puerto D contiene las decenas de segundos
CNT_SEG:	    //Control de segundos
    MOVLW 10
    SUBWF segundos, W
    BTFSS STATUS, 2
    RETURN
    CLRF segundos
    INCF DSEG
    MOVF DSEG, W
    CALL tabla
    MOVWF PORTD
    COMF PORTD,F
    CALL CNT_DSEG
    RETURN
CNT_DSEG:          //Control decenas de segundos
    MOVLW 6
    SUBWF DSEG, W
    BTFSS STATUS, 2
    RETURN
    CLRF DSEG
    MOVF DSEG, W
    CALL tabla
    MOVWF PORTD
    COMF PORTD,F
    RETURN
    
CONTROL4_bits: //Controla que el ciclo de 20ms se repita 10 veces
    MOVLW 10
    SUBWF var, W
    BTFSS STATUS, 2
    return
    CLRF  var
    INCF cont
    RETURN
