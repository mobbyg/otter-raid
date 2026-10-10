; ==========================================================
; Otter Raid - attract-mode demo player
;
; When the title sits idle the game plays itself: demo_ai
; replaces the joystick each frame. It steers for the middle
; of the widest channel and dives when a gator or the eagle
; comes close. Any fire / RETURN press ends the demo.
; ==========================================================

DEMO_MAX_HI      = 12		; ~60 s (state_t wraps 12 times)
DEMO_DANGER_X    = 22		; MC pixels: gator this close -> dive
DEMO_DANGER_Y    = 30		; lines above Ollie to watch

; ===== demo_start =====
demo_start:
	lda #1
	sta demo_mode
	lda #0
	sta demo_t_hi
	jmp game_start

; ===== demo_check_end =====
; Called at the top of state_playing. Carry set = demo over.
demo_check_end:
	lda demo_mode
	beq dce_no
	lda in_new		; real input still arrives here
	and #IN_FIRE|IN_START
	bne dce_end
	lda state_t
	bne dce_no
	inc demo_t_hi
	lda demo_t_hi
	cmp #DEMO_MAX_HI
	bcs dce_end
dce_no:
	clc
	rts
dce_end:
	lda #0
	sta demo_mode
	sec
	rts

; ===== demo_ai =====
; Replace in_held / in_new with the demo player's choices.
demo_ai:
	lda #0
	sta zp_t6		; bits to press
	; where is the water around Ollie?
	lda ply_y
	sec
	sbc #8
	sta zp_t0
	lda ply_y
	clc
	adc #PLY_HB_B
	sta zp_t1
	jsr river_limits
	; target: middle of the wider channel
	lda lim_il
	cmp lim_ir
	beq dai_one		; no island
	lda lim_il
	sec
	sbc lim_l		; left channel width
	sta zp_t0
	lda lim_r
	sec
	sbc lim_ir		; right channel width
	cmp zp_t0
	bcs dai_right_ch
	lda lim_il		; left channel: lim_l..lim_il
	sta lim_r
	jmp dai_one
dai_right_ch:
	lda lim_ir		; right channel: lim_ir..lim_r
	sta lim_l
dai_one:
	lda lim_l
	clc
	adc lim_r
	ror
	sec
	sbc #(PLY_HB_L+PLY_HB_R)/2
	sta zp_t0		; target ply_x
	; steer with a dead zone of 3 pixels
	lda ply_x
	sec
	sbc zp_t0
	bcc dai_go_right
	cmp #3
	bcc dai_danger
	lda #IN_LEFT
	bne dai_steer
dai_go_right:
	cmp #256-3
	bcs dai_danger
	lda #IN_RIGHT
dai_steer:
	sta zp_t6

dai_danger:
	; gators swimming near Ollie's line
	ldx #GATOR_MAX-1
dai_gator:
	lda g_state,x
	cmp #G_SWIM
	bne dai_next
	lda ply_y
	sec
	sbc g_y,x		; gator above Ollie by 0..DANGER_Y
	cmp #DEMO_DANGER_Y
	bcs dai_next
	lda g_x,x
	sec
	sbc #GX_OFS-6		; gator center (MC)
	sec
	sbc ply_x
	sec
	sbc #6
	bcs dai_dx
	eor #$FF
	adc #1
dai_dx:
	cmp #DEMO_DANGER_X
	bcs dai_next
	lda zp_t6
	ora #IN_FIRE
	sta zp_t6
dai_next:
	dex
	bpl dai_gator
	; the eagle's dive
	lda e_state
	cmp #E_SWOOP
	bne dai_speed
	lda e_t
	cmp #E_HALF-24
	bcc dai_speed
	cmp #E_HALF+16
	bcs dai_speed
	lda zp_t6
	ora #IN_FIRE
	sta zp_t6
dai_speed:
	; swim fast through calm stretches now and then
	lda frame_count
	and #$80
	beq dai_out
	lda zp_t6
	ora #IN_UP
	sta zp_t6
dai_out:
	lda in_held
	eor #$FF
	and zp_t6
	sta in_new
	lda zp_t6
	sta in_held
	rts
