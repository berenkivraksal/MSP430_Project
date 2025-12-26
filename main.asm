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
; Win Led -> P2.6

    bic.b #00110110b, &P1SEL    ;Let's reset everything.
    bic.b #00110110b, &P1SEL2   ;Let's reset everything.

    bic.b #01110110b, &P2SEL    ;Let's reset everything.
    bic.b #01110110b, &P2SEL2   ;Let's reset everything.

    bis.b #00110110b, &P1DIR    ;I'm specifying 4 LEDs as outputs.
    bic.b #00110110b, &P2DIR    ;I'm designating 4 buttons as input.
    bis.b #01000000b, &P2DIR    ;I'm specifying Win LED as output.

    bis.b #00110110b, &P2REN    ;I'm opening the button resistor because I'm going to operate the button.
    bis.b #00110110b, &P2OUT    ;1 when no button is pressed. 0 when button is pressed.

INIT_IDLE:
    mov.w #2, r6

IDLE:
    call #Yellow
    call #Check_Start_Button
    cmp.w #0, r6
    jeq START

    call #Green
    call #Check_Start_Button
    cmp.w #0, r6
    jeq START

    call #Red
    call #Check_Start_Button
    cmp.w #0, r6
    jeq START

    call #Blue
    call #Check_Start_Button
    cmp.w #0, r6
    jeq START

    jmp IDLE

Check_Start_Button:
    bit.b #00000010b, &P2IN     ;Checking if the yellow button is pressed.
                                ;If pressed &P2IN = BIT1 = 0, Z=1 -> jeq ise r6--
    jeq Decrease_Start_Counter
    ret

Decrease_Start_Counter:
    dec.w r6
    ret

Yellow:
    bis.b #BIT1, &P1OUT
    bic.b #00110100b, &P1OUT
    mov.w #3, r4    ;I'm assigning a value of 3 to r4 to keep the yellow light on for 1 seconds.
    ret

Green:
    bis.b #BIT2, &P1OUT
    bic.b #00110010b, &P1OUT
    mov.w #3, r4    ;I'm assigning a value of 3 to r4 to keep the green light on for 1 seconds.
    ret

Red:
    bis.b #BIT4, &P1OUT
    bic.b #00100110b, &P1OUT
    mov.w #3, r4    ;I'm assigning a value of 3 to r4 to keep the red light on for 1 seconds.
    ret

Blue:
    bis.b #BIT5, &P1OUT
    bic.b #00010110b, &P1OUT
    mov.w #3, r4    ;I'm assigning a value of 3 to r4 to keep the blue light on for 1 seconds.
    ret

Delay:
    mov.w #0xFFFF, r5   ;At first we wanted to do r5 as larger as we can.
Dloop:
    dec.w r5
    jne Dloop
    dec.w r4
    jne Delay
    ret

Easter_Egg_Sequence:
    bis.b #BIT1, &P1OUT    ;Yellow on
    bic.b #00110100b, &P1OUT
    mov.w #3, r4
    call #Delay
    bis.b #BIT2, &P1OUT    ;Yellow on, Green on
    bic.b #00110000b, &P1OUT
    mov.w #3, r4
    call #Delay
    bis.b #BIT4, &P1OUT    ;Yellow on, Green on, Red on
    bic.b #00100000b, &P1OUT
    mov.w #3, r4
    call #Delay
    bis.b #BIT5, &P1OUT    ;All on
    mov.w #6, r4
    call #Delay
    bic.b #00110110b, &P1OUT ;All off
    ret

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
            