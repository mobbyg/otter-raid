; ==========================================================
; Otter Raid - Commodore 64
; Main program: entry point, module includes, main loop.
;
; Build: make   (vasm6502_oldstyle -Fbin -cbm-prg -dotdir)
; ==========================================================

	include "defs.asm"
	include "memory.asm"
	include "palette.asm"
	include "gfx/gfx_ids.asm"
	include "sound/sound_ids.asm"

	.org $0801

	; 10 SYS2061
	.byte $0B,$08,$0A,$00,$9E
	.text "2061"
	.byte $00,$00,$00

; ===== entry =====
start:
	sei
	ldx #$FF
	txs
	jsr system_init
	jsr sound_init
	lda is_ntsc
	sta snd_ntsc

	lda #HUD_BG
	sta hud_bg_color
	lda #COL_BLACK
	sta VIC_SPR_MC0
	lda #COL_WHITE
	sta VIC_SPR_MC1
	lda #0
	sta in_override
	sta demo_mode
	sta idle_seq
	lda hs_table		; HUD high score = best table entry
	sta hi_score
	lda hs_table+1
	sta hi_score+1
	lda hs_table+2
	sta hi_score+2
	jsr title_enter
	jsr frame_end

; ===== main loop =====
; Each pass prepares exactly one frame; frame_end publishes it
; and returns once the vblank IRQ has latched it.
main_loop:
	lda debug_profile
	beq ml_no_prof
	lda #COL_RED
	sta VIC_BORDER
ml_no_prof:
	jsr input_read
	jsr game_frame
	lda #COL_BLACK
	sta VIC_BORDER
	jsr frame_end
	jmp main_loop

debug_profile:
	.byte 0

irq_sound_hook:
	jmp sound_update

	include "system.asm"
	include "display.asm"
	include "river_engine.asm"
	include "input.asm"
	include "player.asm"
	include "enemies.asm"
	include "eagle.asm"
	include "hud.asm"
	include "game.asm"
	include "screens.asm"
	include "home.asm"
	include "demo.asm"
	include "gfx/gfx_tables.asm"
code_end:

	.if code_end > VIC_BANK
	.fail "code runs into the VIC bank at $4000"
	.endif

	.ifdef SOUND_STUB		; silent build for engine tests
	include "sound_stub.asm"
	.else
	.org $8000
	include "sound/sound.asm"
	include "sound/music_data.asm"
	include "sound/sfx_data.asm"
sound_end:
	.if sound_end > $A000
	.fail "sound overflows $8000-$9FFF"
	.endif
	.endif

; ===== VIC bank 1 data =====
	.org CHARSET_GAME
	include "gfx/charset_game.asm"
	.org CHARSET_TEXT
	include "gfx/charset_text.asm"
	.org SPRITE_DATA
	include "gfx/sprites.asm"
