; GENERATED FILE - do not edit by hand.
; Source: music/sfx.txt   Generator: tools/music.py
; Regenerate with:  python3 tools/music.py

; ===== priority (higher wins, equal restarts) =====
sfx_prio_tbl:
	.byte $00,$01,$03,$03,$02,$01,$06,$06,$05,$03,$06,$04,$08,$07,$02,$02
	.byte $05,$06
sfx_ptr_lo:
	.byte 0,<sfx_prg_menu_move,<sfx_prg_menu_select,<sfx_prg_splash_dive
	.byte <sfx_prg_surface,<sfx_prg_bank_bump,<sfx_prg_gator_chomp
	.byte <sfx_prg_hurt,<sfx_prg_crawfish_pickup,<sfx_prg_invuln_ending
	.byte <sfx_prg_eagle_screech,<sfx_prg_eagle_swoop,<sfx_prg_eagle_catch
	.byte <sfx_prg_heart_gained,<sfx_prg_milestone,<sfx_prg_gator_splash
	.byte <sfx_prg_fish_eat,<sfx_prg_gift
sfx_ptr_hi:
	.byte 0,>sfx_prg_menu_move,>sfx_prg_menu_select,>sfx_prg_splash_dive
	.byte >sfx_prg_surface,>sfx_prg_bank_bump,>sfx_prg_gator_chomp
	.byte >sfx_prg_hurt,>sfx_prg_crawfish_pickup,>sfx_prg_invuln_ending
	.byte >sfx_prg_eagle_screech,>sfx_prg_eagle_swoop,>sfx_prg_eagle_catch
	.byte >sfx_prg_heart_gained,>sfx_prg_milestone,>sfx_prg_gator_splash
	.byte >sfx_prg_fish_eat,>sfx_prg_gift

; ===== programs (see sfx_update in sound.asm) =====
sfx_prg_menu_move:	; 1, prio 1, 0.18 s
	.byte $0c,$00,$a4,$00,$06,$00,$41,$0b,$4c,$02,$0b,$53,$02,$02,$40,$01
	.byte $05,$00
sfx_prg_menu_select:	; 2, prio 3, 0.62 s
	.byte $0c,$00,$c8,$00,$08,$40,$41,$0b,$48,$02,$0b,$4c,$02,$0b,$4f,$02
	.byte $0b,$54,$03,$0b,$4f,$02,$0b,$54,$06,$02,$40,$01,$0e,$00
sfx_prg_splash_dive:	; 3, prio 3, 0.48 s
	.byte $0c,$09,$00,$00,$08,$00,$81,$0d,$10,$f8,$02,$ef,$0a,$06,$00,$00
	.byte $0c,$06,$00,$00,$08,$00,$11,$0d,$ce,$22,$48,$fd,$08,$06,$00,$00
	.byte $02,$10,$01,$06,$00
sfx_prg_surface:	; 4, prio 2, 0.38 s
	.byte $0c,$00,$84,$00,$08,$00,$11,$0d,$0a,$0d,$56,$04,$06,$06,$00,$00
	.byte $0d,$89,$13,$80,$06,$06,$06,$00,$00,$0e,$81,$59,$02,$02,$80,$01
	.byte $05,$00
sfx_prg_bank_bump:	; 5, prio 1, 0.22 s
	.byte $0c,$05,$00,$00,$08,$00,$81,$0b,$4a,$01,$02,$41,$0d,$f7,$0a,$f5
	.byte $fe,$07,$06,$00,$00,$02,$40,$01,$03,$00
sfx_prg_gator_chomp:	; 6, prio 6, 0.60 s
	.byte $0c,$00,$c2,$00,$04,$00,$81,$09,$02,$0e,$81,$5e,$01,$0b,$51,$01
	.byte $02,$21,$0d,$a2,$0e,$ff,$fd,$05,$06,$00,$00,$02,$20,$01,$03,$0a
	.byte $18,$0c,$08,$00,$00,$04,$00,$81,$0d,$b4,$57,$d8,$fa,$08,$06,$00
	.byte $00,$02,$80,$01,$02,$00
sfx_prg_hurt:	; 7, prio 6, 0.62 s
	.byte $0c,$00,$c6,$00,$08,$b0,$41,$0b,$47,$02,$0e,$81,$54,$01,$02,$41
	.byte $0d,$89,$3a,$e3,$fb,$0a,$06,$d8,$ff,$01,$08,$06,$00,$00,$02,$40
	.byte $01,$0a,$00
sfx_prg_crawfish_pickup:	; 8, prio 5, 0.84 s
	.byte $0c,$00,$d9,$00,$03,$60,$41,$0b,$48,$01,$0b,$4c,$01,$0b,$4f,$01
	.byte $0b,$54,$01,$0b,$4c,$01,$0b,$4f,$01,$0b,$54,$01,$0b,$58,$01,$0b
	.byte $4f,$01,$0b,$54,$01,$0b,$58,$01,$0b,$5b,$01,$0b,$54,$01,$0b,$58
	.byte $01,$0b,$5b,$01,$0b,$5e,$03,$02,$40,$09,$03,$0b,$58,$01,$0b,$5b
	.byte $01,$0a,$08,$01,$12,$00
sfx_prg_invuln_ending:	; 9, prio 3, 1.02 s
	.byte $0c,$00,$a3,$00,$03,$00,$40,$09,$03,$0e,$41,$51,$04,$02,$40,$01
	.byte $03,$0e,$41,$4c,$04,$02,$40,$01,$06,$0a,$12,$00
sfx_prg_eagle_screech:	; 10, prio 6, 1.20 s
	.byte $0c,$10,$e8,$80,$01,$18,$41,$0d,$23,$4e,$c9,$07,$05,$09,$05,$06
	.byte $04,$01,$01,$02,$06,$fc,$fe,$01,$02,$0a,$0c,$0d,$12,$75,$22,$f4
	.byte $04,$02,$81,$01,$01,$02,$41,$0d,$68,$83,$23,$fb,$12,$06,$00,$00
	.byte $02,$40,$01,$0c,$00
sfx_prg_eagle_swoop:	; 11, prio 4, 1.16 s
	.byte $0c,$90,$fa,$00,$08,$00,$81,$0d,$67,$11,$cf,$03,$1c,$06,$00,$00
	.byte $02,$80,$0d,$08,$7c,$84,$fc,$1e,$06,$00,$00,$00
sfx_prg_eagle_catch:	; 12, prio 8, 1.52 s
	.byte $0c,$00,$fa,$00,$02,$30,$41,$09,$04,$0b,$4d,$02,$0b,$53,$02,$0a
	.byte $08,$02,$81,$0d,$10,$f8,$2b,$ea,$06,$06,$00,$00,$02,$21,$0d,$9c
	.byte $45,$f8,$fd,$1e,$02,$20,$01,$18,$00
sfx_prg_heart_gained:	; 13, prio 7, 1.30 s
	.byte $0c,$00,$c8,$00,$05,$28,$41,$0b,$43,$04,$0b,$48,$04,$0b,$4c,$04
	.byte $0b,$4f,$04,$02,$40,$01,$01,$0e,$41,$4c,$03,$02,$40,$01,$01,$0e
	.byte $41,$4f,$03,$02,$40,$01,$01,$0e,$41,$54,$14,$02,$40,$01,$14,$00
sfx_prg_milestone:	; 14, prio 2, 0.54 s
	.byte $0c,$0a,$00,$00,$08,$00,$11,$0b,$4f,$03,$0b,$56,$16,$02,$10,$01
	.byte $02,$00
sfx_prg_gator_splash:	; 15, prio 2, 0.32 s
	.byte $0c,$07,$00,$00,$08,$00,$81,$0d,$99,$d0,$c3,$f4,$0c,$06,$00,$00
	.byte $02,$80,$01,$04,$00
sfx_prg_fish_eat:	; 16, prio 5, 0.40 s
	.byte $0c,$00,$a3,$00,$06,$00,$81,$0b,$56,$01,$02,$41,$0d,$ed,$15,$92
	.byte $fd,$03,$06,$00,$00,$0e,$81,$54,$01,$02,$41,$0d,$89,$13,$d6,$fd
	.byte $03,$06,$00,$00,$02,$11,$0d,$67,$11,$2b,$02,$04,$06,$00,$00,$02
	.byte $41,$0d,$9c,$45,$ac,$08,$04,$06,$00,$00,$02,$40,$01,$04,$00
sfx_prg_gift:	; 17, prio 6, 0.80 s
	.byte $0c,$00,$f9,$00,$08,$00,$11,$0b,$56,$01,$0b,$4a,$03,$0b,$5a,$01
	.byte $0b,$4e,$03,$0b,$5d,$01,$0b,$51,$03,$0b,$56,$06,$09,$04,$0b,$5d
	.byte $01,$0b,$56,$02,$0a,$08,$02,$10,$01,$0a,$00
