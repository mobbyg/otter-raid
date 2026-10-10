; ==========================================================
; Otter Raid - game states and the per-frame game logic
;
; game_frame runs once per frame and dispatches on game_state.
; See docs/c64-state-machine.md.
; ==========================================================

ST_TITLE         = 0
ST_PLAYING       = 1
ST_PAUSED        = 2
ST_LIFE_LOST     = 3
ST_GAME_OVER     = 4
ST_HOME          = 5
ST_HIGH_SCORES   = 6

LOSS_NONE        = 0
LOSS_LP          = 1
LOSS_EAGLE       = 2

SAFE_ROWS_NEEDED = 16		; rows without a hit before recovery
LP_PER_ROW       = 5
HEART_COST       = 5000		; LP to earn back a lost heart
CRAWFISH_POINTS  = $05		; 500 (BCD hundreds byte)
LIFE_LOST_TIME   = 150

; ===== game_frame =====
game_frame:
	inc state_t
	lda game_state
	asl
	tax
	lda state_table+1,x
	pha
	lda state_table,x
	pha
	rts			; jump to handler

state_table:
	.word state_title-1, state_playing-1, state_paused-1
	.word state_life_lost-1, state_game_over-1, state_home-1
	.word state_high_scores-1

; ===== set_state =====
; A = new state.
set_state:
	sta game_state
	lda #0
	sta state_t
	rts

; ===== game_start =====
; New game from the title: score 0, three hearts.
game_start:
	lda #0
	sta idle_seq
	sta gifts
	sta score
	sta score+1
	sta score+2
	sta run_seed
	lda #3
	sta hearts
	jmp game_new_run

; ===== game_new_run =====
; Fresh river from the start, Ollie at the bottom. Keeps score
; and hearts.
game_new_run:
	lda #DM_BLANK
	sta disp_mode
	jsr frame_end		; display off before redrawing
	jsr river_init
	jsr display_init
	jsr player_reset
	jsr gators_reset
	jsr eagle_reset
	lda #<LP_START
	sta lp_lo
	lda #>LP_START
	sta lp_hi
	lda #0
	sta heart_prog_lo
	sta heart_prog_hi
	sta safe_rows
	sta loss_cause
	sta pop_t
	sta SPR_SH_XMSB
	sta SPR_SH_EXPX
	sta SPR_SH_EXPY
	sta SPR_SH_PRIO
	lda #%01111111		; all multicolor except the shadow
	sta SPR_SH_MCOLOR
	lda #1<<SPR_N_OLLIE
	sta SPR_SH_ENABLE
	lda top_world
	sta last_top
	jsr hud_draw_all
	jsr player_sprite
	lda demo_mode
	beq gnr_ready
	lda #<900		; demo: show the eagle after ~18 s
	sta e_timer_lo
	lda #>900
	sta e_timer_hi
gnr_ready:
	lda #READY_TIME
	sta ready_t
	lda sec_index
	sta last_sec
	lda #DM_GAME
	sta disp_mode
	lda #MUS_RIVER
	jsr music_play
	lda #ST_PLAYING
	jmp set_state

; ===== state_playing =====
READY_TIME       = 90		; "GET READY" pause before a run
state_playing:
	jsr demo_check_end
	bcc sp_play
	jmp title_enter
sp_play:
	lda ready_t
	beq sp_go
	dec ready_t
	bne sp_ready
	jsr hud_draw_all	; message off, river starts
	jmp sp_go
sp_ready:
	jsr river_animate
	jsr player_sprite
	lda ready_t
	and #16
	beq sp_ready_off
	ldx #T_GET_READY
	jmp print_text
sp_ready_off:
	jmp hud_draw_all
sp_go:
	jsr display_advance
	jsr river_animate
	lda demo_mode
	beq sp_human
	jsr demo_ai
sp_human:
	lda e_state
	cmp #E_CARRY
	beq sp_carried		; Ollie is in the eagle's talons
	jsr player_update
sp_carried:
	jsr gators_update
	jsr eagle_update
	jsr play_progress
	lda e_state
	cmp #E_CARRY
	beq sp_no_pickup
	jsr player_pickup
sp_no_pickup:
	jsr pop_update
	jsr hud_update

	; pause
	lda in_new
	and #IN_PAUSE
	beq sp_no_pause
	lda #1
	jsr sound_pause
	ldx #T_PAUSED
	jsr print_text
	lda #ST_PAUSED
	jmp set_state
sp_no_pause:
	; out of Life Points?
	lda lp_lo
	ora lp_hi
	bne sp_lp_ok
	lda #LOSS_LP
	sta loss_cause
sp_lp_ok:
	lda loss_cause
	beq sp_home
	jmp lose_heart
sp_home:
	; journey's end: the home row has reached Ollie
	lda river_end
	beq sp_done
	lda top_world
	sec
	sbc home_row_lo
	tax
	lda top_world+1
	sbc home_row_hi
	bcc sp_done
	bne sp_arrive
	cpx #18			; screen rows from the top to Ollie
	bcc sp_done
sp_arrive:
	lda #0
	sta home_t_hi
	lda #MUS_HOME
	jsr music_play
	lda #ST_HOME
	jmp set_state
sp_done:
	rts

; ===== play_progress =====
; Per scrolled row: distance points, Life Point recovery and
; earning lost hearts back.
play_progress:
	lda top_world
	cmp last_top
	beq pp_done
	sta last_top
	; 10 points per row
	lda #$10
	ldx #$00
	jsr score_add
	lda safe_rows
	cmp #255
	beq pp_safe
	inc safe_rows
pp_safe:
	lda safe_rows
	cmp #SAFE_ROWS_NEEDED
	bcc pp_done
	lda #LP_PER_ROW
	ldx #0
	jsr lp_add
	; earned a heart back?
	lda hearts
	cmp #3
	bcs pp_full
	lda heart_prog_lo
	cmp #<HEART_COST
	lda heart_prog_hi
	sbc #>HEART_COST
	bcc pp_done
	sta heart_prog_hi
	lda heart_prog_lo
	sec
	sbc #<HEART_COST
	sta heart_prog_lo
	inc hearts
	lda #SFX_HEART_GAINED
	jsr sfx_play
pp_done:
	; a new river section reached
	lda sec_index
	cmp last_sec
	beq pp_same_sec
	sta last_sec
	lda #SFX_MILESTONE
	jsr sfx_play
pp_same_sec:
	rts
pp_full:
	lda #0
	sta heart_prog_lo
	sta heart_prog_hi
	rts

; ===== player_pickup =====
; Crawfish under Ollie's head? Chars live in both screen buffers.
player_pickup:
	; column under Ollie's center
	lda ply_x
	clc
	adc #6
	lsr
	lsr
	sta zp_t2
	; screen row of the head line
	lda #PLAY_TOP_LINE
	clc
	adc fine_pos
	sta zp_t0
	lda ply_y
	clc
	adc #4
	sec
	sbc zp_t0
	bcc ppk_done
	lsr
	lsr
	lsr
	clc
	adc #PLAY_FIRST_ROW
	sta zp_t3
	; rows r and r+1 of the buffer being shown
	jsr ppk_check
	inc zp_t3
	jsr ppk_check
ppk_done:
	rts

ppk_check:
	ldx zp_t3
	cpx #PLAY_LAST_ROW+1
	bcc ppk_row
	rts
ppk_row:
	ldy front_buf
	jsr row_ptr		; zp_ptr0 = row X of buffer Y
	ldy zp_t2
	lda (zp_ptr0),y
	jsr pickup_class
	bne ppk_found
	rts
ppk_found:
	bcc ppk_left
	dey			; right half: step to the left half
ppk_left:
	sty zp_t4
	lda (zp_ptr0),y
	sta pk_left
	jsr pickup_erase	; in the shown buffer
	; the back buffer may already hold this row one lower
	ldx zp_t3
	inx
	cpx #PLAY_LAST_ROW+1
	bcs ppk_reward
	lda front_buf
	eor #1
	tay
	jsr row_ptr
	jsr pickup_erase
ppk_reward:
	; a ring pops where the pickup was
	lda zp_t3
	sec
	sbc #PLAY_FIRST_ROW
	sta zp_t0
	lda top_world
	sec
	sbc zp_t0
	sta pop_world
	lda top_world+1
	sbc #0
	sta pop_world+1
	lda zp_t4
	sta pop_col
	lda #POP_TIME
	sta pop_t
	lda pk_kind
	cmp #PK_FISH
	beq ppk_fish
	cmp #PK_GIFT
	beq ppk_gift
	; crawfish: invulnerable for a while
	lda invuln_frames
	sta ply_invuln
	lda #$00
	ldx #CRAWFISH_POINTS
	jsr score_add
	lda #SFX_CRAWFISH_PICKUP
	jmp sfx_play
ppk_fish:
	; a snack: Life Points
	lda #<FISH_LP
	ldx #>FISH_LP
	jsr lp_add
	lda #$00
	ldx #$01		; 100 points
	jsr score_add
	lda #SFX_FISH_EAT
	jmp sfx_play
ppk_gift:
	; a present for Auntie
	inc gifts
	lda #$00
	ldx #$10		; 1000 points
	jsr score_add
	lda #SFX_GIFT
	jmp sfx_play
ppk_none:
	rts

; ===== pickup_class =====
; A = screen code. Out: pk_kind = PK_* (A = it, Z set when
; none); carry set = right half of the pair. Keeps Y.
PK_NONE          = 0
PK_CRAWFISH      = 1
PK_FISH          = 2
PK_GIFT          = 3
FISH_LP          = 250
pickup_class:
	cmp #CH_CRAWFISH_L
	beq pc_craw_l
	cmp #CH_CRAWFISH_R
	beq pc_craw_r
	cmp #CH_FISH_L
	bcc pc_none
	cmp #CH_GIFT_FIRST+2*GIFT_KINDS
	bcs pc_none
	; fish / gifts: pairs start on even codes
	tax
	lda #PK_FISH
	cpx #CH_GIFT_FIRST
	bcc pc_kind
	lda #PK_GIFT
pc_kind:
	sta pk_kind
	txa
	sec
	sbc #CH_FISH_L
	lsr			; carry = odd = right half
	lda pk_kind
	rts
pc_craw_l:
	lda #PK_CRAWFISH
	sta pk_kind
	clc
	rts
pc_craw_r:
	lda #PK_CRAWFISH
	sta pk_kind
	sec
	rts
pc_none:
	lda #PK_NONE
	sta pk_kind
	rts

; ===== pop_update =====
; Animate the collection ring (CH_POP0..2) where a crawfish
; was eaten; it rides the scroll by tracking its world row.
POP_TIME         = 18		; 3 frames of 6
pop_update:
	lda pop_t
	beq pu_done
	dec pop_t
	; screen row = 2 + (top_world - pop_world)
	lda top_world
	sec
	sbc pop_world
	tax
	lda top_world+1
	sbc pop_world+1
	bne pu_gone
	txa
	clc
	adc #PLAY_FIRST_ROW
	cmp #PLAY_LAST_ROW+1
	bcs pu_gone
	sta zp_t3
	; char pair for this stage (water when finished)
	ldy #CH_WATER
	lda pop_t
	beq pu_chars
	lda #POP_TIME-1
	sec
	sbc pop_t
	ldx #0
pu_stage:
	cmp #6
	bcc pu_stage_ok
	sbc #6
	inx
	bne pu_stage
pu_stage_ok:
	txa
	asl
	clc
	adc #CH_POP0_L
	tay
pu_chars:
	sty zp_t5
	; shown buffer, row r
	ldx zp_t3
	ldy front_buf
	jsr row_ptr
	jsr pop_put
	; back buffer, row r + 1 (if it already holds this row)
	ldx zp_t3
	inx
	cpx #PLAY_LAST_ROW+1
	bcs pu_done
	lda front_buf
	eor #1
	tay
	jsr row_ptr
	jmp pop_put
pu_gone:
	lda #0
	sta pop_t
pu_done:
	rts

; write the pop pair zp_t5 (left), zp_t5+1 (right) at pop_col
; unless something else has replaced the cells
pop_put:
	ldy pop_col
	lda (zp_ptr0),y
	cmp #CH_WATER
	beq pp_ok
	cmp #CH_POP0_L
	bcc pp_skip
	cmp #CH_POP2_R+1
	bcs pp_skip
pp_ok:
	lda zp_t5
	sta (zp_ptr0),y
	cmp #CH_WATER
	beq pp_right
	clc
	adc #1
pp_right:
	iny
	sta (zp_ptr0),y
pp_skip:
	rts

; erase the pickup pair (left char pk_left) at column zp_t4 of
; row zp_ptr0, if it is still there
pickup_erase:
	ldy zp_t4
	lda (zp_ptr0),y
	cmp pk_left
	bne pe_done
	lda #CH_WATER
	sta (zp_ptr0),y
	iny
	sta (zp_ptr0),y
pe_done:
	rts

; ===== row_ptr =====
; zp_ptr0 = start of screen row X in buffer Y (0 = A, 1 = B).
row_ptr:
	lda row_addr_lo,x
	sta zp_ptr0
	lda row_addr_hi,x
	cpy #0
	beq rp_a
	clc
	adc #>(SCREEN_B-SCREEN_A)
rp_a:
	sta zp_ptr0+1
	rts

; ===== score_add =====
; score += X:A as BCD (X = hundreds/thousands, A = tens/units).
score_add:
	sta zp_t0
	stx zp_t1
	php
	sei
	sed
	clc
	lda score
	adc zp_t0
	sta score
	lda score+1
	adc zp_t1
	sta score+1
	lda score+2
	adc #0
	sta score+2
	cld
	plp
	rts

; ===== lose_heart =====
; A hazard ended the run.
lose_heart:
	lda demo_mode
	beq lh_real
	lda #0
	sta demo_mode
	jmp title_enter		; the demo ends at the first mishap
lh_real:
	dec hearts
	lda #0
	sta heart_prog_lo
	sta heart_prog_hi
	lda #MUS_LIFE_LOST
	jsr music_play
	lda #ST_LIFE_LOST
	jmp set_state

; ===== state_paused =====
state_paused:
	lda in_new
	and #IN_PAUSE
	beq spa_done
	lda #0
	jsr sound_pause
	jsr hud_draw_all
	lda #ST_PLAYING
	jmp set_state
spa_done:
	rts

; ===== state_life_lost =====
; Ollie faints (or was carried off); after a pause restart the
; run, or end the game when no hearts are left.
state_life_lost:
	jsr hud_update
	lda loss_cause
	cmp #LOSS_EAGLE
	beq sll_wait		; Ollie already gone with the eagle
	; fainted: spin through the hurt frame and fade
	lda #SPR_OLLIE_HURT
	sta SPR_SH_PTR+SPR_N_OLLIE
	lda state_t
	lsr
	lsr
	and #7
	tax
	lda faint_colors,x
	sta SPR_SH_COLOR+SPR_N_OLLIE
sll_wait:
	lda state_t
	cmp #LIFE_LOST_TIME
	bcc sll_done
	lda hearts
	beq sll_over
	inc run_seed		; a different river next time
	jmp game_new_run
sll_over:
	lda #MUS_GAME_OVER
	jsr music_play
	lda #ST_GAME_OVER
	jmp set_state
sll_done:
	rts

faint_colors:
	.byte COL_BROWN, COL_ORANGE, COL_BROWN, COL_LIGHT_RED
	.byte COL_BROWN, COL_GREY, COL_DARK_GREY, COL_BLUE

; ===== state_game_over =====
state_game_over:
	ldx #T_GAME_OVER
	jsr print_text
	lda state_t
	cmp #200
	bcc sgo_done
	jsr hiscore_check
	lda #ST_TITLE
	jmp set_state
sgo_done:
	rts

