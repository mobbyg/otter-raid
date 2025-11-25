	processor 6502

; ===============================================
; OTTER RAID - Full Game with Procedural River
; ===============================================

SCREEN = $0400
COLOR_RAM = $D800
VIC_SPRITE_ENABLE = $D015
VIC_SPRITE_X = $D000
VIC_SPRITE_Y = $D001
VIC_SPRITE_COLOR = $D027
VIC_BORDER = $D020
VIC_BACKGROUND = $D021
VIC_SPRITE_COLLISION = $D01E
VIC_SPRITE_BG_COLLISION = $D01F
CIA1_PORT_B = $DC01
VIC_RASTER = $D012

; Game variables
score = $FB         ; Score (2 bytes)
lives = $FD         ; Lives remaining
hit_cooldown = $FE  ; Collision cooldown timer
scroll_offset = $FA ; Scroll speed counter
left_bank = $F9     ; Left river bank position (0-39)
right_bank = $F8    ; Right river bank position (0-39)
random_seed = $F7   ; Random number seed

        org $0801

; BASIC: 10 SYS2061
        dc.b $0b,$08,$0a,$00,$9e
        dc.b "2061"
        dc.b $00,$00,$00

start:
        ; Initialize game variables
        lda #0
        sta score
        sta score+1
        sta hit_cooldown
        sta scroll_offset
        lda #3
        sta lives

        ; Initialize river banks
        lda #4
        sta left_bank
        lda #35
        sta right_bank

        ; Initialize random seed
        lda #$A5
        sta random_seed

        ; Setup colors
        lda #0
        sta VIC_BORDER
        lda #6
        sta VIC_BACKGROUND

        ; Clear screen
        lda #$20
        ldx #0
clr:    
        sta SCREEN,x
        sta SCREEN+$100,x
        sta SCREEN+$200,x
        sta SCREEN+$2e8,x
        inx
        bne clr

        ; Draw initial river FIRST (rows 3-24)
        ldx #3
init_river:
        stx $02
        jsr draw_river_row
        jsr adjust_banks
        ldx $02
        inx
        cpx #25
        bne init_river

        ; NOW draw UI on top (will never be touched by scrolling)
        ; Display title (row 0, centered at column 15)
        ldx #0
title:  
        lda txt_title,x
        beq show_score
        sta SCREEN+15,x
        lda #5
        sta COLOR_RAM+15,x
        inx
        jmp title

show_score:
        ; Display "SCORE:" at row 1, column 0
        ldx #0
score_loop:
        lda txt_score,x
        beq show_lives
        sta SCREEN,x
        lda #1
        sta COLOR_RAM,x
        inx
        cpx #6
        bne score_loop

show_lives:
        ; Display "LIVES:" at row 1, column 32
        ldx #0
lives_loop:
        lda txt_lives,x
        beq setup_sprites
        sta SCREEN+32,x
        lda #1
        sta COLOR_RAM+32,x
        inx
        cpx #6
        bne lives_loop

setup_sprites:
        ; Update score and lives displays
        jsr update_score
        jsr update_lives

        ; Copy sprite data
        ldx #0
cpy:    
        lda spr_otter,x
        sta $0340,x
        lda spr_fish,x
        sta $0380,x
        lda spr_gator,x
        sta $03C0,x
        inx
        cpx #64
        bne cpy

        ; Enable sprites 0-6
        lda #%01111111
        sta VIC_SPRITE_ENABLE

        ; Sprite pointers
        lda #$0D
        sta $07F8           ; Otter
        lda #$0E
        sta $07F9           ; Fish 1
        sta $07FA           ; Fish 2
        sta $07FB           ; Fish 3
        lda #$0F
        sta $07FC           ; Gator 1
        sta $07FD           ; Gator 2
        sta $07FE           ; Eagle

        ; Sprite colors
        lda #9
        sta VIC_SPRITE_COLOR+0      ; Brown otter
        lda #7
        sta VIC_SPRITE_COLOR+1      ; Yellow fish
        sta VIC_SPRITE_COLOR+2
        sta VIC_SPRITE_COLOR+3
        lda #5
        sta VIC_SPRITE_COLOR+4      ; Green gators
        sta VIC_SPRITE_COLOR+5
        lda #1
        sta VIC_SPRITE_COLOR+6      ; White eagle

        ; Init sprite positions
        lda #160        ; Otter in center
        sta VIC_SPRITE_X+0
        lda #200
        sta VIC_SPRITE_Y+0

        lda #80         ; Fish 1
        sta VIC_SPRITE_X+2
        lda #50
        sta VIC_SPRITE_Y+2

        lda #150        ; Fish 2
        sta VIC_SPRITE_X+4
        lda #100
        sta VIC_SPRITE_Y+4

        lda #200        ; Fish 3
        sta VIC_SPRITE_X+6
        lda #150
        sta VIC_SPRITE_Y+6

        lda #100        ; Gator 1
        sta VIC_SPRITE_X+8
        lda #60
        sta VIC_SPRITE_Y+8

        lda #180        ; Gator 2
        sta VIC_SPRITE_X+10
        lda #130
        sta VIC_SPRITE_Y+10

        lda #140        ; Eagle
        sta VIC_SPRITE_X+12
        lda #30
        sta VIC_SPRITE_Y+12

; Main game loop
game_loop:
        ; Wait for raster
wait1:  lda VIC_RASTER
        cmp #250
        bne wait1
wait2:  lda VIC_RASTER
        cmp #250
        beq wait2

        ; Check joystick
        lda CIA1_PORT_B
        and #$01
        bne skip_up
        lda VIC_SPRITE_Y+0
        cmp #50
        bcc skip_up
        dec VIC_SPRITE_Y+0
skip_up:
        lda CIA1_PORT_B
        and #$02
        bne skip_down
        lda VIC_SPRITE_Y+0
        cmp #229
        bcs skip_down
        inc VIC_SPRITE_Y+0
skip_down:
        lda CIA1_PORT_B
        and #$04
        bne skip_left
        lda VIC_SPRITE_X+0
        cmp #24
        bcc skip_left
        dec VIC_SPRITE_X+0
skip_left:
        lda CIA1_PORT_B
        and #$08
        bne skip_right
        lda VIC_SPRITE_X+0
        cmp #255
        bcs skip_right
        inc VIC_SPRITE_X+0

skip_right:
        ; Scroll river
        inc scroll_offset
        lda scroll_offset
        cmp #8
        bcs do_scroll_now
        jmp no_scroll_yet

do_scroll_now:
        lda #0
        sta scroll_offset
        jsr scroll_river
        ; Move sprites
        lda VIC_SPRITE_Y+2
        clc
        adc #8
        sta VIC_SPRITE_Y+2

        lda VIC_SPRITE_Y+4
        clc
        adc #8
        sta VIC_SPRITE_Y+4

        lda VIC_SPRITE_Y+6
        clc
        adc #8
        sta VIC_SPRITE_Y+6

        lda VIC_SPRITE_Y+8
        clc
        adc #8
        sta VIC_SPRITE_Y+8

        lda VIC_SPRITE_Y+10
        clc
        adc #8
        sta VIC_SPRITE_Y+10

        lda VIC_SPRITE_X+12
        clc
        adc #8
        sta VIC_SPRITE_X+12

        ; Wrap fish
        lda VIC_SPRITE_Y+2
        cmp #250
        bcc f1_ok
        lda #10
        sta VIC_SPRITE_Y+2
        lda #80
        sta VIC_SPRITE_X+2
f1_ok:
        lda VIC_SPRITE_Y+4
        cmp #250
        bcc f2_ok
        lda #10
        sta VIC_SPRITE_Y+4
        lda #150
        sta VIC_SPRITE_X+4
f2_ok:
        lda VIC_SPRITE_Y+6
        cmp #250
        bcc f3_ok
        lda #10
        sta VIC_SPRITE_Y+6
        lda #200
        sta VIC_SPRITE_X+6
f3_ok:

        ; Wrap gators
        lda VIC_SPRITE_Y+8
        cmp #250
        bcc g1_ok
        lda #10
        sta VIC_SPRITE_Y+8
        lda #100
        sta VIC_SPRITE_X+8
g1_ok:
        lda VIC_SPRITE_Y+10
        cmp #250
        bcc g2_ok
        lda #10
        sta VIC_SPRITE_Y+10
        lda #180
        sta VIC_SPRITE_X+10
g2_ok:

        ; Wrap eagle
        lda VIC_SPRITE_X+12
        cmp #240
        bcc eagle_ok
        lda #60
        sta VIC_SPRITE_X+12
eagle_ok:

no_scroll_yet:
        ; Decrease hit cooldown
        lda hit_cooldown
        beq check_collisions
        dec hit_cooldown
        jmp no_collision

check_collisions:
        ; Check sprite-to-background collision
        lda VIC_SPRITE_BG_COLLISION
        and #$01
        beq check_sprite_collision

        ; Hit riverbank!
        dec lives
        lda lives
        beq game_over

        lda #100
        sta hit_cooldown

        jsr update_lives

        ; Flash border
        lda #2
        sta VIC_BORDER
        ldx #0
bank_flash:
        inx
        bne bank_flash
        lda #0
        sta VIC_BORDER

check_sprite_collision:
        ; Check sprite-to-sprite collisions
        lda VIC_SPRITE_COLLISION
        sta $02
        beq no_collision

        ; Check fish collisions
        lda $02
        and #$0E
        beq check_enemies

        ; Hit a fish!
        sed
        clc
        lda score
        adc #$10
        sta score
        lda score+1
        adc #0
        sta score+1
        cld

        jsr update_score

        ; Move caught fish off screen
        lda $02
        and #$02
        beq not_f1
        lda #250
        sta VIC_SPRITE_Y+2
not_f1:
        lda $02
        and #$04
        beq not_f2
        lda #250
        sta VIC_SPRITE_Y+4
not_f2:
        lda $02
        and #$08
        beq check_enemies
        lda #250
        sta VIC_SPRITE_Y+6

check_enemies:
        ; Check enemy collisions
        lda $02
        and #$70
        beq no_collision

        ; Hit an enemy!
        dec lives
        lda lives
        beq game_over

        lda #100
        sta hit_cooldown

        jsr update_lives

        ; Flash border
        lda #2
        sta VIC_BORDER
        ldx #0
flash:  inx
        bne flash
        lda #0
        sta VIC_BORDER

no_collision:
        jmp game_loop

game_over:
        lda #2
        sta VIC_BORDER
        sta VIC_BACKGROUND

        ldx #0
gover:  lda txt_gameover,x
        beq forever
        sta SCREEN+495,x
        lda #1
        sta COLOR_RAM+495,x
        inx
        jmp gover

forever:
        jmp forever

; Update score display (row 1, after "SCORE:")
update_score:
        lda score+1
        lsr
        lsr
        lsr
        lsr
        ora #$30
        sta SCREEN+7
        lda #7
        sta COLOR_RAM+7

        lda score+1
        and #$0F
        ora #$30
        sta SCREEN+9
        lda #7
        sta COLOR_RAM+9

        lda score
        lsr
        lsr
        lsr
        lsr
        ora #$30
        sta SCREEN+8
        lda #7
        sta COLOR_RAM+8

        lda score
        and #$0F
        ora #$30
        sta SCREEN+10
        lda #7
        sta COLOR_RAM+10
        rts

; Update lives display (row 1, after "LIVES:")
update_lives:
        lda lives
        ora #$30
        sta SCREEN+38
        lda #7
        sta COLOR_RAM+38
        rts

draw_river_row:
        ; Compute 16-bit offset = row * 40
        lda #0
        sta $03  ; offset low
        sta $04  ; offset high
        ldx $02  ; row
        beq offset_done
add40:
        clc
        lda $03
        adc #40
        sta $03
        lda $04
        adc #0
        sta $04
        dex
        bne add40
offset_done:
        ; Screen ptr = SCREEN + offset
        clc
        lda $03
        adc #<SCREEN
        sta $03
        lda $04
        adc #>SCREEN
        sta $04
        ; Color ptr = COLOR_RAM + offset = screen ptr + $D400
        clc
        lda $03
        adc #<$D400  ; $00
        sta $05  ; color low
        lda $04
        adc #>$D400  ; $D4
        sta $06  ; color high

        ldy #0
draw_col:
        cpy left_bank
        bcc is_bank
        cpy right_bank
        bcs is_bank
        ; Water
        lda #$20
        sta ($03),y
        jmp next_col
is_bank:
        lda #$A0
        sta ($03),y
        lda #5
        sta ($05),y
next_col:
        iny
        cpy #40
        bne draw_col
        rts

; Adjust river banks
adjust_banks:
        jsr get_random
        and #$03
        cmp #0
        beq left_widen
        cmp #1
        beq left_narrow
        jmp check_right

left_widen:
        lda left_bank
        cmp #1
        beq check_right
        dec left_bank
        jmp check_right

left_narrow:
        lda left_bank
        cmp #8
        bcs check_right
        inc left_bank

check_right:
        jsr get_random
        and #$03
        cmp #0
        beq right_widen
        cmp #1
        beq right_narrow
        jmp ensure_width

right_widen:
        lda right_bank
        cmp #39
        beq ensure_width
        inc right_bank
        jmp ensure_width

right_narrow:
        lda right_bank
        cmp #32
        bcc ensure_width
        dec right_bank

ensure_width:
        lda right_bank
        sec
        sbc left_bank
        cmp #16
        bcs width_ok

        lda left_bank
        cmp #4
        bcc widen_right
        dec left_bank
        jmp width_ok
widen_right:
        inc right_bank

width_ok:
        rts

; Random number generator
get_random:
        lda random_seed
        asl
        asl
        clc
        adc random_seed
        adc #$11
        sta random_seed
        rts

; Scroll river (rows 3-24 only, protect UI in rows 0-2)
scroll_river:
        ldx #0
scroll_loop:
        ; Scroll from row 23 to 24 (bottom)
        lda SCREEN+920,x
        sta SCREEN+960,x
        lda COLOR_RAM+920,x
        sta COLOR_RAM+960,x

        ; Continue scrolling upward to row 4
        lda SCREEN+880,x
        sta SCREEN+920,x
        lda COLOR_RAM+880,x
        sta COLOR_RAM+920,x

        lda SCREEN+840,x
        sta SCREEN+880,x
        lda COLOR_RAM+840,x
        sta COLOR_RAM+880,x

        lda SCREEN+800,x
        sta SCREEN+840,x
        lda COLOR_RAM+800,x
        sta COLOR_RAM+840,x

        lda SCREEN+760,x
        sta SCREEN+800,x
        lda COLOR_RAM+760,x
        sta COLOR_RAM+800,x

        lda SCREEN+720,x
        sta SCREEN+760,x
        lda COLOR_RAM+720,x
        sta COLOR_RAM+760,x

        lda SCREEN+680,x
        sta SCREEN+720,x
        lda COLOR_RAM+680,x
        sta COLOR_RAM+720,x

        lda SCREEN+640,x
        sta SCREEN+680,x
        lda COLOR_RAM+640,x
        sta COLOR_RAM+680,x

        lda SCREEN+600,x
        sta SCREEN+640,x
        lda COLOR_RAM+600,x
        sta COLOR_RAM+640,x

        lda SCREEN+560,x
        sta SCREEN+600,x
        lda COLOR_RAM+560,x
        sta COLOR_RAM+600,x

        lda SCREEN+520,x
        sta SCREEN+560,x
        lda COLOR_RAM+520,x
        sta COLOR_RAM+560,x

        lda SCREEN+480,x
        sta SCREEN+520,x
        lda COLOR_RAM+480,x
        sta COLOR_RAM+520,x

        lda SCREEN+440,x
        sta SCREEN+480,x
        lda COLOR_RAM+440,x
        sta COLOR_RAM+480,x

        lda SCREEN+400,x
        sta SCREEN+440,x
        lda COLOR_RAM+400,x
        sta COLOR_RAM+440,x

        lda SCREEN+360,x
        sta SCREEN+400,x
        lda COLOR_RAM+360,x
        sta COLOR_RAM+400,x

        lda SCREEN+320,x
        sta SCREEN+360,x
        lda COLOR_RAM+320,x
        sta COLOR_RAM+360,x

        lda SCREEN+280,x
        sta SCREEN+320,x
        lda COLOR_RAM+280,x
        sta COLOR_RAM+320,x

        lda SCREEN+240,x
        sta SCREEN+280,x
        lda COLOR_RAM+240,x
        sta COLOR_RAM+280,x

        lda SCREEN+200,x
        sta SCREEN+240,x
        lda COLOR_RAM+200,x
        sta COLOR_RAM+240,x

        lda SCREEN+160,x
        sta SCREEN+200,x
        lda COLOR_RAM+160,x
        sta COLOR_RAM+200,x

        ; Scroll row 3 to row 4 (120 -> 160)
        lda SCREEN+120,x
        sta SCREEN+160,x
        lda COLOR_RAM+120,x
        sta COLOR_RAM+160,x

        inx
        cpx #40
        beq done_scroll
        jmp scroll_loop

done_scroll:
        ; Draw new row at row 3
        lda #3
        sta $02
        jsr draw_river_row
        jsr adjust_banks
        rts

; Text data
txt_title:
        dc.b $0f,$14,$14,$05,$12,$20,$12,$01,$09,$04,0

txt_score:
        dc.b $13,$03,$0f,$12,$05,$3a,0

txt_lives:
        dc.b $0c,$09,$16,$05,$13,$3a,0

txt_gameover:
        dc.b $07,$01,$0d,$05,$20,$0f,$16,$05,$12,0

; Sprite data
spr_otter:
        dc.b $00,$18,$00,$00,$3c,$00,$00,$7e
        dc.b $00,$00,$7e,$00,$00,$7e,$00,$00
        dc.b $3c,$00,$00,$00,$00,$00,$3c,$00
        dc.b $00,$7e,$00,$00,$7e,$00,$00,$7e
        dc.b $00,$00,$7e,$00,$00,$3c,$00,$00
        dc.b $18,$00,$00,$18,$00,$00,$18,$00
        dc.b $00,$18,$00,$00,$18,$00,$00,$18
        dc.b $00,$00,$00,$00,$00,$00,$00,$02

spr_fish:
        dc.b $00,$00,$00,$00,$00,$00,$00,$00
        dc.b $00,$00,$80,$00,$01,$02,$00,$06
        dc.b $04,$00,$0f,$0e,$00,$1f,$9e,$00
        dc.b $77,$fc,$00,$f7,$f8,$00,$3f,$f8
        dc.b $00,$1f,$bc,$00,$0f,$1e,$00,$06
        dc.b $0e,$00,$04,$04,$00,$02,$02,$00
        dc.b $00,$00,$00,$00,$00,$00,$00,$00
        dc.b $00,$00,$00,$00,$00,$00,$00,$07

spr_gator:
        dc.b $00,$00,$00,$00,$00,$00,$00,$00
        dc.b $00,$00,$00,$00,$00,$00,$00,$00
        dc.b $00,$00,$00,$00,$00,$00,$00,$00
        dc.b $00,$00,$02,$00,$00,$2a,$00,$00
        dc.b $aa,$0a,$82,$a9,$2a,$aa,$81,$a6
        dc.b $aa,$40,$a6,$a8,$40,$aa,$a0,$00
        dc.b $aa,$80,$00,$aa,$01,$04,$a8,$01
        dc.b $04,$aa,$aa,$aa,$aa,$aa,$aa,$85

        rts
