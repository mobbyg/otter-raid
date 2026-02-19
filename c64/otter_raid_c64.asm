        cpu 6502

; ===============================================
; OTTER RAID - COLLISION FIX: Just ignore banks!
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
VIC_CTRL1 = $D011

; Game variables
score = $FB
lives = $FD
energy = $FC         ; Energy level (0-100)
hit_cooldown = $FE
scroll_offset = $FA
left_bank = $F9
right_bank = $F8
random_seed = $F7
anim_counter = $F6   ; Animation frame counter
fine_scroll = $F5
frame_counter = $F4
second_counter = $F3
eagle_state = $F2
eagle_timer = $F1
eagle_dx = $F0
gator_dir = $EF
gator_dir2 = $EE
gator_dir3 = $ED

EAGLE_REPEAT_SECONDS = 60

        org $0801

; BASIC: 10 SYS2061
        .byte $0b,$08,$0a,$00,$9e
        .byte "2061"
        .byte $00,$00,$00

start:
        ; Initialize game variables
        lda #0
        sta score
        sta score+1
        sta hit_cooldown
        sta scroll_offset
        sta anim_counter
        sta fine_scroll
        sta frame_counter
        sta second_counter
        sta eagle_state
        sta eagle_timer
        lda #3
        sta lives
        lda #100
        sta energy

        ; Initialize river banks
        lda #4
        sta left_bank
        lda #35
        sta right_bank

        ; Initialize random seed
        lda #$A5
        sta random_seed

        lda #1
        sta gator_dir
        sta gator_dir2
        sta gator_dir3

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
        
        ; Setup multicolor sprite mode BEFORE drawing text
        lda #$01
        sta $D025          ; Sprite multicolor 1 (white)
        lda #$00
        sta $D026          ; Sprite multicolor 2 (black)
        
        ; Enable multicolor for sprite 0 (otter)
        lda #%00000001
        sta $D01C

        ; Draw initial river (rows 3-24)
        ldx #3
init_river:
        stx $02
        jsr draw_river_row
        jsr adjust_banks
        ldx $02
        inx
        cpx #25
        bne init_river

        ; Draw UI
        ldx #0
title:  lda txt_title,x
        beq show_score
        sta SCREEN+15,x
        lda #5
        sta COLOR_RAM+15,x
        inx
        jmp title

show_score:
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
        ldx #0
lives_loop:
        lda txt_lives,x
        beq show_energy
        sta SCREEN+32,x
        lda #1
        sta COLOR_RAM+32,x
        inx
        cpx #6
        bne lives_loop

show_energy:
        ldx #0
energy_loop:
        lda txt_energy,x
        beq setup_sprites
        sta SCREEN+48,x     ; Row 1, column 8 (after LIVES at col 0-5)
        lda #1
        sta COLOR_RAM+48,x
        inx
        cpx #8
        bne energy_loop

setup_sprites:
        jsr update_score
        jsr update_lives
        jsr update_energy

        ; Copy sprite data
        ldx #0
cpy:    lda spr_otter_1,x
        sta $0340,x
        lda spr_otter_2,x
        sta $0380,x
        lda spr_otter_3,x
        sta $03C0,x
        lda spr_fish,x
        sta $0400,x
        lda spr_gator,x
        sta $0440,x
        lda spr_gator_open,x
        sta $0480,x
        lda spr_eagle,x
        sta $04C0,x
        inx
        cpx #64
        bne cpy

        ; Enable sprites
        lda #%11111111
        sta VIC_SPRITE_ENABLE

        ; Sprite pointers
        lda #$0D
        sta $07F8           ; Otter (will animate between $0D, $0E, $0F)
        lda #$10
        sta $07F9           ; Fish 1
        sta $07FA           ; Fish 2
        sta $07FB           ; Fish 3
        lda #$11
        sta $07FC           ; Gator 1
        sta $07FD           ; Gator 2
        sta $07FF           ; Gator 3
        lda #$13
        sta $07FE           ; Eagle

        ; Sprite colors
        lda #8              ; Orange/brown for otter
        sta VIC_SPRITE_COLOR+0
        lda #7
        sta VIC_SPRITE_COLOR+1
        sta VIC_SPRITE_COLOR+2
        sta VIC_SPRITE_COLOR+3
        lda #5
        sta VIC_SPRITE_COLOR+4
        sta VIC_SPRITE_COLOR+5
        sta VIC_SPRITE_COLOR+7
        lda #1
        sta VIC_SPRITE_COLOR+6

        ; Init positions
        lda #160
        sta VIC_SPRITE_X+0
        lda #200
        sta VIC_SPRITE_Y+0

        lda #80
        sta VIC_SPRITE_X+2
        lda #50
        sta VIC_SPRITE_Y+2

        lda #150
        sta VIC_SPRITE_X+4
        lda #100
        sta VIC_SPRITE_Y+4

        lda #200
        sta VIC_SPRITE_X+6
        lda #150
        sta VIC_SPRITE_Y+6

        lda #60
        sta VIC_SPRITE_X+8
        lda #90
        sta VIC_SPRITE_Y+8

        lda #200
        sta VIC_SPRITE_X+10
        lda #140
        sta VIC_SPRITE_Y+10

        lda #130
        sta VIC_SPRITE_X+14
        lda #190
        sta VIC_SPRITE_Y+14

        lda #140
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

        ; Animate otter sprite (cycle through 3 frames)
        inc anim_counter
        lda anim_counter
        cmp #10
        bcc skip_anim
        lda #0
        sta anim_counter
        
        ; Cycle sprite pointer: $0D -> $0E -> $0F -> $0D
        lda $07F8
        cmp #$0D
        beq set_frame2
        cmp #$0E
        beq set_frame3
        lda #$0D
        sta $07F8
        jmp skip_anim
set_frame2:
        lda #$0E
        sta $07F8
        jmp skip_anim
set_frame3:
        lda #$0F
        sta $07F8
skip_anim:

        ; Joystick input
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

        ; Smooth scroll using VIC fine scroll
        inc fine_scroll
        lda fine_scroll
        and #$07
        sta fine_scroll

        lda VIC_CTRL1
        and #%11111000
        ora fine_scroll
        sta VIC_CTRL1

        lda fine_scroll
        bne no_scroll_yet
        jsr scroll_river

no_scroll_yet:
        ; Move fish downward smoothly
        inc VIC_SPRITE_Y+2
        inc VIC_SPRITE_Y+4
        inc VIC_SPRITE_Y+6

        ; Animate gator mouths
        lda anim_counter
        and #$08
        beq gator_frame_closed
        lda #$12
        sta $07FC
        sta $07FD
        sta $07FF
        jmp move_gators
gator_frame_closed:
        lda #$11
        sta $07FC
        sta $07FD
        sta $07FF

move_gators:
        ; Gator horizontal patrol
        lda gator_dir
        bne g1_right
        dec VIC_SPRITE_X+8
        lda VIC_SPRITE_X+8
        cmp #40
        bcs g2_move
        lda #1
        sta gator_dir
        jmp g2_move
g1_right:
        inc VIC_SPRITE_X+8
        lda VIC_SPRITE_X+8
        cmp #220
        bcc g2_move
        lda #0
        sta gator_dir

g2_move:
        lda gator_dir2
        bne g2_right
        dec VIC_SPRITE_X+10
        lda VIC_SPRITE_X+10
        cmp #40
        bcs g3_move
        lda #1
        sta gator_dir2
        jmp g3_move
g2_right:
        inc VIC_SPRITE_X+10
        lda VIC_SPRITE_X+10
        cmp #220
        bcc g3_move
        lda #0
        sta gator_dir2

g3_move:
        lda gator_dir3
        bne g3_right
        dec VIC_SPRITE_X+14
        lda VIC_SPRITE_X+14
        cmp #40
        bcs eagle_logic
        lda #1
        sta gator_dir3
        jmp eagle_logic
g3_right:
        inc VIC_SPRITE_X+14
        lda VIC_SPRITE_X+14
        cmp #220
        bcc eagle_logic
        lda #0
        sta gator_dir3

eagle_logic:
        jsr update_eagle

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

check_collisions:
        ; Always check bank collisions (no cooldown for banks)
        jsr enforce_otter_bounds
        lda VIC_SPRITE_BG_COLLISION
        and #$01
        bne bank_collision
        
        ; Handle sprite collision cooldown
        lda hit_cooldown
        beq check_sprite_collision
        dec hit_cooldown
        jmp no_collision
        
bank_collision:
        ; Clear collision register (read twice to clear)
        lda VIC_SPRITE_BG_COLLISION
        lda VIC_SPRITE_BG_COLLISION
        
        ; Flash background RED to show bank hit
        lda #2
        sta VIC_BACKGROUND
        
        ; Drain energy
        lda energy
        sec
        sbc #5
        bcs bank_energy_ok
        lda #0
bank_energy_ok:
        sta energy
        jsr update_energy
        
        ; Reset background
        lda #6
        sta VIC_BACKGROUND
        
        ; Check if energy depleted
        lda energy
        bne bank_continue
        
        ; Lost a life!
        dec lives
        lda lives
        bne reset_energy_bank
        jmp game_over
        
reset_energy_bank:
        lda #100
        sta energy
        jsr update_energy
        jsr update_lives
        
bank_continue:
        ; Set cooldown
        lda #50
        sta hit_cooldown

check_sprite_collision:
        ; Check sprite collisions
        lda VIC_SPRITE_COLLISION
        sta $02
        bne has_collision
        jmp no_collision
        
has_collision:
        ; Check fish
        lda $02
        and #$0E
        bne hit_fish
        jmp check_enemies
        
hit_fish:
        ; Simplified collision - just check Y distance (fish move down)
        ; If Y is close, count it as a hit
        lda $02
        and #$02
        beq check_f2
        ; Check fish 1 - is otter within 20 pixels vertically?
        lda VIC_SPRITE_Y+2
        sec
        sbc #20
        cmp VIC_SPRITE_Y+0
        bcs check_f2
        lda VIC_SPRITE_Y+2
        clc
        adc #20
        cmp VIC_SPRITE_Y+0
        bcc check_f2
        jmp caught_fish1
        
check_f2:
        lda $02
        and #$04
        beq check_f3
        ; Check fish 2
        lda VIC_SPRITE_Y+4
        sec
        sbc #20
        cmp VIC_SPRITE_Y+0
        bcs check_f3
        lda VIC_SPRITE_Y+4
        clc
        adc #20
        cmp VIC_SPRITE_Y+0
        bcc check_f3
        jmp caught_fish2
        
check_f3:
        lda $02
        and #$08
        beq check_enemies
        ; Check fish 3
        lda VIC_SPRITE_Y+6
        sec
        sbc #20
        cmp VIC_SPRITE_Y+0
        bcs check_enemies
        lda VIC_SPRITE_Y+6
        clc
        adc #20
        cmp VIC_SPRITE_Y+0
        bcc check_enemies
        jmp caught_fish3
        
caught_fish1:
        lda #250
        sta VIC_SPRITE_Y+2
        jmp add_fish_bonus
caught_fish2:
        lda #250
        sta VIC_SPRITE_Y+4
        jmp add_fish_bonus
caught_fish3:
        lda #250
        sta VIC_SPRITE_Y+6
        
add_fish_bonus:
        ; Hit fish - add energy and score
        lda energy
        clc
        adc #10
        cmp #101
        bcc energy_ok
        lda #100
energy_ok:
        sta energy
        jsr update_energy
        
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

        jmp check_enemies

check_enemies:
        ; Check enemies
        lda $02
        and #$F0
        bne has_enemy_collision
        jmp no_collision_jump
        
has_enemy_collision:
        
        ; Refine enemy collision - check if within 12 pixels
        lda $02
        and #$10
        beq check_g2
        ; Check gator 1
        lda VIC_SPRITE_Y+0
        sec
        sbc VIC_SPRITE_Y+8
        cmp #12
        bcs check_g2
        lda VIC_SPRITE_X+0
        sec
        sbc VIC_SPRITE_X+8
        cmp #12
        bcs check_g2
        jmp hit_enemy
        
check_g2:
        lda $02
        and #$20
        beq check_g3
        ; Check gator 2
        lda VIC_SPRITE_Y+0
        sec
        sbc VIC_SPRITE_Y+10
        cmp #12
        bcs check_g3
        lda VIC_SPRITE_X+0
        sec
        sbc VIC_SPRITE_X+10
        cmp #12
        bcs check_g3
        jmp hit_enemy

check_g3:
        lda $02
        and #$80
        beq check_eagle
        ; Check gator 3
        lda VIC_SPRITE_Y+0
        sec
        sbc VIC_SPRITE_Y+14
        cmp #12
        bcs check_eagle
        lda VIC_SPRITE_X+0
        sec
        sbc VIC_SPRITE_X+14
        cmp #12
        bcs check_eagle
        jmp hit_enemy
        
check_eagle:
        lda $02
        and #$40
        beq no_collision_jump
        ; Check eagle
        lda VIC_SPRITE_Y+0
        sec
        sbc VIC_SPRITE_Y+12
        cmp #12
        bcs no_collision_jump
        lda VIC_SPRITE_X+0
        sec
        sbc VIC_SPRITE_X+12
        cmp #12
        bcs no_collision_jump
        
hit_enemy:
        lda $02
        and #$40
        bne eagle_hit

        ; Hit enemy - lose energy
        lda energy
        sec
        sbc #20
        bcs enemy_energy_ok
        lda #0
enemy_energy_ok:
        sta energy
        jsr update_energy
        
        ; Check if energy depleted
        lda energy
        bne energy_remaining
        
        ; Lost a life!
        dec lives
        lda lives
        bne reset_energy
        jmp game_over
        
reset_energy:
        lda #100
        sta energy
        jsr update_energy
        jsr update_lives

energy_remaining:
        lda #100
        sta hit_cooldown

        ; Flash border
        lda #2
        sta VIC_BORDER
        ldx #0
flash:  inx
        bne flash
        lda #0
        sta VIC_BORDER

no_collision_jump:
        jmp no_collision

eagle_hit:
        dec lives
        jsr update_lives
        lda lives
        beq game_over
        lda #160
        sta VIC_SPRITE_X+0
        lda #200
        sta VIC_SPRITE_Y+0
        lda #100
        sta energy
        jsr update_energy
        lda #100
        sta hit_cooldown
        jmp no_collision

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

update_eagle:
        lda eagle_state
        bne eagle_active

        inc frame_counter
        lda frame_counter
        cmp #50
        bcc eagle_done
        lda #0
        sta frame_counter
        inc second_counter

        lda eagle_timer
        bne eagle_countdown_init
        jsr get_random
        and #$1F
        clc
        adc #90
        sta eagle_timer

eagle_countdown_init:
        dec eagle_timer
        bne eagle_done

        lda #1
        sta eagle_state
        jsr get_random
        and #$01
        beq eagle_from_left
        lda #240
        sta VIC_SPRITE_X+12
        lda #$FF
        sta eagle_dx
        jmp eagle_spawned
eagle_from_left:
        lda #40
        sta VIC_SPRITE_X+12
        lda #1
        sta eagle_dx

eagle_spawned:
        lda #30
        sta VIC_SPRITE_Y+12
        lda #$13
        sta $07FE
        jmp eagle_done

eagle_active:
        lda eagle_state
        cmp #1
        beq eagle_dive

        ; rising away
        dec VIC_SPRITE_Y+12
        lda eagle_dx
        bmi eagle_up_left
        inc VIC_SPRITE_X+12
        jmp eagle_up_pos_done
eagle_up_left:
        dec VIC_SPRITE_X+12
eagle_up_pos_done:
        lda VIC_SPRITE_Y+12
        cmp #18
        bcs eagle_done
        lda #0
        sta eagle_state
        lda #EAGLE_REPEAT_SECONDS
        sta eagle_timer
        lda #250
        sta VIC_SPRITE_Y+12
        rts

eagle_dive:
        inc VIC_SPRITE_Y+12
        lda eagle_dx
        bmi eagle_down_left
        inc VIC_SPRITE_X+12
        jmp eagle_down_pos_done
eagle_down_left:
        dec VIC_SPRITE_X+12
eagle_down_pos_done:
        lda VIC_SPRITE_Y+12
        cmp #120
        bcc eagle_done
        lda #2
        sta eagle_state
        lda eagle_dx
        eor #$FF
        clc
        adc #1
        sta eagle_dx

eagle_done:
        rts

enforce_otter_bounds:
        ; Conservative dynamic clamp by bank estimates
        lda left_bank
        asl
        asl
        asl
        clc
        adc #24
        sta $03

        lda right_bank
        asl
        asl
        asl
        sec
        sbc #16
        sta $04

        lda VIC_SPRITE_X+0
        cmp $03
        bcs check_right_bound
        lda $03
        sta VIC_SPRITE_X+0

check_right_bound:
        lda VIC_SPRITE_X+0
        cmp $04
        bcc bounds_done
        lda $04
        sta VIC_SPRITE_X+0
bounds_done:
        rts

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

update_lives:
        lda lives
        ora #$30
        sta SCREEN+78
        lda #7
        sta COLOR_RAM+78
        rts

update_energy:
        ; Display energy at row 1, columns 16-18 (positions 56-58) - after "ENERGY:"
        lda energy
        cmp #100
        bne not_100
        lda #$31  ; '1'
        sta SCREEN+56
        lda #$30  ; '0'
        sta SCREEN+57
        sta SCREEN+58
        lda #7
        sta COLOR_RAM+56
        sta COLOR_RAM+57
        sta COLOR_RAM+58
        rts
        
not_100:
        lda #$20  ; Space for leading digit
        sta SCREEN+56
        
        lda energy
        cmp #10
        bcs tens_digit
        
        ; Single digit (0-9)
        lda #$20
        sta SCREEN+57
        lda energy
        ora #$30
        sta SCREEN+58
        jmp color_energy
        
tens_digit:
        ; Two digits (10-99)
        lda energy
        ldx #0
div10:
        cmp #10
        bcc done_div
        sbc #10
        inx
        jmp div10
done_div:
        pha
        txa
        ora #$30
        sta SCREEN+57
        pla
        ora #$30
        sta SCREEN+58
        
color_energy:
        lda #7
        sta COLOR_RAM+56
        sta COLOR_RAM+57
        sta COLOR_RAM+58
        rts

draw_river_row:
        ; Compute offset = row * 40
        lda #0
        sta $03
        sta $04
        ldx $02
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
        ; Screen ptr
        clc
        lda $03
        adc #<SCREEN
        sta $03
        lda $04
        adc #>SCREEN
        sta $04
        ; Color ptr
        clc
        lda $03
        adc #<$D400
        sta $05
        lda $04
        adc #>$D400
        sta $06

        ldy #0
draw_col:
        cpy left_bank
        bcc is_bank
        cpy right_bank
        bcs is_bank
        ; Water - use blue space
        lda #$20
        sta ($03),y
        lda #6
        sta ($05),y
        jmp next_col
is_bank:
        ; Bank - use SOLID block (160 = $A0) which triggers collision
        lda #$E0          ; Solid block character
        sta ($03),y
        lda #5            ; Green
        sta ($05),y
next_col:
        iny
        cpy #40
        bne draw_col
        rts

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

get_random:
        lda random_seed
        asl
        asl
        clc
        adc random_seed
        adc #$11
        sta random_seed
        rts

scroll_river:
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

        inx
        cpx #40
        beq done_scroll
        jmp scroll_loop

done_scroll:
        lda #3
        sta $02
        jsr draw_river_row
        jsr adjust_banks
        rts

txt_title:
        .byte $0f,$14,$14,$05,$12,$20,$12,$01,$09,$04,0

txt_score:
        .byte $13,$03,$0f,$12,$05,$3a,0

txt_lives:
        .byte $0c,$09,$16,$05,$13,$3a,0

txt_energy:
        .byte $05,$0e,$05,$12,$07,$19,$3a,0

txt_gameover:
        .byte $07,$01,$0d,$05,$20,$0f,$16,$05,$12,0

; Otter sprite data (3 frames for animation)
spr_otter_1:
        .byte $00,$3c,$00,$00,$eb,$00,$00,$eb
        .byte $00,$00,$eb,$00,$00,$eb,$00,$00
        .byte $3c,$00,$00,$c3,$00,$00,$eb,$00
        .byte $00,$eb,$00,$00,$eb,$00,$00,$eb
        .byte $00,$00,$eb,$00,$00,$eb,$00,$00
        .byte $3b,$00,$00,$0b,$00,$00,$ec,$00
        .byte $03,$b0,$00,$0e,$c0,$00,$03,$00
        .byte $00,$00,$00,$00,$00,$00,$00,$88

spr_otter_2:
        .byte $00,$3c,$00,$00,$eb,$00,$00,$eb
        .byte $00,$00,$eb,$00,$00,$eb,$00,$00
        .byte $3c,$00,$00,$c3,$00,$00,$eb,$00
        .byte $00,$eb,$00,$00,$eb,$00,$00,$eb
        .byte $00,$00,$eb,$00,$00,$eb,$00,$00
        .byte $eb,$00,$00,$3b,$00,$00,$3b,$00
        .byte $00,$3b,$00,$00,$3b,$00,$00,$3b
        .byte $00,$00,$3b,$00,$00,$0c,$00,$88

spr_otter_3:
        .byte $00,$3c,$00,$00,$eb,$00,$00,$eb
        .byte $00,$00,$eb,$00,$00,$eb,$00,$00
        .byte $3c,$00,$00,$c3,$00,$00,$eb,$00
        .byte $00,$eb,$00,$00,$eb,$00,$00,$eb
        .byte $00,$00,$eb,$00,$00,$eb,$00,$00
        .byte $ec,$00,$00,$e0,$00,$00,$3b,$00
        .byte $00,$0e,$c0,$00,$03,$b0,$00,$00
        .byte $c0,$00,$00,$00,$00,$00,$00,$88

spr_gator_open:
        .byte $00,$00,$00,$00,$00,$00,$00,$00
        .byte $00,$00,$00,$00,$00,$00,$00,$00
        .byte $00,$00,$00,$00,$00,$00,$00,$00
        .byte $00,$00,$02,$00,$00,$2a,$00,$00
        .byte $aa,$0a,$82,$a9,$2a,$aa,$81,$a6
        .byte $aa,$40,$a2,$a8,$40,$8a,$a0,$00
        .byte $8a,$80,$00,$88,$01,$04,$88,$01
        .byte $04,$aa,$aa,$aa,$aa,$aa,$aa,$85

spr_eagle:
        .byte $00,$00,$00,$00,$00,$00,$00,$00
        .byte $00,$00,$10,$00,$00,$38,$00,$00
        .byte $7c,$00,$00,$fe,$00,$03,$ff,$80
        .byte $07,$ff,$c0,$0f,$ff,$e0,$1f,$ff
        .byte $f0,$0f,$ff,$e0,$07,$ff,$c0,$03
        .byte $ff,$80,$00,$fe,$00,$00,$7c,$00
        .byte $00,$38,$00,$00,$10,$00,$00,$00
        .byte $00,$00,$00,$00,$00,$00,$00,$01

spr_fish:
        .byte $00,$00,$00,$00,$00,$00,$00,$00
        .byte $00,$00,$80,$00,$01,$02,$00,$06
        .byte $04,$00,$0f,$0e,$00,$1f,$9e,$00
        .byte $77,$fc,$00,$f7,$f8,$00,$3f,$f8
        .byte $00,$1f,$bc,$00,$0f,$1e,$00,$06
        .byte $0e,$00,$04,$04,$00,$02,$02,$00
        .byte $00,$00,$00,$00,$00,$00,$00,$00
        .byte $00,$00,$00,$00,$00,$00,$00,$07

spr_gator:
        .byte $00,$00,$00,$00,$00,$00,$00,$00
        .byte $00,$00,$00,$00,$00,$00,$00,$00
        .byte $00,$00,$00,$00,$00,$00,$00,$00
        .byte $00,$00,$02,$00,$00,$2a,$00,$00
        .byte $aa,$0a,$82,$a9,$2a,$aa,$81,$a6
        .byte $aa,$40,$a6,$a8,$40,$aa,$a0,$00
        .byte $aa,$80,$00,$aa,$01,$04,$a8,$01
        .byte $04,$aa,$aa,$aa,$aa,$aa,$aa,$85
