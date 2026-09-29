; Otter Raid — C64 river-only prototype
; Fixed HUD, smooth fine-scroll, stitched river sections.

        include "constants.asm"
        include "river.asm"
        include "river_render.asm"

        org $0801

        ; 10 SYS2061
        .byte $0B,$08,$0A,$00,$9E
        .byte "2061"
        .byte $00,$00,$00

start:
        sei
        lda #0
        sta VIC_BORDER
        lda #6
        sta VIC_BACKGROUND

        jsr clear_screen
        jsr river_init
        jsr render_initial_playfield
        jsr setup_hud
        jsr setup_raster_irq

        lda #0
        sta zp_fine_scroll
        sta zp_frame_counter

        cli

main_loop:
        ; Synchronize gameplay work to the bottom raster interrupt.
wait_frame:
        lda VIC_RASTER
        cmp #250
        bne wait_frame
wait_frame2:
        lda VIC_RASTER
        cmp #250
        beq wait_frame2

        inc zp_frame_counter

        ; Move the playfield one pixel each frame. Every eight pixels,
        ; advance the logical world by one row and expose a new row.
        inc zp_fine_scroll
        lda zp_fine_scroll
        and #7
        sta zp_fine_scroll
        bne main_loop

        jsr scroll_playfield
        jmp main_loop

clear_screen:
        lda #$20
        ldx #0
clear_rows:
        sta SCREEN_RAM,x
        sta SCREEN_RAM+40,x
        sta SCREEN_RAM+80,x
        sta SCREEN_RAM+120,x
        sta SCREEN_RAM+160,x
        sta SCREEN_RAM+200,x
        sta SCREEN_RAM+240,x
        sta SCREEN_RAM+280,x
        sta SCREEN_RAM+320,x
        sta SCREEN_RAM+360,x
        sta SCREEN_RAM+400,x
        sta SCREEN_RAM+440,x
        sta SCREEN_RAM+480,x
        sta SCREEN_RAM+520,x
        sta SCREEN_RAM+560,x
        sta SCREEN_RAM+600,x
        sta SCREEN_RAM+640,x
        sta SCREEN_RAM+680,x
        sta SCREEN_RAM+720,x
        sta SCREEN_RAM+760,x
        sta SCREEN_RAM+800,x
        sta SCREEN_RAM+840,x
        sta SCREEN_RAM+880,x
        sta SCREEN_RAM+920,x
        sta SCREEN_RAM+960,x
        inx
        cpx #40
        bne clear_rows

        lda #COLOR_WATER
        ldx #0
clear_colors:
        sta COLOR_RAM,x
        sta COLOR_RAM+40,x
        sta COLOR_RAM+80,x
        sta COLOR_RAM+120,x
        sta COLOR_RAM+160,x
        sta COLOR_RAM+200,x
        sta COLOR_RAM+240,x
        sta COLOR_RAM+280,x
        sta COLOR_RAM+320,x
        sta COLOR_RAM+360,x
        sta COLOR_RAM+400,x
        sta COLOR_RAM+440,x
        sta COLOR_RAM+480,x
        sta COLOR_RAM+520,x
        sta COLOR_RAM+560,x
        sta COLOR_RAM+600,x
        sta COLOR_RAM+640,x
        sta COLOR_RAM+680,x
        sta COLOR_RAM+720,x
        sta COLOR_RAM+760,x
        sta COLOR_RAM+800,x
        sta COLOR_RAM+840,x
        sta COLOR_RAM+880,x
        sta COLOR_RAM+920,x
        sta COLOR_RAM+960,x
        inx
        cpx #40
        bne clear_colors
        rts

setup_hud:
        lda #$20
        ldx #0
hud_clear:
        sta SCREEN_RAM,x
        sta SCREEN_RAM+40,x
        lda #COLOR_HUD
        sta COLOR_RAM,x
        sta COLOR_RAM+40,x
        inx
        cpx #40
        bne hud_clear

        ldx #0
hud_text_loop:
        lda hud_text,x
        beq hud_done
        sta SCREEN_RAM+5,x
        lda #COLOR_HUD
        sta COLOR_RAM+5,x
        inx
        bne hud_text_loop
hud_done:
        rts

; Raster split: row 0/1 remain at fine scroll 0. The playfield begins
; around raster 67 (the normal C64 display starts near raster 51).
setup_raster_irq:
        lda #<raster_irq
        sta $0314
        lda #>raster_irq
        sta $0315
        lda #67
        sta VIC_RASTER
        lda $D01A
        ora #1
        sta $D01A
        lda $D019
        sta $D019
        lda VIC_CTRL1
        and #%11111000
        sta VIC_CTRL1
        rts

raster_irq:
        pha
        txa
        pha
        tya
        pha

        lda $D019
        sta $D019
        lda VIC_RASTER
        cmp #67
        beq raster_playfield

        ; Bottom phase: restore HUD scroll and schedule the playfield phase.
        lda VIC_CTRL1
        and #%11111000
        sta VIC_CTRL1
        lda #67
        sta VIC_RASTER
        jmp raster_exit

raster_playfield:
        lda VIC_CTRL1
        and #%11111000
        ora zp_fine_scroll
        sta VIC_CTRL1
        lda #250
        sta VIC_RASTER

raster_exit:
        pla
        tay
        pla
        tax
        pla
        rti

hud_text:
        .byte "OTTER RAID   RIVER PROTOTYPE",0
