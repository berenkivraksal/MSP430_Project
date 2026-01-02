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
; MSP430 Simon Game - Full Fixed Version
;-------------------------------------------------------------------------------

    .data
pattern: .byte 0,0,0,0,0,0,0,0      ; 8 pattern capacity
level_count: .byte 4               ; Levels
level_lengths: .byte 2,4,6,8       ; Lengths
level_speeds: .byte 30,20,15,10   ; Speeds (Easy=30, Medium=20, Hard=15, Nightmare=10)
current_level: .byte 1
current_len: .byte 0
index: .byte 0
start_flag: .byte 1
random_seed: .word 0            ; LCG seed storage

    .text

; Pin Definitions
; P1.1 (Yel LED), P1.2 (Grn LED), P1.4 (Red LED), P1.5 (Blu LED)
; P2.1 (Yel Btn), P2.2 (Grn Btn), P2.4 (Red Btn), P2.5 (Blu Btn)
; P2.6 (Win LED), P1.0 (MCU Green - gers swap), P1.6 (MCU Red - gers swap)

; Register Usage:
; r4-r6   : Delay counters and temporary values
; r7-r9   : Easter Egg state tracking
; r10     : Current button pressed (BIT mask)
; r11-r15 : Pattern generation and game logic

    mov.w   #0x280, SP      ; Stack Pointer
    mov.w   #WDTPW+WDTHOLD, &WDTCTL ; Stop Watchdog

    bic.b #01110111b, &P1SEL
    bic.b #01110111b, &P1SEL2
    bic.b #01110110b, &P2SEL
    bic.b #01110110b, &P2SEL2

    bis.b #01110111b, &P1DIR    ; LEDs Output
    bis.b #01000000b, &P2DIR    ; Win LED Output
    bic.b #00110110b, &P2DIR    ; Buttons Input

    bis.b #00110110b, &P2REN    ; Enable Resistors
    bis.b #00110110b, &P2OUT    ; Pull-up (1=Not Pressed)

    bic.b #BIT6, &P2OUT ; Win LED Off
    bic.b #01110111b, &P1OUT ; Game LEDs Off
    bic.b #BIT0, &P1OUT ; MCU Red Off
    bic.b #BIT6, &P1OUT ; MCU Green Off

    call #TimerA_Init

INIT_IDLE:
    mov.w   #0x280, SP
    mov.w #0, r7            ; EE varsayılanlar
    mov.w #0, r8
    mov.w #0, r9
    mov.w #0, r10           ; Buton tracker (yeni eklendi)
    jmp  IDLE

; --- IDLE STATE ---
; Sırayla yanar, Yeşil butona (P2.2) basılınca START'a gider.
IDLE:
    bis.b #BIT1, &P1OUT       ; Yellow ON
    bic.b #00110100b, &P1OUT
    mov.w #2, r4              ; Dengeli animasyon hızı
    call #Delay_With_Button_Check
    bic.b #01110111b, &P1OUT  ; OFF
    call #Pull_Buttons_for_Easter_Egg  ; Her LED'den sonra kontrol

    bis.b #BIT2, &P1OUT       ; Green ON
    bic.b #00110010b, &P1OUT
    mov.w #2, r4              ; Dengeli animasyon hızı
    call #Delay_With_Button_Check
    bic.b #01110111b, &P1OUT
    call #Pull_Buttons_for_Easter_Egg  ; Her LED'den sonra kontrol

    bis.b #BIT4, &P1OUT       ; Red ON
    bic.b #00100110b, &P1OUT
    mov.w #2, r4              ; Dengeli animasyon hızı
    call #Delay_With_Button_Check
    bic.b #01110111b, &P1OUT
    call #Pull_Buttons_for_Easter_Egg  ; Her LED'den sonra kontrol

    bis.b #BIT5, &P1OUT       ; Blue ON
    bic.b #00010110b, &P1OUT
    mov.w #2, r4              ; Dengeli animasyon hızı
    call #Delay_With_Button_Check
    bic.b #01110111b, &P1OUT
    call #Pull_Buttons_for_Easter_Egg  ; Her LED'den sonra kontrol

    call #Pull_Buttons_for_Easter_Egg  ; Son bir kontrol daha
    jmp IDLE

Delay_With_Button_Check:
Delay_Outer:
    mov.w #0x2000, r5         ; Optimized: Hızlı ama görünür delay
Delay_Inner:
    bit.b #BIT2, &P2IN        ; Yeşil Buton basıldı mı?
    jeq get_timer             ; Evetse oyuna git
    dec.w r5
    jne Delay_Inner
    dec.w r4
    jne Delay_Outer
    ret

; --- MAIN DELAY FUNCTION ---
; Tüm zamanlamalar buna bağlıdır.
Delay:
    mov.w #0x2000, r5         ; Optimized: Oynanabilir hız için ayarlandı
Dloop:
    dec.w r5
    jne Dloop
    dec.w r4
    jne Delay
    ret

TimerA_Init:
    mov.w   #TASSEL_2+MC_2, &TACTL
    ret

get_timer:
    bic.b   #01110111b, &P1OUT  ; Tüm LED'leri söndür
    mov.w   &TAR, r12
    mov.w   r12, &random_seed   ; TAR'ı seed olarak kaydet

    ; Easter Egg registerlarını temizle (oyun başlarken)
    mov.w   #0, r7
    mov.w   #0, r8
    mov.w   #0, r9

wait_release:
    bit.b   #BIT2, &P2IN      ; Butonu bırakmasını bekle
    jeq      wait_release
    mov.w   #5, r4            ; Debounce için bekle
    call    #Delay
    jmp START

; --- GENERATE PATTERN ---
; Memory game mantığı: Her seviyede sadece YENİ elemanlar eklenir!
generatePattern:
    mov.b &current_level, r11
    cmp.b #1, r11
    jeq set_l1
    cmp.b #2, r11
    jeq set_l2
    cmp.b #3, r11
    jeq set_l3
    ; Level 4 (Nightmare)
    mov.b #6, r12           ; Önceki uzunluk (Level 3'ten)
    mov.b #8, &current_len  ; Yeni toplam uzunluk
    jmp gp_start

set_l1:
    mov.b #0, r12           ; Baştan başla
    mov.b #2, &current_len  ; 2 eleman
    jmp gp_start
set_l2:
    mov.b #2, r12           ; Level 1'den devam (2 eleman zaten var)
    mov.b #4, &current_len  ; Toplam 4 eleman
    jmp gp_start
set_l3:
    mov.b #4, r12           ; Level 2'den devam (4 eleman var)
    mov.b #6, &current_len  ; Toplam 6 eleman

gp_start:
    ; r12 = başlangıç indeksi (önceki pattern uzunluğu)
    ; current_len = hedef uzunluk
    mov.w #pattern, r14
    add.w r12, r14          ; Önceki pattern'in sonundan başla

gen_loop:
    ; Xorshift RNG - Basit ve HIZLI! (Nightmare için kritik)
    ; seed ^= seed << 7;  seed ^= seed >> 9;  seed ^= seed << 8

    mov.w &random_seed, r13     ; Mevcut seed (1 instruction)

    ; seed ^= seed << 7  (9 instructions)
    mov.w r13, r15
    rla.w r15
    rla.w r15
    rla.w r15
    rla.w r15
    rla.w r15
    rla.w r15
    rla.w r15
    xor.w r15, r13

    ; seed ^= seed >> 9  (11 instructions)
    mov.w r13, r15
    clrc
    rrc.w r15
    rrc.w r15
    rrc.w r15
    rrc.w r15
    rrc.w r15
    rrc.w r15
    rrc.w r15
    rrc.w r15
    rrc.w r15
    xor.w r15, r13

    ; seed ^= seed << 8  (2 instructions - byte swap trick!)
    mov.w r13, r15
    swpb r15
    xor.w r15, r13

    mov.w r13, &random_seed     ; Yeni seed'i kaydet (1 instruction)

    ; 0-3 arası değer al (1 instruction)
    and.w #0x0003, r13

    mov.b r13, 0(r14)           ; Pattern'e yaz
    inc.w r14
    inc.b r12
    cmp.b r12, &current_len
    jne gen_loop
    ret

; --- PLAY PATTERN ---
Play_Pattern:
    clr.b   r12

pp_loop:
    mov.w   #pattern, r14
    add.w   r12, r14
    mov.b   @r14, r13
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
    bis.b #BIT1, &P1OUT
    bic.b #00110100b, &P1OUT
    jmp pp_show

pp_green:
    bis.b #BIT2, &P1OUT
    bic.b #00110010b, &P1OUT
    jmp pp_show

pp_red:
    bis.b #BIT4, &P1OUT
    bic.b #00100110b, &P1OUT
    jmp pp_show

pp_blue:
    bis.b #BIT5, &P1OUT
    bic.b #00010110b, &P1OUT
    jmp pp_show

pp_show:
    ; Level speed hesaplama (KRİTİK FIX: word arithmetic!)
    mov.w   #level_speeds, r14
    mov.b   &current_level, r15
    dec.b   r15                  ; Level 1->0, 2->1, 3->2, 4->3
    clr.w   r6
    ; KRİTİK: add.w kullan, add.b DEĞİL! (Pointer arithmetic)
    add.w   r15, r14             ; WORD pointer arithmetic ✅
    mov.b   @r14, r6             ; Speed değerini r6'ya al
    mov.w   r6, r4               ; r4'e kopyala (Delay için)
    call #Delay                  ; LED Yanık Kalıyor
    bic.b #01110111b, &P1OUT     ; LED Sönüyor
    mov.w #1, r4                 ; LED'ler arası bekleme
    call #Delay

pp_next:
    inc.b r12
    cmp.b r12, &current_len
    jne pp_loop
    ret

; --- GET PLAYER INPUT ---
Get_Player_Input:
    clr.b r12

    ; Butonların serbest olduğundan emin ol
gpi_wait_all_released:
    mov.b &P2IN, r13
    and.b #00110110b, r13
    cmp.b #00110110b, r13
    jne gpi_wait_all_released

    mov.w #2, r4
    call #Delay

gpi_loop:
    bit.b #BIT1, &P2IN
    jeq gpi_yellow
    bit.b #BIT2, &P2IN
    jeq gpi_green
    bit.b #BIT4, &P2IN
    jeq gpi_red
    bit.b #BIT5, &P2IN
    jeq gpi_blue
    jmp gpi_loop

gpi_yellow:
    mov.b #0, r13
    mov.b #BIT1, r10         ; Hangi buton basıldı (r10'a kaydet)
    bis.b #BIT1, &P1OUT      ; LED YANSIN
    mov.w #1, r4             ; Debounce
    call  #Delay
    jmp gpi_wait_release

gpi_green:
    mov.b #1, r13
    mov.b #BIT2, r10         ; Hangi buton basıldı
    bis.b #BIT2, &P1OUT      ; LED YANSIN
    mov.w #1, r4
    call  #Delay
    jmp gpi_wait_release

gpi_red:
    mov.b #2, r13
    mov.b #BIT4, r10         ; Hangi buton basıldı
    bis.b #BIT4, &P1OUT      ; LED YANSIN
    mov.w #1, r4
    call  #Delay
    jmp gpi_wait_release

gpi_blue:
    mov.b #3, r13
    mov.b #BIT5, r10         ; Hangi buton basıldı
    bis.b #BIT5, &P1OUT      ; LED YANSIN
    mov.w #1, r4
    call  #Delay

gpi_wait_release:
    ; SADECE basılan butonu bekle (r10'da kayıtlı)
    bit.b r10, &P2IN
    jeq gpi_wait_release

gpi_release_done:
    bic.b #01110111b, &P1OUT ; DÜZELTME: Elini çekince LED SÖNSÜN
    mov.w #1, r4
    call #Delay

    ; Pattern Karşılaştırma
    mov.w #pattern, r14
    add.w r12, r14
    mov.b @r14, r15
    cmp.b r13, r15
    jne gpi_wrong
    jmp gpi_ok

gpi_wrong:
    call #Failure_Handler ; Asla geri dönmez, INIT_IDLE'a gider

gpi_ok:
    inc.b r12
    cmp.b r12, &current_len
    jne gpi_loop

    call #Success_Handler ; Seviye bitti
    ret

; --- HANDLERS ---
Success_Handler:
    bic.b #BIT6, &P1OUT     ; Red LED OFF (diğerini söndür)
    bis.b #BIT0, &P1OUT     ; Green ON (breadboard config)
    mov.w #3, r4
    call #Delay
    bic.b #BIT0, &P1OUT     ; Green OFF
    ret

Failure_Handler:
    bic.b #BIT0, &P1OUT     ; Green LED OFF (diğerini söndür)
    bis.b #BIT6, &P1OUT     ; Red ON (breadboard config)
    mov.w #5, r4
    call #Delay

    ; Yanıp sönme efekti (TAM 2 saniye!)
    ; 8 döngü × (3+3) = 48 delay units ≈ 2 saniye
    ; Sadece GAME LED'leri yanıp söner, MCU LED'leri dokunmaz!
    mov.w #8, r13           ; 8 blink döngüsü
fh_loop:
    bis.b #00110110b, &P1OUT ; Sadece Game LED'leri (Yellow,Green,Red,Blue)
    mov.w #3, r4
    call #Delay
    bic.b #00110110b, &P1OUT ; Sadece Game LED'leri söndür
    mov.w #3, r4
    call #Delay
    dec.w r13
    jne fh_loop

    bic.b #BIT6, &P1OUT      ; Red OFF
    jmp INIT_IDLE            ; Başa dön

; --- LEVELS ---
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

; --- EASTER EGG (Değişmedi) ---
Pull_Buttons_for_Easter_Egg:
    bit.b   #BIT1, &P2IN
    jeq      ee_yellow
    bit.b   #BIT2, &P2IN
    jeq      ee_green
    bit.b   #BIT4, &P2IN
    jeq      ee_red
    bit.b   #BIT5, &P2IN
    jeq      ee_blue
    ret

ee_yellow:
    mov.w #0, r9
    call #Check_Easter_Egg
ee_yellow_wait:
    bit.b #BIT1, &P2IN
    jeq    ee_yellow_wait
    ret

ee_green:
    mov.w #1, r9
    call #Check_Easter_Egg
ee_green_wait:
    bit.b #BIT2, &P2IN
    jeq    ee_green_wait
    ret

ee_red:
    mov.w #2, r9
    call #Check_Easter_Egg
ee_red_wait:
    bit.b #BIT4, &P2IN
    jeq    ee_red_wait
    ret

ee_blue:
    mov.w #3, r9
    call #Check_Easter_Egg
ee_blue_wait:
    bit.b #BIT5, &P2IN
    jeq    ee_blue_wait
    ret

Check_Easter_Egg:
    ; Basitleştirilmiş Easter Egg: Sadece Red-Red (Kırmızı 2×)
    ; r8 = kaç kere Red basıldı
    ; r9 = basılan renk (2=red)

    cmp.w #2, r9                ; Red mi basıldı?
    jne ee_reset                ; Değilse sıfırla

    inc.w r8                    ; Red sayacını artır
    cmp.w #2, r8                ; 2 kere Red basıldı mı?
    jne ee_return               ; Henüz değil, bekle

    ; BAŞARILI! Easter Egg göster
    jmp Easter_Egg_Sequence

ee_return:
    ret
ee_reset:
    mov.w #0, r7
    mov.w #0, r8
    ret

Easter_Egg_Sequence:
    ; Sequence: Blue → Red → Green → Yellow → All Off → All On → Off
    bic.b #01110111b, &P1OUT    ; Tümünü söndür

    ; Blue yanar
    bis.b #BIT5, &P1OUT
    mov.w #25, r4               ; Daha uzun süre
    call #Delay
    bic.b #BIT5, &P1OUT

    ; Red yanar
    bis.b #BIT4, &P1OUT
    mov.w #25, r4               ; Daha uzun süre
    call #Delay
    bic.b #BIT4, &P1OUT

    ; Green yanar
    bis.b #BIT2, &P1OUT
    mov.w #25, r4               ; Daha uzun süre
    call #Delay
    bic.b #BIT2, &P1OUT

    ; Yellow yanar
    bis.b #BIT1, &P1OUT
    mov.w #25, r4               ; Daha uzun süre
    call #Delay
    bic.b #BIT1, &P1OUT

    ; Tümü söner (zaten sönük)
    mov.w #10, r4
    call #Delay

    ; Tümü yanar - UZUN SÜRE!
    bis.b #01110110b, &P1OUT    ; Dört LED yanar (Yellow,Green,Red,Blue)
    mov.w #30, r4               ; Çok uzun süre (finalde!)
    call #Delay

    ; Tümü söner
    bic.b #01110110b, &P1OUT
    mov.w #10, r4
    call #Delay

    ; Reset ve IDLE'a dön
    mov.w #0, r7
    mov.w #0, r8
    jmp INIT_IDLE            ; IDLE'a geri dön ✅

; --- MAIN GAME LOOP ---
START:
    bic.b #BIT6, &P2OUT    ; Win LED Off
    bic.b #01110111b, &P1OUT ; All Off
    mov.w #10, r4          ; Başlamadan önce bekleme (Artırıldı)
    call #Delay

    ; --- EASY ---
    call #Easy_Level
    mov.w #80, r4          ; 2 saniye level arası bekleme (artırıldı)
    call #Delay

    ; --- MEDIUM ---
    call #Medium_Level
    mov.w #80, r4          ; 2 saniye level arası bekleme
    call #Delay

    ; --- HARD ---
    call #Hard_Level
    mov.w #80, r4          ; 2 saniye level arası bekleme
    call #Delay

    ; --- NIGHTMARE ---
    call #Nightmare_Level
    mov.w #80, r4          ; 2 saniye final bekleme
    call #Delay

    jmp WIN_LED

WIN_LED:
    bis.b #BIT6, &P2OUT ; Win LED On
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