; Archivo:	mainProyect.s
; Dispositivo:	PIC16F887
; Autor:	Abner Casasola
; Compilador:	pic-as (v2.35), MPLABX V6.00
;                
; Programa:	Reloj digital		
;
; Creado:	03 marzo 2022
; Última modificación: 03 marzo 2022
 
PROCESSOR 16F887
    
; PIC16F887 Configuration Bit Settings

; Assembly source line config statements

; CONFIG1
  CONFIG  FOSC = INTRC_NOCLKOUT ; Oscillator Selection bits (INTOSCIO oscillator: I/O function on RA6/OSC2/CLKOUT pin, I/O function on RA7/OSC1/CLKIN)
  CONFIG  WDTE = OFF            ; Watchdog Timer Enable bit (WDT disabled and can be enabled by SWDTEN bit of the WDTCON register)
  CONFIG  PWRTE = ON            ; Power-up Timer Enable bit (PWRT enabled)
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
BMODO EQU 4
; -------------- MACROS --------------- 
RESET_TMR0  MACRO TMR_VAR
    BANKSEL TMR0	    ; cambiamos de banco
    MOVLW   TMR_VAR
    MOVWF   TMR0	    ; configuramos tiempo de retardo
    BCF	    T0IF	    ; limpiamos bandera de interrupción
    ENDM
    
SET_TIME   MACRO TIME
   CLRF    preseg
   CLRF    segundos
   CLRF    decsegundos
   
   BTFSS   PORTB, 0
   INCF    TIME
   BTFSS   PORTB, 1
   DECF    TIME
   ENDM
   
   
CONTROLTMR MACRO VARCONT, CICLOSR, VARINC
    MOVLW CICLOSR
    SUBWF VARCONT, W
    BTFSS STATUS, 2
    return
    CLRF  VARCONT
    DECF VARINC
    ENDM
    
RESTCON    MACRO VARIABLET, SET_DOWN
    BTFSS VARIABLET, 4
    RETURN 
    CLRF VARIABLET
    MOVLW SET_DOWN
    MOVWF VARIABLET
    ENDM
RESTCONTMR    MACRO VARIABLET, SET_DOWN, vardec
    BTFSS VARIABLET, 4
    RETURN 
    CLRF VARIABLET
    MOVLW SET_DOWN
    MOVWF VARIABLET
    DECF vardec
    ENDM  
    
INCRETMRMA MACRO VARCONTROLTMR, TIMETMR
    MOVLW VARCONTROLTMR
    SUBWF flagTMR, W
    BTFSS STATUS, 2
    RETURN
    CLRF presegTMR
    BTFSS PORTBINTMR, 0
    INCF  TIMETMR
    BTFSS  PORTBDETMR, 0
    DECF  TIMETMR
    ENDM
    
RESET_TMR1 MACRO TMR1_H, TMR1_L
    MOVLW   TMR1_H	        ; Literal a guardar en TMR1H
    MOVWF   TMR1H	        ; Guardamos literal en TMR1H
    MOVLW   TMR1_L	        ; Literal a guardar en TMR1L
    MOVWF   TMR1L	        ; Guardamos literal en TMR1L
    BCF	    TMR1IF	        ; Limpiamos bandera de int. TMR1
    ENDM
    
 INDE MACRO FLAGTMRVALUE, timevalue
    MOVLW FLAGTMRVALUE
    SUBWF flagTMR, W
    BTFSS STATUS, 2
    RETURN
    BTFSS PORTB, 0
    INCF  timevalue
    BTFSS  PORTB, 1
    DECF  timevalue
    ENDM
    
    ; ------- VARIABLES EN MEMORIA --------
PSECT udata_shr		        ; Memoria compartida
    W_TEMP:		DS 1
    STATUS_TEMP:	DS 1
    
PSECT udata_bank0
    //Variables del RELOJ
    preseg:             DS 1
    segundos:           DS 1
    decsegundos:        DS 1
    minutos:            DS 1
    decminutos:         DS 1
    horas:              DS 1
    dechoras:           DS 1
    form24horas:        DS 1
    estado:             DS 1
    flagleds:           DS 1
    flagRD:             DS 1
    
    //Variables del TMR
    presegTMR:          DS 1
    segundosTMR:        DS 1
    decsegundosTMR:     DS 1
    minutosTMR:         DS 1
    decminutosTMR:      DS 1
    flagTMR:            DS 1
    PORTBDETMR:         DS 1
    PORTBINTMR:         DS 1
    BANDTMR:            DS 1
    ALARMAflujo:        DS 1
    ALARMATMRMIN:       DS 1
    segundosalarma:     DS 1
    contadorTMRALARMA:  DS 1
    //Variables de FECHA
    dia:                DS 1
    decdia:             DS 1
    mes:                DS 1
    decmes:             DS 1
    
    //Variables de los Display
    valor1:		DS 1	 ; Contiene valor a mostrar en los displays de 7-seg
    valor2:		DS 1	 ; Contiene valor a mostrar en los displays de 7-seg
    valor3:		DS 1	 ; Contiene valor a mostrar en los displays de 7-seg
    valor4:		DS 1	 ; Contiene valor a mostrar en los displays de 7-seg
    banderasA:		DS 1	 ; Indica que display hay que encender
    banderasB:		DS 1	 ; Indica que display hay que encender
    banderasAB:         DS 1
    nibbles:		DS 2	 ; Contiene los nibbles alto y bajo de valor
    nibbles2:		DS 2	 ; Contiene los nibbles alto y bajo de valor
    display:		DS 4	 ; Representación de cada nibble en el display de 7-seg
     
    
    ;------------ VECTOR RESET --------------
    PSECT resVect, class=CODE, abs, delta=2
    ORG 00h 
    resetVec:
	PAGESEL MAIN	          ; Cambio de pagina
	GOTO    MAIN
    
    
    ;------- VECTOR INTERRUPCIONES ----------
    PSECT intVect, class=CODE, abs, delta=2
    ORG 04h			  ; posición 0004h para interrupciones
    
PUSH:
    MOVWF   W_TEMP	          ; Guardamos W
    SWAPF   STATUS, W
    MOVWF   STATUS_TEMP	          ; Guardamos STATUS
    
ISR:
    BTFSC   TMR1IF	    
    CALL    INT_TMR1
    
    BTFSC   RBIF
    CALL    INT_PORTB
    
    BTFSC   T0IF		; Fue interrupción del TMR0? No=0 Si=1
    CALL    INT_TMR0		; Si -> Subrutina de interrupción de TMR0\
    
    
    
POP:
    SWAPF   STATUS_TEMP, W  
    MOVWF   STATUS	          ; Recuperamos el valor de reg STATUS
    SWAPF   W_TEMP, F	    
    SWAPF   W_TEMP, W	          ; Recuperamos valor de W
    RETFIE		          ; Regresamos a ciclo principal
    
     ;------- INTERRUPCIONES ---------
     
     ;------- INTERRUPCION PORTB ----------
INT_PORTB:
    // ESTADOS
    BTFSC   PORTA, 2
    GOTO   ESTADORELOJ
    BTFSC   PORTA, 4
    GOTO    ESTADOTMR
    BTFSC   PORTA, 3
    GOTO    ESTADOFECHA
    BCF     RBIF
    RETURN
;------- INTERRUPCION TMR1 ----------
INT_TMR1:
    RESET_TMR1 0x85, 0xEE
    BTFSS ALARMATMRMIN, 0
    GOTO   $+2
    CALL   ALARMADETMR
    BTFSS  flagleds, 0		; Verificamos bandera
    GOTO    LON		  
    GOTO    LOFF
    RETURN
ALARMADETMR:
   INCF segundosalarma
   MOVLW 120
   SUBWF segundosalarma, W
   BTFSS STATUS, 2
   return
   CLRF segundosalarma
   BCF PORTA, 6
   BCF ALARMATMRMIN, 0
   CLRF  contadorTMRALARMA
   MOVLW 1
   MOVWF segundosTMR
   RETURN
;------- INTERRUPCION TMR0 ----------
INT_TMR0:
    RESET_TMR0 61	    ; Reiniciamos TMR0 para 50ms
    CALL    MOSTRAR_VALOR
    INCF    preseg
    INCF    presegTMR
    CALL    contPRE
    CALL    contsegundos
    CALL    contdecsegundos
    CALL    contminutos
    CALL    contdecminutos
    CALL    conthoras
    CALL    contdecenashoras
    CALL    contdec2horas
    CALL    RESTA1
    CALL    RESTA2
    CALL    RESTAhoras
    CALL    RESTADEChoras
    
    CALL    PRESTMR
    CALL    ENDFLAGTMR
    RETURN
    
 ENDFLAGTMR:
    MOVF  decminutosTMR, W
    BTFSS STATUS, 2
    RETURN
    MOVF  minutosTMR, W
    BTFSS STATUS, 2
    RETURN
    MOVF  decsegundosTMR, W
    BTFSS STATUS, 2
    RETURN
    MOVF  segundosTMR, W
    BTFSS STATUS, 2
    RETURN
    BSF  PORTA, 6
    BCF ALARMAflujo,0
    BSF ALARMATMRMIN, 0
    RETURN
    
 PRESTMR:
    MOVLW 10
    SUBWF presegTMR, W
    BTFSS STATUS, 2
    return
    CLRF  presegTMR
    BTFSS ALARMAflujo, 0
    RETURN
    DECF  segundosTMR
    MOVF  decminutosTMR, W
    SUBLW 1
    BTFSS STATUS, 1
    CALL NOZEROTMRMIN
    CALL SIZEROTMRMIN
    MOVF  minutosTMR, W
    BTFSS STATUS, 2
    goto $+3
    CALL CONTROLTIMEMINUN
    RETURN
    CALL NOZEROTMRSEG
    RETURN
    
CONTROLTIMEMINUN:
    MOVF  decsegundosTMR, W
    BTFSS STATUS, 2
    goto $+3
    CALL SIZEROTMRSEG
    RETURN
    CALL NOZEROTMRSEG
    RETURN
    
NOZEROTMRSEG:
    RESTCONTMR segundosTMR, 9, decsegundosTMR
    RESTCONTMR decsegundosTMR, 5, minutosTMR
    RETURN
SIZEROTMRSEG:
    RESTCON segundosTMR, 0
    RESTCON decsegundosTMR, 0
    RETURN
    
NOZEROTMRMIN:
    RESTCONTMR minutosTMR, 9, decminutosTMR
    RESTCON decminutosTMR, 9
    RETURN
    
SIZEROTMRMIN:
    RESTCON minutosTMR, 0
    RESTCON decminutosTMR, 0
    RETURN

    ;------- CONTROL UNDERFLOW RELOJ ---------
RESTA1:
    RESTCON minutos, 9
    RETURN
RESTA2:
    RESTCON decminutos, 5
    RETURN
RESTAhoras:
    MOVLW 2
    SUBWF dechoras, W
    BTFSS STATUS, 2
    CALL NOZERO
    CALL CONTD24B
    RETURN
NOZERO:
    RESTCON horas, 9
    RETURN
CONTD24B:
    RESTCON horas, 3
    RETURN
    
RESTADEChoras:
    RESTCON dechoras, 2
    RETURN
    
    ;------- ESTADO RELOJ ----------
ESTADORELOJ:
    //INSTRUCCIONES DEL ESTADO RELOJ
    BTFSS  PORTB, 3
    CALL   SETCONFIG
    CALL   INDCMIN
    CALL   INDCEMIN
    CALL   INDCHOR
    CALL   INDCEHOR
    CALL   CONTROLDISPLAYRELOJ
    BTFSS  PORTB, 2
    CALL   LEDCONFIGURACION
    //CAMBIO DE ESTADO
    BTFSS  PORTB, BMODO
    CALL   INSTRUCCIONESRELOJ
    BCF    RBIF
    RETURN
    ;------- LED INDICADOR MODO CONFIGURACION RELOJ ----------
LEDCONFIGURACION:
    INCF   flagRD
    BSF    PORTA, 5
    RETURN
    ;------- BOTON DE ACEPTAR CONFIGURACION ----------
SETCONFIG:
    MOVLW 5
    MOVWF flagRD
    RETURN
    
    ;------- CONTROL OVERFLOW RELOJ ----------
INDCMIN:
    MOVLW 1
    SUBWF flagRD, W
    BTFSS STATUS, 2
    RETURN
    SET_TIME minutos
    BCF    RBIF
    RETURN
 
INDCEMIN:
    MOVLW 2
    SUBWF flagRD, W
    BTFSS STATUS, 2
    RETURN
    SET_TIME decminutos
    BCF    RBIF
    RETURN
INDCHOR:
    MOVLW 3
    SUBWF flagRD, W
    BTFSS STATUS, 2
    RETURN
    SET_TIME horas
    BCF    RBIF
    RETURN
INDCEHOR:
    MOVLW 4
    SUBWF flagRD, W
    BTFSS STATUS, 2
    RETURN
    SET_TIME dechoras
    BCF    RBIF
    RETURN
    
CONTROLDISPLAYRELOJ:
    MOVLW 5
    SUBWF flagRD, W
    BTFSS STATUS, 2
    RETURN
    CLRF   flagRD
    BCF    PORTA, 5
    BCF    RBIF
    RETURN
INSTRUCCIONESRELOJ:
    BCF    PORTA, 2
    BCF    PORTA, 4
    BSF    PORTA, 3
    BCF    RBIF
    RETURN
    
    ;------- ESTADO FECHA ----------
ESTADOFECHA:
    //INSTRUCCIONES DEL ESTADO FECHA
    
    //CAMBIO DE ESTADO
    BTFSS  PORTB, BMODO
    CALL   INSTRUCCIONESFECHA
    BCF    RBIF
    RETURN
    
INSTRUCCIONESFECHA:
    BCF    PORTA, 3
    BCF    PORTA, 2
    BSF    PORTA, 4
    BCF    RBIF
    RETURN
    
 ;------- ESTADO TMR ----------
ESTADOTMR:
    //INSTRUCCIONES DEL ESTADO TMR0
    BTFSS  PORTB, 3
    CALL   SETCONFIGTMR
    CALL   DISPTMRCO
    BTFSS  PORTB, 2
    CALL   FLOWTMR
    CALL   INCREDECRETMRS
    CALL   INCREDECRETMRDS
    CALL   INCREDECRETMRM
    CALL   INCREDECRETMRDM
    CALL   restaTMRS
    CALL   restaTMRDS
    CALL   restaTMRM
    CALL   restaTMRDM
    CALL   sumaTMRS
    CALL   sumaTMRDS
    CALL   sumaTMRM
    CALL   sumaTMRDM
    //CAMBIO DE ESTADO
    BTFSS  PORTB, BMODO
    CALL   INSTRUCCIONESTMR
    BCF    RBIF
    RETURN
;------- CONTROL UNDERFLOW TMR ----------
BOTONAL:
    MOVLW 2
    SUBWF contadorTMRALARMA, W
    BTFSS STATUS, 2
    RETURN
    CLRF  contadorTMRALARMA
    MOVLW 119
    MOVWF segundosalarma
    CALL  ALARMADETMR
    RETURN
    
NOBOTONAL:
    MOVLW 1
    SUBWF contadorTMRALARMA, W
    BTFSS STATUS, 2
    RETURN
    BSF  ALARMAflujo, 0
    RETURN
    
SETCONFIGTMR:
    MOVLW 5
    MOVWF flagTMR
    INCF contadorTMRALARMA
    CALL   BOTONAL
    CALL   NOBOTONAL
    RETURN
    
sumaTMRS:
    MOVLW 10
    SUBWF segundosTMR, W
    BTFSS STATUS, 2
    return
    CLRF  segundosTMR
    INCF decsegundosTMR
    RETURN
sumaTMRDS:
    MOVLW 6
    SUBWF decsegundosTMR, W
    BTFSS STATUS, 2
    return
    CLRF  decsegundosTMR
    INCF minutosTMR
    RETURN
sumaTMRM:
    MOVLW 10
    SUBWF minutosTMR, W
    BTFSS STATUS, 2
    return
    CLRF  minutosTMR
    INCF decminutosTMR
    RETURN
sumaTMRDM:
    MOVLW 10
    SUBWF decminutosTMR, W
    BTFSS STATUS, 2
    return
    CLRF  decminutosTMR
    CLRF  minutosTMR
    CLRF  decsegundosTMR
    CLRF  segundosTMR
    RETURN
    
restaTMRS:
    RESTCON segundosTMR, 9
    RETURN
restaTMRDS:
    RESTCON decsegundosTMR, 5
    RETURN   
restaTMRM:
    RESTCON minutosTMR, 9
    RETURN
restaTMRDM:
    RESTCON decminutosTMR, 9
    RETURN
    
INCREDECRETMRS:
    INDE   1, segundosTMR
    RETURN
INCREDECRETMRDS:
    INDE   2, decsegundosTMR
    RETURN
INCREDECRETMRM:
    INDE   3, minutosTMR
    RETURN
INCREDECRETMRDM:
    INDE   4, decminutosTMR
    RETURN
DISPTMRCO:
    MOVLW 5
    SUBWF flagTMR, W
    BTFSS STATUS, 2
    RETURN
    CLRF   flagTMR
    BCF    PORTA, 5
    BCF    RBIF
    RETURN
    
FLOWTMR:
    INCF   flagTMR
    BSF    PORTA, 5
    BSF    BANDTMR, 0
    RETURN
INSTRUCCIONESTMR:
    BCF    PORTA, 4
    BCF    PORTA, 3
    BSF    PORTA, 2
    BCF    RBIF
    RETURN
    
;------- CONTROL VARIABLES DE TIEMPO DEL TMR0 ESTADO RELOJ ----------
contPRE:
    MOVLW 10
    SUBWF preseg, W
    BTFSS STATUS, 2
    return
    CLRF  preseg
    INCF segundos
    RETURN
    
contsegundos:
    MOVLW 10
    SUBWF segundos, W
    BTFSS STATUS, 2
    return
    CLRF  segundos
    INCF decsegundos
    RETURN
    
contdecsegundos:
    MOVLW 6
    SUBWF decsegundos, W
    BTFSS STATUS, 2
    return
    CLRF  decsegundos
    INCF minutos
    RETURN
        
contminutos:
    MOVLW 10
    SUBWF minutos, W
    BTFSS STATUS, 2
    return
    CLRF  minutos
    INCF decminutos
    RETURN
    
contdecminutos:
    MOVLW 6
    SUBWF decminutos, W
    BTFSS STATUS, 2
    return
    CLRF  decminutos
    INCF horas
    RETURN
    
conthoras:
    MOVLW 10
    SUBWF horas, W
    BTFSS STATUS, 2
    return
    CLRF  horas
    INCF dechoras
    RETURN
contdecenashoras:
    MOVLW 3
    SUBWF dechoras, W
    BTFSS STATUS, 2
    return
    CLRF  dechoras
    RETURN
contdec2horas:
    MOVLW 4
    SUBWF horas, W
    BTFSS STATUS, 2
    return
    CALL CONTD24
    RETURN
CONTD24:
    MOVLW 2
    SUBWF dechoras, W
    BTFSS STATUS, 2
    return
    CLRF horas
    CLRF dechoras
    RETURN
    ;------- PARPADEO LEDS 500ms ----------
LON:
    BSF PORTA,0
    BSF PORTA,1
    BSF flagleds, 0
    RETURN
LOFF:
    BCF PORTA,0
    BCF PORTA,1
    BCF flagleds, 0
    RETURN
    
    ;------- CONFIGURACIONES ----------
org 300h
MAIN:
    CALL    CONFIG_IO	    ; Configuración de I/O
    CALL    CONFIG_RELOJ    ; Configuración de Oscilador
    CALL    CONFIG_TMR0	    
    CALL    CONFIG_TMR1
    CALL    CONFIG_INT	    ; Configuración de interrupciones
    CALL    CONFIG_IOC
    BANKSEL PORTA	    ; Cambio a banco 00

LOOP:
    
    BTFSC   PORTA, 2
    CALL    DISPLAYS_ESTADO0
    BTFSC   PORTA, 3 
    CALL    DISPLAYS_ESTADO1
    BTFSC   PORTA, 4
    CALL    DISPLAYS_ESTADO2
    CALL    OBTENER_NIBBLE
    CALL    SET_DISPLAY
    GOTO    LOOP
  
 
     ;------- ESTADOS LOOP ----------

DISPLAYS_ESTADO0:
    
    MOVF    minutos, W
    MOVWF   valor4
    MOVF    decminutos, W
    MOVWF   valor3
    MOVF    horas, W
    MOVWF   valor2
    MOVF    dechoras, W
    MOVWF   valor1
    RETURN
DISPLAYS_ESTADO2: 
   
    MOVF  segundosTMR, W
    MOVWF   valor4
    MOVF  decsegundosTMR, W
    MOVWF   valor3
    MOVF  minutosTMR, W
    MOVWF   valor2
    MOVF  decminutosTMR, W
    MOVWF   valor1
    RETURN
    
DISPLAYS_ESTADO1:
    MOVLW    6
    MOVWF   valor4
    MOVLW    7
    MOVWF   valor3
    MOVLW    8
    MOVWF   valor2
    MOVLW    9
    MOVWF   valor1
    RETURN
    ;------- CONFIGURACION ENTRADAS/SALIDAS ----------
CONFIG_IO:
    BANKSEL ANSEL
    CLRF    ANSEL
    CLRF    ANSELH	           ; I/O digitales
    
    BANKSEL TRISA                  ; Puertos A, C, D son salidasa
    CLRF    TRISD		   ; Bits <0:4> del puesto B son entradas
    CLRF    TRISA
    CLRF    TRISC
    BSF     TRISB, 0
    BSF     TRISB, 1
    BSF     TRISB, 2
    BSF     TRISB, 3
    BSF     TRISB, BMODO
    
    BANKSEL OPTION_REG             ; Puerto B PULL_UP
    BCF	    OPTION_REG, 7
    BANKSEL WPUB
    BSF	    WPUB, 0
    BSF	    WPUB, 1
    BSF	    WPUB, 2
    BSF	    WPUB, 3
    BSF	    WPUB, BMODO
    
    BANKSEL PORTA
    CLRF    PORTD	           ; Limpiamos los puertos
    CLRF    PORTA
    CLRF    PORTC
    CLRF    PORTB
    BSF     PORTA, 2
    CLRF    banderasAB
    CLRF    banderasA
    CLRF    preseg
    CLRF    segundos
    CLRF    decsegundos
    CLRF    minutos
    CLRF    decminutos
    CLRF    horas
    CLRF    dechoras
    CLRF    banderasB
    CLRF    presegTMR
    CLRF    segundosTMR
    CLRF    decsegundosTMR
    CLRF    minutosTMR
    CLRF    decminutosTMR
    CLRF    valor1
    CLRF    valor2
    CLRF    valor3
    CLRF    valor4
    MOVLW   1
    MOVWF   segundosTMR
    CLRF    contadorTMRALARMA
    ;------- CONFIGURACION RELOJ ----------
CONFIG_RELOJ:
    BANKSEL OSCCON	    ; cambiamos a banco 1
    BSF	    OSCCON, 0	    ; SCS -> 1, Usamos reloj interno
    BSF	    OSCCON, 6
    BCF	    OSCCON, 5
    BSF	    OSCCON, 4	    ; IRCF<2:0> -> 101 2MHz
    RETURN
    
    ;------- CONFIGURACION TMR0 ----------
    ; TMR0 controla los displays y reloj
CONFIG_TMR0:
    BANKSEL OPTION_REG		; cambiamos de banco
    BCF	    T0CS		; TMR0 como temporizador
    BCF	    PSA			; prescaler a TMR0
    BSF	    PS2
    BSF	    PS1
    BSF	    PS0			; PS<2:0> -> 000 prescaler 1 : 256
    RESET_TMR0 61		; Reiniciamos TMR0 para 100ms
    RETURN
    
    ;------- CONFIGURACION TRM1 ----------
    ; TMR1 controla los leds que parpadean
CONFIG_TMR1:
    BANKSEL T1CON	    ; Cambiamos a banco 00
    BCF	    TMR1GE	    ; TMR1 siempre cuenta
    BSF	    T1CKPS1	    ; prescaler 1:8
    BSF	    T1CKPS0
    BCF	    T1OSCEN	    ; LP deshabilitado
    BCF	    TMR1CS	    ; Reloj interno
    BSF	    TMR1ON	    ; Prendemos TMR1
    RESET_TMR1 0x85, 0xEE   ;TMR1 cada medio segundo
    RETURN
    

    ;------- CONFIGURACION INTERRUPCIONES ----------
CONFIG_INT:
    BANKSEL PIE1
    BSF     TMR1IE          ; Interrupcion TMR1
    BSF     TMR2IE	    ; Interrupcion TMR2
    
    BANKSEL INTCON	    
    BSF	    PEIE	    ; Habilitamos interrupciones de perifericos
    BSF	    GIE		    ; Habilitamos interrupciones
    BSF	    RBIE	    ; Habilitamos interrupciones en puerto B
    BCF	    RBIF            ; Limpiamos bandera de PORTB
    BSF	    T0IE	    ; Habilitamos interrupcion TMR0
    BCF	    T0IF	    ; Limpiamos bandera de TMR0
    BCF	    TMR1IF	    ; Limpiamos bandera de TMR1
    BCF     TMR2IF	    ; Limpiamos bandera de TMR2
    RETURN
    
CONFIG_IOC:
    BANKSEL TRISA
    BSF	    IOCB, 0
    BSF	    IOCB, 1
    BSF	    IOCB, 2
    BSF	    IOCB, 3
    BSF	    IOCB, BMODO
    BANKSEL PORTA
    MOVF    PORTB, W
    BCF	    RBIF
    RETURN
    ;------- DISPLAYS ----------
OBTENER_NIBBLE:
    //SEGUNDO DISPLAY
    MOVLW   0xF		        ;    Valor = 1101 0101
    ANDWF   valor2, W		;	 AND 0000 1111
    MOVWF   nibbles		;	     0000 0101	
				; Obtenemos nibble alto
    //PRIMER DISPLAY
    MOVLW   0xF		        ;     Valor = 1101 0101
    ANDWF   valor1, W		;	  AND 1111 0000
    MOVWF   nibbles+1		;	      1101 0000
    	
    
    //ULTIMO DISPLAY
    MOVLW   0xF		        ;    Valor = 1101 0101
    ANDWF   valor4, W		;	 AND 0000 1111
    MOVWF   nibbles2		;	     0000 0101	
    //PENULTIMO DISPLAY
				; Obtenemos nibble alto
    MOVLW   0xF		        ;     Valor = 1101 0101
    ANDWF   valor3, W		;	  AND 1111 0000
    MOVWF   nibbles2+1		;	      1101 0000
    RETURN
    
SET_DISPLAY:
    MOVF    nibbles, W		; Movemos nibble bajo a W
    CALL    TABLA_7SEG		; Buscamos valor a cargar en PORT
    MOVWF   display+1		; Guardamos en display
    
    MOVF    nibbles+1, W	; Movemos nibble alto a W
    CALL    TABLA_7SEG		; Buscamos valor a cargar en PORTC
    MOVWF   display		; Guardamos en display+1
    
    MOVF    nibbles2, W		; Movemos nibble bajo a W
    CALL    TABLA_7SEG		; Buscamos valor a cargar en PORT
    MOVWF   display+3		; Guardamos en display
    
    MOVF    nibbles2+1, W	; Movemos nibble alto a W
    CALL    TABLA_7SEG		; Buscamos valor a cargar en PORTC
    MOVWF   display+2		; Guardamos en display+1
    RETURN
    
MOSTRAR_VALOR:
    CLRF    PORTC
    BCF	    PORTD, 0		
    BCF	    PORTD, 1		
    BCF	    PORTD, 2		
    BCF	    PORTD, 3
    BTFSC   banderasAB, 0		; Verificamos bandera
    GOTO    SEG_A
    GOTO    SEG_B
    
SEG_A:
    BTFSC   banderasA, 0
    GOTO DISPLAY_0
    GOTO DISPLAY_1
    
    
    DISPLAY_0:			
	MOVF    display, W	; Movemos display a W
	MOVWF   PORTC		; Movemos Valor de tabla a PORTC
	BSF	PORTD, 0	; Encendemos display de nibble bajo
	BCF	banderasA, 0	; Cambiamos bandera para cambiar el otro display en la siguiente interrupción
	BCF     banderasAB, 0
    RETURN

    DISPLAY_1:
	MOVF    display+1, W	; Movemos display+1 a W
	MOVWF   PORTC		; Movemos Valor de tabla a PORTC
	BSF	PORTD, 1	; Encendemos display de nibble alto
	BSF	banderasA, 0	; Cambiamos bandera para cambiar el otro display en la siguiente interrupción
	
    RETURN
SEG_B:
    BTFSC   banderasB, 0
    GOTO DISPLAY_2
    GOTO DISPLAY_3
    
    DISPLAY_2:			
	MOVF    display+2, W	; Movemos display a W
	MOVWF   PORTC		; Movemos Valor de tabla a PORTC
	BSF	PORTD, 2	; Encendemos display de nibble bajo
	BCF	banderasB, 0	; Cambiamos bandera para cambiar el otro display en la siguiente interrupción
	BSF     banderasAB, 0
    RETURN

    DISPLAY_3:
	MOVF    display+3, W	; Movemos display+1 a W
	MOVWF   PORTC		; Movemos Valor de tabla a PORTC
	BSF	PORTD, 3	; Encendemos display de nibble alto
	BSF	banderasB, 0	; Cambiamos bandera para cambiar el otro display en la siguiente interrupción
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