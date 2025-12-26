;-------------------------------------------------------------------------------
; MSP430 Assembler Code Template for use with TI Code Composer Studio
;
;
;-------------------------------------------------------------------------------
            .cdecls C,LIST,"msp430.h"       ; Include device header file
            
;-------------------------------------------------------------------------------
            .def    RESET                   ; Export program entry-point to
                                            ; make it known to linker.
;-------------------------------------------------------------------------------
            .text                           ; Assemble into program memory.
            .retain                         ; Override ELF conditional linking
                                            ; and retain current section.
            .retainrefs                     ; And retain any sections that have
                                            ; references to current section.

;-------------------------------------------------------------------------------
RESET       mov.w   #__STACK_END,SP         ; Initialize stackpointer
StopWDT     mov.w   #WDTPW|WDTHOLD,&WDTCTL  ; Stop watchdog timer


;-------------------------------------------------------------------------------
; Main loop here
;-------------------------------------------------------------------------------

; Yellow Led -> P1.1        Yellow Button -> P2.1
; Green Led -> P1.2         Green Button -> P2.2 
; Red Led -> P1.4           Red Button -> P2.4
; Blue Led -> P1.5          Blue Button -> P2.5

    bic.b #00110110b, &P1SEL    ;Let's reset everything.
    bic.b #00110110b, &P1SEL2   ;Let's reset everything.

    bic.b #00110110b, &P2SEL    ;Let's reset everything.
    bic.b #00110110b, &P2SEL2   ;Let's reset everything.

    bis.b #00110110b, &P1DIR    ;I'm specifying 4 LEDs as outputs.
    bic.b #00110110b, &P2DIR    ;I'm designating 4 buttons as input.

    bis.b #00110110b, &P2REN    ;I'm opening the button resistor because I'm going to operate the button.
    bis.b #00110110b, &P2OUT    ;1 when no button is pressed. 0 when button is pressed.

;-------------------------------------------------------------------------------
; Stack Pointer definition
;-------------------------------------------------------------------------------
            .global __STACK_END
            .sect   .stack
            
;-------------------------------------------------------------------------------
; Interrupt Vectors
;-------------------------------------------------------------------------------
            .sect   ".reset"                ; MSP430 RESET Vector
            .short  RESET
            