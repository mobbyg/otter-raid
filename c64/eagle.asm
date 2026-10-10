; ==========================================================
; Otter Raid - the eagle
;
; Every 90-120 s the eagle screeches (WARN) and then swoops in
; a V from a random top corner: a straight dive toward the
; spot where Ollie was when the dive began, then a straight
; climb out on the far side. Diving or crawfish protection
; makes Ollie safe. A catch carries Ollie away (CARRY).
;
; The eagle and its shadow are X/Y-expanded sprites. e_x is a
; 16-bit sprite X with an 8-bit fraction, e_y likewise.
; ==========================================================

E_WAIT           = 0
E_WARN           = 1
E_SWOOP          = 2
E_CARRY          = 3
E_WARN_TIME      = 60
E_HALF           = 64		; frames down (and up) the V
E_CATCH_FROM     = E_HALF-10
E_CATCH_TO       = E_HALF+10
E_TALON_DX       = 24		; talons relative to sprite X/Y
E_TALON_DY       = 34		; (expanded sprite is 48 x 42)
E_CATCH_DIST     = 14
E_CARRY_TIME     = 70
E_START_Y        = 22		; above the visible top (border)
E_MIN_WAIT       = 4500		; 90 s at 50 Hz


; ===== eagle_reset =====
; New run: no eagle, fresh attack timer.
eagle_reset:
	lda #E_WAIT
	sta e_state
	; timer = E_MIN_WAIT + random(0..255) * 6  (up to ~30 s)
	jsr rng_next
	sta zp_t0
	lda #0
	sta zp_t1
	asl zp_t0
	rol zp_t1		; r*2
	lda zp_t0
	sta zp_t2
	lda zp_t1
	sta zp_t3
	asl zp_t0
	rol zp_t1		; r*4
	clc
	lda zp_t0
	adc zp_t2
	sta zp_t0
	lda zp_t1
	adc zp_t3
	sta zp_t1		; r*6
	clc
	lda zp_t0
	adc #<E_MIN_WAIT
	sta e_timer_lo
	lda zp_t1
	adc #>E_MIN_WAIT
	sta e_timer_hi
	rts

; ===== eagle_update =====
eagle_update:
	inc e_anim
	ldx e_state
	beq eu_wait
	dex
	beq eu_warn_j
	dex
	bne eu_carry_j
	jmp eu_swoop
eu_warn_j:
	jmp eu_warn
eu_carry_j:
	jmp eagle_carry

eu_wait:
	lda river_end		; leave the home stretch in peace
	bne eu_hide
	lda e_timer_lo
	bne eu_dec
	lda e_timer_hi
	beq eu_start_warn
	dec e_timer_hi
eu_dec:
	dec e_timer_lo
eu_hide:
	lda SPR_SH_ENABLE
	and #$FF-(1<<SPR_N_EAGLE)-(1<<SPR_N_SHADOW)
	sta SPR_SH_ENABLE
	rts

eu_start_warn:
	lda #E_WARN
	sta e_state
	lda #0
	sta e_t
	jsr rng_next
	and #1
	sta e_side		; attack side, telegraphed by the shadow
	lda #SFX_EAGLE_SCREECH
	jsr sfx_play
	lda #MUS_EAGLE
	jsr music_play
	jmp eu_hide

eu_warn:
	inc e_t
	lda e_t
	cmp #E_WARN_TIME
	bcc eu_telegraph
	jmp eagle_launch
eu_telegraph:
	; the eagle's shadow slides in over the water from its side
	lda #SPR_EAGLE_SHADOW0
	sta SPR_SH_PTR+SPR_N_SHADOW
	lda #COL_DARK_GREY
	sta SPR_SH_COLOR+SPR_N_SHADOW
	lda ply_y
	sec
	sbc #70
	sta SPR_SH_Y+SPR_N_SHADOW
	lda e_t			; 0..59 -> 2 px per frame inward
	asl
	ldx e_side
	beq eut_left
	eor #$FF		; from the right: 344 - 2t
	clc
	adc #<(344+1)
	sta zp_t0
	lda #>(344+1)
	adc #$FF
	sta zp_t1
	jmp eut_x
eut_left:
	sec
	sbc #48			; from the left: 2t - 48 (offscreen first)
	sta zp_t0
	lda #0
	sbc #0
	and #$01		; 9-bit sprite X wraps into the border
	sta zp_t1
eut_x:
	ldx #SPR_N_SHADOW
	jsr sprite_set_x16
	lda SPR_SH_ENABLE
	and #$FF-(1<<SPR_N_EAGLE)
	ora #1<<SPR_N_SHADOW
	sta SPR_SH_ENABLE
	lda SPR_SH_EXPX
	ora #1<<SPR_N_SHADOW
	sta SPR_SH_EXPX
	lda SPR_SH_EXPY
	ora #1<<SPR_N_SHADOW
	sta SPR_SH_EXPY
	rts

eu_swoop:
	jsr eagle_move
	inc e_t
	lda e_t
	cmp #2*E_HALF
	bcs eagle_done
	; catch window around the bottom of the V
	cmp #E_CATCH_FROM
	bcc eu_draw
	cmp #E_CATCH_TO
	bcs eu_draw
	jsr eagle_check_catch
eu_draw:
	jmp eagle_sprites

; ===== eagle_done =====
; Swoop over without a catch: bonus, back to waiting.
eagle_done:
	lda #$00
	ldx #$10		; 1000 points
	jsr score_add
	jsr eagle_reset
	lda #MUS_RIVER
	jsr music_play
	jmp eu_hide

; ===== eagle_launch =====
; Pick a corner and aim the V at Ollie's current position.
eagle_launch:
	lda #E_SWOOP
	sta e_state
	lda #0
	sta e_t
	sta e_xf
	sta e_yf
	lda #E_START_Y
	sta e_y
	lda #SFX_EAGLE_SWOOP
	jsr sfx_play

	; target sprite position so the talons meet Ollie's center:
	; tx = 24 + 2*ply_x + 12 - E_TALON_DX, ty = ply_y + 10 - DY
	lda ply_x
	asl
	sta zp_t0
	lda #0
	rol
	sta zp_t1
	lda zp_t0
	clc
	adc #24+12-E_TALON_DX
	sta zp_t0
	lda zp_t1
	adc #0
	sta zp_t1		; zp_t0/1 = target x

	; start corner: the side the shadow came from
	lda e_side
	beq el_left
	lda #<344
	sta e_xl
	lda #>344
	sta e_xh
	jmp el_dx
el_left:
	lda #0
	sta e_xl
	sta e_xh
el_dx:
	; dx = (target - start) / 64 as 8.8: (diff << 2) >> 8 ...
	; i.e. 16-bit diff * 4 gives the 8.8 step directly.
	lda zp_t0
	sec
	sbc e_xl
	sta e_dxf
	lda zp_t1
	sbc e_xh
	sta e_dxl
	asl e_dxf
	rol e_dxl
	asl e_dxf
	rol e_dxl
	; dy = (ty - start_y) / 64, ty = ply_y + 10 - E_TALON_DY
	lda ply_y
	clc
	adc #10
	sec
	sbc #E_TALON_DY
	sec
	sbc #E_START_Y
	sta e_dyf
	lda #0
	sta e_dyl
	asl e_dyf
	rol e_dyl
	asl e_dyf
	rol e_dyl
	jmp eagle_sprites

; ===== eagle_move =====
; x += dx always; y += dy on the way down, -dy on the way up.
eagle_move:
	; sign-extended 16-bit dx added to the 24-bit x
	lda e_dxl
	and #$80
	beq em_pos
	lda #$FF
em_pos:
	sta zp_t0
	clc
	lda e_xf
	adc e_dxf
	sta e_xf
	lda e_xl
	adc e_dxl
	sta e_xl
	lda e_xh
	adc zp_t0
	sta e_xh
	lda e_t
	cmp #E_HALF
	bcs em_up
	clc
	lda e_yf
	adc e_dyf
	sta e_yf
	lda e_y
	adc e_dyl
	sta e_y
	rts
em_up:
	sec
	lda e_yf
	sbc e_dyf
	sta e_yf
	lda e_y
	sbc e_dyl
	sta e_y
	rts

; ===== eagle_check_catch =====
eagle_check_catch:
	; talon x = e_x + 24 vs Ollie center 24 + 2*ply_x + 12
	lda e_xl
	clc
	adc #E_TALON_DX
	sta zp_t0
	lda e_xh
	adc #0
	sta zp_t1
	lda ply_x
	asl
	sta zp_t2
	lda #0
	rol
	sta zp_t3
	lda zp_t2
	clc
	adc #24+12
	sta zp_t2
	lda zp_t3
	adc #0
	sta zp_t3
	; |dx| < E_CATCH_DIST ?
	sec
	lda zp_t0
	sbc zp_t2
	tax
	lda zp_t1
	sbc zp_t3
	beq ecc_dx_pos
	cmp #$FF
	bne ecc_miss
	txa
	eor #$FF
	tax
	inx
	jmp ecc_dx
ecc_dx_pos:
	txa
	bmi ecc_miss
ecc_dx:
	cpx #E_CATCH_DIST
	bcs ecc_miss
	; |dy| < E_CATCH_DIST ?
	lda e_y
	clc
	adc #E_TALON_DY
	sec
	sbc ply_y
	sec
	sbc #10
	bcs ecc_dy
	eor #$FF
	adc #1
ecc_dy:
	cmp #E_CATCH_DIST
	bcs ecc_miss
	jsr player_protected
	bne ecc_miss
	; caught!
	lda #E_CARRY
	sta e_state
	lda #0
	sta e_t
	lda #SFX_EAGLE_CATCH
	jsr sfx_play
ecc_miss:
	rts

; ===== eagle_carry =====
; Fly up and away with Ollie, then report the lost heart.
eagle_carry:
	lda #E_HALF
	sta e_t			; keep climbing (em_up branch)
	jsr eagle_move
	; climb fast, then wait out of sight above the screen
	lda e_y
	sec
	sbc #2
	bcc ec_top
	cmp #8
	bcs ec_y
ec_top:
	lda #8
ec_y:
	sta e_y
	; Ollie dangles under the talons
	lda #SPR_OLLIE_CAUGHT
	sta SPR_SH_PTR+SPR_N_OLLIE
	lda #COL_BROWN
	sta SPR_SH_COLOR+SPR_N_OLLIE
	lda e_y
	clc
	adc #E_TALON_DY-4
	sta SPR_SH_Y+SPR_N_OLLIE
	lda e_xl
	clc
	adc #E_TALON_DX-12
	sta zp_t0
	lda e_xh
	adc #0
	sta zp_t1
	ldx #SPR_N_OLLIE
	jsr sprite_set_x16
	inc e_anim
	inc ec_time
	lda ec_time
	cmp #E_CARRY_TIME
	bcc eagle_sprites
	lda #0
	sta ec_time
	lda #LOSS_EAGLE
	sta loss_cause
	lda #E_WAIT
	sta e_state
	jmp eagle_sprites

ec_time:
	.byte 0

; ===== eagle_sprites =====
; Eagle (expanded) and its shadow on the water.
eagle_sprites:
	; frame: flapping, wings tucked near the bottom of the V
	lda e_state
	cmp #E_CARRY
	bne es_not_carry
	lda #SPR_EAGLE_CARRY
	bne es_ptr
es_not_carry:
	lda e_t
	cmp #E_HALF-16
	bcc es_flap
	cmp #E_HALF+8
	bcs es_flap
	lda #SPR_EAGLE_DIVE
	bne es_ptr
es_flap:
	lda e_anim
	lsr
	lsr
	and #3
	tax
	lda eagle_flap,x
es_ptr:
	sta SPR_SH_PTR+SPR_N_EAGLE
	lda #COL_BROWN
	sta SPR_SH_COLOR+SPR_N_EAGLE
	lda e_y
	sta SPR_SH_Y+SPR_N_EAGLE
	lda e_xl
	sta zp_t0
	lda e_xh
	sta zp_t1
	ldx #SPR_N_EAGLE
	jsr sprite_set_x16

	; shadow: offset grows with the eagle's height above the
	; water, h = |E_HALF - e_t| (0 at the bottom of the V)
	lda e_t
	sec
	sbc #E_HALF
	bcs es_h
	eor #$FF
	adc #1
es_h:
	lsr
	sta zp_t2		; h / 2
	lda frame_count
	and #1
	sta zp_t3
	lda e_anim
	and #8
	lsr
	lsr
	lsr
	tax
	lda eagle_shadow,x
	sta SPR_SH_PTR+SPR_N_SHADOW
	lda #COL_DARK_GREY
	sta SPR_SH_COLOR+SPR_N_SHADOW
	lda e_y
	clc
	adc zp_t2
	adc zp_t2
	adc #8
	sta SPR_SH_Y+SPR_N_SHADOW
	lda e_xl
	clc
	adc zp_t2
	sta zp_t0
	lda e_xh
	adc #0
	sta zp_t1
	ldx #SPR_N_SHADOW
	jsr sprite_set_x16
	lda SPR_SH_ENABLE
	ora #(1<<SPR_N_EAGLE)|(1<<SPR_N_SHADOW)
	sta SPR_SH_ENABLE
	lda SPR_SH_EXPX
	ora #(1<<SPR_N_EAGLE)|(1<<SPR_N_SHADOW)
	sta SPR_SH_EXPX
	sta SPR_SH_EXPY
	rts

eagle_flap:
	.byte SPR_EAGLE0, SPR_EAGLE1, SPR_EAGLE2, SPR_EAGLE3
eagle_shadow:
	.byte SPR_EAGLE_SHADOW0, SPR_EAGLE_SHADOW1
