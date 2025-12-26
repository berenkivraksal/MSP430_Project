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


    .data
pattern: .byte 0,0,0,0,0,0,0,0; 8 pattern capacity
level_count:   .byte 0                ; 
index:       .byte 0                ; 


    .text
          
; Yellow Led -> P1.1        Yellow Button -> P2.1
; Green Led -> P1.2         Green Button -> P2.2 
; Red Led -> P1.4           Red Button -> P2.4
; Blue Led -> P1.5          Blue Button -> P2.5
; Win Led -> P2.6


    mov.w   #0x280, SP      ; Stack Pointer (MSP430G2553 RAM last )
    mov.w   #WDTPW+WDTHOLD, &WDTCTL ; stop the Watchdog 


    bic.b #01110111b, &P1SEL    ;Let's reset everything.
    bic.b #01110111b, &P1SEL2   ;Let's reset everything.

    bic.b #01110110b, &P2SEL    ;Let's reset everything.
    bic.b #01110110b, &P2SEL2   ;Let's reset everything.

    bis.b #01110111b, &P1DIR    ;I'm specifying 4 LEDs as outputs. And also the microprocessor's red and green leds as output.
    bis.b #01000000b, &P2DIR    ;I'm designating the Win Led as output.
    bic.b #00110110b, &P2DIR    ;I'm designating 4 buttons as input.

    bis.b #00110110b, &P2REN    ;I'm opening the button resistor because I'm going to operate the button.
    bis.b #00110110b, &P2OUT    ;1 when no button is pressed. 0 when button is pressed.

INIT_IDLE:
    mov.w #2, r6

IDLE:
    call #Yellow
    call #Delay
    call #Check_Start_Button
    cmp.w #0, r6
    jeq START

    call #Green
    call #Delay
    call #Check_Start_Button
    cmp.w #0, r6
    jeq START

    call #Red
    call #Delay
    call #Check_Start_Button
    cmp.w #0, r6
    jeq START

    call #Blue
    call #Delay
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

; --- start the game with pushing the yellow light button twice---
check_start:
            ; Is yellow button (P2.1) has been pressed?
            bit.b   #BIT1, &P2IN    ; BIT1 corresponds to P2.1 (Yellow Button)
            jnz     IDLE            ; If not pressed  stay in Idle mode

            ; --- Capture first random step on first press ---
            mov.w   &TAR, R12       ; stop the  timer for the 1st random step
            and.w   #0x003, R12     ; change the bits to get a value between 0 and 3
            mov.b   R12, &pattern   ; Store the first step in RAM


; ---  first press and wait for release ---
wait_release:
            ; Wait until the user releases the button to avoid "long press" false triggers
            bit.b   #BIT1, &P2IN    
            jz      wait_release    ; Stay here while button is still held down
            
            call    #DELAY_50MS     ; Small delay to eliminate mechanical switch bouncing

; --- Wait for the second press  ---
wait_second:
            mov.w   #0xFFFF, R10    ; Load a large value into R10 as a timeout counter
wait_second_inner:                        
             bit.b   #BIT1, &P2IN    ; Check for the second press on P2.1
            jz      second_press_ok ; If pressed get the second value
            dec.w   R10             ; Decrease the timeout counter
            jnz     wait_second_inner     ; Continue decrease the time until counter becomes zero
            jmp     IDLE            ; Time has finished without second press, return to Idle

second_press_ok:
            ; --- Capture second random step on second press ---
            mov.w   &TAR, R12       ; Capture Timer for the 2nd random step
            and.w   #0x003, R12     ; change the bits to get a value between 0 and 3
            mov.b   R12, &pattern+1 ; Store the second step in RAM
       
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

START:
    bic.b #01000000b, &P2OUT    ;Win Led off
    call #Easy_Level
    bic.b #00110110b, &P1OUT ;All off
    mov.b #6, r4    ;2 second delay between levels
    call #Delay
    call #Medium_Level
    bic.b #00110110b, &P1OUT ;All off
    mov.b #6, r4    ;2 second delay between levels
    call #Delay
    call #Hard_Level
    bic.b #00110110b, &P1OUT ;All off
    mov.b #6, r4    ;2 second delay between levels
    call #Delay
    call #Nightmare_Level
    bic.b #00110110b, &P1OUT ;All off
    mov.b #6, r4    ;2 second delay between levels
    call #Delay
    jmp WIN_LED

WIN_LED:
    bis.b #BIT6, &P2OUT ;Win Led on
    jmp INIT_IDLE

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
            