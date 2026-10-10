; =====================================================================
; Otter Raid - sound system test harness (standalone PRG)
; =====================================================================
; Build from the repository root:
;   python3 tools/music.py
;   vasm6502_oldstyle -Fbin -cbm-prg -dotdir -quiet \
;       -o build/sound_test.prg c64/sound/sound_test.asm
; Run:  x64sc -autostart build/sound_test.prg
;
; Keys: 1-7 play tune, 0 stop music, A-O sfx 1-15, Q sfx 16,
;       R sfx 17, P pause/resume,
;       SPACE reset the cycle maximum.
;
; Monitor interface (fixed addresses, see tst_* equates below):
;   poke a command into $0340 (and optionally $0341, executed in the
;   same frame); the harness clears it when done:
;     $01-$07 music_play n      $08 music_play 0 (stop)
;     $80+n   sfx_play n        $20 pause      $21 resume
;     $30 reset cycle maximum   $40-$47 snd_voice_mask = n & 7
;     $50 run script at $C000   $51 stop script
;     $60 snd_ntsc = 0          $61 snd_ntsc = 1
;   script: triplets (command, wait lo, wait hi), command 0 ends;
;   wait 0 runs the next command in the same frame.
;   $0342/3 last and $0344/5 maximum sound_update cycles (incl.
;   jsr/rts), $0346/7 frame counter, $0348/9 frame of the maximum,
;   $CE00/$CF00 cycles of the last 256 frames (index = frame lo).

	include "sound_ids.asm"

tst_cmd		= $0340		; command mailbox
tst_cmd2	= $0341		; second command (same frame)
tst_last	= $0342		; cycles of the last sound_update
tst_max		= $0344		; maximum cycles seen
tst_frame	= $0346		; frame counter
tst_maxf	= $0348		; frame of the maximum
tst_script	= $034A		; 1 = script running
tst_sptr	= $034B		; script pointer
tst_swait	= $034D		; script wait (frames)
tst_tune	= $034F		; last tune started
tst_sfx		= $0350		; last sfx started
tst_ovh		= $0351		; timer overhead (cycles)
tst_flag	= $0352		; set by the IRQ every frame
tst_key		= $0353		; last key code ($FF none)
tst_ptr		= $FB		; print pointer (2)
tst_scr		= $FD		; screen pointer (2)

TST_SCRIPT_MEM	= $C000
TST_HIST_LO	= $CE00		; cycles per frame, indexed by frame lo
TST_HIST_HI	= $CF00
TST_IRQ_LINE	= 250
SCREEN		= $0400

	.org $0801
	.word tst_basic_end, 10
	.byte $9e, "2061", 0
tst_basic_end:
	.word 0

; ===== startup =====
tst_start:
	sei
	cld
	ldx #$FF
	txs
	lda #$35		; RAM, I/O, no BASIC/KERNAL
	sta $01
	lda #$7F
	sta $DC0D
	sta $DD0D
	lda $DC0D
	lda $DD0D
	lda #<tst_irq
	sta $FFFE
	lda #>tst_irq
	sta $FFFF
	lda #<tst_nmi
	sta $FFFA
	lda #>tst_nmi
	sta $FFFB
	lda #$FF		; keyboard: port A out, port B in
	sta $DC02
	lda #$00
	sta $DC03
	ldx #$13
	lda #0
tst_clr:
	sta tst_cmd,x
	dex
	bpl tst_clr
	lda #$FF
	sta tst_key
	jsr tst_detect_ntsc
	jsr tst_calibrate
	jsr sound_init
	jsr tst_draw
	lda #$1B
	sta $D011
	lda #TST_IRQ_LINE
	sta $D012
	lda #1
	sta $D01A
	sta $D019
	cli

; ===== main loop: one pass per frame =====
tst_main:
	lda tst_flag
	beq tst_main
	lda #0
	sta tst_flag
	jsr tst_keys
	jsr tst_run_script
	lda tst_cmd
	beq tst_main_c2
	jsr tst_exec
	lda #0
	sta tst_cmd
tst_main_c2:
	lda tst_cmd2
	beq tst_main_upd
	jsr tst_exec
	lda #0
	sta tst_cmd2
tst_main_upd:
	jsr tst_status
	jmp tst_main

; ===== raster IRQ: sound_update, cycle measurement =====
tst_irq:
	pha
	txa
	pha
	tya
	pha
	lda #1
	sta $D019
	inc $D020
	lda #$FF		; CIA2 timer A, one-shot from $FFFF
	sta $DD04
	sta $DD05
	lda #%00011001
	sta $DD0E
	jsr sound_update
	lda #%00001000
	sta $DD0E
	dec $D020
	sec
	lda #$FF
	sbc $DD04
	tax
	lda #$FF
	sbc $DD05
	tay
	txa
	sec
	sbc tst_ovh
	sta tst_last
	bcs tst_irq_hi
	dey
tst_irq_hi:
	sty tst_last+1
	ldx tst_script		; per-frame history while the script
	beq tst_irq_nohist	; runs (for the monitor)
	ldx tst_frame
	sta TST_HIST_LO,x
	pha
	tya
	sta TST_HIST_HI,x
	pla
tst_irq_nohist:
	cpy tst_max+1		; new maximum?
	bcc tst_irq_frame
	bne tst_irq_max
	cmp tst_max
	bcc tst_irq_frame
tst_irq_max:
	sta tst_max
	sty tst_max+1
	lda tst_frame
	sta tst_maxf
	lda tst_frame+1
	sta tst_maxf+1
tst_irq_frame:
	inc tst_frame
	bne tst_irq_done
	inc tst_frame+1
tst_irq_done:
	lda #1
	sta tst_flag
	pla
	tay
	pla
	tax
	pla
tst_nmi:
	rti

; measure the timer overhead with an empty subroutine: the
; reported value then counts sound_update incl. its jsr/rts
tst_calibrate:
	lda #$FF
	sta $DD04
	sta $DD05
	lda #%00011001
	sta $DD0E
	jsr tst_rts
	lda #%00001000
	sta $DD0E
	sec
	lda #$FF
	sbc $DD04
	sec
	sbc #12
	sta tst_ovh
tst_rts:
	rts

; snd_ntsc = 1 when the raster never passes line 263
tst_detect_ntsc:
	ldx #0
	ldy #0
	stx tst_ptr
tst_dn_loop:
	lda $D011
	bpl tst_dn_next
	lda $D012
	cmp #$08
	bcc tst_dn_next
	lda #1			; line >= 264: PAL
	sta tst_ptr
tst_dn_next:
	inx
	bne tst_dn_loop
	iny
	cpy #20
	bne tst_dn_loop
	lda tst_ptr
	eor #1
	and #1
	sta snd_ntsc
	rts

; ===== command execution (A = command) =====
tst_exec:
	cmp #$80
	bcc tst_ex_low
	and #$7F		; $80+n: sfx n
	sta tst_sfx
	jmp sfx_play
tst_ex_low:
	cmp #$08
	beq tst_ex_stop
	bcs tst_ex_pause
	sta tst_tune
	jmp music_play
tst_ex_stop:
	lda #0
	sta tst_tune
	jmp music_play
tst_ex_pause:
	cmp #$20
	bne tst_ex_resume
	lda #1
	sta tst_paused
	jmp sound_pause
tst_ex_resume:
	cmp #$21
	bne tst_ex_reset
	lda #0
	sta tst_paused
	jmp sound_pause
tst_ex_reset:
	cmp #$30
	bne tst_ex_mask
	lda #0
	sta tst_max
	sta tst_max+1
	rts
tst_ex_mask:
	cmp #$40
	bcc tst_ex_rts
	cmp #$48
	bcs tst_ex_script
	and #7
	sta snd_voice_mask
	rts
tst_ex_script:
	cmp #$50
	bne tst_ex_sstop
	lda #<TST_SCRIPT_MEM
	sta tst_sptr
	lda #>TST_SCRIPT_MEM
	sta tst_sptr+1
	lda #0
	sta tst_swait
	sta tst_swait+1
	lda #1
	sta tst_script
	rts
tst_ex_sstop:
	cmp #$51
	bne tst_ex_ntsc
	lda #0
	sta tst_script
	rts
tst_ex_ntsc:
	cmp #$60
	bne tst_ex_ntsc1
	lda #0
	sta snd_ntsc
	rts
tst_ex_ntsc1:
	cmp #$61
	bne tst_ex_rts
	lda #1
	sta snd_ntsc
tst_ex_rts:
	rts

; ===== script runner (one step per frame) =====
tst_run_script:
	lda tst_script
	beq tst_rs_rts
	lda tst_swait
	ora tst_swait+1
	beq tst_rs_next
	lda tst_swait
	bne tst_rs_dec
	dec tst_swait+1
tst_rs_dec:
	dec tst_swait
	rts
tst_rs_next:
	lda tst_sptr
	sta tst_ptr
	lda tst_sptr+1
	sta tst_ptr+1
	ldy #0
	lda (tst_ptr),y
	beq tst_rs_end
	pha
	iny
	lda (tst_ptr),y
	sta tst_swait
	iny
	lda (tst_ptr),y
	sta tst_swait+1
	clc
	lda tst_sptr
	adc #3
	sta tst_sptr
	bcc tst_rs_exec
	inc tst_sptr+1
tst_rs_exec:
	pla
	jsr tst_exec
	lda tst_swait		; wait 0: next command in this frame
	ora tst_swait+1
	beq tst_rs_next
	rts
tst_rs_end:
	sta tst_script
tst_rs_rts:
	rts

; ===== keyboard =====
tst_keys:
	jsr tst_scan
	cmp tst_key
	beq tst_k_rts
	sta tst_key
	cmp #$FF
	beq tst_k_rts
	tax
	lda tst_keymap,x
	beq tst_k_rts
	cmp #$22		; P: toggle pause
	bne tst_k_cmd
	lda tst_paused		; $20 pause / $21 resume
	ora #$20
tst_k_cmd:
	jmp tst_exec
tst_k_rts:
	rts

; A = key code (column * 8 + row bit) of the first pressed key,
; or $FF when no key is down
tst_scan:
	ldx #0
tst_sc_col:
	lda tst_colmask,x
	sta $DC00
	lda $DC01
	cmp #$FF
	bne tst_sc_found
	inx
	cpx #8
	bne tst_sc_col
	lda #$FF
	rts
tst_sc_found:
	ldy #0
tst_sc_bit:
	lsr
	bcc tst_sc_code
	iny
	bne tst_sc_bit
tst_sc_code:
	stx tst_ptr
	tya
	sta tst_ptr+1
	lda tst_ptr
	asl
	asl
	asl
	ora tst_ptr+1
	rts

tst_colmask:
	.byte $FE,$FD,$FB,$F7,$EF,$DF,$BF,$7F

; key code -> command (0 = none)
tst_keymap:
	.byte 0,0,0,0,0,0,0,0			; col 0
	.byte $03,0,$81,$04,0,0,$85,0		; 3 W A 4 Z S E
	.byte $05,$91,$84,$06,$83,$86,0,0	; 5 R D 6 C F T X
	.byte $07,0,$87,0,$82,$88,0,0		; 7 Y G 8 B H U V
	.byte 0,$89,$8A,$08,$8D,$8B,$8F,$8E	; 9 I J 0 M K O N
	.byte 0,$22,$8C,0,0,0,0,0		; + P L
	.byte 0,0,0,0,0,0,0,0			; col 6
	.byte $01,0,0,$02,$30,0,$90,0		; 1 <- CTRL 2 SPACE C= Q

; ===== screen =====
tst_draw:
	lda #0
	sta $D020
	lda #6
	sta $D021
	ldx #0
tst_dr_clr:
	lda #$20
	sta SCREEN,x
	sta SCREEN+$100,x
	sta SCREEN+$200,x
	sta SCREEN+$2E8,x
	lda #1
	sta $D800,x
	sta $D900,x
	sta $DA00,x
	sta $DAE8,x
	inx
	bne tst_dr_clr
	lda #<tst_text
	sta tst_ptr
	lda #>tst_text
	sta tst_ptr+1
	lda #<SCREEN
	sta tst_scr
	lda #>SCREEN
	sta tst_scr+1
	lda #0
	sta tst_col
tst_dr_loop:
	ldy #0
	lda (tst_ptr),y
	beq tst_dr_rts
	cmp #$0A		; newline: next screen row
	bne tst_dr_char
	clc
	lda tst_scr
	adc #40
	sta tst_scr
	bcc tst_dr_nl
	inc tst_scr+1
tst_dr_nl:
	lda #0
	sta tst_col
	beq tst_dr_adv
tst_dr_char:
	and #$3F		; ASCII -> screen code
	ldy tst_col
	sta (tst_scr),y
	inc tst_col
tst_dr_adv:
	inc tst_ptr
	bne tst_dr_loop
	inc tst_ptr+1
	bne tst_dr_loop
tst_dr_rts:
	rts

; ASCII text, $0A = next row, 0 = end (rows up to 40 chars)
tst_text:
	.byte "OTTER RAID SOUND TEST",$0A
	.byte $0A
	.byte "1-7 TUNE  0 STOP  P PAUSE  SPC RESET MAX",$0A
	.byte $0A
	.byte "1 TITLE  2 RIVER  3 EAGLE  4 LIFE LOST",$0A
	.byte "5 GAME OVER  6 HOME  7 HIGH SCORE",$0A
	.byte $0A
	.byte "A MENU MOVE      I INVULN ENDING",$0A
	.byte "B MENU SELECT    J EAGLE SCREECH",$0A
	.byte "C SPLASH DIVE    K EAGLE SWOOP",$0A
	.byte "D SURFACE        L EAGLE CATCH",$0A
	.byte "E BANK BUMP      M HEART GAINED",$0A
	.byte "F GATOR CHOMP    N MILESTONE",$0A
	.byte "G HURT           O GATOR SPLASH",$0A
	.byte "H CRAWFISH PICKUP Q FISH EAT  R GIFT",$0A
	.byte $0A
	.byte "TUNE",$0A
	.byte "SFX",$0A
	.byte "PLAYING SFX",$0A
	.byte "MUSIC BUSY",$0A
	.byte "LOOPS",$0A
	.byte "PAUSED",$0A
	.byte "NTSC",$0A
	.byte "CYCLES",$0A
	.byte "MAX CYCLES",$0A
	.byte 0

TST_ROW_TUNE	= SCREEN+16*40+14

; live values, one per row from TST_ROW_TUNE down
tst_status:
	ldx #0
	lda tst_tune
	jsr tst_hex_at
	ldx #1
	lda tst_sfx
	jsr tst_hex_at
	ldx #2
	lda sfx_cur
	jsr tst_hex_at
	ldx #3
	lda snd_music_busy
	jsr tst_hex_at
	ldx #4
	lda snd_mus_loops
	jsr tst_hex_at
	ldx #5
	lda tst_paused
	jsr tst_hex_at
	ldx #6
	lda snd_ntsc
	jsr tst_hex_at
	ldx #7
	lda tst_last+1
	jsr tst_hex_at
	lda tst_last
	jsr tst_hex
	ldx #8
	lda tst_max+1
	jsr tst_hex_at
	lda tst_max
	jmp tst_hex

; print A as hex at status row X
tst_hex_at:
	pha
	lda tst_row_lo,x
	sta tst_scr
	lda tst_row_hi,x
	sta tst_scr+1
	pla

; print A as two hex digits at tst_scr, advance by 2
tst_hex:
	pha
	lsr
	lsr
	lsr
	lsr
	jsr tst_digit
	pla
	and #$0F
tst_digit:
	cmp #10
	bcc tst_dg_num
	sbc #9			; A-F screen codes 1-6
	bne tst_dg_put
tst_dg_num:
	ora #$30
tst_dg_put:
	ldy #0
	sta (tst_scr),y
	inc tst_scr
	bne tst_dg_rts
	inc tst_scr+1
tst_dg_rts:
	rts

tst_row_lo:
	.byte <(TST_ROW_TUNE),<(TST_ROW_TUNE+40),<(TST_ROW_TUNE+80)
	.byte <(TST_ROW_TUNE+120),<(TST_ROW_TUNE+160)
	.byte <(TST_ROW_TUNE+200),<(TST_ROW_TUNE+240)
	.byte <(TST_ROW_TUNE+280),<(TST_ROW_TUNE+320)
tst_row_hi:
	.byte >(TST_ROW_TUNE),>(TST_ROW_TUNE+40),>(TST_ROW_TUNE+80)
	.byte >(TST_ROW_TUNE+120),>(TST_ROW_TUNE+160)
	.byte >(TST_ROW_TUNE+200),>(TST_ROW_TUNE+240)
	.byte >(TST_ROW_TUNE+280),>(TST_ROW_TUNE+320)

tst_paused:
	.byte 0
tst_col:
	.byte 0

; ===== the sound system, at its in-game address =====
	.org $8000
	include "sound.asm"
	include "music_data.asm"
	include "sfx_data.asm"
snd_end_of_sound:
