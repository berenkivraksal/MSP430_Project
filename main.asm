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
            call    #TimerA_Init                 ; start Timer A for simple RNG use


;-------------------------------------------------------------------------------
; Main loop here
;-------------------------------------------------------------------------------


    .data
pattern: .byte 0,0,0,0,0,0,0,0      ; 8 pattern capacity
level_count: .byte 4               ; Number of levels (Easy, Medium, Hard, Nightmare)
level_lengths: .byte 2,4,6,8       ; Level lengths for levels 1..4 respectively
level_speeds: .byte 3,2,1,1        ; On-time speed per level (Easy -> Nightmare)
current_level: .byte 1             ; Current level (1-based)
current_len: .byte 0               ; Computed length for current level
index: .byte 0                     ; Pattern index (used while generating/playing patterns)
level_result: .byte 0              ; Result from last level (1=pass,0=fail)
start_flag: .byte 1                ; Helper flag for start (student-style)


    .text
          
; Yellow Led -> P1.1        Yellow Button -> P2.1
; Green Led -> P1.2         Green Button -> P2.2 
; Red Led -> P1.4           Red Button -> P2.4
; Blue Led -> P1.5          Blue Button -> P2.5
; Win Led -> P2.6
; Red Led on the microprocessor -> P1.0
; Green Led on the microprocessor -> P1.6

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


;In IDLE state, the lights will turn on one by one in a loop, and if the yellow button is pressed twice, the game will start.
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

;We turn on the yellow light for 1 second.
Yellow:
    bis.b #BIT1, &P1OUT
    bic.b #00110100b, &P1OUT
    mov.w #3, r4    ;I'm assigning a value of 3 to r4 to keep the yellow light on for 1 seconds.
    ret

;We turn on the green light for 1 second.
Green:
    bis.b #BIT2, &P1OUT
    bic.b #00110010b, &P1OUT
    mov.w #3, r4    ;I'm assigning a value of 3 to r4 to keep the green light on for 1 seconds.
    ret

;We turn on the red light for 1 second.
Red:
    bis.b #BIT4, &P1OUT
    bic.b #00100110b, &P1OUT
    mov.w #3, r4    ;I'm assigning a value of 3 to r4 to keep the red light on for 1 seconds.
    ret

;We turn on the blue light for 1 second.
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

DELAY_50MS:               ; ~ small debounce delay (student-style loop)
    mov.w #0x0C35, r5     ; small count ~50ms-ish depending on clock
D50loop:
    dec.w r5
    jne D50loop
    ret

TimerA_Init:
    mov.w   #TASSEL_2+MC_2, &TACTL   ; SMCLK, continuous mode
    ret

; --- start the game with pushing the yellow light button twice---
Check_Start_Button:
check_start:
            ; Is yellow button (P2.1) has been pressed?
            bit.b   #BIT1, &P2IN    ; BIT1 corresponds to P2.1 (Yellow Button)
            jnz     IDLE            ; If not pressed  stay in Idle mode

get_timer:
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
            mov.w   #0, r6          ; signal start to the IDLE loop (r6==0 -> START)
            mov.b   #0, &level_result ; clear previous level result
            ret

generatePattern:    ; compute current_len from current_level (1..4)
    mov.b   &current_level, r11
    cmp.b   #1, r11
    jeq     set_l1
    cmp.b   #2, r11
    jeq     set_l2
    cmp.b   #3, r11
    jeq     set_l3
    mov.b   #8, &current_len
    jmp     gp_continue

set_l1: mov.b #2, &current_len; jmp gp_continue
set_l2: mov.b #4, &current_len; jmp gp_continue
set_l3: mov.b #6, &current_len

gp_continue:
    clr.b   r12       ; index=0
    
gen_loop:
    mov.w   &TAR, r13
    and.w   #0x0003, r13
    mov.w   #pattern, r14
    add.w   r12, r14
    mov.b   r13, @r14
    inc.b   r12
    cmp.b   r12, &current_len
    jne gen_loop
    ret

; -----------------------------------------------------------------------------
; Play pattern and player input routines (student-style, small and clear)
; -----------------------------------------------------------------------------
Play_Pattern:
    clr.b   r12              ; index = 0

pp_loop:
    mov.w   #pattern, r14
    add.w   r12, r14
    mov.b   @r14, r13        ; r13 = color (0..3)
    cmp.b   #0, r13
    jeq pp_yellow
    cmp.b   #1, r13
    jeq pp_green
    cmp.b   #2, r13
    jeq pp_red
    cmp.b   #3, r13
    jeq pp_blue
    jmp pp_next

pp_yellow:
    call #Yellow
    jmp pp_show
    
pp_green:
    call #Green
    jmp pp_show

pp_red:
    call #Red
    jmp pp_show

pp_blue:
    call #Blue

pp_show:
    ; set per-level on-time from level_speeds[current_level-1]
    mov.w   #level_speeds, r14
    mov.b   &current_level, r15
    dec.b   r15
    add.b   r15, r14
    mov.b   @r14, r12         ; r12 = speed byte
    mov.w   r12, r4           ; r4 <- on-time for Delay
    call #Delay
    bic.b #01110111b, &P1OUT    ; turn off game leds
    mov.w #2, r4
    call #Delay

pp_next:
    inc.b r12
    cmp.b r12, &current_len
    jne pp_loop
    ret

Get_Player_Input:
    clr.b r12                ; index = 0
    mov.b #0, &level_result  ; assume fail until success
gpi_loop:
    ; wait for a button press
    bit.b #BIT1, &P2IN
    jz gpi_yellow
    bit.b #BIT2, &P2IN
    jz gpi_green
    bit.b #BIT4, &P2IN
    jz gpi_red
    bit.b #BIT5, &P2IN
    jz gpi_blue
    jmp gpi_loop

gpi_yellow:
    mov.b #0, r13
    call #DELAY_50MS
    jmp gpi_waitrel

gpi_green:
    mov.b #1, r13
    call #DELAY_50MS
    jmp gpi_waitrel

gpi_red:
    mov.b #2, r13
    call #DELAY_50MS
    jmp gpi_waitrel

gpi_blue:
    mov.b #3, r13
    call #DELAY_50MS

gpi_waitrel:
    ; wait for release of the same button
    cmp.b #0, r13
    jeq gpi_wait_y
    cmp.b #1, r13
    jeq gpi_wait_g
    cmp.b #2, r13
    jeq gpi_wait_r
    cmp.b #3, r13
    jeq gpi_wait_b

gpi_wait_y:
    bit.b #BIT1, &P2IN
    jnz gpi_rel_done
    jmp gpi_wait_y

gpi_wait_g:
    bit.b #BIT2, &P2IN
    jnz gpi_rel_done
    jmp gpi_wait_g

gpi_wait_r:
    bit.b #BIT4, &P2IN
    jnz gpi_rel_done
    jmp gpi_wait_r

gpi_wait_b:
    bit.b #BIT5, &P2IN
    jnz gpi_rel_done
    jmp gpi_wait_b

gpi_rel_done:
    ; compare with pattern
    mov.w #pattern, r14
    add.w r12, r14
    mov.b @r14, r15        ; expected
    cmp.b r13, r15
    jeq gpi_ok
    ; wrong button -> failure
    call #Failure_Handler
    mov.b #0, &level_result
    ret

gpi_ok:
    inc.b r12
    cmp.b r12, &current_len
    jne gpi_loop
    ; all matched
    call #Success_Handler
    mov.b #1, &level_result
    ret

Success_Handler:
    bis.b #BIT6, &P1OUT     ; on-board green (short)
    mov.w #3, r4
    call #Delay
    bic.b #01000000b, &P1OUT
    ret

Failure_Handler:
    bis.b #BIT0, &P1OUT     ; on-board red on
    mov.w #3, r4
    call #Delay
    mov.w #3, r13           ; blink 3 times ~2s
fh_loop:
    bis.b #01110111b, &P1OUT
    mov.w #2, r4
    call #Delay
    bic.b #01110111b, &P1OUT
    mov.w #2, r4
    call #Delay
    dec.w r13
    jne fh_loop
    bic.b #BIT0, &P1OUT
    jmp INIT_IDLE

; Level stubs 
Easy_Level:
    mov.b #1, &current_level
    call #generatePattern
    call #Play_Pattern
    call #Get_Player_Input
    ret

Medium_Level:
    mov.b #2, &current_level
    call #generatePattern
    call #Play_Pattern
    call #Get_Player_Input
    ret

Hard_Level:
    mov.b #3, &current_level
    call #generatePattern
    call #Play_Pattern
    call #Get_Player_Input
    ret

Nightmare_Level:
    mov.b #4, &current_level
    call #generatePattern
    call #Play_Pattern
    call #Get_Player_Input
    ret

;If we find a hidden Easter egg in the game, the hidden blink pattern should activate.
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

;Let's start the game if the Yellow Led is pressed twice.
START:
    bic.b #01000000b, &P2OUT    ;Win Led off
    call #Easy_Level
    bic.b #01110111b, &P1OUT ;All off
    mov.b #6, r4    ;2 second delay between levels
    call #Delay
    call #Medium_Level
    bic.b #01110111b, &P1OUT ;All off
    mov.b #6, r4    ;2 second delay between levels
    call #Delay
    call #Hard_Level
    bic.b #01110111b, &P1OUT ;All off
    mov.b #6, r4    ;2 second delay between levels
    call #Delay
    call #Nightmare_Level
    bic.b #01110111b, &P1OUT ;All off
    mov.b #6, r4    ;2 second delay between levels
    call #Delay
    jmp WIN_LED

;If we win the game (successfully complete all levels), our Win LED will stay lit until the next game starts (until we enter START again).
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
            