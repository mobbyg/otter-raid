; Otter Raid river renderer prototype
        include "constants.asm"

render_river_row:
        jsr river_sample

        lda zp_width
        lsr
        sta zp_tmp
        lda zp_center
        sec
        sbc zp_tmp
        sta zp_left
        lda zp_center
        clc
        adc zp_tmp
        sta zp_right

        ldy #0
        lda #CHAR_BANK
render_bank:
        sta SCREEN_RAM,y
        lda #COLOR_BANK
        sta COLOR_RAM,y
        iny
        cpy #SCREEN_COLS
        bne render_bank

        ldy zp_left
        lda #CHAR_WATER
render_water:
        cpy zp_right
        bcs render_done
        sta SCREEN_RAM,y
        lda #COLOR_WATER
        sta COLOR_RAM,y
        iny
        bne render_water
render_done:
        rts

render_initial_playfield:
        ldx #PLAY_START
render_initial_loop:
        jsr render_river_row
        ; Move the rendered row into the correct screen page.
        jsr copy_row_to_x
        jsr river_advance_row
        inx
        cpx #(PLAY_END+1)
        bne render_initial_loop
        rts

; The row renderer writes to SCREEN_RAM as a 40-byte staging row.
; Copy it to screen row X. Color RAM is copied the same way.
copy_row_to_x:
        stx zp_tmp2
        txa
        asl
        asl
        asl
        asl
        asl
        clc
        adc zp_tmp2
        asl
        ; X * 40 = X * 32 + X * 8.
        sta zp_dst_lo
        lda #0
        adc #0
        sta zp_dst_hi

        lda #<SCREEN_RAM
        clc
        adc zp_dst_lo
        sta zp_dst_lo
        lda #>SCREEN_RAM
        adc zp_dst_hi
        sta zp_dst_hi

        lda #0
        sta zp_src_lo
        lda #>SCREEN_RAM
        sta zp_src_hi

        ldy #0
copy_screen_row:
        lda SCREEN_RAM,y
        sta (zp_dst_lo),y
        iny
        cpy #SCREEN_COLS
        bne copy_screen_row

        lda #<COLOR_RAM
        clc
        adc zp_dst_lo
        sta zp_dst_lo
        lda #>COLOR_RAM
        adc zp_dst_hi
        sta zp_dst_hi
        ldy #0
copy_color_row:
        lda COLOR_RAM,y
        sta (zp_dst_lo),y
        iny
        cpy #SCREEN_COLS
        bne copy_color_row
        rts

; Shift playfield rows 3..23 into rows 2..22.
; The copy uses a pair of indirect pointers so it is independent of the
; physical screen address layout.
scroll_playfield:
        lda #<(SCREEN_RAM+120)
        sta zp_src_lo
        lda #>(SCREEN_RAM+120)
        sta zp_src_hi
        lda #<(SCREEN_RAM+80)
        sta zp_dst_lo
        lda #>(SCREEN_RAM+80)
        sta zp_dst_hi
        lda #< (COLOR_RAM+120)
        sta zp_tmp
        lda #> (COLOR_RAM+120)
        sta zp_tmp2

        ldx #21
scroll_row:
        ldy #0
scroll_char:
        lda (zp_src_lo),y
        sta (zp_dst_lo),y
        iny
        cpy #SCREEN_COLS
        bne scroll_char

        ; Advance source and destination by 40 bytes.
        clc
        lda zp_src_lo
        adc #40
        sta zp_src_lo
        bcc src_no_carry
        inc zp_src_hi
src_no_carry:
        clc
        lda zp_dst_lo
        adc #40
        sta zp_dst_lo
        bcc dst_no_carry
        inc zp_dst_hi
dst_no_carry:
        dex
        bne scroll_row

        ; Color RAM follows the same row movement.
        lda #<(COLOR_RAM+120)
        sta zp_src_lo
        lda #>(COLOR_RAM+120)
        sta zp_src_hi
        lda #<(COLOR_RAM+80)
        sta zp_dst_lo
        lda #>(COLOR_RAM+80)
        sta zp_dst_hi
        ldx #21
color_scroll_row:
        ldy #0
color_scroll_char:
        lda (zp_src_lo),y
        sta (zp_dst_lo),y
        iny
        cpy #SCREEN_COLS
        bne color_scroll_char
        clc
        lda zp_src_lo
        adc #40
        sta zp_src_lo
        bcc color_src_no_carry
        inc zp_src_hi
color_src_no_carry:
        clc
        lda zp_dst_lo
        adc #40
        sta zp_dst_lo
        bcc color_dst_no_carry
        inc zp_dst_hi
color_dst_no_carry:
        dex
        bne color_scroll_row

        ldx #PLAY_END
        jsr render_river_row
        jsr copy_row_to_x
        jsr river_advance_row
        rts
