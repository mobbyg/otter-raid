; ==========================================================
; Otter Raid - alligators
;
; A pool of GATOR_MAX independent gators, hardware sprites
; SPR_N_GATOR0.. . A gator surfaces at a bank (LURK), swims
; across (SWIM) and sinks at the far shore or an island (SINK).
; Gators ride the current: their Y grows with scroll_delta.
;
; X is kept in multicolor pixels + GX_OFS so gators can sit
; partly off the playfield edges: sprite X = 24 + 2*(gx-GX_OFS).
; ==========================================================

GATOR_MAX        = 4
GX_OFS           = 16
G_OFF            = 0
G_LURK           = 1
G_SWIM           = 2
G_BITE           = 3
G_SINK           = 4
G_LURK_TIME      = 40		; frames showing only the eyes
G_BITE_TIME      = 24
G_SINK_TIME      = 30
G_HB_L           = 1		; hitbox, MC pixels from sprite left
G_HB_R           = 11
G_HB_T           = 6
G_HB_B           = 16
G_SPAWN_Y_MIN    = 92		; sprite Y range for new gators
G_SPAWN_Y_RANGE  = 56
G_Y_GONE         = 248		; despawn below this
GATOR_DAMAGE     = 100

; per-gator arrays

; ===== gators_reset =====
gators_reset:
	ldx #GATOR_MAX-1
	lda #G_OFF
gr_clear:
	sta g_state,x
	dex
	bpl gr_clear
	lda #100
	sta gator_spawn_t
	rts

; ===== gators_update =====
; Spawn, move, animate and collide all gators; write sprites.
gators_update:
	jsr gator_spawn
	ldx #GATOR_MAX-1
gu_loop:
	stx gu_index
	lda g_state,x
	beq gu_next
	jsr gator_step
	ldx gu_index
gu_next:
	jsr gator_sprite
	ldx gu_index
	dex
	bpl gu_loop
	rts

gu_index:
	.byte 0

; ===== gator_spawn =====
gator_spawn:
	dec gator_spawn_t
	beq gs_try
	rts
gs_try:
	; next attempt: 40..103 frames early, 12..75 late
	lda #40
	sec
	sbc sec_index
	cmp #12
	bcs gs_interval
	lda #12
gs_interval:
	sta zp_t7
	lda #64
	jsr rng_below
	clc
	adc zp_t7
	sta gator_spawn_t
	; no gators at the very start or in the home stretch
	lda river_end
	bne gs_done
	lda top_world+1
	bne gs_free
	lda top_world
	cmp #40
	bcc gs_done
gs_free:
	ldx #GATOR_MAX-1
gs_find:
	lda g_state,x
	beq gs_slot
	dex
	bpl gs_find
gs_done:
	rts
gs_slot:
	stx gs_slot_x
	; random height in the upper playfield
	lda #G_SPAWN_Y_RANGE
	jsr rng_below
	clc
	adc #G_SPAWN_Y_MIN
	ldx gs_slot_x
	sta g_y,x
	; keep away from other gators' lines
	jsr gator_y_clear
	bcs gs_done
	; water limits at that height
	ldx gs_slot_x
	lda g_y,x
	clc
	adc #G_HB_T
	sta zp_t0
	lda g_y,x
	clc
	adc #G_HB_B-1
	sta zp_t1
	jsr river_limits
	; side
	jsr rng_next
	and #1
	bne gs_right_bank
	; Left bank: A=0, so store direction after loading the slot.
	ldx gs_slot_x
	sta g_dir,x
	; left bank, swimming right: head just out of the bank
	lda lim_l
	clc
	adc #GX_OFS-G_HB_R+4
	sta g_x,x
	jmp gs_speed
gs_right_bank:
	; Right bank: A=1 from the random choice; preserve it for direction.
	ldx gs_slot_x
	sta g_dir,x
	lda lim_r
	clc
	adc #GX_OFS-G_HB_L-4
	sta g_x,x
gs_speed:
	; speed 6..13 early, up to 15..22 late (1/16 MC px/frame)
	lda #8
	jsr rng_below
	sta zp_t7
	lda sec_index
	lsr
	lsr
	clc
	adc #6
	adc zp_t7
	ldx gs_slot_x
	sta g_speed,x
	lda #0
	sta g_xf,x
	sta g_anim,x
	lda #G_LURK_TIME
	sta g_timer,x
	lda #G_LURK
	sta g_state,x
	lda #SFX_GATOR_SPLASH
	jsr sfx_play
	rts

gs_slot_x:
	.byte 0

; ===== gator_y_clear =====
; Carry set if another active gator is within 24 lines of the
; new gator's Y (slot gs_slot_x).
gator_y_clear:
	ldx #GATOR_MAX-1
gyc_loop:
	cpx gs_slot_x
	beq gyc_next
	lda g_state,x
	beq gyc_next
	ldy gs_slot_x
	lda g_y,x
	sec
	sbc g_y,y
	bcs gyc_abs
	eor #$FF
	adc #1
gyc_abs:
	cmp #24
	bcc gyc_busy
gyc_next:
	dex
	bpl gyc_loop
	clc
	rts
gyc_busy:
	sec
	rts

; ===== gator_step =====
; One frame for the active gator in X.
gator_step:
	inc g_anim,x
	; drift with the river
	lda g_y,x
	clc
	adc scroll_delta
	bcs gst_gone
	cmp #G_Y_GONE
	bcc gst_on_screen
gst_gone:
	lda #G_OFF
	sta g_state,x
	rts
gst_on_screen:
	sta g_y,x

	lda g_state,x
	cmp #G_LURK
	beq gst_lurk
	cmp #G_SINK
	beq gst_sink
	cmp #G_BITE
	bne gst_swim
	dec g_timer,x
	bne gst_bite_hold
	lda #G_SWIM
	sta g_state,x
gst_bite_hold:
	jmp gst_collide

gst_lurk:
	dec g_timer,x
	bne gst_done
	lda #G_SWIM
	sta g_state,x
	rts

gst_sink:
	dec g_timer,x
	bne gst_done
	lda #G_OFF
	sta g_state,x
gst_done:
	rts

gst_swim:
	; move: x += +-speed/16 with a 4-bit fraction
	lda g_speed,x
	sta zp_t0
	lda g_dir,x
	bne gst_left
	lda g_xf,x
	clc
	adc zp_t0
	tay
	and #$0F
	sta g_xf,x
	tya
	lsr
	lsr
	lsr
	lsr
	clc
	adc g_x,x
	sta g_x,x
	jmp gst_shore
gst_left:
	lda g_xf,x
	sec
	sbc zp_t0
	tay
	and #$0F
	sta g_xf,x
	tya
	; arithmetic shift right by 4 of a negative/positive byte
	cmp #$80
	ror
	cmp #$80
	ror
	cmp #$80
	ror
	cmp #$80
	ror
	clc
	adc g_x,x
	sta g_x,x

gst_shore:
	; reached the far bank or an island? then sink. The water
	; limits are looked up every 4th frame per gator (staggered).
	txa
	clc
	adc frame_count
	and #3
	beq gst_limits
	jmp gst_collide
gst_limits:
	lda g_y,x
	clc
	adc #G_HB_T
	sta zp_t0
	lda g_y,x
	clc
	adc #G_HB_B-1
	sta zp_t1
	stx gu_index
	jsr river_limits
	ldx gu_index
	lda g_dir,x
	bne gst_check_left
	; moving right: nose = gx - GX_OFS + G_HB_R
	lda g_x,x
	sec
	sbc #GX_OFS-G_HB_R
	cmp lim_r
	bcs gst_start_sink
	; island ahead?
	ldy lim_il
	cpy lim_ir
	beq gst_collide
	cmp lim_il
	bcc gst_collide
	lda g_x,x
	sec
	sbc #GX_OFS-G_HB_L
	cmp lim_il
	bcs gst_collide		; already past the island's left shore
	bcc gst_start_sink
gst_check_left:
	lda g_x,x
	sec
	sbc #GX_OFS-G_HB_L
	bcc gst_start_sink
	cmp lim_l
	bcc gst_start_sink
	ldy lim_il
	cpy lim_ir
	beq gst_collide
	cmp lim_ir
	bcs gst_collide
	lda g_x,x
	sec
	sbc #GX_OFS-G_HB_R
	cmp lim_ir
	bcc gst_collide
gst_start_sink:
	lda #G_SINK
	sta g_state,x
	lda #G_SINK_TIME
	sta g_timer,x
	rts

gst_collide:
	; overlap with Ollie's hitbox?
	lda g_state,x
	cmp #G_SWIM
	bne gst_no_hit
	; x: gator [gx-OFS+HB_L, gx-OFS+HB_R) vs Ollie [px+3, px+9)
	lda g_x,x
	sec
	sbc #GX_OFS-G_HB_L
	sta zp_t0		; gator left
	clc
	adc #G_HB_R-G_HB_L
	sta zp_t1		; gator right (exclusive)
	lda ply_x
	clc
	adc #PLY_HB_R
	cmp zp_t0
	bcc gst_no_hit
	beq gst_no_hit
	lda ply_x
	clc
	adc #PLY_HB_L
	cmp zp_t1
	bcs gst_no_hit
	; y
	lda g_y,x
	clc
	adc #G_HB_T
	sta zp_t0
	clc
	adc #G_HB_B-G_HB_T
	sta zp_t1
	lda ply_y
	clc
	adc #PLY_HB_B
	cmp zp_t0
	bcc gst_no_hit
	beq gst_no_hit
	lda ply_y
	clc
	adc #PLY_HB_T
	cmp zp_t1
	bcs gst_no_hit
	; contact: protected (or carried-off) Ollie is safe
	lda e_state
	cmp #E_CARRY
	beq gst_no_hit
	jsr player_protected
	bne gst_no_hit
	lda ply_hurt
	bne gst_no_hit
	ldx gu_index
	lda #G_BITE
	sta g_state,x
	lda #G_BITE_TIME
	sta g_timer,x
	jsr player_hit_gator
gst_no_hit:
	rts

; ===== gator_sprite =====
; Shadow registers for gator X (also when inactive: disable).
gator_sprite:
	txa
	clc
	adc #SPR_N_GATOR0
	tay			; hardware sprite number
	lda g_state,x
	bne gsp_on
	lda bit_masks,y
	eor #$FF
	and SPR_SH_ENABLE
	sta SPR_SH_ENABLE
	rts
gsp_on:
	lda bit_masks,y
	ora SPR_SH_ENABLE
	sta SPR_SH_ENABLE
	; frame
	lda g_state,x
	cmp #G_SWIM
	beq gsp_swim
	cmp #G_BITE
	beq gsp_bite
	; LURK / SINK: eyes only
	lda g_dir,x
	beq gsp_lurk_r
	lda #SPR_GATOR_LURK_L
	bne gsp_ptr
gsp_lurk_r:
	lda #SPR_GATOR_LURK_R
	bne gsp_ptr
gsp_bite:
	lda g_dir,x
	beq gsp_bite_r
	lda #SPR_GATOR_BITE_L
	bne gsp_ptr
gsp_bite_r:
	lda #SPR_GATOR_BITE_R
	bne gsp_ptr
gsp_swim:
	lda g_anim,x
	lsr
	lsr
	lsr
	and #3
	sty zp_t2
	tay
	lda gator_cycle,y
	ldy g_dir,x
	beq gsp_swim_r
	clc
	adc #3			; L frames follow in gator_frames
gsp_swim_r:
	tay
	lda gator_frames,y
	ldy zp_t2
gsp_ptr:
	sta SPR_SH_PTR,y
	lda #COL_GREEN
	sta SPR_SH_COLOR,y
	lda g_y,x
	sta SPR_SH_Y,y
	; sprite X = 2*gx + 24 - 2*GX_OFS (16 bit)
	lda g_x,x
	asl
	sta zp_t0
	lda #0
	rol
	sta zp_t1
	lda zp_t0
	clc
	adc #<(24-2*GX_OFS)
	sta zp_t0
	lda zp_t1
	adc #>(24-2*GX_OFS)
	sta zp_t1
	stx zp_t3
	tya
	tax
	jsr sprite_set_x16
	ldx zp_t3
	rts

gator_cycle:
	.byte 0, 1, 2, 1
gator_frames:
	.byte SPR_GATOR_R0, SPR_GATOR_R1, SPR_GATOR_R2
	.byte SPR_GATOR_L0, SPR_GATOR_L1, SPR_GATOR_L2

; ===== player_hit_gator =====
; Ollie was bitten: lose Life Points, short grace, sounds.
player_hit_gator:
	lda #<GATOR_DAMAGE
	ldx #>GATOR_DAMAGE
	jsr lp_sub
	lda #HURT_FRAMES
	sta ply_hurt
	lda #0
	sta safe_rows
	lda #SFX_GATOR_CHOMP
	jsr sfx_play
	rts
