; ==========================================================
; Otter Raid - double-buffered vertical scroll engine
;
; The playfield (screen rows 2-23) moves DOWN. Screen buffers
; A and B alternate: while one is shown, the other is prepared
; as "front shifted down one row, plus the new top row". When
; the fine scroll passes 8 pixels the buffers swap at vblank.
;
; Color RAM never scrolls: every playfield cell uses the same
; color RAM value, so all river art is in the charset.
;
; World rows grow upstream. top_world is the world row shown in
; screen row 2; screen row k shows world row top_world-(k-2).
; The top raster line of world row w is
;     71 + fine_pos + 8 * (top_world - w)
; ==========================================================

PLAY_FIRST_ROW   = 2
PLAY_LAST_ROW    = 23
PLAY_ROWS        = PLAY_LAST_ROW-PLAY_FIRST_ROW+1
PLAY_TOP_LINE    = 71		; raster line of row 2 when fine = 0

; ===== display_init =====
; Clear screens and color RAM, draw the first playfield into
; buffer A from the row generator, and prepare buffer B.
; gen_row must hand out consecutive world rows (emit_world);
; on exit top_world is the row in screen row 2.
display_init:
	lda #0
	ldx #0
di_clear:
	sta SCREEN_A,x
	sta SCREEN_A+$100,x
	sta SCREEN_A+$200,x
	sta SCREEN_A+$300,x
	sta SCREEN_B,x
	sta SCREEN_B+$100,x
	sta SCREEN_B+$200,x
	sta SCREEN_B+$300,x
	inx
	bne di_clear

	; color RAM: HUD rows keep their own colors, playfield rows
	; use the single shared multicolor value
	ldx #0
di_color:
	lda #PLAY_COLRAM
	sta COLOR_RAM+80,x
	sta COLOR_RAM+$100,x
	sta COLOR_RAM+$200,x
	sta COLOR_RAM+$2E8,x
	inx
	bne di_color
	ldx #79
	lda #COL_WHITE
di_hud_color:
	sta COLOR_RAM,x
	dex
	bpl di_hud_color

	lda #0
	sta fine_pos
	sta scroll_sub
	sta front_buf
	sta back_ready
	sta copy_stage

	; generate rows bottom (row 23) to top (row 2) into A
	ldx #PLAY_LAST_ROW
di_rows:
	txa
	pha			; row counter survives gen_row
	jsr gen_row		; next world row -> row_buf
	pla
	pha
	tax
	ldy #0			; buffer A
	jsr blit_row
	pla
	tax
	dex
	cpx #PLAY_FIRST_ROW-1
	bne di_rows

	; screen row 2 holds the last generated row
	sec
	lda emit_world
	sbc #1
	sta top_world
	lda emit_world+1
	sbc #0
	sta top_world+1

	; build buffer B synchronously
	lda #1
	sta copy_stage
di_prep:
	jsr run_copy_stage
	lda copy_stage
	bne di_prep
	rts

; ===== blit_row =====
; Copy row_buf to screen row X of buffer Y (0 = A, 1 = B).
blit_row:
	lda row_addr_lo,x
	sta zp_ptr0
	lda row_addr_hi,x
	cpy #0
	beq br_a
	clc
	adc #>(SCREEN_B-SCREEN_A)
br_a:
	sta zp_ptr0+1
	ldy #39
br_loop:
	lda row_buf,y
	sta (zp_ptr0),y
	dey
	bpl br_loop
	rts

; ===== display_advance =====
; Once per frame: continue preparing the back buffer, then
; advance the scroll by scroll_speed (1/16 px units) and swap
; buffers on each 8-pixel step if the back buffer is ready.
display_advance:
	lda copy_stage
	beq da_scroll
	jsr run_copy_stage
da_scroll:
	lda fine_pos
	sta scroll_delta	; becomes the distance moved below
	lda scroll_sub
	clc
	adc scroll_speed
	tax
	and #$0F
	sta scroll_sub
	txa
	lsr
	lsr
	lsr
	lsr
	clc
	adc fine_pos
	cmp #8
	bcc da_store
	ldx back_ready
	bne da_swap
	; back buffer late: hold at the last fine position
	lda #7
	bne da_store
da_swap:
	sec
	sbc #8
	pha
	lda front_buf
	eor #1
	sta front_buf
	inc top_world
	bne da_no_hi
	inc top_world+1
da_no_hi:
	lda #0
	sta back_ready
	lda #1
	sta copy_stage		; starts after the swap is latched
	pla
	sta fine_pos
	clc
	adc #8
	sec
	sbc scroll_delta
	sta scroll_delta
	rts
da_store:
	sta fine_pos
	sec
	sbc scroll_delta
	sta scroll_delta
	rts

; ===== run_copy_stage =====
; Back buffer = front buffer shifted down one row + new top
; row, spread evenly over three frames; the river's next row is
; generated alongside (it only touches the river ring):
;   stage 1: rows 2-8   + sample and draw the new world row
;   stage 2: rows 9-15  + its scenery
;   stage 3: rows 16-22 + hand the shown row to the back buffer
run_copy_stage:
	lda copy_stage
	cmp #2
	beq rcs_stage2
	bcs rcs_stage3
	ldx front_buf
	bne rcs_1b
	jsr copy_a_to_b_1
	jmp rcs_1gen
rcs_1b:
	jsr copy_b_to_a_1
rcs_1gen:
	jsr river_build_row_a
	inc copy_stage
	rts
rcs_stage2:
	ldx front_buf
	bne rcs_2b
	jsr copy_a_to_b_2
	jmp rcs_2gen
rcs_2b:
	jsr copy_b_to_a_2
rcs_2gen:
	jsr river_build_row_b
	inc copy_stage
	rts
rcs_stage3:
	ldx front_buf
	bne rcs_3b
	jsr copy_a_to_b_3
	jmp rcs_new_row
rcs_3b:
	jsr copy_b_to_a_3
rcs_new_row:
	jsr gen_emit		; world row top_world+1 -> row_buf
	lda front_buf
	eor #1
	tay
	ldx #PLAY_FIRST_ROW
	jsr blit_row
	lda #0
	sta copy_stage
	lda #1
	sta back_ready
	rts

; ===== unrolled row shifters =====
; Each copies 40 columns of a block of rows from the front
; buffer to the next row down in the back buffer.
	.macro SHIFT_ROWS	; src, dst, first row, row count
	ldx #39
.loop\@:
R	.set \3
	.rept \4
	lda \1+R*40,x
	sta \2+(R+1)*40,x
R	.set R+1
	.endr
	dex
	bmi .done\@
	jmp .loop\@
.done\@:
	rts
	.endm

copy_a_to_b_1:
	SHIFT_ROWS SCREEN_A, SCREEN_B, 2, 7
copy_a_to_b_2:
	SHIFT_ROWS SCREEN_A, SCREEN_B, 9, 7
copy_a_to_b_3:
	SHIFT_ROWS SCREEN_A, SCREEN_B, 16, 7
copy_b_to_a_1:
	SHIFT_ROWS SCREEN_B, SCREEN_A, 2, 7
copy_b_to_a_2:
	SHIFT_ROWS SCREEN_B, SCREEN_A, 9, 7
copy_b_to_a_3:
	SHIFT_ROWS SCREEN_B, SCREEN_A, 16, 7

; Screen row start offsets within a buffer (buffer A).
row_addr_lo:
R	.set 0
	.rept 25
	.byte <(SCREEN_A+R*40)
R	.set R+1
	.endr
row_addr_hi:
R	.set 0
	.rept 25
	.byte >(SCREEN_A+R*40)
R	.set R+1
	.endr
