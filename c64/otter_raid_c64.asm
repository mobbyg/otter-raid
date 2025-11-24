	processor 6502

; ===============================================
; OTTER RAID - Full Game
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
VIC_CTRL1 = $D011   ; Vertical scroll control
VIC_CTRL2 = $D016   ; Horizontal scroll control

; Game variables
score = $FB         ; Score (2 bytes)
lives = $FD         ; Lives remaining
hit_cooldown = $FE  ; Collision cooldown timer
scroll_offset = $FA ; Fine scroll offset (0-7)
river_pattern = $F9 ; Current river pattern index

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
        sta river_pattern
        lda #3
        sta lives

        ; Setup colors
        lda #0
        sta VIC_BORDER
        lda #6
        sta VIC_BACKGROUND

        ; Disable smooth scrolling for now - simpler approach
        lda #1
        sta scroll_offset

        ; Clear screen with river pattern
        jsr draw_river

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
        sta VIC_SPRITE_COLOR+6      ; white eagle

        ; Init positions (keep sprites in water area, away from banks)
        ; Banks are at X: 0-7 (left) and 280-319 (right on 40-col = cols 35-39)
        ; Safe water area: X between 60-220 approximately

        lda #160        ; Otter in center
        sta VIC_SPRITE_X+0
        lda #200
        sta VIC_SPRITE_Y+0

        lda #80         ; Fish 1 - left side of water
        sta VIC_SPRITE_X+2
        lda #50
        sta VIC_SPRITE_Y+2

        lda #150        ; Fish 2 - center
        sta VIC_SPRITE_X+4
        lda #100
        sta VIC_SPRITE_Y+4

        lda #200        ; Fish 3 - right side of water
        sta VIC_SPRITE_X+6
        lda #150
        sta VIC_SPRITE_Y+6

        lda #100        ; Gator 1 - left-center
        sta VIC_SPRITE_X+8
        lda #60
        sta VIC_SPRITE_Y+8

        lda #180        ; Gator 2 - right-center
        sta VIC_SPRITE_X+10
        lda #130
        sta VIC_SPRITE_Y+10

        lda #140        ; Eagle - center
        sta VIC_SPRITE_X+12
        lda #30
        sta VIC_SPRITE_Y+12

        ; Clear top 3 rows for UI (just to be safe)
        lda #$20
        ldx #0
clear_ui:
        sta SCREEN,x        ; Row 0
        sta SCREEN+40,x     ; Row 1
        sta SCREEN+80,x     ; Row 2
        inx
        cpx #40
        bne clear_ui

        ; Display title and UI
        ldx #0
title:
	    lda txt_title,x
        beq show_ui
        sta SCREEN+15,x
		lda #5
		sta COLOR_RAM+15,x
        inx
        jmp title

show_ui:
        ; Display "SCORE:" at position 40 (second line)
        ldx #0
show_score_txt:
        lda txt_score,x
        beq show_lives_txt
        sta SCREEN,x
        lda #1          ; White color
        sta COLOR_RAM,x
        inx
        cpx #6
        bne show_score_txt

show_lives_txt:
        ldx #0
show_lives_loop:
        lda txt_lives,x
        beq init_displays
        sta SCREEN+32,x
        lda #1          ; White color
        sta COLOR_RAM+32,x
        inx
        cpx #6
        bne show_lives_loop

init_displays:
        ; Initialize score display
        jsr update_score
        jsr update_lives

; Main game loop
game_loop:
        ; Wait for raster line 250 (bottom of screen)
wait1:
	lda VIC_RASTER
        cmp #250
        bne wait1

        ; Wait for it to pass
wait2:
	lda VIC_RASTER
        cmp #250
        beq wait2

        ; Check joystick (port 2, bits inverted: 0=pressed)
        lda CIA1_PORT_B
        and #$01        ; Up
        bne skip_up
        lda VIC_SPRITE_Y+0
        cmp #50         ; Top boundary (leave room for score display)
        bcc skip_up
        dec VIC_SPRITE_Y+0
skip_up:
        lda CIA1_PORT_B
        and #$02        ; Down
        bne skip_down
        lda VIC_SPRITE_Y+0
        cmp #229        ; Bottom boundary
        bcs skip_down
        inc VIC_SPRITE_Y+0
skip_down:
        lda CIA1_PORT_B
        and #$04        ; Left
        bne skip_left
        lda VIC_SPRITE_X+0
        cmp #24         ; Left boundary
        bcc skip_left
        dec VIC_SPRITE_X+0
skip_left:
        lda CIA1_PORT_B
        and #$08        ; Right
        bne skip_right
        lda VIC_SPRITE_X+0
        cmp #255        ; Right boundary (allow near edge)
        bcs skip_right
        inc VIC_SPRITE_X+0
skip_right:

        ; Scroll river every few frames
        inc scroll_offset
        lda scroll_offset
        cmp #8          ; Scroll every 5 frames / scroll speed
        bcs do_scroll_now
        jmp no_scroll_yet
do_scroll_now:
        lda #0
        sta scroll_offset
        jsr scroll_river

        ; Move sprites 8 pixels to match river scroll speed
        lda VIC_SPRITE_Y+2
        clc
        adc #8
        sta VIC_SPRITE_Y+2      ; Fish 1

        lda VIC_SPRITE_Y+4
        clc
        adc #8
        sta VIC_SPRITE_Y+4      ; Fish 2

        lda VIC_SPRITE_Y+6
        clc
        adc #8
        sta VIC_SPRITE_Y+6      ; Fish 3

        lda VIC_SPRITE_Y+8
        clc
        adc #8
        sta VIC_SPRITE_Y+8      ; Gator 1

        lda VIC_SPRITE_Y+10
        clc
        adc #8
        sta VIC_SPRITE_Y+10     ; Gator 2

        lda VIC_SPRITE_X+12
        clc
        adc #8
        sta VIC_SPRITE_X+12     ; Eagle (moves right)

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
        ; Check sprite-to-background collision (hitting river banks)
        lda VIC_SPRITE_BG_COLLISION
        and #$01        ; Sprite 0 (otter)
        beq check_sprite_collision

        ; Hit the riverbank! Lose a life
        dec lives
        lda lives
        beq game_over

        ; Set cooldown timer
        lda #100
        sta hit_cooldown

        ; Update lives display
        jsr update_lives

        ; Flash border red
        lda #2
        sta VIC_BORDER
        ldx #0
bank_flash:
        inx
        bne bank_flash
        lda #6
        sta VIC_BORDER

check_sprite_collision:
        ; Check sprite-to-sprite collisions (reading clears the register)
        lda VIC_SPRITE_COLLISION
        sta $02         ; Save collision flags
        beq no_collision

        ; Check if otter (sprite 0) hit fish (sprites 1,2,3)
        ; Collision register bit N is set if sprite 0 collided with sprite N
        lda $02
        and #$0E        ; Bits 1,2,3 = fish sprites
        beq check_enemies

        ; Hit a fish! Add 10 points
        sed             ; Decimal mode for BCD scoring
        clc
        lda score
        adc #$10        ; Add 10 in BCD
        sta score
        lda score+1
        adc #0
        sta score+1
        cld

        ; Update score display
        jsr update_score

        ; Move the caught fish off screen
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
        ; Check if otter hit gators (sprites 4,5) or eagle (sprite 6)
        lda $02
        and #$70        ; Bits 4,5,6 = enemies
        beq no_collision

        ; Hit an enemy! Lose a life
        dec lives
        lda lives       ; Check if lives is zero
        beq game_over

        ; Set cooldown timer (prevents multiple hits)
        lda #100        ; About 2 seconds of invincibility
        sta hit_cooldown

        ; Update lives display
        jsr update_lives

        ; Flash border red briefly
        lda #2
        sta VIC_BORDER
        ldx #0
flash:  
        inx
        bne flash
        lda #6
        sta VIC_BORDER

no_collision:
        jmp game_loop

game_over:
        ; Flash border
        lda #2
        sta VIC_BORDER
        sta VIC_BACKGROUND

        ; Display GAME OVER
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

; Update score display
update_score:
        ; Display score at screen position 46-49 (after "SCORE:")
        ; Screen codes: digits are $30-$39
        lda score+1     ; High byte
        lsr
        lsr
        lsr
        lsr
        ora #$30
        sta SCREEN+6
        lda #7          ; Yellow
        sta COLOR_RAM+6

        lda score+1
        and #$0F
        ora #$30
        sta SCREEN+7
        lda #7
        sta COLOR_RAM+7

        lda score       ; Low byte
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
        sta SCREEN+9
        lda #7
        sta COLOR_RAM+9

        rts

; Update lives display
update_lives:
        ; Display lives at screen position 61 (after "LIVES:")
        lda lives
        ora #$30
        sta SCREEN+39
        lda #7          ; Yellow
        sta COLOR_RAM+39
        rts

; Draw initial river
draw_river:
        ; Clear entire screen first
        lda #$20
        ldx #0
clr:    sta SCREEN,x
        sta SCREEN+$100,x
        sta SCREEN+$200,x
        sta SCREEN+$2e8,x
        inx
        bne clr

        ; Draw river banks using bitmap - start at row 3 (after UI rows 0-2)
        lda #0
        sta river_pattern
        lda #3
        sta $0E         ; Screen row counter (3-24)

draw_init_row:
        ; Use same bitmap drawing logic
        ; Get current pattern row
        lda river_pattern
        and #$3F
        sta $05
        asl
        asl
        clc
        adc $05         ; x5
        tax             ; X = offset into river_map

        ; Calculate screen position for this row
        lda $0E
        asl
        asl
        asl
        sta $04
        lda $0E
        asl
        asl
        asl
        asl
        asl
        clc
        adc $04         ; Screen row offset
        sta $0F         ; Save screen offset

        ; Draw 40 columns
        ldy #0
init_columns:
        ; Calculate byte and bit
        tya
        lsr
        lsr
        lsr
        sta $06         ; Byte index
        tya
        and #$07
        sta $07         ; Bit index

        ; Get byte from map
        txa
        clc
        adc $06
        tax
        lda river_map,x

        ; Test the bit using a mask
        ldx $07
        cpx #0
        beq init_test_bit7
        cpx #1
        beq init_test_bit6
        cpx #2
        beq init_test_bit5
        cpx #3
        beq init_test_bit4
        cpx #4
        beq init_test_bit3
        cpx #5
        beq init_test_bit2
        cpx #6
        beq init_test_bit1
        and #$01
        jmp init_test_done
init_test_bit1:
        and #$02
        jmp init_test_done
init_test_bit2:
        and #$04
        jmp init_test_done
init_test_bit3:
        and #$08
        jmp init_test_done
init_test_bit4:
        and #$10
        jmp init_test_done
init_test_bit5:
        and #$20
        jmp init_test_done
init_test_bit6:
        and #$40
        jmp init_test_done
init_test_bit7:
        and #$80
init_test_done:
        beq init_water
        jmp init_bank

init_water:

        ; Draw water
        ldx $0F
        stx $08
        tya
        clc
        adc $08
        tax
        lda #$20
        sta SCREEN,x
        jmp init_next

init_bank:
        ; Draw bank
        ldx $0F
        stx $08
        tya
        clc
        adc $08
        tax
        lda #$A0
        sta SCREEN,x
        lda #5
        sta COLOR_RAM,x

init_next:
        ; Restore map offset
        lda river_pattern
        and #$3F
        sta $05
        asl
        asl
        clc
        adc $05
        tax

        iny
        cpy #40
        beq init_row_done
        jmp init_columns

init_row_done:
        ; Next row
        inc river_pattern
        inc $0E
        lda $0E
        cmp #25
        beq init_all_done
        jmp draw_init_row

init_all_done:
        rts

; Scroll river downward (River Raid style)
scroll_river:
        ; Shift all river data down one row (40 chars)
        ; Start from bottom and work up to avoid overwriting
        ldx #0
scroll_loop:
        lda SCREEN+920,x
        sta SCREEN+960,x
        lda COLOR_RAM+920,x
        sta COLOR_RAM+960,x

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

        lda SCREEN+120,x
        sta SCREEN+160,x
        lda COLOR_RAM+120,x
        sta COLOR_RAM+160,x

        lda SCREEN+120,x
        sta SCREEN+160,x
        lda COLOR_RAM+120,x
        sta COLOR_RAM+160,x

        inx
        cpx #40
        beq done_scroll
        jmp scroll_loop

done_scroll:
        ; Add new row at TOP (after score) - using bit map
        ; Top playfield row is at screen position 120 (row 3)

        ; Get current pattern row from map
        inc river_pattern
        lda river_pattern
        and #$3F        ; 64 map rows (0-63)

        ; Multiply by 5 to get byte offset (each row = 5 bytes)
        sta $05
        asl             ; x2
        asl             ; x4
        clc
        adc $05         ; x5
        tax             ; X = offset into river_map

        ; Draw 40 columns from bit map
        ldy #0          ; Column counter
draw_columns:
        ; Calculate which byte and bit
        tya
        lsr
        lsr
        lsr             ; Y / 8 = byte index (0-4)
        sta $06

        tya
        and #$07        ; Y % 8 = bit index (0-7)
        sta $07

        ; Get the byte from map
        txa
        clc
        adc $06         ; Add byte offset
        tax
        lda river_map,x

        ; Test the bit using a mask
        ; Bit 0 (column 0) = bit 7, bit 1 = bit 6, etc.
        ldx $07         ; Bit position (0-7)
        cpx #0
        beq test_bit7
        cpx #1
        beq test_bit6
        cpx #2
        beq test_bit5
        cpx #3
        beq test_bit4
        cpx #4
        beq test_bit3
        cpx #5
        beq test_bit2
        cpx #6
        beq test_bit1
        and #$01
        jmp test_done
test_bit1:
        and #$02
        jmp test_done
test_bit2:
        and #$04
        jmp test_done
test_bit3:
        and #$08
        jmp test_done
test_bit4:
        and #$10
        jmp test_done
test_bit5:
        and #$20
        jmp test_done
test_bit6:
        and #$40
        jmp test_done
test_bit7:
        and #$80
test_done:
        beq draw_water_scroll
        jmp draw_bank

draw_water_scroll:
        ; Draw water (space)
        lda #$20
        ldx #120        ; Row 3
        stx $08
        tya
        clc
        adc $08
        tax
        lda #$20
        sta SCREEN,x
        jmp next_column

draw_bank:
        ; Draw bank
        lda #$A0
        ldx #120        ; Row 3
        stx $08
        tya
        clc
        adc $08
        tax
        lda #$A0
        sta SCREEN,x
        lda #13
        sta COLOR_RAM,x

next_column:
        ; Restore X to map offset
        lda river_pattern
        and #$3F
        sta $05
        asl
        asl
        clc
        adc $05
        tax

        iny
        cpy #40
        beq done_drawing
        jmp draw_columns

done_drawing:
        rts

; River map - each byte is a row showing which columns have banks (1) or water (0)
; 40 columns = 5 bytes per row (40 bits)
; This gives us 64 rows of river patterns to cycle through
river_map:
        ; Row 0-7: Straight wide river (banks at edges)
        dc.b %11110000,%00000000,%00000000,%00000000,%00001111  ; 4 left, 4 right
        dc.b %11110000,%00000000,%00000000,%00000000,%00001111
        dc.b %11110000,%00000000,%00000000,%00000000,%00001111
        dc.b %11110000,%00000000,%00000000,%00000000,%00001111
        dc.b %11110000,%00000000,%00000000,%00000000,%00001111
        dc.b %11110000,%00000000,%00000000,%00000000,%00001111
        dc.b %11110000,%00000000,%00000000,%00000000,%00001111
        dc.b %11110000,%00000000,%00000000,%00000000,%00001111

        ; Row 8-15: Narrowing river
        dc.b %11111000,%00000000,%00000000,%00000000,%00011111  ; 5 left, 5 right
        dc.b %11111000,%00000000,%00000000,%00000000,%00011111
        dc.b %11111100,%00000000,%00000000,%00000000,%00111111  ; 6 left, 6 right
        dc.b %11111100,%00000000,%00000000,%00000000,%00111111
        dc.b %11111110,%00000000,%00000000,%00000000,%01111111  ; 7 left, 7 right
        dc.b %11111110,%00000000,%00000000,%00000000,%01111111
        dc.b %11111111,%00000000,%00000000,%00000000,%11111111  ; 8 left, 8 right
        dc.b %11111111,%00000000,%00000000,%00000000,%11111111

        ; Row 16-23: Widening river
        dc.b %11111110,%00000000,%00000000,%00000000,%01111111  ; 7 left, 7 right
        dc.b %11111110,%00000000,%00000000,%00000000,%01111111
        dc.b %11111100,%00000000,%00000000,%00000000,%00111111  ; 6 left, 6 right
        dc.b %11111100,%00000000,%00000000,%00000000,%00111111
        dc.b %11111000,%00000000,%00000000,%00000000,%00011111  ; 5 left, 5 right
        dc.b %11111000,%00000000,%00000000,%00000000,%00011111
        dc.b %11110000,%00000000,%00000000,%00000000,%00001111  ; 4 left, 4 right
        dc.b %11110000,%00000000,%00000000,%00000000,%00001111

        ; Row 24-31: Asymmetric bends (left curve)
        dc.b %11100000,%00000000,%00000000,%00000000,%00001111  ; 3 left, 4 right
        dc.b %11000000,%00000000,%00000000,%00000000,%00001111  ; 2 left, 4 right
        dc.b %11000000,%00000000,%00000000,%00000000,%00011111  ; 2 left, 5 right
        dc.b %11000000,%00000000,%00000000,%00000000,%00111111  ; 2 left, 6 right
        dc.b %11000000,%00000000,%00000000,%00000000,%00111111  ; 2 left, 6 right
        dc.b %11000000,%00000000,%00000000,%00000000,%00011111  ; 2 left, 5 right
        dc.b %11000000,%00000000,%00000000,%00000000,%00001111  ; 2 left, 4 right
        dc.b %11100000,%00000000,%00000000,%00000000,%00001111  ; 3 left, 4 right

        ; Row 32-39: Asymmetric bends (right curve)
        dc.b %11110000,%00000000,%00000000,%00000000,%00000111  ; 4 left, 3 right
        dc.b %11110000,%00000000,%00000000,%00000000,%00000011  ; 4 left, 2 right
        dc.b %11111000,%00000000,%00000000,%00000000,%00000011  ; 5 left, 2 right
        dc.b %11111100,%00000000,%00000000,%00000000,%00000011  ; 6 left, 2 right
        dc.b %11111100,%00000000,%00000000,%00000000,%00000011  ; 6 left, 2 right
        dc.b %11111000,%00000000,%00000000,%00000000,%00000011  ; 5 left, 2 right
        dc.b %11110000,%00000000,%00000000,%00000000,%00000011  ; 4 left, 2 right
        dc.b %11110000,%00000000,%00000000,%00000000,%00000111  ; 4 left, 3 right

        ; Row 40-47: More variations
        dc.b %11111000,%00000000,%00000000,%00000000,%00001111  ; 5 left, 4 right
        dc.b %11110000,%00000000,%00000000,%00000000,%00011111  ; 4 left, 5 right
        dc.b %11111000,%00000000,%00000000,%00000000,%00001111  ; 5 left, 4 right
        dc.b %11110000,%00000000,%00000000,%00000000,%00011111  ; 4 left, 5 right
        dc.b %11111100,%00000000,%00000000,%00000000,%00011111  ; 6 left, 5 right
        dc.b %11111000,%00000000,%00000000,%00000000,%00111111  ; 5 left, 6 right
        dc.b %11111100,%00000000,%00000000,%00000000,%00011111  ; 6 left, 5 right
        dc.b %11111000,%00000000,%00000000,%00000000,%00111111  ; 5 left, 6 right

        ; Row 48-55: Narrow passages
        dc.b %11111111,%00000000,%00000000,%00000000,%11111111  ; 8 left, 8 right
        dc.b %11111111,%10000000,%00000000,%00000000,%11111111  ; 9 left, 8 right
        dc.b %11111111,%00000000,%00000000,%00000001,%11111111  ; 8 left, 9 right
        dc.b %11111111,%10000000,%00000000,%00000001,%11111111  ; 9 left, 9 right
        dc.b %11111111,%00000000,%00000000,%00000001,%11111111  ; 8 left, 9 right
        dc.b %11111111,%10000000,%00000000,%00000000,%11111111  ; 9 left, 8 right
        dc.b %11111111,%00000000,%00000000,%00000000,%11111111  ; 8 left, 8 right
        dc.b %11111110,%00000000,%00000000,%00000000,%01111111  ; 7 left, 7 right

        ; Row 56-63: Back to normal
        dc.b %11111000,%00000000,%00000000,%00000000,%00011111  ; 5 left, 5 right
        dc.b %11111000,%00000000,%00000000,%00000000,%00011111
        dc.b %11110000,%00000000,%00000000,%00000000,%00001111  ; 4 left, 4 right
        dc.b %11110000,%00000000,%00000000,%00000000,%00001111
        dc.b %11110000,%00000000,%00000000,%00000000,%00001111
        dc.b %11110000,%00000000,%00000000,%00000000,%00001111
        dc.b %11110000,%00000000,%00000000,%00000000,%00001111
        dc.b %11110000,%00000000,%00000000,%00000000,%00001111

txt_title:
        dc.b $0f,$14,$14,$05,$12,$20,$12,$01,$09,$04,0  ; "OTTER RAID"

txt_score:
        dc.b $13,$03,$0f,$12,$05,$3a,0  ; "SCORE:"

txt_lives:
        dc.b $0c,$09,$16,$05,$13,$3a,0  ; "LIVES:"

txt_gameover:
        dc.b $07,$01,$0d,$05,$20,$0f,$16,$05,$12,0  ; "GAME OVER"

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
