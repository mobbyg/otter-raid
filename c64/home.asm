; ==========================================================
; Otter Raid - the homecoming
;
; The river stops at Auntie's place. Ollie swims to the
; landing, then Ollie, the present and Auntie dance while
; balloons rise and fireworks burst; leftover Life Points and
; hearts are tallied into the score.
;
; Sprites: 0-1 fireworks, 2 Ollie, 3 present, 4 Auntie,
; 5-6 balloons, 7 firework.
; ==========================================================

HOME_SWIM_TIME   = 100		; frames for Ollie to reach the spot
HOME_PARTY_AT    = HOME_SWIM_TIME+10
HOME_TALLY_AT    = HOME_PARTY_AT+60
HOME_LEAVE_MIN   = HOME_TALLY_AT+150
HOME_LEAVE_MAX   = 255*3
HOME_HEART_BONUS = $50		; 5000 points per heart (BCD x100)


; ===== state_home =====
state_home:
	lda state_t
	bne sh_counting
	inc home_t_hi		; state_t wrapped
sh_counting:
	jsr river_animate
	lda state_t
	cmp #1
	bne sh_not_first
	lda home_t_hi
	bne sh_not_first
	jsr home_begin
sh_not_first:
	lda home_t_hi
	bne sh_party
	lda state_t
	cmp #HOME_PARTY_AT
	bcs sh_party
	jsr home_swim
	jmp home_hud
sh_party:
	jsr home_party
	jsr home_tally
	jsr home_hud
	; leave after the show (fire skips once the tally is done)
	lda home_t_hi
	cmp #>HOME_LEAVE_MAX
	bcs sh_leave
	; 16-bit (home_t_hi:state_t) >= HOME_LEAVE_MIN ?
	lda state_t
	cmp #<HOME_LEAVE_MIN
	lda home_t_hi
	sbc #>HOME_LEAVE_MIN
	bcc sh_done
sh_fire:
	lda in_new
	and #IN_FIRE|IN_START
	beq sh_done
sh_leave:
	lda #0
	sta home_t_hi
	jmp hiscore_check
sh_done:
	rts

; row 1 carries the party messages: only score and hearts;
; the birthday wish and the gift count take turns
home_hud:
	jsr hud_score
	jsr hud_hearts
	lda state_t
	and #127
	bne hhm_done
	lda state_t
	and #128
	beq hhm_wish
	ldx #T_GIFTS
	jsr print_text
	ldx #<(SCREEN_A+40+29)
	ldy #>(SCREEN_A+40+29)
	lda #COL_WHITE
	jmp print_2digits
hhm_wish:
	ldx #T_HOME
	jmp print_text
hhm_done:
	rts

; ===== home_begin =====
; Freeze the river, clear hazards, choose the party spot.
home_begin:
	lda gifts
	sta home_gift_t
	lda #0
	sta scroll_speed
	sta home_t_hi
	lda #G_OFF
	ldx #GATOR_MAX-1
hb_gators:
	sta g_state,x
	dex
	bpl hb_gators
	lda #E_WAIT
	sta e_state
	lda #1<<SPR_N_OLLIE
	sta SPR_SH_ENABLE
	lda #0
	sta SPR_SH_EXPX
	sta SPR_SH_EXPY
	; the party happens at the dock: find its screen position
	; dock bottom row = home_row + HOME_HOUSE_ROW
	lda home_row_lo
	clc
	adc #HOME_HOUSE_ROW
	sta zp_t0
	lda top_world
	sec
	sbc zp_t0		; rows below the top (fits: on screen)
	asl
	asl
	asl
	clc
	adc #PLAY_TOP_LINE
	adc fine_pos
	sec
	sbc #12			; sprite top a little above the row
	sta home_spot_y
	; Ollie in the water just right of the dock
	ldx #STAMP_DOCK
	lda home_dock_col
	clc
	adc stamp_w,x
	asl
	asl
	sta home_spot_x
	; message across HUD row 1
	ldx #39
	lda #$20
hb_row:
	sta SCREEN_A+40,x
	dex
	bpl hb_row
	ldx #T_HOME
	jmp print_text

; ===== home_swim =====
; Ollie paddles to the party spot.
home_swim:
	lda #0
	sta in_held		; no steering
	lda ply_x
	cmp home_spot_x
	beq hs_y
	bcc hs_right
	dec ply_x
	jmp hs_y
hs_right:
	inc ply_x
hs_y:
	lda ply_y
	cmp home_spot_y
	beq hs_anim
	bcc hs_down
	dec ply_y
	jmp hs_anim
hs_down:
	inc ply_y
hs_anim:
	inc ply_anim
	lda #0
	sta ply_vx
	sta ply_dive
	sta ply_hurt
	jmp player_sprite

; ===== home_party =====
home_party:
	; dance frame flips every 16 frames
	lda frame_count
	lsr
	lsr
	lsr
	lsr
	and #1
	tax
	; Ollie (front view) on the right
	lda ollie_dance,x
	sta SPR_SH_PTR+SPR_N_OLLIE
	lda #COL_BROWN
	sta SPR_SH_COLOR+SPR_N_OLLIE
	lda home_spot_y
	sta SPR_SH_Y+SPR_N_OLLIE
	lda home_spot_x
	stx zp_t6
	ldx #SPR_N_OLLIE
	jsr sprite_set_mcx
	ldx zp_t6
	; Auntie on the left
	lda auntie_dance,x
	sta SPR_SH_PTR+4
	lda #COL_ORANGE
	sta SPR_SH_COLOR+4
	lda home_spot_y
	sec
	sbc #6
	sta SPR_SH_Y+4
	lda home_spot_x
	sec
	sbc #20
	ldx #4
	jsr sprite_set_mcx
	; the present between them, hopping with the beat
	lda #SPR_PRESENT
	sta SPR_SH_PTR+3
	lda #COL_RED
	sta SPR_SH_COLOR+3
	lda zp_t6
	eor #1
	asl
	eor #$FF
	sec
	adc home_spot_y		; bounce 2 lines
	clc
	adc #4
	sta SPR_SH_Y+3
	lda home_spot_x
	sec
	sbc #10
	ldx #3
	jsr sprite_set_mcx
	jsr home_balloons
	jsr home_fireworks
	lda #%11111100		; party sprites: 2-7 (+0-1 fireworks)
	ora SPR_SH_ENABLE
	sta SPR_SH_ENABLE
	lda #%00000011
	ora SPR_SH_ENABLE
	sta SPR_SH_ENABLE
	lda #%01111100		; fireworks 0, 1, 7 are hires
	sta SPR_SH_MCOLOR
	rts

ollie_dance:
	.byte SPR_OLLIE_FRONT0, SPR_OLLIE_FRONT1
auntie_dance:
	.byte SPR_AUNTIE0, SPR_AUNTIE1

; ===== home_balloons =====
; Two balloons rise from the party, wrapping back to the bottom.
home_balloons:
	ldx #0
hbl_loop:
	lda #SPR_BALLOON
	sta SPR_SH_PTR+5,x
	lda balloon_colors,x
	sta SPR_SH_COLOR+5,x
	; y = start - t/2, wrapping in the playfield
	lda state_t
	lsr
	clc
	adc balloon_phase,x
	eor #$FF
	and #$7F
	clc
	adc #90
	sta SPR_SH_Y+5,x
	; gentle sideways sway
	lda state_t
	lsr
	lsr
	lsr
	clc
	adc balloon_phase,x
	and #7
	tay
	lda sway,y
	clc
	adc balloon_x,x
	stx zp_t6
	pha
	txa
	clc
	adc #5
	tax
	pla
	jsr sprite_set_mcx
	ldx zp_t6
	inx
	cpx #2
	bne hbl_loop
	rts

balloon_colors:
	.byte COL_LIGHT_RED, COL_YELLOW
balloon_phase:
	.byte 0, 70
balloon_x:
	.byte 30, 116
sway:
	.byte 0, 1, 2, 3, 3, 2, 1, 0

; ===== home_fireworks =====
; Three bursts (hires sprites 0, 1, 7) on staggered 64-frame
; cycles at pseudo-random spots in the sky above the party.
home_fireworks:
	ldx #0
hfw_loop:
	lda state_t
	clc
	adc fw_offset,x
	and #63
	sta zp_t4		; age in the cycle
	bne hfw_alive
	; new burst: new spot
	jsr rng_next
	and #127
	clc
	adc #16
	sta fw_x,x
	jsr rng_next
	and #63
	clc
	adc #82
	sta fw_y,x
	jsr rng_next
	and #7
	tay
	lda fw_colors,y
	sta fw_color,x
hfw_alive:
	ldy fw_sprite,x
	lda zp_t4
	lsr
	lsr
	lsr
	lsr			; frame 0..3
	stx zp_t6
	tax
	lda firework_frames,x
	ldx zp_t6
	sta SPR_SH_PTR,y
	lda fw_color,x
	sta SPR_SH_COLOR,y
	lda fw_y,x
	sta SPR_SH_Y,y
	lda fw_x,x
	pha
	stx zp_t6
	tya
	tax			; X = hardware sprite
	pla
	jsr sprite_set_mcx
	ldx zp_t6
	inx
	cpx #3
	bne hfw_loop
	rts

fw_sprite:
	.byte 0, 1, 7
fw_offset:
	.byte 0, 21, 42
fw_x:
	.byte 40, 80, 120
fw_y:
	.byte 90, 100, 110
fw_color:
	.byte COL_YELLOW, COL_LIGHT_RED, COL_WHITE
fw_colors:
	.byte COL_YELLOW, COL_LIGHT_RED, COL_WHITE, COL_LIGHT_GREEN
	.byte COL_CYAN, COL_ORANGE, COL_LIGHT_BLUE, COL_PURPLE
firework_frames:
	.byte SPR_FIREWORK0, SPR_FIREWORK1, SPR_FIREWORK2, SPR_FIREWORK3

; ===== home_tally =====
; Convert leftover Life Points (100 per frame) and then hearts
; into score.
home_tally:
	lda home_t_hi
	bne htl_go
	lda state_t
	cmp #HOME_TALLY_AT
	bcc htl_done
htl_go:
	lda lp_hi
	bne htl_lp
	lda lp_lo
	cmp #100
	bcc htl_hearts
htl_lp:
	lda #100
	ldx #0
	jsr lp_sub
	lda #$00
	ldx #$01		; +100 points
	jsr score_add
	lda frame_count
	and #3
	bne htl_done
	lda #SFX_MENU_MOVE
	jmp sfx_play
htl_hearts:
	lda #0
	sta lp_lo
	sta lp_hi
	lda hearts
	beq htl_gifts
	dec hearts
	lda #$00
	ldx #HOME_HEART_BONUS
	jsr score_add
	lda #SFX_HEART_GAINED
	jmp sfx_play
htl_gifts:
	; each gift Auntie unwraps: +500, one every 16 frames
	lda home_gift_t
	beq htl_done
	lda frame_count
	and #15
	bne htl_done
	dec home_gift_t
	lda #$00
	ldx #$05
	jsr score_add
	lda #SFX_GIFT
	jmp sfx_play
htl_done:
	rts
