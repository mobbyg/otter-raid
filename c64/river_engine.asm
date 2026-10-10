; ==========================================================
; Otter Raid - river world generator and row renderer
;
; The journey is SECTION_COUNT sections of SECTION_LEN rows.
; Each section eases (smoothstep) the river center and width
; from its start to a target; island sections grow and shrink
; an island in the middle. Bank edges are sampled once per row
; boundary in multicolor pixels (0-159) and rate limited to
; EDGE_STEP pixels per row so the generated edge tiles apply.
;
; Boundary n is the bottom edge of world row n. Building world
; row w needs boundaries w and w+1. Rows are built LOOKAHEAD
; rows before they are shown so multi-row scenery stamps can
; be placed into rows that are not on screen yet.
; ==========================================================

SECTION_COUNT    = 40
SECTION_LEN      = 64
LOOKAHEAD        = 5
EDGE_STEP        = 2
RIVER_MIN_L      = 8		; leftmost left bank (MC pixels)
RIVER_MAX_R      = 152		; rightmost right bank
MIN_CHANNEL      = 30		; narrowest channel beside an island
WIDTH_MIN        = 48
WIDTH_MAX        = 128
ISLAND_WIDTH     = 128		; river width while an island is up
ISLAND_MIN_SHOW  = 8		; island narrower than this is water
RIPPLE_CHANCE    = 20		; of 256: open water cells with glints
LAND_VAR_CHANCE  = 48		; of 256: grass cells with variation

KIND_STRAIGHT    = 0
KIND_BEND        = 1
KIND_WIDTH       = 2
KIND_PRE_ISLAND  = 3
KIND_ISLAND      = 4
KIND_HOME        = 5

; render scratch: edge spans of the row being built

; class lists of stamp ids (built by river_init)

; ===== rng_next =====
; 16-bit Galois LFSR (taps $B400). Returns a byte in A.
; Preserves X and Y.
rng_next:
	lsr rng_hi
	ror rng_lo
	bcc rn_done
	lda rng_hi
	eor #$B4
	sta rng_hi
rn_done:
	lda rng_lo
	eor rng_hi
	rts

; ===== rng_below =====
; A = random number in 0..A-1 (A = 0 means 0..255).
rng_below:
	sta zp_t2
	jsr rng_next
	sta zp_t4
	lda zp_t2
	beq rb_any
	jsr mul8		; (rnd * n) >> 8
	rts
rb_any:
	lda zp_t4
	rts

; ===== mul8 =====
; zp_t4 * zp_t2 -> A (high byte), zp_t5 (low byte).
; Clobbers X and zp_t4.
mul8:
	lda #0
	ldx #8
m8_loop:
	lsr zp_t4
	bcc m8_skip
	clc
	adc zp_t2
m8_skip:
	ror
	ror zp_t5
	dex
	bne m8_loop
	rts

; ===== lerp =====
; A = zp_t0 + (zp_t1 - zp_t0) * zp_t2 / 256 (unsigned ends,
; signed difference). Clobbers X, zp_t3-zp_t5.
lerp:
	lda zp_t1
	sec
	sbc zp_t0
	bcc lp_neg
	sta zp_t4
	jsr mul8
	clc
	adc zp_t0
	rts
lp_neg:
	lda zp_t0
	sec
	sbc zp_t1
	sta zp_t4
	jsr mul8
	sta zp_t3
	lda zp_t0
	sec
	sbc zp_t3
	rts

; ===== clamp_step =====
; A = target clamped to zp_t6 +- EDGE_STEP.
clamp_step:
	sec
	sbc zp_t6
	bcc cst_neg
	cmp #EDGE_STEP+1
	bcc cst_add
	lda #EDGE_STEP
	bne cst_add
cst_neg:
	cmp #256-EDGE_STEP
	bcs cst_add
	lda #256-EDGE_STEP
cst_add:
	clc
	adc zp_t6
	rts

; ===== river_init =====
; Start a new journey at world row 0. run_seed varies the river
; between runs. Pre-builds the lookahead rows.
river_init:
	lda run_seed
	eor #$5D
	sta rng_lo
	lda #$C3
	sta rng_hi
	ldx #0
ri_noise:
	jsr rng_next
	sta NOISE,x
	inx
	bne ri_noise

	jsr river_build_classes
	; empty skyline: every column long free
	ldx #39
	lda #256-100
ri_occ:
	sta occ_top,x
	dex
	bpl ri_occ

	lda #0
	sta emit_world
	sta emit_world+1
	sta base_world
	sta base_world+1
	sta sec_index
	sta island_next
	sta river_end
	sta water_frame

	; opening stretch: wide, centered, gentle
	lda #80-52
	sta edge_l
	lda #80+52
	sta edge_r
	lda #80
	sta edge_il
	sta edge_ir
	jsr section_setup_start

	; boundary 0
	ldx #0
	jsr store_boundary

	ldx #LOOKAHEAD
ri_pre:
	txa
	pha
	jsr river_build_row
	pla
	tax
	dex
	bne ri_pre
	rts

; ===== river_build_classes =====
; Sort stamp ids into per-class lists and fill land_var_tab.
river_build_classes:
	lda #0
	sta stamp_counts
	sta stamp_counts+1
	sta stamp_counts+2
	sta stamp_counts+3
	ldx #0
rbc_loop:
	cpx #STAMP_COUNT
	beq rbc_vars
	lda stamp_class,x
	cmp #4
	bcs rbc_next		; SPECIAL stamps are placed by hand
	tay
	lda class_list_lo,y
	sta zp_ptr1
	lda class_list_hi,y
	sta zp_ptr1+1
	lda stamp_counts,y
	cmp #32
	bcs rbc_next
	pha
	clc
	adc #1
	sta stamp_counts,y
	pla
	tay
	txa
	sta (zp_ptr1),y
rbc_next:
	inx
	bne rbc_loop
rbc_vars:
	; repeat each class list to 32 entries: a 5-bit random
	; index then picks uniformly without a multiply
	ldy #3
rbc_cycle:
	lda class_list_lo,y
	sta zp_ptr1
	lda class_list_hi,y
	sta zp_ptr1+1
	lda stamp_counts,y
	beq rbc_cycle_next
	sta zp_t0		; count
	tya
	pha
	ldy zp_t0
rbc_fill:
	cpy #32
	bcs rbc_filled
	tya
	sec
	sbc zp_t0
	sty zp_t1
	tay
	lda (zp_ptr1),y		; entry (i - count)
	ldy zp_t1
	sta (zp_ptr1),y
	iny
	bne rbc_fill
rbc_filled:
	pla
	tay
rbc_cycle_next:
	dey
	bpl rbc_cycle
	ldx #0
	ldy #0
rbc_var_loop:
	tya
	clc
	adc #CH_LAND_VAR_FIRST
	sta land_var_tab,x
	iny
	cpy #CH_LAND_VAR_COUNT
	bcc rbc_var_ok
	ldy #0
rbc_var_ok:
	inx
	cpx #16
	bne rbc_var_loop
	rts

class_list_lo:
	.byte <stamps_land, <stamps_water, <stamps_shore_l, <stamps_shore_r
class_list_hi:
	.byte >stamps_land, >stamps_water, >stamps_shore_l, >stamps_shore_r

; ===== store_boundary =====
; Store the current edge samples at boundary index X & 63.
store_boundary:
	txa
	and #63
	tax
	lda edge_l
	sta BND_L,x
	lda edge_r
	sta BND_R,x
	lda edge_il
	sta BND_IL,x
	lda edge_ir
	sta BND_IR,x
	rts

; ===== section_setup_start / section_setup =====
; Begin a section at the current edges and choose its target.
section_setup_start:
	lda #KIND_STRAIGHT
	sta sec_kind
	jsr section_from_edges
	lda #80
	sta sec_c1
	lda #104
	sta sec_w1
	lda #0
	sta sec_iw
	lda #1
	sta sec_row
	lda #160
	sta scen_rate
	lda #0
	sta fish_rate
	sta gift_rate
	lda #10			; a few snacks from the start
	sta snack_rate
	rts

section_from_edges:
	lda edge_l
	clc
	adc edge_r
	ror
	sta sec_c0
	lda edge_r
	sec
	sbc edge_l
	sta sec_w0
	rts

section_next:
	inc sec_index
	lda #1
	sta sec_row
	jsr section_from_edges
	lda #0
	sta sec_iw
	lda sec_c0
	sta sec_c1
	lda sec_w0
	sta sec_w1

	; difficulty: the river narrows along the journey
	lda #88
	sec
	sbc sec_index
	sta zp_t7		; base width

	lda sec_index
	cmp #SECTION_COUNT-1
	bcc sn_not_home
	lda #KIND_HOME
	sta sec_kind
	lda river_end
	bne sn_home_again
	; the journey ends partway into the final section
	lda base_world
	clc
	adc #SECTION_LEN/2
	sta home_row_lo
	lda base_world+1
	adc #0
	sta home_row_hi
sn_home_again:
	lda #1
	sta river_end
	; leave room on the left bank for Auntie's house
	lda #100
	sta sec_c1
	lda #104
	sta sec_w1
	lda #16
	sta scen_rate
	lda #0
	sta fish_rate
	sta snack_rate
	sta gift_rate
	jmp sn_clamp

sn_not_home:
	lda island_next
	beq sn_pick
	lda #0
	sta island_next
	lda #KIND_ISLAND
	sta sec_kind
	; island takes the width that is left for two channels
	lda sec_w0
	sec
	sbc #2*MIN_CHANNEL
	bcc sn_no_island
	sta sec_iw
sn_no_island:
	jmp sn_rates

sn_pick:
	lda #8
	jsr rng_below
	cmp #3
	bcc sn_bend
	beq sn_straight
	cmp #6
	bcc sn_width
	; island candidate: not too early or near the end
	lda sec_index
	cmp #3
	bcc sn_bend
	cmp #SECTION_COUNT-4
	bcs sn_bend
	lda #KIND_PRE_ISLAND
	sta sec_kind
	lda #1
	sta island_next
	lda #80
	sta sec_c1
	lda #ISLAND_WIDTH
	sta sec_w1
	jmp sn_clamp

sn_straight:
	lda #KIND_STRAIGHT
	sta sec_kind
	lda #16
	jsr rng_below
	sec
	sbc #8
	clc
	adc sec_c0
	sta sec_c1
	lda zp_t7
	sta sec_w1
	jmp sn_clamp

sn_width:
	lda #KIND_WIDTH
	sta sec_kind
	lda #48
	jsr rng_below
	clc
	adc zp_t7
	sec
	sbc #24
	sta sec_w1
	jmp sn_clamp

sn_bend:
	lda #KIND_BEND
	sta sec_kind
	lda #48
	jsr rng_below
	clc
	adc #24
	sta zp_t6		; bend size
	jsr rng_next
	and #1
	beq sn_bend_left
	lda sec_c0
	clc
	adc zp_t6
	sta sec_c1
	jmp sn_bend_w
sn_bend_left:
	lda sec_c0
	sec
	sbc zp_t6
	bcs sn_bend_ok
	lda #0
sn_bend_ok:
	sta sec_c1
sn_bend_w:
	lda #24
	jsr rng_below
	clc
	adc zp_t7
	sec
	sbc #12
	sta sec_w1

sn_clamp:
	; width limits
	lda sec_w1
	cmp #WIDTH_MIN
	bcs sn_w_lo_ok
	lda #WIDTH_MIN
sn_w_lo_ok:
	cmp #WIDTH_MAX+1
	bcc sn_w_hi_ok
	lda #WIDTH_MAX
sn_w_hi_ok:
	and #$FE		; even width: banks at c -+ w/2
	sta sec_w1
	; center so both banks stay on screen
	lsr
	sta zp_t6		; half width
	clc
	adc #RIVER_MIN_L
	cmp sec_c1
	bcc sn_c_lo_ok
	sta sec_c1
sn_c_lo_ok:
	lda #RIVER_MAX_R
	sec
	sbc zp_t6
	cmp sec_c1
	bcs sn_rates
	sta sec_c1

sn_rates:
	; scenery density varies by stretch, crawfish now and then
	lda #96
	jsr rng_below
	clc
	adc #100
	sta scen_rate
	lda #6
	sta fish_rate
	lda #14
	sta snack_rate
	lda #3			; gifts are rare treasures
	sta gift_rate
	lda sec_kind
	cmp #KIND_BEND
	bne sn_done
	lda #220
	sta scen_rate
sn_done:
	rts

; ===== river_advance_boundary =====
; Sample the next boundary (base_world + 1) into edge_*.
river_advance_boundary:
	lda sec_row
	cmp #SECTION_LEN+1
	bcc rab_sample
	jsr section_next
rab_sample:
	ldx sec_row
	lda river_smooth,x
	sta zp_t2
	lda sec_c0
	sta zp_t0
	lda sec_c1
	sta zp_t1
	jsr lerp
	sta zp_t7		; target center
	lda sec_w0
	sta zp_t0
	lda sec_w1
	sta zp_t1
	jsr lerp
	lsr
	sta zp_t3		; target half width

	lda edge_l
	sta zp_t6
	lda zp_t7
	sec
	sbc zp_t3
	jsr clamp_step
	sta edge_l
	lda edge_r
	sta zp_t6
	lda zp_t7
	clc
	adc zp_t3
	jsr clamp_step
	sta edge_r

	; island around the actual river center
	lda edge_l
	clc
	adc edge_r
	ror
	sta zp_t7
	lda #0
	sta zp_t3
	lda sec_iw
	beq rab_island
	ldx sec_row
	lda river_bump,x
	sta zp_t2
	lda sec_iw
	sta zp_t4
	jsr mul8		; iw * bump / 256 = island width
	lsr
	sta zp_t3		; island half width
rab_island:
	lda edge_il
	sta zp_t6
	lda zp_t7
	sec
	sbc zp_t3
	jsr clamp_step
	sta edge_il
	lda edge_ir
	sta zp_t6
	lda zp_t7
	clc
	adc zp_t3
	jsr clamp_step
	sta edge_ir

	inc sec_row
	ldx base_world
	inx
	jmp store_boundary

; ===== river_build_row =====
; Build world row base_world into the ring, then advance. The
; display calls the two halves on different frames.
river_build_row:
	jsr river_build_row_a
river_build_row_b:
	; scenery for the row (its ring row pointer is needed again)
	lda base_world
	and #RIVER_RING_ROWS-1
	tax
	lda ring_lo,x
	sta zp_ptr0
	lda ring_hi,x
	sta zp_ptr0+1
	jsr river_place_extras
	inc base_world
	bne rbr_done
	inc base_world+1
rbr_done:
	rts

river_build_row_a:
	jsr river_advance_boundary
	jmp river_render_base

; ===== river_render_base =====
; Water, banks, island and texture for row base_world.
river_render_base:
	lda base_world
	and #RIVER_RING_ROWS-1
	tax
	lda ring_lo,x
	sta zp_ptr0
	lda ring_hi,x
	sta zp_ptr0+1
	ldx base_world
	lda NOISE,x
	sta row_seed

	; open water everywhere, with sparse glints
	ldy #39
rrb_water:
	tya
	clc
	adc row_seed
	tax
	lda NOISE,x
	cmp #RIPPLE_CHANCE
	bcs rrb_plain
	and #7
	tax
	lda ripple_tab,x
	bne rrb_store
rrb_plain:
	lda #CH_WATER
rrb_store:
	sta (zp_ptr0),y
	dey
	bpl rrb_water

	; boundary indices: bottom = base_world, top = base_world+1
	lda base_world
	and #63
	sta zp_t7
	tax
	inx
	txa
	and #63
	tax			; X = top index
	ldy zp_t7		; Y = bottom index

	; left bank
	lda BND_L,x
	sta zp_t0
	lda BND_L,y
	sta zp_t1
	lda #<edge_lut_left
	sta zp_ptr1
	lda #>edge_lut_left
	sta zp_ptr1+1
	txa
	pha
	jsr edge_span
	lda zp_t2
	sta rb_la
	lda zp_t3
	sta rb_lb
	pla
	tax
	ldy zp_t7

	; right bank
	lda BND_R,x
	sta zp_t0
	lda BND_R,y
	sta zp_t1
	lda #<edge_lut_right
	sta zp_ptr1
	lda #>edge_lut_right
	sta zp_ptr1+1
	txa
	pha
	jsr edge_span
	lda zp_t2
	sta rb_ra
	lda zp_t3
	sta rb_rb
	pla
	tax
	ldy zp_t7

	; land beside the banks
	lda rb_la
	beq rrb_no_left_land
	sec
	sbc #1
	sta zp_t1
	lda #0
	sta zp_t0
	txa
	pha
	jsr fill_land
	pla
	tax
	ldy zp_t7
rrb_no_left_land:
	lda rb_rb
	cmp #39
	bcs rrb_no_right_land
	adc #1
	sta zp_t0
	lda #39
	sta zp_t1
	txa
	pha
	jsr fill_land
	pla
	tax
	ldy zp_t7
rrb_no_right_land:

	; island: only where it is wide enough at both boundaries
	lda #0
	sta rb_island
	lda BND_IR,x
	sec
	sbc BND_IL,x
	cmp #ISLAND_MIN_SHOW
	bcc rrb_done
	lda BND_IR,y
	sec
	sbc BND_IL,y
	cmp #ISLAND_MIN_SHOW
	bcc rrb_done
	inc rb_island
	; island left shore is a right-bank style edge
	lda BND_IL,x
	sta zp_t0
	lda BND_IL,y
	sta zp_t1
	lda #<edge_lut_right
	sta zp_ptr1
	lda #>edge_lut_right
	sta zp_ptr1+1
	txa
	pha
	jsr edge_span
	lda zp_t3
	sta rb_ila		; last char of the island's left shore
	pla
	tax
	ldy zp_t7
	; island right shore is a left-bank style edge
	lda BND_IR,x
	sta zp_t0
	lda BND_IR,y
	sta zp_t1
	lda #<edge_lut_left
	sta zp_ptr1
	lda #>edge_lut_left
	sta zp_ptr1+1
	jsr edge_span
	lda zp_t2
	sta rb_irb		; first char of the island's right shore
	; land between the shores
	lda rb_ila
	clc
	adc #1
	sta zp_t0
	lda rb_irb
	sec
	sbc #1
	sta zp_t1
	cmp zp_t0
	bcc rrb_done
	jsr fill_land
rrb_done:
	; remember this row's limits for scenery placement
	lda base_world
	and #RIVER_RING_ROWS-1
	tax
	lda rb_la
	sta row_la,x
	lda rb_lb
	sta row_lb,x
	lda rb_ra
	sta row_ra,x
	lda rb_rb
	sta row_rb,x
	lda #0
	sta row_il,x
	sta row_ir,x
	lda rb_island
	beq rrb_no_island
	lda rb_ila
	clc
	adc #1
	sta row_il,x
	lda rb_irb
	sta row_ir,x
rrb_no_island:
	rts

; ===== edge_span =====
; Draw one bank edge into the row at zp_ptr0.
; In:  zp_t0 = x at the row top, zp_t1 = x at the row bottom,
;      zp_ptr1 = edge LUT (50 bytes, (lt+2)*5 + (d+2)).
; Out: zp_t2 = first char column, zp_t3 = last char column.
; Clobbers A, X, Y, zp_t4-zp_t6.
edge_span:
	lda zp_t0
	cmp zp_t1
	bcc es_top_min
	lda zp_t1
	sta zp_t4		; min
	lda zp_t0
	sta zp_t5		; max
	jmp es_cols
es_top_min:
	sta zp_t4
	lda zp_t1
	sta zp_t5
es_cols:
	lda zp_t4
	sec
	sbc #1
	lsr
	lsr
	sta zp_t2		; first column (covers the foam pixel)
	lda zp_t5
	lsr
	lsr
	sta zp_t3		; last column (covers the mud pixel)
	; LUT index for the first column
	lda zp_t2
	asl
	asl
	sta zp_t6
	lda zp_t0
	sec
	sbc zp_t6		; lt = x_top - 4c
	clc
	adc #2
	sta zp_t6
	asl
	asl
	adc zp_t6		; (lt+2)*5
	sta zp_t6
	lda zp_t1
	sec
	sbc zp_t0
	clc
	adc #2
	clc
	adc zp_t6
	sta zp_t6		; LUT index
	ldx zp_t2
es_loop:
	ldy zp_t6
	lda (zp_ptr1),y
	sta zp_t4
	txa
	tay
	lda zp_t4
	sta (zp_ptr0),y
	lda zp_t6
	sec
	sbc #20			; next column: lt - 4
	sta zp_t6
	inx
	cpx zp_t3
	bcc es_loop
	beq es_loop
	rts

; ===== fill_land =====
; Grass from column zp_t0 to zp_t1 (inclusive) with sparse
; variants. Clobbers A, X, Y.
fill_land:
	ldy zp_t0
fl_loop:
	tya
	clc
	adc row_seed
	eor #$80
	tax
	lda NOISE,x
	cmp #LAND_VAR_CHANCE
	bcs fl_plain
	and #15
	tax
	lda land_var_tab,x
	bne fl_store
fl_plain:
	lda #CH_LAND
fl_store:
	sta (zp_ptr0),y
	cpy zp_t1
	beq fl_done
	iny
	bne fl_loop
fl_done:
	rts

; ===== scenery placement =====
; Bounded and multiply-free:
; - occ_top[c] holds the top world row (low byte) of the
;   scenery already placed in column c. Stamps always have
;   their top in the newest row and reach down into rows that
;   are built but not shown yet, so a stamp of height h fits in
;   column c iff base_world - occ_top[c] >= h.
; - row_la/rb/il/ir/lb/ra[r] keep each ring row's land and
;   water limits, so "is it all grass" is h compares.
; - choices come from the noise table (5-bit masks into the
;   32-entry cyclic class tables), a fixed number per row.
SCEN_CANDIDATES  = 4
SHORE_RATE       = 60
WATER_RATE       = 18
SPAN_LEFT        = 0
SPAN_RIGHT       = 1
SPAN_ISLAND      = 2
SPAN_WATER       = 3

river_place_extras:
	lda river_end
	beq rpe_normal
	jsr place_home
rpe_normal:
	jsr occ_refresh
	; noise base for this row's decisions
	lda row_seed
	eor #$A5
	sta rpe_base
	ldx #SCEN_CANDIDATES-1
rpe_loop:
	stx rpe_k
	txa
	asl
	asl
	asl
	asl
	clc
	adc rpe_base
	tay
	lda NOISE,y
	cmp scen_rate
	bcs rpe_next
	lda NOISE+1,y
	sta zp_t2		; span (bits 0-1), pick (bits 3-7)
	lda NOISE+2,y
	sta zp_t3		; column bits
	jsr scen_land
rpe_next:
	ldx rpe_k
	dex
	bpl rpe_loop
	; one shore, one water and one crawfish chance per row
	ldy rpe_base
	lda NOISE+64,y
	cmp #SHORE_RATE
	bcs rpe_water
	lda NOISE+65,y
	sta zp_t2
	jsr scen_shore
rpe_water:
	ldy rpe_base
	lda NOISE+80,y
	cmp #WATER_RATE
	bcs rpe_fish
	lda NOISE+81,y
	sta zp_t2
	lda NOISE+82,y
	sta zp_t3
	jsr scen_water
rpe_fish:
	; one pickup roll: crawfish, a fish snack or a gift
	ldy rpe_base
	lda NOISE+97,y
	sta zp_t3		; column bits
	lda NOISE+98,y
	sta zp_t6		; gift kind bits
	lda NOISE+96,y
	cmp fish_rate
	bcs rpe_not_craw
	lda #CH_CRAWFISH_L
	jmp place_pickup
rpe_not_craw:
	sbc fish_rate		; (carry set)
	cmp snack_rate
	bcs rpe_not_snack
	lda #CH_FISH_L
	jmp place_pickup
rpe_not_snack:
	sbc snack_rate
	cmp gift_rate
	bcs rpe_done
	lda zp_t6
	and #3
	cmp #GIFT_KINDS
	bcc rpe_gift
	lda #0
rpe_gift:
	asl
	clc
	adc #CH_GIFT_FIRST
	jmp place_pickup
rpe_done:
	rts

rpe_k:
	.byte 0
rpe_base:
	.byte 0

; ===== occ_refresh =====
; Keep every column's age below 128 so the 8-bit row
; difference never wraps: one column per row, 64-row cycle.
occ_refresh:
	lda base_world
	and #63
	cmp #40
	bcs ocr_done
	tax
	lda base_world
	sec
	sbc occ_top,x
	cmp #64
	bcc ocr_done
	lda base_world
	sec
	sbc #64
	sta occ_top,x
ocr_done:
	rts

; ===== stamp_prepare =====
; X = stamp id: zp_t7 = id, zp_t0 = w, zp_t1 = h.
; Carry set if its rows would reach rows already handed to the
; display (h - 1 > base_world - emit_world).
stamp_prepare:
	stx zp_t7
	lda stamp_w,x
	sta zp_t0
	lda stamp_h,x
	sta zp_t1
	lda base_world
	sec
	sbc emit_world
	clc
	adc #1
	cmp zp_t1
	rts			; carry clear = no room (flipped below)

; ===== scen_land =====
; Candidate land stamp; span and pick from zp_t2, column from
; zp_t3.
scen_land:
	lda stamp_counts+STAMP_CLASS_LAND
	beq sl_no
	lda zp_t2
	lsr
	lsr
	lsr
	tay
	ldx stamps_land,y
	jsr stamp_prepare
	bcc sl_no		; not enough built rows below
	lda zp_t2
	and #3
	cmp #3
	bne sl_span
	lda #SPAN_LEFT
sl_span:
	sta zp_t4		; span kind
	cmp #SPAN_RIGHT
	beq sl_right
	bcs sl_island
	; left bank: columns 0 .. rb_la-1
	lda #0
	sta zp_t5
	lda rb_la
	jmp sl_pick
sl_right:
	lda rb_rb
	clc
	adc #1
	sta zp_t5
	lda #40
	jmp sl_pick
sl_island:
	lda rb_island
	beq sl_no
	lda rb_ila
	clc
	adc #1
	sta zp_t5
	lda rb_irb
sl_pick:
	; zp_t5 = span start, A = span end (exclusive)
	jsr span_column
	bcs sl_no
	jsr stamp_fit
	bcs sl_no
	jmp stamp_place
sl_no:
	rts

; ===== span_column =====
; Column for a stamp of width zp_t0 in span zp_t5..A-1 from the
; random bits zp_t3. Out: zp_t3 = column; carry set if the
; span is too narrow.
span_column:
	sec
	sbc zp_t5		; span width
	bcc sc_no
	sec
	sbc zp_t0		; last start offset
	bcc sc_no
	clc
	adc #1
	sta sc_positions
	lda zp_t3
	and #31
sc_mod:
	cmp sc_positions
	bcc sc_ok
	sbc sc_positions
	bcs sc_mod
sc_ok:
	clc
	adc zp_t5
	sta zp_t3
	clc
	rts
sc_no:
	sec
	rts

sc_positions:
	.byte 0

; ===== stamp_fit =====
; Stamp zp_t7 (w zp_t0, h zp_t1) at column zp_t3, top row
; base_world, span kind zp_t4. Carry clear if it fits.
stamp_fit:
	; occupancy skyline: base_world - occ_top[c] >= h
	ldx zp_t3
	ldy zp_t0
sf_occ:
	lda base_world
	sec
	sbc occ_top,x
	cmp zp_t1
	bcc sf_no
	inx
	dey
	bne sf_occ
	; per-row limits for rows base_world .. base_world-h+1
	lda zp_t3
	clc
	adc zp_t0
	sta zp_t2		; end column (exclusive)
	lda base_world
	sta zp_t6
	ldy zp_t1
sf_row:
	lda zp_t6
	and #RIVER_RING_ROWS-1
	tax
	lda zp_t4
	beq sf_left
	cmp #SPAN_RIGHT
	beq sf_right
	cmp #SPAN_ISLAND
	beq sf_island
	; water: clear of both banks and of any island
	lda row_ir,x
	cmp row_il,x
	bne sf_no
	lda row_lb,x
	clc
	adc #1
	cmp zp_t3
	bcs sf_no		; column must be > lb + 1
	lda zp_t2
	cmp row_ra,x
	bcs sf_no		; end must be < ra
	bcc sf_next
sf_left:
	lda row_la,x
	cmp zp_t2
	bcc sf_no		; end must be <= la
	bcs sf_next
sf_right:
	lda row_rb,x
	cmp zp_t3
	bcs sf_no		; column must be > rb
	bcc sf_next
sf_island:
	lda row_ir,x
	cmp row_il,x
	beq sf_no		; no island in this row
	cmp zp_t2
	bcc sf_no		; end must be <= ir
	lda zp_t3
	cmp row_il,x
	bcc sf_no		; column must be >= il
sf_next:
	dec zp_t6
	dey
	bne sf_row
	clc
	rts
sf_no:
	sec
	rts

; ===== stamp_place =====
; Write stamp zp_t7 at column zp_t3 (top row base_world) and
; mark its columns in the skyline.
stamp_place:
	jsr stamp_write
occ_mark:
	ldx zp_t3
	ldy zp_t0
	lda base_world
om_loop:
	sta occ_top,x
	inx
	dey
	bne om_loop
	rts

; ===== scen_shore =====
; Reeds right against a bank edge. zp_t2 bit 0 = side, bits
; 3-7 = pick.
scen_shore:
	lda zp_t2
	lsr
	bcc ss_right
	lda stamp_counts+STAMP_CLASS_SHORE_L
	beq ss_no
	lda zp_t2
	lsr
	lsr
	lsr
	tay
	ldx stamps_shore_l,y
	jsr stamp_prepare
	bcc ss_no
	lda rb_la
	sec
	sbc zp_t0
	bcc ss_no
	sta zp_t3
	lda #SPAN_LEFT
	sta zp_t4
	jmp ss_fit
ss_right:
	lda stamp_counts+STAMP_CLASS_SHORE_R
	beq ss_no
	lda zp_t2
	lsr
	lsr
	lsr
	tay
	ldx stamps_shore_r,y
	jsr stamp_prepare
	bcc ss_no
	lda rb_rb
	clc
	adc #1
	sta zp_t3
	adc zp_t0
	cmp #41
	bcs ss_no
	lda #SPAN_RIGHT
	sta zp_t4
ss_fit:
	jsr stamp_fit
	bcs ss_no
	jmp stamp_place
ss_no:
	rts

; ===== scen_water =====
; Lily pads, rocks and logs on open water.
scen_water:
	lda stamp_counts+STAMP_CLASS_WATER
	beq sw_no
	lda zp_t2
	lsr
	lsr
	lsr
	tay
	ldx stamps_water,y
	jsr stamp_prepare
	bcc sw_no
	lda rb_lb
	clc
	adc #2
	sta zp_t5
	lda rb_ra
	sec
	sbc #1
	jsr span_column
	bcs sw_no
	lda #SPAN_WATER
	sta zp_t4
	jsr stamp_fit
	bcs sw_no
	jmp stamp_place
sw_no:
	rts

; ===== place_pickup =====
; A two-character pickup (left char in A, right = A+1) on two
; adjacent open-water cells of the newest row; column bits in
; zp_t3.
place_pickup:
	sta zp_t7
	lda rb_lb
	clc
	adc #2
	sta zp_t5
	lda #2
	sta zp_t0
	lda rb_ra
	sec
	sbc #1
	jsr span_column
	bcs ppu_done
	ldy zp_t3
	lda (zp_ptr0),y
	cmp #8
	bcs ppu_done
	iny
	lda (zp_ptr0),y
	cmp #8
	bcs ppu_done
	ldx zp_t7
	inx
	txa
	sta (zp_ptr0),y
	dey
	lda zp_t7
	sta (zp_ptr0),y
	lda #1
	sta zp_t1
	jmp occ_mark
ppu_done:
	rts

; ===== stamp_write =====
; Write stamp zp_t7 at column zp_t3; data row j goes to world
; row base_world - j. Code $FF keeps the underlying char.
stamp_write:
	ldx zp_t7
	lda stamp_lo,x
	sta zp_ptr3
	lda stamp_hi,x
	sta zp_ptr3+1
	lda #0
	sta zp_t4		; row j
	sta zp_t6		; data offset
sw_row:
	lda base_world
	sec
	sbc zp_t4
	and #RIVER_RING_ROWS-1
	tax
	lda ring_lo,x
	clc
	adc zp_t3
	sta zp_ptr2
	lda ring_hi,x
	adc #0
	sta zp_ptr2+1
	ldx #0
sw_col:
	ldy zp_t6
	lda (zp_ptr3),y
	inc zp_t6
	cmp #$FF
	beq sw_skip
	stx zp_t5
	ldy zp_t5
	sta (zp_ptr2),y
sw_skip:
	inx
	cpx zp_t0
	bne sw_col
	inc zp_t4
	lda zp_t4
	cmp zp_t1
	bne sw_row
	rts

; ===== gen_row / gen_emit =====
; Display interface: hand the next world row (emit_world) to
; the display in row_buf. gen_row also builds one row to keep
; the lookahead filled; gen_emit only hands over (the staged
; display builds the row itself, see run_copy_stage).
gen_row:
	jsr river_build_row
gen_emit:
	lda emit_world
	and #RIVER_RING_ROWS-1
	tax
	lda ring_lo,x
	sta zp_ptr0
	lda ring_hi,x
	sta zp_ptr0+1
	ldy #39
gr_copy:
	lda (zp_ptr0),y
	sta row_buf,y
	dey
	bpl gr_copy
	inc emit_world
	bne gr_done
	inc emit_world+1
gr_done:
	rts

; ===== river_animate =====
; Called once per frame: cycle the water glint and crawfish
; character graphics.
river_animate:
	; one animation per frame of an 8-frame cycle keeps the cost
	; flat: 0 water, 2 crawfish, 4 fish, 6 gifts
	lda frame_count
	and #7
	beq ra_go
	cmp #2
	bne ra_not_craw
	jmp ra_crawfish
ra_not_craw:
	cmp #4
	bne ra_not_fish
	jmp ra_fishes
ra_not_fish:
	cmp #6
	bne ra_none
	jmp ra_gifts
ra_none:
	rts
ra_go:
	inc water_frame
	lda water_frame
	cmp #WATER_FRAMES
	bcc ra_frame_ok
	lda #0
	sta water_frame
ra_frame_ok:
	; 64 bytes per water frame
	lsr
	lsr
	sta zp_t0
	lda water_frame
	asl
	asl
	asl
	asl
	asl
	asl
	clc
	adc #<water_anim_data
	sta zp_ptr0
	lda zp_t0
	adc #>water_anim_data
	sta zp_ptr0+1
	ldy #63
ra_copy:
	lda (zp_ptr0),y
	sta CHARSET_GAME,y
	dey
	bpl ra_copy
	rts

ra_crawfish:
	; crawfish: 16 bytes per frame, same counter
	lda water_frame
ra_fish_mod:
	cmp #CRAWFISH_FRAMES
	bcc ra_fish_frame
	sbc #CRAWFISH_FRAMES
	bcs ra_fish_mod
ra_fish_frame:
	asl
	asl
	asl
	asl
	tax
	ldy #0
ra_fish:
	lda crawfish_anim_data,x
	sta CHARSET_GAME+CH_CRAWFISH_L*8,y
	inx
	iny
	cpy #16
	bne ra_fish
	rts

ra_fishes:
	; fish snack wiggle: 16 bytes per frame
	lda water_frame
ra_snack_mod:
	cmp #FISH_FRAMES
	bcc ra_snack_frame
	sbc #FISH_FRAMES
	bcs ra_snack_mod
ra_snack_frame:
	asl
	asl
	asl
	asl
	tax
	ldy #0
ra_snack:
	lda fish_anim_data,x
	sta CHARSET_GAME+CH_FISH_L*8,y
	inx
	iny
	cpy #16
	bne ra_snack
	rts

ra_gifts:
	.if GIFT_FRAMES > 1
	; gift shimmer: 48 bytes per frame
	lda water_frame
ra_gift_mod:
	cmp #GIFT_FRAMES
	bcc ra_gift_frame
	sbc #GIFT_FRAMES
	bcs ra_gift_mod
ra_gift_frame:
	asl
	asl
	asl
	asl
	sta zp_t0		; frame * 16
	asl
	clc
	adc zp_t0		; frame * 48
	tax
	ldy #0
ra_gift:
	lda gift_anim_data,x
	sta CHARSET_GAME+CH_GIFT_FIRST*8,y
	inx
	iny
	cpy #6*8
	bne ra_gift
	.endif
ra_done:
	rts

ripple_tab:
	.byte CH_WATER+1, CH_WATER+2, CH_WATER+3, CH_WATER+4
	.byte CH_WATER+5, CH_WATER+6, CH_WATER+7, CH_WATER+3

ring_lo:
R	.set 0
	.rept RIVER_RING_ROWS
	.byte <(RIVER_RING+R*40)
R	.set R+1
	.endr
ring_hi:
R	.set 0
	.rept RIVER_RING_ROWS
	.byte >(RIVER_RING+R*40)
R	.set R+1
	.endr

; smoothstep(i/64) * 255, i = 0..64
river_smooth:
	.byte 0,0,1,2,3,4,6,8,11,14,17,20,24
	.byte 27,31,35,40,44,49,54,59,64,70,75,81,86
	.byte 92,98,104,110,116,122,128,133,139,145,151,157,163
	.byte 169,174,180,185,191,196,201,206,211,215,220,224,228
	.byte 231,235,238,241,244,247,249,251,252,253,254,255,255

; 16 t^2 (1-t)^2 * 255: island growth and shrink
river_bump:
	.byte 0,1,4,8,14,21,29,39,49,60,71,83,95
	.byte 107,119,131,143,155,167,178,188,198,208,216,224,231
	.byte 237,243,247,251,253,255,255,255,253,251,247,243,237
	.byte 231,224,216,208,198,188,178,167,155,143,131,119,107
	.byte 95,83,71,60,49,39,29,21,14,8,4,1,0

; ===== river_limits =====
; Water limits for raster lines zp_t0..zp_t1 (inclusive) of the
; frame being prepared, from the boundary samples of every row
; those lines touch (conservative: narrowest banks, widest
; island).
; Out: lim_l = first water pixel of the left bank,
;      lim_r = first land pixel of the right bank,
;      lim_il..lim_ir = island land span (equal when none).
river_limits:
	; a range that wrapped past line 255 ends at the bottom
	lda zp_t1
	cmp zp_t0
	bcs rl_range_ok
	lda #255
	sta zp_t1
rl_range_ok:
	lda #PLAY_TOP_LINE
	clc
	adc fine_pos
	sta zp_t2
	lda zp_t0
	sec
	sbc zp_t2
	bcs rl_k0
	lda #0
rl_k0:
	lsr
	lsr
	lsr
	sta zp_t3		; rows below the top for the first line
	lda zp_t1
	sec
	sbc zp_t2
	bcs rl_k1
	lda #0
rl_k1:
	lsr
	lsr
	lsr
	sta zp_t4		; ... for the last line
	sec
	sbc zp_t3
	clc
	adc #2
	cmp #6
	bcc rl_count
	lda #5			; never more than a sprite's height
rl_count:
	sta zp_t5		; boundaries to scan
	lda top_world
	sec
	sbc zp_t4
	and #63
	tax			; lowest (bottom) boundary
	lda #0
	sta lim_l
	sta lim_ir
	lda #$FF
	sta lim_r
	sta lim_il
rl_loop:
	lda BND_L,x
	cmp lim_l
	bcc rl_r
	sta lim_l
rl_r:
	lda BND_R,x
	cmp lim_r
	bcs rl_isl
	sta lim_r
rl_isl:
	lda BND_IR,x
	sec
	sbc BND_IL,x
	cmp #ISLAND_MIN_SHOW
	bcc rl_next
	lda BND_IL,x
	cmp lim_il
	bcs rl_ir
	sta lim_il
rl_ir:
	lda BND_IR,x
	cmp lim_ir
	bcc rl_next
	sta lim_ir
rl_next:
	inx
	txa
	and #63
	tax
	dec zp_t5
	bne rl_loop
	lda lim_ir
	bne rl_done
	sta lim_il		; no island: both 0
rl_done:
	rts

; ===== place_home =====
; Auntie's house on the left bank with its dock on the water,
; bunting above the house and balloons on the right bank. The
; house's bottom row is world row home_row + HOME_HOUSE_ROW.
HOME_HOUSE_ROW   = 6
place_home:
	; rows above home_row: base_world - home_row
	lda base_world
	sec
	sbc home_row_lo
	sta zp_t0
	lda base_world+1
	sbc home_row_hi
	beq ph_near
	rts			; far away (or below)
ph_near:
	ldx #STAMP_AUNTIE_HOUSE
	lda zp_t0
	sec
	sbc #HOME_HOUSE_ROW
	clc
	adc #1
	cmp stamp_h,x		; top row of the house = house bottom + h-1
	bne ph_bunting
	; house: right against the left bank's edge
	lda rb_la
	sec
	sbc stamp_w,x
	bcs ph_house_x
	lda #0
ph_house_x:
	sta zp_t3
	sta home_house_col
	stx zp_t7
	lda stamp_w,x
	sta zp_t0
	lda stamp_h,x
	sta zp_t1
	jsr stamp_place
	; dock on the water at the house's bottom rows
	ldx #STAMP_DOCK
	stx zp_t7
	lda stamp_w,x
	sta zp_t0
	lda stamp_h,x
	sta zp_t1
	lda rb_lb
	clc
	adc #1
	sta zp_t3
	sta home_dock_col
	; its top row is the house's bottom row + dock height - 1:
	; write it now with its top at base_world - (house h - dock h)
	ldx #STAMP_AUNTIE_HOUSE
	lda stamp_h,x
	sec
	sbc zp_t1
	sta zp_t6		; rows down from base_world
	lda base_world
	pha
	sec
	sbc zp_t6
	sta base_world
	jsr stamp_place
	pla
	sta base_world
	; balloons on the right bank, beside the party
	ldx #STAMP_BALLOONS
	stx zp_t7
	lda stamp_w,x
	sta zp_t0
	lda stamp_h,x
	sta zp_t1
	lda rb_rb
	clc
	adc #1
	sta zp_t3
	jmp stamp_place
ph_bunting:
	; the row right above the house top: party flags
	ldx #STAMP_AUNTIE_HOUSE
	lda zp_t0
	sec
	sbc #HOME_HOUSE_ROW
	cmp stamp_h,x
	bne ph_done
	ldx #STAMP_BUNTING
	stx zp_t7
	lda stamp_w,x
	sta zp_t0
	lda stamp_h,x
	sta zp_t1
	lda home_house_col
	sta zp_t3
	jmp stamp_place
ph_done:
	rts
