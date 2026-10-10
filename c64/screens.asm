; ==========================================================
; Otter Raid - title, controls and high-score screens
;
; These use the full-screen text mode (DM_TEXT): screen A,
; hires text charset, color RAM per cell. Strings are ASCII
; upper case; print_at converts them to screen codes.
; ==========================================================

MENU_START       = 0
MENU_SCORES      = 1
MENU_CONTROLS    = 2
MENU_ITEMS       = 3
MENU_ROW         = 14
MENU_COL         = 14
TITLE_IDLE       = $400		; frames (~20 s) before the idle tour
HS_ENTRIES       = 5
HS_SIZE          = 6		; 3 bytes BCD score + 3 letters
HS_ROW           = 8


; ===== text_clear =====
; Blank screen A and set every color cell to A.
text_clear:
	pha
	ldx #0
tcl_loop:
	lda #$20
	sta SCREEN_A,x
	sta SCREEN_A+$100,x
	sta SCREEN_A+$200,x
	sta SCREEN_A+$2E8,x
	pla
	pha
	sta COLOR_RAM,x
	sta COLOR_RAM+$100,x
	sta COLOR_RAM+$200,x
	sta COLOR_RAM+$2E8,x
	inx
	bne tcl_loop
	pla
	rts

; ===== print_rc =====
; Print string zp_ptr0 at row X, column Y, color zp_t7.
print_rc:
	tya
	clc
	adc row_addr_lo,x
	sta zp_ptr1
	lda row_addr_hi,x
	adc #0
	sta zp_ptr1+1
	jmp print_at

; ===== print_list =====
; Print a list of (row, col, color, string...0) records ending
; with row $FF. Pointer to the list in A (lo) / X (hi).
print_list:
	sta zp_ptr2
	stx zp_ptr2+1
pl_loop:
	ldy #0
	lda (zp_ptr2),y
	cmp #$FF
	beq pl_done
	tax			; row
	iny
	lda (zp_ptr2),y
	sta zp_t6		; column
	iny
	lda (zp_ptr2),y
	sta zp_t7		; color
	; string starts at zp_ptr2 + 3
	lda zp_ptr2
	clc
	adc #3
	sta zp_ptr0
	lda zp_ptr2+1
	adc #0
	sta zp_ptr0+1
	ldy zp_t6
	jsr print_rc
	; skip past the terminator: zp_ptr2 = zp_ptr0 + len + 1
	ldy #0
pl_skip:
	lda (zp_ptr0),y
	beq pl_end
	iny
	bne pl_skip
pl_end:
	iny
	tya
	clc
	adc zp_ptr0
	sta zp_ptr2
	lda zp_ptr0+1
	adc #0
	sta zp_ptr2+1
	jmp pl_loop
pl_done:
	rts

; ===== title_enter =====
; Show the title screen with its menu and start the title tune.
title_enter:
	lda #MUS_TITLE
	jsr music_play
	lda #ST_TITLE
	jsr set_state

; ===== title_menu =====
; Redraw the title screen (also when leaving a sub-screen).
title_menu:
	lda #DM_BLANK
	sta disp_mode
	jsr frame_end
	lda #0
	sta SPR_SH_ENABLE
	sta ts_mode
	sta ts_idle_lo
	sta ts_idle_hi
	lda #COL_BLACK
	sta hud_bg_color
	lda #COL_WHITE
	jsr text_clear
	lda #<title_texts
	ldx #>title_texts
	jsr print_list
	jsr title_logo
	jsr menu_draw
	jsr title_sprites
	lda #DM_TEXT
	sta disp_mode
	rts

; ===== title_logo =====
; The big logo from the text charset when the graphics provide
; one (title_logo_map), else a plain title line.
LOGO_ROW         = 1
title_logo:
	.ifdef TITLE_LOGO_W
	lda #<title_logo_map
	sta zp_ptr0
	lda #>title_logo_map
	sta zp_ptr0+1
	ldx #0			; logo row
tl_row:
	txa
	clc
	adc #LOGO_ROW
	tay
	lda row_addr_lo,y
	clc
	adc #(40-TITLE_LOGO_W)/2
	sta zp_ptr1
	lda row_addr_hi,y
	adc #0
	sta zp_ptr1+1
	ldy #TITLE_LOGO_W-1
tl_col:
	lda (zp_ptr0),y
	sta (zp_ptr1),y
	dey
	bpl tl_col
	lda zp_ptr0
	clc
	adc #TITLE_LOGO_W
	sta zp_ptr0
	bcc tl_next
	inc zp_ptr0+1
tl_next:
	inx
	cpx #TITLE_LOGO_H
	bne tl_row
	rts
	.else
	lda #<tx_title_name
	sta zp_ptr0
	lda #>tx_title_name
	sta zp_ptr0+1
	lda #COL_YELLOW
	sta zp_t7
	ldx #4
	ldy #15
	jmp print_rc
	.endif

; ===== title_sprites =====
; Ollie's portrait (2 x 2 multicolor sprites) beside the logo.
TITLE_SPR_X      = 24+8*4
TITLE_SPR_Y      = 50+8*12
title_sprites:
	ldx #3
tsp_loop:
	lda title_spr_ptr,x
	sta SPR_SH_PTR,x
	lda #COL_BROWN
	sta SPR_SH_COLOR,x
	lda title_spr_x,x
	sta SPR_SH_X,x
	lda title_spr_y,x
	sta SPR_SH_Y,x
	dex
	bpl tsp_loop
	lda #0
	sta SPR_SH_XMSB
	sta SPR_SH_EXPX
	sta SPR_SH_EXPY
	sta SPR_SH_PRIO
	lda #$FF
	sta SPR_SH_MCOLOR
	; the present Ollie holds shows through between his paws
	lda #SPR_PRESENT
	sta SPR_SH_PTR+4
	lda #COL_RED
	sta SPR_SH_COLOR+4
	lda #<(TITLE_SPR_X+12)
	sta SPR_SH_X+4
	lda #TITLE_SPR_Y+23
	sta SPR_SH_Y+4
	lda #%00011111
	sta SPR_SH_ENABLE
	rts

title_spr_ptr:
	.byte SPR_TITLE_OLLIE_TL, SPR_TITLE_OLLIE_TR
	.byte SPR_TITLE_OLLIE_BL, SPR_TITLE_OLLIE_BR
title_spr_x:
	.byte <TITLE_SPR_X, <(TITLE_SPR_X+24)
	.byte <TITLE_SPR_X, <(TITLE_SPR_X+24)
title_spr_y:
	.byte TITLE_SPR_Y, TITLE_SPR_Y, TITLE_SPR_Y+21, TITLE_SPR_Y+21

; ===== menu_draw =====
; Cursor arrow beside the selected menu item.
menu_draw:
	ldx #0
md_loop:
	txa
	asl
	clc
	adc #MENU_ROW
	tay
	lda row_addr_lo,y
	sta zp_ptr0
	lda row_addr_hi,y
	sta zp_ptr0+1
	ldy #MENU_COL-2
	lda #$20
	cpx menu_sel
	bne md_put
	lda #TX_CURSOR_RIGHT
md_put:
	sta (zp_ptr0),y
	; highlight the selected item
	lda zp_ptr0+1
	clc
	adc #>(COLOR_RAM-SCREEN_A)
	sta zp_ptr0+1
	lda #COL_GREY
	cpx menu_sel
	bne md_color
	lda #COL_WHITE
md_color:
	ldy #MENU_COL-2
md_cells:
	sta (zp_ptr0),y
	iny
	cpy #MENU_COL+12
	bne md_cells
	inx
	cpx #MENU_ITEMS
	bne md_loop
	rts

; ===== state_title =====
state_title:
	lda ts_mode
	beq stt_menu
	cmp #3
	bne stt_sub
	jmp name_entry
stt_sub:
	; scores / controls: fire or timeout returns to the menu
	lda in_new
	and #IN_FIRE|IN_START
	bne stt_back
	lda state_t
	cmp #250
	bcc stt_done
	lda idle_seq		; idle tour: scores -> demo
	beq stt_back
	lda #0
	sta idle_seq
	jmp demo_start
stt_back:
	lda #0
	sta idle_seq
	jmp title_menu

stt_menu:
	jsr title_animate
	; idle: show the high scores now and then
	inc ts_idle_lo
	bne stt_idle_hi
	inc ts_idle_hi
stt_idle_hi:
	lda ts_idle_hi
	cmp #>TITLE_IDLE
	bcc stt_input
	lda #1
	sta idle_seq
	jmp scores_enter
stt_input:
	lda in_new
	and #IN_UP
	beq stt_not_up
	lda menu_sel
	beq stt_moved
	dec menu_sel
	jmp stt_moved
stt_not_up:
	lda in_new
	and #IN_DOWN
	beq stt_not_down
	lda menu_sel
	cmp #MENU_ITEMS-1
	bcs stt_moved
	inc menu_sel
stt_moved:
	lda #0
	sta ts_idle_lo
	sta ts_idle_hi
	lda #SFX_MENU_MOVE
	jsr sfx_play
	jmp menu_draw
stt_not_down:
	lda in_new
	and #IN_FIRE|IN_START
	beq stt_done
	lda #SFX_MENU_SELECT
	jsr sfx_play
	lda menu_sel
	beq stt_start
	cmp #MENU_SCORES
	bne stt_controls
	jmp scores_enter
stt_controls:
	jmp controls_enter
stt_start:
	jmp game_start
stt_done:
	rts

; ===== title_animate =====
; Logo: a slowly cycling color gradient, one color per row
; (or a color wave along the plain title line).
title_animate:
	.ifdef TITLE_LOGO_W
	lda frame_count
	and #3
	bne ta_done
	ldx #0
ta_row:
	txa
	clc
	adc #LOGO_ROW
	tay
	lda row_addr_lo,y
	clc
	adc #(40-TITLE_LOGO_W)/2
	sta zp_ptr1
	lda row_addr_hi,y
	adc #>(COLOR_RAM-SCREEN_A)
	sta zp_ptr1+1
	txa
	clc
	adc ta_phase
	and #7
	tay
	lda title_wave,y
	ldy #TITLE_LOGO_W-1
ta_col:
	sta (zp_ptr1),y
	dey
	bpl ta_col
	inx
	cpx #TITLE_LOGO_H
	bne ta_row
	lda frame_count
	and #15
	bne ta_done
	dec ta_phase
ta_done:
	rts
ta_phase:
	.byte 0
	.else
	ldx #0
ta_loop:
	txa
	clc
	adc frame_count
	lsr
	lsr
	and #7
	tay
	lda title_wave,y
	sta COLOR_RAM+4*40+15,x
	inx
	cpx #10
	bne ta_loop
	rts
	.endif

title_wave:
	.byte COL_YELLOW, COL_ORANGE, COL_LIGHT_RED, COL_ORANGE
	.byte COL_YELLOW, COL_WHITE, COL_LIGHT_GREEN, COL_WHITE

; ===== controls_enter =====
controls_enter:
	lda #COL_WHITE
	jsr text_clear
	lda #<controls_texts
	ldx #>controls_texts
	jsr print_list
	lda #0
	sta SPR_SH_ENABLE
	lda #2
	sta ts_mode
	lda #0
	sta state_t
	rts

; ===== scores_enter =====
scores_enter:
	lda #COL_WHITE
	jsr text_clear
	lda #0
	sta SPR_SH_ENABLE
	lda #<scores_texts
	ldx #>scores_texts
	jsr print_list
	jsr scores_draw
	lda #1
	sta ts_mode
	lda #0
	sta state_t
	sta ts_idle_lo
	sta ts_idle_hi
	rts

; ===== scores_draw =====
; Table rows: "N. NAME  000000"
scores_draw:
	ldx #0
sd_loop:
	stx zp_t5
	txa
	asl
	clc
	adc #HS_ROW
	tay
	lda row_addr_lo,y
	clc
	adc #12
	sta zp_ptr1
	lda row_addr_hi,y
	adc #0
	sta zp_ptr1+1
	; rank digit
	ldy #0
	txa
	clc
	adc #$31
	sta (zp_ptr1),y
	iny
	lda #$2E		; '.'
	sta (zp_ptr1),y
	; name
	lda zp_t5
	jsr hs_offset		; X = table offset
	ldy #3
sd_name:
	lda hs_table+3,x
	and #$3F
	sta (zp_ptr1),y
	inx
	iny
	cpy #6
	bne sd_name
	; score at column +9
	lda zp_ptr1
	clc
	adc #9
	sta zp_ptr1
	bcc sd_noc
	inc zp_ptr1+1
sd_noc:
	lda zp_t5
	jsr hs_offset
	lda hs_table,x
	sta zp_t0
	lda hs_table+1,x
	sta zp_t1
	lda hs_table+2,x
	sta zp_t2
	ldx #zp_t0
	ldy zp_t5
	lda hs_colors,y
	jsr print_bcd6
	; color the rank and name too
	lda zp_ptr1
	sec
	sbc #9
	sta zp_ptr1
	bcs sd_nob
	dec zp_ptr1+1
sd_nob:
	lda zp_ptr1+1
	clc
	adc #>(COLOR_RAM-SCREEN_A)
	sta zp_ptr1+1
	ldy zp_t5
	lda hs_colors,y
	ldy #5
sd_col:
	sta (zp_ptr1),y
	dey
	bpl sd_col
	ldx zp_t5
	inx
	cpx #HS_ENTRIES
	beq sd_done
	jmp sd_loop
sd_done:
	rts

hs_colors:
	.byte COL_YELLOW, COL_WHITE, COL_LIGHT_GREY, COL_GREY
	.byte COL_DARK_GREY

; A = entry 0..4 -> X = entry * HS_SIZE
hs_offset:
	sta zp_t6
	asl
	clc
	adc zp_t6
	asl
	tax
	rts

; ===== hiscore_check =====
; After a game: insert the score into the table if it places
; and start name entry; otherwise go straight to the title.
hiscore_check:
	; update the HUD high score
	lda score+2
	cmp hi_score+2
	bcc hc_table
	bne hc_new_hi
	lda score+1
	cmp hi_score+1
	bcc hc_table
	bne hc_new_hi
	lda score
	cmp hi_score
	bcc hc_table
hc_new_hi:
	lda score
	sta hi_score
	lda score+1
	sta hi_score+1
	lda score+2
	sta hi_score+2
hc_table:
	; find the first entry the score beats
	ldy #0
hc_find:
	tya
	jsr hs_offset
	lda score+2
	cmp hs_table+2,x
	bcc hc_next
	bne hc_insert
	lda score+1
	cmp hs_table+1,x
	bcc hc_next
	bne hc_insert
	lda score
	cmp hs_table,x
	bcs hc_insert
hc_next:
	iny
	cpy #HS_ENTRIES
	bne hc_find
	jmp title_enter		; did not place
hc_insert:
	sty hs_slot
	; shift entries slot..3 down to slot+1..4
	lda #HS_ENTRIES-1
	sta zp_t4
hc_shift:
	lda zp_t4
	cmp hs_slot
	beq hc_place
	jsr hs_offset		; X = destination entry
	txa
	sec
	sbc #HS_SIZE
	tay			; Y = source entry (one above)
	lda #HS_SIZE
	sta zp_t3
hc_copy:
	lda hs_table,y
	sta hs_table,x
	inx
	iny
	dec zp_t3
	bne hc_copy
	dec zp_t4
	jmp hc_shift
hc_place:
	lda hs_slot
	jsr hs_offset
	lda score
	sta hs_table,x
	lda score+1
	sta hs_table+1,x
	lda score+2
	sta hs_table+2,x
	lda #'A'
	sta hs_table+3,x
	sta hs_table+4,x
	sta hs_table+5,x
	; show the table with the new line in edit mode
	lda #DM_BLANK
	sta disp_mode
	jsr frame_end
	lda #COL_BLACK
	sta hud_bg_color
	jsr scores_enter
	lda #<tx_enter_name
	sta zp_ptr0
	lda #>tx_enter_name
	sta zp_ptr0+1
	lda #COL_LIGHT_GREEN
	sta zp_t7
	ldx #20
	ldy #9
	jsr print_rc
	lda #3
	sta ts_mode
	lda #0
	sta hs_letter
	lda #DM_TEXT
	sta disp_mode
	lda #MUS_HIGH_SCORE
	jsr music_play
	lda #ST_TITLE
	jmp set_state

; ===== name_entry =====
; Up/down change the letter, fire moves on; after 3 letters
; back to the title.
name_entry:
	lda hs_slot
	jsr hs_offset
	txa
	clc
	adc hs_letter
	tax			; X = offset of the letter
	lda in_new
	and #IN_UP
	beq ne_not_up
	inc hs_table+3,x
	lda hs_table+3,x
	cmp #'Z'+1
	bcc ne_redraw
	lda #'A'
	sta hs_table+3,x
	bne ne_redraw
ne_not_up:
	lda in_new
	and #IN_DOWN
	beq ne_not_down
	dec hs_table+3,x
	lda hs_table+3,x
	cmp #'A'
	bcs ne_redraw
	lda #'Z'
	sta hs_table+3,x
	bne ne_redraw
ne_not_down:
	lda in_new
	and #IN_FIRE|IN_START
	beq ne_blink
	lda #SFX_MENU_SELECT
	jsr sfx_play
	inc hs_letter
	lda hs_letter
	cmp #3
	bcc ne_redraw
	jmp title_enter
ne_redraw:
	lda #SFX_MENU_MOVE
	jsr sfx_play
	jsr scores_draw
ne_blink:
	; blink the letter being edited
	lda hs_slot
	asl
	clc
	adc #HS_ROW
	tay
	lda row_addr_lo,y
	clc
	adc #12+3
	adc hs_letter
	sta zp_ptr0
	lda row_addr_hi,y
	adc #>(COLOR_RAM-SCREEN_A)
	sta zp_ptr0+1
	lda frame_count
	and #8
	beq ne_on
	lda #COL_BLACK
	.byte $2C		; skip the next instruction (BIT abs)
ne_on:
	lda #COL_LIGHT_GREEN
	ldy #0
	sta (zp_ptr0),y
	rts

; ===== screen texts =====
; records: row, column, color, text, 0 ... $FF
title_texts:
	.byte 9, 10, COL_LIGHT_BLUE
	.text "OLLIE'S JOURNEY HOME"
	.byte 0
	.byte MENU_ROW, MENU_COL, COL_WHITE
	.text "START GAME"
	.byte 0
	.byte MENU_ROW+2, MENU_COL, COL_WHITE
	.text "HIGH SCORES"
	.byte 0
	.byte MENU_ROW+4, MENU_COL, COL_WHITE
	.text "CONTROLS"
	.byte 0
	.byte 21, 6, COL_GREY
	.text "JOYSTICK PORT 2 OR W A S D"
	.byte 0
	.byte 23, 9, COL_DARK_GREY
	.text "A RIVER RAID TRIBUTE"
	.byte 0
	.byte $FF

controls_texts:
	.byte 3, 15, COL_YELLOW
	.text "CONTROLS"
	.byte 0
	.byte 7, 6, COL_WHITE
	.text "JOYSTICK 2      KEYS"
	.byte 0
	.byte 9, 6, COL_LIGHT_GREY
	.text "LEFT / RIGHT    A / D    STEER"
	.byte 0
	.byte 11, 6, COL_LIGHT_GREY
	.text "UP              W        FAST"
	.byte 0
	.byte 13, 6, COL_LIGHT_GREY
	.text "DOWN            S        SLOW"
	.byte 0
	.byte 15, 6, COL_LIGHT_GREY
	.text "FIRE            SPACE    DIVE"
	.byte 0
	.byte 17, 6, COL_LIGHT_GREY
	.text "                P        PAUSE"
	.byte 0
	.byte 20, 4, COL_LIGHT_BLUE
	.text "DIVE UNDER GATORS AND THE EAGLE."
	.byte 0
	.byte 21, 4, COL_LIGHT_BLUE
	.text "CRAWFISH MAKE YOU INVINCIBLE!"
	.byte 0
	.byte $FF

scores_texts:
	.byte 4, 14, COL_YELLOW
	.text "HIGH SCORES"
	.byte 0
	.byte $FF

tx_enter_name:
	.text "ENTER YOUR NAME!"
	.byte 0
tx_title_name:
	.text "OTTER RAID"
	.byte 0

; ===== high score table (survives games) =====
hs_table:
	.byte $00,$50,$00
	.text "OLL"
	.byte $00,$40,$00
	.text "AUN"
	.byte $00,$30,$00
	.text "EAG"
	.byte $00,$20,$00
	.text "GAT"
	.byte $00,$10,$00
	.text "CRW"

; ===== state_high_scores =====
; (High scores are a title sub-screen; kept for the state table.)
state_high_scores:
	jmp title_menu
