; ==========================================================
; Otter Raid - Ollie: movement, speed, diving, bank contact
;
; Coordinates: ply_x is the sprite's left edge in multicolor
; pixels (0-159, 2 hires pixels each), sprite X = 24 + 2*ply_x.
; ply_y is the sprite Y register value. The hitbox below is
; relative to the sprite's top-left corner.
; ==========================================================

PLY_HB_L         = 3		; hitbox, MC pixels from sprite left
PLY_HB_R         = 9		; (exclusive)
PLY_HB_T         = 3		; hitbox, lines from sprite top
PLY_HB_B         = 18		; (exclusive)
PLY_ACCEL        = 10		; 1/64 MC pixel per frame^2
PLY_FRICTION     = 6
PLY_MAX_VX       = 96		; 1.5 MC pixels per frame
PLY_START_X      = 74		; centered: (160 - 12) / 2

SPR_N_EAGLE      = 0		; hardware sprite numbers
SPR_N_EFFECT     = 1		; (lower number is drawn on top)
SPR_N_OLLIE      = 2
SPR_N_GATOR0     = 3
SPR_N_SHADOW     = 7

DIVE_NONE        = 0
DIVE_DOWN        = 1
DIVE_UNDER       = 2
DIVE_UP          = 3
DIVE_ANIM_LEN    = 12		; frames to go under / come up
DIVE_FREE        = 150		; 3 s at 50 Hz before it costs LP

INVULN_FRAMES    = 250		; crawfish: 5 s
HURT_FRAMES      = 75		; grace after a gator hit

; ===== player_reset =====
; Ollie at the start of a run.
player_reset:
	lda #PLY_START_X
	sta ply_x
	lda #0
	sta ply_xf
	sta ply_vx
	sta ply_dive
	sta ply_dive_t
	sta ply_under_lo
	sta ply_under_hi
	sta ply_invuln
	sta ply_hurt
	sta ply_anim
	sta ply_bump
	sta fx_splash_t
	sta fx_bump_t
	; real-time constants for 50 / 60 Hz
	ldx is_ntsc
	lda dive_free_tab,x
	sta dive_free
	lda invuln_tab,x
	sta invuln_frames
	lda #1
	sta ply_speed
	lda #PLY_Y_NORMAL
	sta ply_y
	rts

; ===== player_update =====
; Once per frame during PLAYING, after display_advance.
player_update:
	inc ply_anim
	jsr player_speed
	jsr player_steer
	jsr player_banks
	jsr player_dive
	lda ply_invuln
	beq pu_no_inv
	dec ply_invuln
pu_no_inv:
	lda ply_hurt
	beq pu_no_hurt
	dec ply_hurt
pu_no_hurt:
	jsr player_fx
	jmp player_sprite

; ===== player_speed =====
; Up / down choose the swim speed; Ollie's height follows it.
PLY_Y_SLOW       = 208
PLY_Y_NORMAL     = 198
PLY_Y_FAST       = 186
player_speed:
	ldx #1
	lda in_held
	and #IN_UP
	beq ps_not_up
	ldx #2
ps_not_up:
	lda in_held
	and #IN_DOWN
	beq ps_set
	ldx #0
ps_set:
	stx ply_speed
	lda speed_table,x
	ldy is_ntsc
	beq ps_pal
	lda speed_table_ntsc,x	; same pixels per second at 60 Hz
ps_pal:
	sta scroll_speed
	; ease the sprite toward the speed's height, 1 line/frame
	lda speed_y,x
	cmp ply_y
	beq ps_done
	bcs ps_lower
	dec ply_y
	rts
ps_lower:
	inc ply_y
ps_done:
	rts

speed_table:
	.byte 16, 28, 40		; 1, 1.75, 2.5 pixels per frame
speed_table_ntsc:
	.byte 13, 23, 33
speed_y:
	.byte PLY_Y_SLOW, PLY_Y_NORMAL, PLY_Y_FAST

; ===== player_steer =====
; Left / right accelerate, friction otherwise, then move.
player_steer:
	lda in_held
	and #IN_LEFT
	beq pst_not_left
	lda ply_vx
	sec
	sbc #PLY_ACCEL
	bvs pst_clamp_left
	bpl pst_store		; still >= 0
	cmp #256-PLY_MAX_VX	; negative: compare within $80-$FF
	bcs pst_store
pst_clamp_left:
	lda #256-PLY_MAX_VX
	bne pst_store
pst_not_left:
	lda in_held
	and #IN_RIGHT
	beq pst_friction
	lda ply_vx
	clc
	adc #PLY_ACCEL
	bvs pst_clamp_right
	bmi pst_store		; still < 0
	cmp #PLY_MAX_VX+1
	bcc pst_store
pst_clamp_right:
	lda #PLY_MAX_VX
	bne pst_store
pst_friction:
	lda ply_vx
	beq pst_move
	bmi pst_fr_neg
	sec
	sbc #PLY_FRICTION
	bcs pst_store
	lda #0
	beq pst_store
pst_fr_neg:
	clc
	adc #PLY_FRICTION
	bcc pst_store
	lda #0
pst_store:
	sta ply_vx
pst_move:
	; x += vx / 64 (8.8 fixed point: vx * 4 into the fraction)
	lda ply_vx
	sta zp_t0
	lda #0
	ldx ply_vx
	bpl pst_pos
	lda #$FF
pst_pos:
	sta zp_t1		; sign extension
	asl zp_t0
	rol zp_t1
	asl zp_t0
	rol zp_t1
	clc
	lda ply_xf
	adc zp_t0
	sta ply_xf
	lda ply_x
	adc zp_t1
	sta ply_x
	rts

; ===== player_banks =====
; Keep the hitbox inside the water at Ollie's rows.
player_banks:
	lda #0
	sta ply_bump
	lda ply_y
	clc
	adc #PLY_HB_T
	sta zp_t0
	lda ply_y
	clc
	adc #PLY_HB_B-1
	sta zp_t1
	jsr river_limits

	; left bank: hitbox left must be >= lim_l
	lda ply_x
	clc
	adc #PLY_HB_L
	cmp lim_l
	bcs pb_left_ok
	lda lim_l
	sec
	sbc #PLY_HB_L
	sta ply_x
	jsr pb_bump
pb_left_ok:
	; right bank: hitbox right (exclusive) must be <= lim_r
	lda ply_x
	clc
	adc #PLY_HB_R
	cmp lim_r
	beq pb_right_ok
	bcc pb_right_ok
	lda lim_r
	sec
	sbc #PLY_HB_R
	sta ply_x
	jsr pb_bump
pb_right_ok:
	; island: push out to the nearer side
	lda lim_il
	cmp lim_ir
	beq pb_done
	lda ply_x
	clc
	adc #PLY_HB_R
	cmp lim_il
	bcc pb_done
	beq pb_done		; right edge left of the island
	lda ply_x
	clc
	adc #PLY_HB_L
	cmp lim_ir
	bcs pb_done		; left edge right of the island
	; overlap: compare hitbox center with island center
	lda lim_il
	clc
	adc lim_ir
	ror
	sta zp_t0
	lda ply_x
	clc
	adc #(PLY_HB_L+PLY_HB_R)/2
	cmp zp_t0
	bcs pb_island_right
	lda lim_il
	sec
	sbc #PLY_HB_R
	sta ply_x
	jmp pb_bump
pb_island_right:
	lda lim_ir
	sec
	sbc #PLY_HB_L
	sta ply_x
	jmp pb_bump
pb_done:
	rts

pb_bump:
	lda #0
	sta ply_vx
	sta ply_xf
	inc ply_bump
	rts

; ===== player_dive =====
; FIRE dives. Protection is on from halfway down to halfway up.
player_dive:
	ldx ply_dive
	beq pd_surface
	cpx #DIVE_DOWN
	beq pd_down
	cpx #DIVE_UNDER
	beq pd_under
	; coming up
	inc ply_dive_t
	lda ply_dive_t
	cmp #DIVE_ANIM_LEN
	bcc pd_count
	lda #DIVE_NONE
	sta ply_dive
	lda #0
	sta ply_under_lo
	sta ply_under_hi
	rts
pd_surface:
	lda in_held
	and #IN_FIRE
	beq pd_done
	lda #DIVE_DOWN
	sta ply_dive
	lda #0
	sta ply_dive_t
	lda #FX_SPLASH_TIME
	sta fx_splash_t
	lda #SFX_SPLASH_DIVE
	jsr sfx_play
	rts
pd_down:
	inc ply_dive_t
	lda ply_dive_t
	cmp #DIVE_ANIM_LEN
	bcc pd_count
	lda #DIVE_UNDER
	sta ply_dive
	lda #0
	sta ply_dive_t
	jmp pd_count
pd_under:
	inc ply_dive_t
	lda in_held
	and #IN_FIRE
	bne pd_count
	lda #DIVE_UP
	sta ply_dive
	lda #0
	sta ply_dive_t
	lda #FX_SPLASH_TIME
	sta fx_splash_t
	lda #SFX_SURFACE
	jsr sfx_play
pd_count:
	; time underwater; past the free period it costs 1 LP/frame
	inc ply_under_lo
	bne pd_no_hi
	inc ply_under_hi
pd_no_hi:
	lda ply_under_hi
	bne pd_drain
	lda ply_under_lo
	cmp dive_free
	bcc pd_done
pd_drain:
	lda #1
	ldx #0
	jsr lp_sub
pd_done:
	rts

; ===== player_protected =====
; Z clear (bne) when Ollie cannot be hurt by gators or eagle:
; underwater (see player_dive) or crawfish invulnerability.
player_protected:
	lda ply_invuln
	bne ppr_yes
	lda ply_dive
	cmp #DIVE_UNDER
	beq ppr_yes
	cmp #DIVE_DOWN
	bne ppr_up
	lda ply_dive_t
	cmp #DIVE_ANIM_LEN/2
	bcs ppr_yes
	bcc ppr_no
ppr_up:
	cmp #DIVE_UP
	bne ppr_no
	lda ply_dive_t
	cmp #DIVE_ANIM_LEN/2
	bcc ppr_yes
ppr_no:
	lda #0
	rts
ppr_yes:
	lda #1
	rts

; ===== player_sprite =====
; Choose Ollie's frame and color and write the sprite shadow.
player_sprite:
	ldx ply_dive
	beq psp_swim
	cpx #DIVE_UNDER
	beq psp_under
	; going down (t 0..11 -> frames 0..2) or up (reverse)
	lda ply_dive_t
	lsr
	lsr			; 0..2
	cpx #DIVE_UP
	bne psp_down
	eor #$FF
	sec
	adc #2			; 2 - t/4
psp_down:
	tax
	lda ollie_dive_frames,x
	ldy #COL_BROWN
	bne psp_store
psp_under:
	lda ply_anim
	lsr
	lsr
	lsr
	and #1
	tax
	lda ollie_under_frames,x
	ldy #COL_DARK_GREY
	bne psp_store
psp_swim:
	; leaning while steering hard
	lda ply_vx
	bmi psp_neg
	cmp #48
	bcc psp_cycle
	lda #SPR_OLLIE_RIGHT
	bne psp_brown
psp_neg:
	cmp #256-48
	bcs psp_cycle
	lda #SPR_OLLIE_LEFT
	bne psp_brown
psp_cycle:
	; swim cycle, faster at higher speed
	lda ply_anim
	ldx ply_speed
	beq psp_slow
	cpx #2
	beq psp_fast
	lsr
psp_slow:
	lsr
psp_fast:
	lsr
	lsr
	and #3
	tax
	lda ollie_swim_frames,x
psp_brown:
	ldy #COL_BROWN
psp_store:
	sta SPR_SH_PTR+SPR_N_OLLIE
	; crawfish power: cycle bright colors
	lda ply_invuln
	beq psp_no_inv
	lda frame_count
	lsr
	and #3
	tax
	ldy invuln_colors,x
psp_no_inv:
	sty SPR_SH_COLOR+SPR_N_OLLIE
	; hurt: blink every 4 frames
	lda SPR_SH_ENABLE
	ora #1<<SPR_N_OLLIE
	ldx ply_hurt
	beq psp_visible
	ldx frame_count
	txa
	and #4
	beq psp_on
	lda SPR_SH_ENABLE
	and #$FF-(1<<SPR_N_OLLIE)
	jmp psp_visible
psp_on:
	lda SPR_SH_ENABLE
	ora #1<<SPR_N_OLLIE
psp_visible:
	sta SPR_SH_ENABLE
	; position
	lda ply_y
	sta SPR_SH_Y+SPR_N_OLLIE
	lda ply_x
	ldx #SPR_N_OLLIE
	jmp sprite_set_mcx

dive_free_tab:
	.byte DIVE_FREE, DIVE_FREE*6/5
invuln_tab:
	.byte INVULN_FRAMES, 255	; 60 Hz: 255 frames = 4.25 s (one byte)
dive_free:
	.byte DIVE_FREE
invuln_frames:
	.byte INVULN_FRAMES

ollie_swim_frames:
	.byte SPR_OLLIE_SWIM0, SPR_OLLIE_SWIM1
	.byte SPR_OLLIE_SWIM2, SPR_OLLIE_SWIM3
ollie_dive_frames:
	.byte SPR_OLLIE_DIVE0, SPR_OLLIE_DIVE1, SPR_OLLIE_DIVE2
ollie_under_frames:
	.byte SPR_OLLIE_UNDER0, SPR_OLLIE_UNDER1
invuln_colors:
	.byte COL_YELLOW, COL_WHITE, COL_ORANGE, COL_LIGHT_RED

; ===== lp_sub / lp_add =====
; Life Points -= / += X:A (16 bit), clamped to 0..LP_MAX.
LP_MAX           = 10000
LP_START         = 1000
lp_sub:
	sta zp_t0
	stx zp_t1
	sec
	lda lp_lo
	sbc zp_t0
	sta lp_lo
	lda lp_hi
	sbc zp_t1
	sta lp_hi
	bcs lps_done
	lda #0
	sta lp_lo
	sta lp_hi
lps_done:
	rts

lp_add:
	sta zp_t0
	stx zp_t1
	clc
	lda lp_lo
	adc zp_t0
	sta lp_lo
	lda lp_hi
	adc zp_t1
	sta lp_hi
	; clamp at LP_MAX
	lda lp_hi
	cmp #>LP_MAX
	bcc lpa_heart
	bne lpa_clamp
	lda lp_lo
	cmp #<LP_MAX
	bcc lpa_heart
lpa_clamp:
	lda #<LP_MAX
	sta lp_lo
	lda #>LP_MAX
	sta lp_hi
lpa_heart:
	; progress toward recovering a lost heart
	clc
	lda heart_prog_lo
	adc zp_t0
	sta heart_prog_lo
	lda heart_prog_hi
	adc zp_t1
	sta heart_prog_hi
	rts

; ===== player_fx =====
; The effect sprite around Ollie: a splash when he dives or
; surfaces, bubbles while under, twinkles while invulnerable.
FX_SPLASH_TIME   = 12

player_fx:
	lda fx_bump_t
	beq pfx_bump
	dec fx_bump_t
pfx_bump:
	lda ply_bump
	beq pfx_show
	lda fx_bump_t
	bne pfx_show
	lda #12
	sta fx_bump_t
	lda #SFX_BANK_BUMP
	jsr sfx_play
pfx_show:
	lda fx_splash_t
	beq pfx_no_splash
	dec fx_splash_t
	; splash frames 0..2 over the splash time
	lda #FX_SPLASH_TIME-1
	sec
	sbc fx_splash_t
	lsr
	lsr
	tax
	lda splash_frames,x
	ldy #COL_WHITE
	ldx #1			; multicolor
	jmp pfx_place
pfx_no_splash:
	lda ply_dive
	cmp #DIVE_UNDER
	bne pfx_no_bubbles
	lda ply_anim
	lsr
	lsr
	lsr
	and #1
	tax
	lda bubble_frames,x
	ldy #COL_LIGHT_BLUE
	ldx #0			; hires
	jmp pfx_place
pfx_no_bubbles:
	lda ply_invuln
	beq pfx_off
	; warn when the protection is about to end
	cmp #50
	bcs pfx_twinkle
	and #15
	bne pfx_twinkle
	lda #SFX_INVULN_ENDING
	jsr sfx_play
pfx_twinkle:
	lda ply_anim
	lsr
	lsr
	and #3
	tax
	lda sparkle_frames,x
	ldy #COL_YELLOW
	ldx #0
pfx_place:
	sta SPR_SH_PTR+SPR_N_EFFECT
	sty SPR_SH_COLOR+SPR_N_EFFECT
	lda SPR_SH_MCOLOR
	and #$FF-(1<<SPR_N_EFFECT)
	cpx #0
	beq pfx_mc
	ora #1<<SPR_N_EFFECT
pfx_mc:
	sta SPR_SH_MCOLOR
	lda ply_y
	sta SPR_SH_Y+SPR_N_EFFECT
	lda ply_x
	ldx #SPR_N_EFFECT
	jsr sprite_set_mcx
	lda SPR_SH_ENABLE
	ora #1<<SPR_N_EFFECT
	sta SPR_SH_ENABLE
	rts
pfx_off:
	lda SPR_SH_ENABLE
	and #$FF-(1<<SPR_N_EFFECT)
	sta SPR_SH_ENABLE
	rts

splash_frames:
	.byte SPR_SPLASH0, SPR_SPLASH1, SPR_SPLASH2
bubble_frames:
	.byte SPR_BUBBLES0, SPR_BUBBLES1
sparkle_frames:
	.byte SPR_SPARKLE0, SPR_SPARKLE1, SPR_SPARKLE2, SPR_SPARKLE3
