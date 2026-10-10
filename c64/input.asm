; ==========================================================
; Otter Raid - joystick and keyboard input
;
; Joystick port 2 and the keys W A S D, SPACE, P, RETURN are
; merged into one active-high byte. in_held is the current
; state, in_new the bits that went down this frame.
; ==========================================================

IN_UP            = %00000001
IN_DOWN          = %00000010
IN_LEFT          = %00000100
IN_RIGHT         = %00001000
IN_FIRE          = %00010000
IN_PAUSE         = %00100000
IN_START         = %01000000	; RETURN (menus)

; ===== input_read =====
; Once per frame from the main thread.
input_read:
	lda in_override
	beq ir_hw
	sta zp_t0
	jmp ir_edges
ir_hw:
	; joystick 2: no keyboard column selected
	lda #$FF
	sta CIA1_PRA
	lda CIA1_PRA
	eor #$FF
	and #%00011111		; up down left right fire
	sta zp_t0

	; keyboard matrix: select one column, read rows (active low)
	ldx #0
ir_key:
	lda key_col,x
	sta CIA1_PRA
	lda CIA1_PRB
	and key_row,x
	bne ir_key_up
	lda zp_t0
	ora key_bit,x
	sta zp_t0
ir_key_up:
	inx
	cpx #KEY_COUNT
	bne ir_key
	lda #$FF
	sta CIA1_PRA

ir_edges:
	lda in_held
	eor #$FF
	and zp_t0
	sta in_new
	lda zp_t0
	sta in_held
	rts

; key table: column select, row mask, input bit
KEY_COUNT        = 7
key_col:
	.byte %11111101, %11111101, %11111101, %11111011
	.byte %01111111, %11011111, %11111110
key_row:
	.byte %00000010, %00000100, %00100000, %00000100
	.byte %00010000, %00000010, %00000010
key_bit:
	.byte IN_UP, IN_LEFT, IN_DOWN, IN_RIGHT
	.byte IN_FIRE, IN_PAUSE, IN_START
	; W, A, S, D, SPACE, P, RETURN
