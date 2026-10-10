; ==========================================================
; Otter Raid - HUD (screen A rows 0-1, hires text charset)
;
; Row 0:  SCORE 000000      [hearts]          HI 000000
; Row 1:  LIFE [bar........] 01000   [start]~~~~~O~~~~[home]
;
; Text charset icon codes are fixed by the graphics spec.
; ==========================================================

; (TX_* icon codes come from gfx/gfx_ids.asm)

HUD_SCORE_COL    = 6		; row 0
HUD_HEARTS_COL   = 18
HUD_HI_COL       = 34
HUD_GIFT_COL     = 25		; row 0: gift icon, count at +1
HUD_BAR_COL      = 5		; row 1: cap at 5, cells 6-15, cap 16
HUD_BAR_CELLS    = 10
HUD_LP_COL       = 18
HUD_TRACK_COL    = 25		; start marker; track 26-38; home 39
HUD_TRACK_LEN    = 13

; ===== print_at =====
; Print a 0-terminated string at screen A offset zp_ptr1 in
; color zp_t7. String pointer in zp_ptr0. ASCII letters become
; screen codes; bytes $80+n print icon $40+n.
print_at:
	ldy #0
pa_loop:
	lda (zp_ptr0),y
	beq pa_done
	bmi pa_icon
	cmp #$40
	bcc pa_put
	and #$3F		; 'A'..'Z' -> 1..26
	bpl pa_put
pa_icon:
	and #$7F
	clc
	adc #$40
pa_put:
	sta (zp_ptr1),y
	; color RAM at the same offset
	lda zp_ptr1+1
	pha
	clc
	adc #>(COLOR_RAM-SCREEN_A)
	sta zp_ptr1+1
	lda zp_t7
	sta (zp_ptr1),y
	pla
	sta zp_ptr1+1
	iny
	bne pa_loop
pa_done:
	rts

; ===== print_text =====
; Inline-style helper: X = text id (index into text_lo/hi),
; prints at its stored row/column/color.
print_text:
	lda text_lo,x
	sta zp_ptr0
	lda text_hi,x
	sta zp_ptr0+1
	lda text_pos_lo,x
	sta zp_ptr1
	lda text_pos_hi,x
	sta zp_ptr1+1
	lda text_color,x
	sta zp_t7
	jmp print_at

; ===== hud_draw_all =====
; Clear the HUD rows and draw every static part.
hud_draw_all:
	ldx #79
	lda #$20
hda_clear:
	sta SCREEN_A,x
	dex
	bpl hda_clear
	ldx #T_HUD_SCORE
	jsr print_text
	ldx #T_HUD_HI
	jsr print_text
	ldx #T_HUD_LIFE
	jsr print_text
	; bar caps and track ends
	lda #TX_BAR_LEFT
	sta SCREEN_A+40+HUD_BAR_COL
	lda #TX_BAR_RIGHT
	sta SCREEN_A+40+HUD_BAR_COL+HUD_BAR_CELLS+1
	lda #COL_GREEN
	sta COLOR_RAM+40+HUD_BAR_COL
	sta COLOR_RAM+40+HUD_BAR_COL+HUD_BAR_CELLS+1
	lda #TX_TRACK_START
	sta SCREEN_A+40+HUD_TRACK_COL
	lda #TX_TRACK_HOME
	sta SCREEN_A+40+HUD_TRACK_COL+HUD_TRACK_LEN+1
	lda #COL_LIGHT_GREEN
	sta COLOR_RAM+40+HUD_TRACK_COL
	lda #COL_YELLOW
	sta COLOR_RAM+40+HUD_TRACK_COL+HUD_TRACK_LEN+1
	lda #$FF
	sta hud_last_score	; force redraws
	sta hud_last_lp
	sta hud_last_hearts
	sta hud_last_track
	jsr hud_hiscore
	lda #TX_GIFT
	sta SCREEN_A+HUD_GIFT_COL
	lda #COL_YELLOW
	sta COLOR_RAM+HUD_GIFT_COL
	lda #$FF
	sta gifts_shown
	jmp hud_update

hud_last_lp:
	.byte 0
hud_last_lp_lo:
	.byte 0
hud_last_score:
	.byte $FF, $FF, $FF
hud_last_hearts:
	.byte 0
hud_last_track:
	.byte 0

; ===== hud_update =====
; Once per frame: redraw the parts that changed.
hud_update:
	jsr hud_score
	jsr hud_hearts
	jsr hud_gifts
	jsr hud_life
	jmp hud_track

; ===== hud_gifts =====
; Two-digit count of gifts collected for Auntie.
hud_gifts:
	lda gifts
	cmp gifts_shown
	beq hg_done
	sta gifts_shown
	ldx #<(SCREEN_A+HUD_GIFT_COL+1)
	ldy #>(SCREEN_A+HUD_GIFT_COL+1)
	lda #COL_WHITE
	jmp print_2digits
hg_done:
	rts

; ===== print_2digits =====
; gifts (0-99) as two digits at Y:X (screen A) in color A.
print_2digits:
	stx zp_ptr1
	sty zp_ptr1+1
	sta zp_t7
	lda gifts
	ldx #$30
p2_tens:
	cmp #10
	bcc p2_units
	sbc #10
	inx
	bne p2_tens
p2_units:
	ora #$30
	ldy #1
	jsr p2_put
	txa
	ldy #0
p2_put:
	sta (zp_ptr1),y
	lda zp_ptr1+1
	pha
	clc
	adc #>(COLOR_RAM-SCREEN_A)
	sta zp_ptr1+1
	lda zp_t7
	sta (zp_ptr1),y
	pla
	sta zp_ptr1+1
	rts

; ===== hud_score =====
; Redrawn only when the score changed.
hud_score:
	lda score
	cmp hud_last_score
	bne hs_changed
	lda score+1
	cmp hud_last_score+1
	bne hs_changed
	lda score+2
	cmp hud_last_score+2
	bne hs_changed
	rts
hs_changed:
	lda score
	sta hud_last_score
	lda score+1
	sta hud_last_score+1
	lda score+2
	sta hud_last_score+2
	lda #<(SCREEN_A+HUD_SCORE_COL)
	sta zp_ptr1
	lda #>(SCREEN_A+HUD_SCORE_COL)
	sta zp_ptr1+1
	ldx #score
	lda #COL_WHITE
	jmp print_bcd6

hud_hiscore:
	lda #<(SCREEN_A+HUD_HI_COL)
	sta zp_ptr1
	lda #>(SCREEN_A+HUD_HI_COL)
	sta zp_ptr1+1
	ldx #hi_score
	lda #COL_YELLOW
	jmp print_bcd6

; ===== print_bcd6 =====
; Six BCD digits of the 3-byte number at zero page X (low byte
; first) to zp_ptr1 in color A.
print_bcd6:
	sta zp_t7
	ldy #0
	lda 2,x
	jsr pb_byte
	lda 1,x
	jsr pb_byte
	lda 0,x
pb_byte:
	pha
	lsr
	lsr
	lsr
	lsr
	jsr pb_digit
	pla
	and #$0F
pb_digit:
	ora #$30
	sta (zp_ptr1),y
	lda zp_ptr1+1
	pha
	clc
	adc #>(COLOR_RAM-SCREEN_A)
	sta zp_ptr1+1
	lda zp_t7
	sta (zp_ptr1),y
	pla
	sta zp_ptr1+1
	iny
	rts

; ===== hud_hearts =====
hud_hearts:
	lda hearts
	cmp hud_last_hearts
	beq hh_done
	sta hud_last_hearts
	ldx #0
	ldy #0
hh_loop:
	lda #TX_HEART_EMPTY
	cpx hearts
	bcs hh_put
	lda #TX_HEART_FULL
hh_put:
	sta SCREEN_A+HUD_HEARTS_COL,y
	lda #COL_RED
	sta COLOR_RAM+HUD_HEARTS_COL,y
	iny
	iny
	inx
	cpx #3
	bne hh_loop
hh_done:
	rts

; ===== hud_life =====
; Bar of 80 steps (LP >> 7, i.e. 128 LP each) plus the number.
hud_life:
	; steps = LP >> 7 (128 LP per step, 78 at the 10000 cap)
	lda lp_hi
	sta zp_t1
	lda lp_lo
	asl
	rol zp_t1		; zp_t1 = LP >> 7
	lda lp_lo		; redraw on any Life Point change
	cmp hud_last_lp_lo
	bne hl_draw
	lda zp_t1
	cmp hud_last_lp
	bne hl_draw
	rts
hl_draw:
	lda lp_lo
	sta hud_last_lp_lo
	lda zp_t1
	sta hud_last_lp
	sta zp_t0		; steps 0..78
	; color by level
	ldy #COL_GREEN
	cmp #24
	bcs hl_color
	ldy #COL_YELLOW
	cmp #8
	bcs hl_color
	ldy #COL_RED
hl_color:
	sty zp_t7
	ldx #0
hl_cell:
	lda zp_t0
	cmp #8
	bcc hl_partial
	sbc #8
	sta zp_t0
	lda #TX_BAR_0+8
	bne hl_put
hl_partial:
	clc
	adc #TX_BAR_0
	pha
	lda #0
	sta zp_t0
	pla
hl_put:
	sta SCREEN_A+40+HUD_BAR_COL+1,x
	lda zp_t7
	sta COLOR_RAM+40+HUD_BAR_COL+1,x
	inx
	cpx #HUD_BAR_CELLS
	bne hl_cell
	; number: binary LP -> 5 decimal digits
	lda lp_lo
	sta zp_t0
	lda lp_hi
	sta zp_t1
	lda #<(SCREEN_A+40+HUD_LP_COL)
	sta zp_ptr1
	lda #>(SCREEN_A+40+HUD_LP_COL)
	sta zp_ptr1+1
	lda #COL_WHITE
	sta zp_t7
	ldx #0
hl_digit:
	ldy #$30		; '0'
hl_sub:
	lda zp_t0
	sec
	sbc pow10_lo,x
	sta zp_t2
	lda zp_t1
	sbc pow10_hi,x
	bcc hl_put_digit
	sta zp_t1
	lda zp_t2
	sta zp_t0
	iny
	bne hl_sub
hl_put_digit:
	tya
	pha
	txa
	tay
	pla
	sta (zp_ptr1),y
	lda zp_t7
	sta COLOR_RAM+40+HUD_LP_COL,y
	inx
	cpx #5
	bne hl_digit
	rts

pow10_lo:
	.byte <10000, <1000, <100, <10, <1
pow10_hi:
	.byte >10000, >1000, >100, >10, >1

; ===== hud_track =====
; Ollie's progress along the journey (sections 0-39).
hud_track:
	; position 0..HUD_TRACK_LEN-1 = sec_index * 13 / 40
	lda sec_index
	cmp #SECTION_COUNT
	bcc ht_ok
	lda #SECTION_COUNT-1
ht_ok:
	sta zp_t4
	lda #HUD_TRACK_LEN*256/SECTION_COUNT
	sta zp_t2
	jsr mul8
	cmp hud_last_track
	beq ht_done
	sta hud_last_track
	tay
	ldx #0
ht_loop:
	lda #TX_TRACK
	sta zp_t0
	lda #COL_LIGHT_BLUE
	cpx hud_last_track
	bne ht_put
	lda #TX_TRACK_OLLIE
	sta zp_t0
	lda #COL_ORANGE
ht_put:
	sta COLOR_RAM+40+HUD_TRACK_COL+1,x
	lda zp_t0
	sta SCREEN_A+40+HUD_TRACK_COL+1,x
	inx
	cpx #HUD_TRACK_LEN
	bne ht_loop
ht_done:
	rts

; ===== hud_message =====
; Print text id X centered message in HUD row 1 area (used for
; PAUSED etc.); hud_draw_all restores the row.
hud_message:
	jmp print_text

; ===== text table =====
T_HUD_SCORE      = 0
T_HUD_HI         = 1
T_HUD_LIFE       = 2
T_PAUSED         = 3
T_GET_READY      = 4
T_GAME_OVER      = 5
T_HOME           = 6
T_GIFTS          = 7

text_lo:
	.byte <tx_score, <tx_hi, <tx_life, <tx_paused, <tx_ready
	.byte <tx_game_over, <tx_home, <tx_gifts
text_hi:
	.byte >tx_score, >tx_hi, >tx_life, >tx_paused, >tx_ready
	.byte >tx_game_over, >tx_home, >tx_gifts
text_pos_lo:
	.byte <(SCREEN_A+0), <(SCREEN_A+31), <(SCREEN_A+40)
	.byte <(SCREEN_A+40+14), <(SCREEN_A+40+14)
	.byte <(SCREEN_A+40+14), <(SCREEN_A+40+8), <(SCREEN_A+40+8)
text_pos_hi:
	.byte >(SCREEN_A+0), >(SCREEN_A+31), >(SCREEN_A+40)
	.byte >(SCREEN_A+40+14), >(SCREEN_A+40+14)
	.byte >(SCREEN_A+40+14), >(SCREEN_A+40+8), >(SCREEN_A+40+8)
text_color:
	.byte COL_LIGHT_BLUE, COL_YELLOW, COL_LIGHT_GREEN
	.byte COL_YELLOW, COL_WHITE, COL_LIGHT_RED, COL_YELLOW
	.byte COL_LIGHT_GREEN

tx_score:
	.text "SCORE"
	.byte 0
tx_hi:
	.text "HI"
	.byte 0
tx_life:
	.text "LIFE"
	.byte 0
tx_paused:
	.text "  - PAUSED -  "
	.byte 0
tx_ready:
	.text "  GET READY!  "
	.byte 0
tx_game_over:
	.text "  GAME  OVER  "
	.byte 0
tx_home:
	.text "HAPPY BIRTHDAY, AUNTIE!   "
	.byte 0
tx_gifts:
	.text "  GIFTS FOR AUNTIE:       "
	.byte 0
