; ==========================================================
; Otter Raid - machine setup and raster interrupt chain
;
; Frame layout (PAL raster lines, 24-row mode RSEL=0):
;   55- 70  HUD, text rows 0-1, YSCROLL 7, hires text
;   71- 78  black band (ECM+MCM invalid mode) hides the seam
;   79-246  scrolling playfield, multicolor text, rows 2-23
;  250      vblank IRQ: latch next frame, sound, HUD mode
;
; The playfield's first character row (screen row 2) starts its
; bad line at 71+d, where d is the fine scroll 0-7, so content
; moves down by d pixels behind the band (an FLD-style delay).
; ==========================================================

LINE_VBLANK      = 250
DM_GAME          = 0		; disp_mode: HUD + band + playfield
DM_TEXT          = 1		; 25 rows of text from screen A
DM_BLANK         = 2		; display off
LINE_SPLIT_IRQ   = 69
LINE_BAND        = 70		; last HUD line, band mode set here
LINE_PLAY_IRQ    = 77
LINE_PLAY        = 79		; first visible playfield line
HUD_YSCROLL      = 7
D011_BASE        = D011_DEN	; text, 24 rows, raster bit 8 clear
D011_HUD         = D011_BASE|HUD_YSCROLL
D016_HUD         = D016_CSEL
D016_PLAY        = D016_CSEL|D016_MCM

; ===== system_init =====
; Bank out ROMs, silence CIAs, select VIC bank 1 and install
; the raster interrupt chain. Interrupts are enabled on exit.
system_init:
	sei
	cld
	lda #$2F		; default CPU port direction
	sta CPU_DDR
	lda #CPU_IO_ONLY
	sta CPU_PORT

	; stop all CIA interrupt sources and acknowledge leftovers
	lda #$7F
	sta CIA1_ICR
	sta CIA2_ICR
	lda CIA1_ICR
	lda CIA2_ICR
	lda #0
	sta CIA1_CRA
	sta CIA1_CRB
	sta CIA2_CRA
	sta CIA2_CRB

	; keyboard: port A drives columns, port B reads rows
	lda #$FF
	sta CIA1_DDRA
	lda #$00
	sta CIA1_DDRB

	; hardware vectors live in RAM now
	lda #<nmi_handler
	sta VEC_NMI
	lda #>nmi_handler
	sta VEC_NMI+1
	lda #<irq_vblank
	sta VEC_IRQ
	lda #>irq_vblank
	sta VEC_IRQ+1

	; VIC bank 1
	lda CIA2_DDRA
	ora #%00000011
	sta CIA2_DDRA
	lda CIA2_PRA
	and #%11111100
	ora #CIA2_BANK1
	sta CIA2_PRA

	lda #0
	sta VIC_IDLE_BYTE
	sta VIC_SPR_ENABLE
	sta VIC_BORDER
	sta frame_count
	sta next_valid
	sta is_ntsc
	sta cur_fine
	sta cur_front
	sta next_fine
	sta next_front
	lda #DM_BLANK
	sta disp_mode

	jsr detect_ntsc

	; blank the display until the first vblank IRQ sets it up
	lda #0
	sta VIC_CTRL1
	lda #LINE_VBLANK
	sta VIC_RASTER
	lda #$01
	sta VIC_IRQ_ENABLE
	lda #$FF
	sta VIC_IRQ_STATUS
	cli
	rts

; ===== detect_ntsc =====
; Sets is_ntsc to 1 when the last raster line is below 300.
detect_ntsc:
dn_wait_top:
	lda VIC_CTRL1
	bpl dn_wait_top		; wait for line >= 256
dn_wait_low:
	lda VIC_CTRL1
	bmi dn_wait_low		; wrapped to line 0
	; scan lines 256+ : remember the highest low byte seen
	lda #0
	sta zp_t0
dn_scan:
	lda VIC_CTRL1
	bpl dn_scan		; until line >= 256 again
dn_track:
	lda VIC_RASTER
	cmp zp_t0
	bcc dn_track_skip
	sta zp_t0
dn_track_skip:
	lda VIC_CTRL1
	bmi dn_track
	; PAL tops out at 311 ($37), NTSC at 262 ($06)
	lda zp_t0
	cmp #$20
	bcs dn_pal
	lda #1
	sta is_ntsc
dn_pal:
	rts

nmi_handler:
	rti

; ===== irq_vblank (line 250) =====
; Latch the frame state prepared by the main thread, run the
; sound engine and set up HUD mode for the top of the screen.
irq_vblank:
	pha
	txa
	pha
	tya
	pha
	lda #$01
	sta VIC_IRQ_STATUS

	lda disp_mode
	beq ivb_game
	cmp #DM_TEXT
	beq ivb_text
	lda #0			; DM_BLANK: display off
	sta VIC_CTRL1
	beq ivb_common
ivb_text:
	lda #D011_DEN|D011_RSEL|3	; 25 rows of hires text
	sta VIC_CTRL1
	lda #D016_HUD
	sta VIC_CTRL2
	lda #D018_HUD
	sta VIC_MEM
	lda hud_bg_color
	sta VIC_BG0
	jmp ivb_common
ivb_game:
	lda #D011_HUD
	sta VIC_CTRL1
	lda #D016_HUD
	sta VIC_CTRL2
	lda #D018_HUD
	sta VIC_MEM
	lda hud_bg_color
	sta VIC_BG0
	lda #COL_BLACK
	sta VIC_BG1		; ECM transition safety on line 70
ivb_common:

	lda next_valid
	beq ivb_no_latch
	lda next_fine
	sta cur_fine
	lda next_front
	sta cur_front
	jsr sprites_latch
	lda #0
	sta next_valid
ivb_no_latch:
	inc frame_count

	jsr irq_sound_hook

	lda disp_mode
	bne ivb_no_split	; text / blank: no playfield splits
	lda #LINE_SPLIT_IRQ
	sta VIC_RASTER
	lda #<irq_split
	sta VEC_IRQ
	lda #>irq_split
	sta VEC_IRQ+1
ivb_no_split:
	pla
	tay
	pla
	tax
	pla
	rti

; ===== irq_split (line 69) =====
; On line 70 switch to the black band (ECM+MCM is an invalid
; mode that draws only black) and program YSCROLL so that the
; playfield's first bad line falls on line 71+d.
irq_split:
	pha
	txa
	pha
	tya
	pha
	lda #$01
	sta VIC_IRQ_STATUS

	ldx cur_fine
	lda split_d011_first,x
	ldy #LINE_BAND
isp_wait_band:
	cpy VIC_RASTER
	bne isp_wait_band
	sta VIC_CTRL1
	lda #D016_PLAY
	sta VIC_CTRL2
	ldy cur_front
	lda split_d018,y
	sta VIC_MEM
	lda #PLAY_BG0
	sta VIC_BG0
	lda #PLAY_BG1
	sta VIC_BG1
	lda #PLAY_BG2
	sta VIC_BG2

	; d = 7 needs YSCROLL 6, but line 70 itself has (70&7)=6.
	; A first write of 5 parks the bad line; now that line 70
	; is over, the final value is safe.
	cpx #7
	bne isp_done
	ldy #LINE_BAND+1
isp_wait_71:
	cpy VIC_RASTER
	bne isp_wait_71
	lda #D011_BASE|D011_ECM|6
	sta VIC_CTRL1
isp_done:
	lda #LINE_PLAY_IRQ
	sta VIC_RASTER
	lda #<irq_play
	sta VEC_IRQ
	lda #>irq_play
	sta VEC_IRQ+1
	pla
	tay
	pla
	tax
	pla
	rti

; ===== irq_play (line 77) =====
; Leave band mode at the very start of line 79.
irq_play:
	pha
	txa
	pha
	tya
	pha
	lda #$01
	sta VIC_IRQ_STATUS

	ldx cur_fine
	lda split_d011_play,x
	ldy #LINE_PLAY
ipl_wait:
	cpy VIC_RASTER
	bne ipl_wait
	sta VIC_CTRL1

	lda #LINE_VBLANK
	sta VIC_RASTER
	lda #<irq_vblank
	sta VEC_IRQ
	lda #>irq_vblank
	sta VEC_IRQ+1
	pla
	tay
	pla
	tax
	pla
	rti

; Fine scroll d -> YSCROLL of the playfield = (71+d) & 7.
; The band write uses 5 for d = 7 (see irq_split).
split_d011_first:
	.byte D011_BASE|D011_ECM|7, D011_BASE|D011_ECM|0
	.byte D011_BASE|D011_ECM|1, D011_BASE|D011_ECM|2
	.byte D011_BASE|D011_ECM|3, D011_BASE|D011_ECM|4
	.byte D011_BASE|D011_ECM|5, D011_BASE|D011_ECM|5
split_d011_play:
	.byte D011_BASE|7, D011_BASE|0, D011_BASE|1, D011_BASE|2
	.byte D011_BASE|3, D011_BASE|4, D011_BASE|5, D011_BASE|6
split_d018:
	.byte D018_PLAY_A, D018_PLAY_B

; ===== sprites_latch =====
; Copy the sprite shadow into the VIC and both screens'
; sprite pointers. Runs inside irq_vblank.
sprites_latch:
	ldx #7
sl_loop:
	txa
	asl
	tay
	lda SPR_SH_X,x
	sta VIC_SPR0_X,y
	lda SPR_SH_Y,x
	sta VIC_SPR0_Y,y
	lda SPR_SH_COLOR,x
	sta VIC_SPR0_COLOR,x
	lda SPR_SH_PTR,x
	sta SPR_PTRS_A,x
	sta SPR_PTRS_B,x
	dex
	bpl sl_loop
	lda SPR_SH_XMSB
	sta VIC_SPR_X_MSB
	lda SPR_SH_MCOLOR
	sta VIC_SPR_MCOLOR
	lda SPR_SH_EXPX
	sta VIC_SPR_EXPAND_X
	lda SPR_SH_EXPY
	sta VIC_SPR_EXPAND_Y
	lda SPR_SH_PRIO
	sta VIC_SPR_PRIORITY
	lda SPR_SH_ENABLE
	sta VIC_SPR_ENABLE
	rts

; ===== frame_end =====
; Main thread: publish the prepared frame state and wait until
; the vblank IRQ has latched it. On return a new frame period
; has just begun and the old front buffer is no longer shown.
frame_end:
	lda fine_pos
	sta next_fine
	lda front_buf
	sta next_front
	lda #1
	sta next_valid
fe_wait:
	lda next_valid
	bne fe_wait
	rts

; ===== sprite_set_mcx =====
; Sprite X (shadow) from a playfield multicolor x in A:
; X register = sprite number. Hires X = 24 + 2 * A.
sprite_set_mcx:
	sta zp_t0
	lda #0
	asl zp_t0
	rol
	sta zp_t1
	lda zp_t0
	clc
	adc #24
	sta SPR_SH_X,x
	lda zp_t1
	adc #0
	; fall through with A = X bit 8

; ===== sprite_set_msb =====
; Set or clear sprite X's X bit 8 from A bit 0.
sprite_set_msb:
	lsr
	lda bit_masks,x
	bcs ssm_set
	eor #$FF
	and SPR_SH_XMSB
	sta SPR_SH_XMSB
	rts
ssm_set:
	ora SPR_SH_XMSB
	sta SPR_SH_XMSB
	rts

; ===== sprite_set_x16 =====
; Sprite X (shadow) from a 16-bit hires sprite coordinate in
; zp_t0 (low) / zp_t1 (high); X register = sprite number.
sprite_set_x16:
	lda zp_t0
	sta SPR_SH_X,x
	lda zp_t1
	jmp sprite_set_msb

bit_masks:
	.byte 1, 2, 4, 8, 16, 32, 64, 128
