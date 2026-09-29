; Otter Raid river world prototype
river_init:
        lda #$A5
        sta zp_seed
        lda #0
        sta zp_section
        sta zp_section_row
        sta zp_world_row

        lda #20
        sta river_cp0_x
        lda #24
        sta river_cp0_w
        lda #24
        sta river_cp1_x
        lda #22
        sta river_cp1_w
        lda #28
        sta river_cp2_x
        lda #26
        sta river_cp2_w
        rts

river_next_section:
        inc zp_section
        lda #0
        sta zp_section_row

        lda river_cp2_x
        sta river_cp0_x
        lda river_cp2_w
        sta river_cp0_w

        jsr river_random_step
        lda zp_seed
        and #$0F
        sec
        sbc #8
        clc
        adc river_cp0_x
        jsr clamp_center
        sta river_cp1_x

        jsr river_random_step
        lda zp_seed
        and #$07
        sec
        sbc #3
        clc
        adc river_cp0_w
        jsr clamp_width
        sta river_cp1_w

        jsr river_random_step
        lda zp_seed
        and #$0F
        sec
        sbc #8
        clc
        adc river_cp1_x
        jsr clamp_center
        sta river_cp2_x

        jsr river_random_step
        lda zp_seed
        and #$07
        sec
        sbc #3
        clc
        adc river_cp1_w
        jsr clamp_width
        sta river_cp2_w
        rts

river_random_step:
        lda zp_seed
        asl
        bcc random_no_xor
        eor #$1D
random_no_xor:
        sta zp_seed
        rts

clamp_center:
        cmp #8
        bcs center_low_ok
        lda #8
center_low_ok:
        cmp #32
        bcc center_done
        lda #31
center_done:
        rts

clamp_width:
        cmp #RIVER_MIN_WIDTH
        bcs width_low_ok
        lda #RIVER_MIN_WIDTH
width_low_ok:
        cmp #(RIVER_MAX_WIDTH+1)
        bcc width_done
        lda #RIVER_MAX_WIDTH
width_done:
        rts

river_sample:
        lda zp_section_row
        cmp #80
        bcs sample_second

        ; First half: interpolate cp0 to cp1.
        lda river_cp1_x
        sec
        sbc river_cp0_x
        sta zp_tmp
        lda zp_tmp
        bmi sample_first_x_negative
        lda zp_section_row
        lsr
        lsr
        lsr
        sta zp_tmp2
        lda river_cp0_x
        clc
        adc zp_tmp2
        sta zp_center
        jmp sample_first_width
sample_first_x_negative:
        lda zp_section_row
        lsr
        lsr
        lsr
        sta zp_tmp2
        lda river_cp0_x
        sec
        sbc zp_tmp2
        sta zp_center

sample_first_width:
        lda river_cp1_w
        sec
        sbc river_cp0_w
        sta zp_tmp
        lda zp_tmp
        bmi sample_first_w_negative
        lda zp_section_row
        lsr
        lsr
        lsr
        sta zp_tmp2
        lda river_cp0_w
        clc
        adc zp_tmp2
        sta zp_width
        rts
sample_first_w_negative:
        lda zp_section_row
        lsr
        lsr
        lsr
        sta zp_tmp2
        lda river_cp0_w
        sec
        sbc zp_tmp2
        sta zp_width
        rts

sample_second:
        ; Second half: interpolate cp1 to cp2 using (row-80)/8.
        lda zp_section_row
        sec
        sbc #80
        lsr
        lsr
        lsr
        sta zp_tmp2

        lda river_cp2_x
        sec
        sbc river_cp1_x
        sta zp_tmp
        lda zp_tmp
        bmi sample_second_x_negative
        lda river_cp1_x
        clc
        adc zp_tmp2
        sta zp_center
        jmp sample_second_width
sample_second_x_negative:
        lda river_cp1_x
        sec
        sbc zp_tmp2
        sta zp_center

sample_second_width:
        lda river_cp2_w
        sec
        sbc river_cp1_w
        sta zp_tmp
        lda zp_tmp
        bmi sample_second_w_negative
        lda river_cp1_w
        clc
        adc zp_tmp2
        sta zp_width
        rts
sample_second_w_negative:
        lda river_cp1_w
        sec
        sbc zp_tmp2
        sta zp_width
        rts

river_advance_row:
        inc zp_section_row
        inc zp_world_row
        lda zp_section_row
        cmp #SECTION_ROWS
        bcc river_row_done
        jsr river_next_section
river_row_done:
        rts
