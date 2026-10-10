; GENERATED FILE - do not edit by hand.
; Source: music/*.txt   Generator: tools/music.py
; Regenerate with:  python3 tools/music.py

; ===== song table: order lists for voices 1-3 =====
mus_song_tbl:
	.word mus_ord_title_1,mus_ord_title_2,mus_ord_title_3
	.word mus_ord_river_1,mus_ord_river_2,mus_ord_river_3
	.word mus_ord_eagle_1,mus_ord_eagle_2,mus_ord_eagle_3
	.word mus_ord_life_lost_1,mus_ord_life_lost_2,mus_ord_life_lost_3
	.word mus_ord_game_over_1,mus_ord_game_over_2,mus_ord_game_over_3
	.word mus_ord_home_1,mus_ord_home_2,mus_ord_home_3
	.word mus_ord_high_score_1,mus_ord_high_score_2,mus_ord_high_score_3

; ===== order lists =====
; title (MUS_TITLE = 1): loops after 7.7 s intro, 61.4 s loop
mus_ord_title_1:
	.byte $2b,$2b,$a5,$2b,$a7,$2b,$a0,$2b,$a9,$2b,$a5,$2b,$a7,$2b,$a0,$2b
	.byte $a9,$2b,$a5,$2c,$a7,$2c,$a0,$2b,$2d,$a9,$2d,$a5,$2d,$a7,$2d,$a0
	.byte $2d,$a9,$2d,$a5,$2e,$a7,$2e,$a0,$2d,$a9,$2f,$a5,$2f,$a0,$2f,$a7
	.byte $2f,$a9,$2f,$a5,$2f,$a2,$30,$a7,$30,$2f,$a0,$2d,$a9,$2d,$a5,$2d
	.byte $a7,$2d,$a0,$2d,$a9,$2d,$a5,$2e,$a7,$2e,$a0,$2d,$fe,$06
mus_ord_title_2:
	.byte $31,$c1,$a0,$32,$33,$c2,$32,$34,$c4,$35,$c1,$36,$fe,$01
mus_ord_title_3:
	.byte $37,$37,$99,$37,$9b,$37,$a0,$37,$9d,$38,$99,$37,$9b,$37,$a0,$37
	.byte $9d,$38,$99,$39,$9b,$39,$a0,$37,$37,$9d,$38,$99,$37,$9b,$37,$a0
	.byte $37,$9d,$38,$99,$39,$9b,$39,$a0,$37,$9d,$38,$99,$37,$a0,$37,$9b
	.byte $37,$9d,$38,$99,$37,$a2,$3a,$9b,$39,$37,$a0,$37,$9d,$38,$99,$37
	.byte $9b,$37,$a0,$37,$9d,$38,$99,$39,$9b,$39,$a0,$37,$fe,$06
; river (MUS_RIVER = 2): loops after 3.8 s intro, 76.8 s loop
mus_ord_river_1:
	.byte $1e,$1e,$a0,$1e,$1e,$9c,$1e,$9e,$1e,$a0,$1e,$1e,$9c,$1e,$9e,$1f
	.byte $9b,$1f,$a3,$1e,$9e,$1e,$99,$1e,$a0,$1e,$a3,$1e,$9e,$1e,$9c,$1e
	.byte $9b,$1e,$a0,$1e,$1e,$9c,$1e,$9e,$1e,$a0,$1e,$1e,$9c,$1e,$9e,$1f
	.byte $9b,$1f,$a0,$20,$9c,$20,$a3,$20,$9e,$20,$a0,$20,$9c,$20,$9b,$20
	.byte $20,$a0,$1e,$1e,$9c,$1e,$9e,$1e,$a0,$1e,$1e,$9c,$1e,$9e,$1f,$9b
	.byte $1f,$fe,$02
mus_ord_river_2:
	.byte $21,$c1,$a0,$22,$c1,$23,$c2,$22,$c3,$24,$c1,$25,$fe,$01
mus_ord_river_3:
	.byte $26,$26,$a0,$26,$26,$9c,$27,$9e,$27,$a0,$26,$26,$9c,$27,$9e,$28
	.byte $9b,$28,$a3,$29,$9e,$29,$99,$2a,$a0,$2a,$a3,$29,$9e,$29,$9c,$29
	.byte $9b,$29,$a0,$26,$26,$9c,$27,$9e,$27,$a0,$26,$26,$9c,$27,$9e,$28
	.byte $9b,$28,$a0,$2a,$9c,$29,$a3,$29,$9e,$29,$a0,$2a,$9c,$29,$9b,$29
	.byte $29,$a0,$26,$26,$9c,$27,$9e,$27,$a0,$26,$26,$9c,$27,$9e,$28,$9b
	.byte $28,$fe,$02
; eagle (MUS_EAGLE = 3): loops after 1.6 s intro, 6.4 s loop
mus_ord_eagle_1:
	.byte $00,$a0,$01,$01,$a1,$01,$a0,$01,$fe,$01
mus_ord_eagle_2:
	.byte $02,$a0,$03,$fe,$01
mus_ord_eagle_3:
	.byte $04,$a0,$05,$05,$a1,$05,$a0,$05,$fe,$01
; life_lost (MUS_LIFE_LOST = 4): plays once, 2.9 s
mus_ord_life_lost_1:
	.byte $1b,$ff
mus_ord_life_lost_2:
	.byte $1c,$ff
mus_ord_life_lost_3:
	.byte $1d,$ff
; game_over (MUS_GAME_OVER = 5): plays once, 7.7 s
mus_ord_game_over_1:
	.byte $06,$ff
mus_ord_game_over_2:
	.byte $07,$ff
mus_ord_game_over_3:
	.byte $08,$ff
; home (MUS_HOME = 6): loops after 3.4 s intro, 16.8 s loop
mus_ord_home_1:
	.byte $10,$a0,$11,$a7,$11,$11,$a0,$11,$11,$a5,$11,$a0,$11,$11,$12,$fe
	.byte $01
mus_ord_home_2:
	.byte $13,$c4,$a0,$14,$c2,$15,$fe,$01
mus_ord_home_3:
	.byte $16,$a0,$17,$9b,$17,$17,$a0,$17,$18,$99,$17,$a0,$19,$17,$1a,$fe
	.byte $01
; high_score (MUS_HIGH_SCORE = 7): loops after 0.0 s intro, 20.5 s loop
mus_ord_high_score_1:
	.byte $a0,$09,$9d,$09,$99,$09,$9b,$09,$a0,$09,$9d,$09,$a2,$0a,$9b,$0a
	.byte $a0,$09,$fe,$00
mus_ord_high_score_2:
	.byte $a0,$0b,$fe,$00
mus_ord_high_score_3:
	.byte $a0,$0c,$9d,$0d,$99,$0c,$9b,$0c,$a0,$0c,$9d,$0d,$a2,$0e,$9b,$0f
	.byte $a0,$0c,$fe,$00

; ===== patterns =====
mus_pat_lo:
	.byte <mus_pat_000,<mus_pat_001,<mus_pat_002,<mus_pat_003,<mus_pat_004
	.byte <mus_pat_005,<mus_pat_006,<mus_pat_007,<mus_pat_008,<mus_pat_009
	.byte <mus_pat_010,<mus_pat_011,<mus_pat_012,<mus_pat_013,<mus_pat_014
	.byte <mus_pat_015,<mus_pat_016,<mus_pat_017,<mus_pat_018,<mus_pat_019
	.byte <mus_pat_020,<mus_pat_021,<mus_pat_022,<mus_pat_023,<mus_pat_024
	.byte <mus_pat_025,<mus_pat_026,<mus_pat_027,<mus_pat_028,<mus_pat_029
	.byte <mus_pat_030,<mus_pat_031,<mus_pat_032,<mus_pat_033,<mus_pat_034
	.byte <mus_pat_035,<mus_pat_036,<mus_pat_037,<mus_pat_038,<mus_pat_039
	.byte <mus_pat_040,<mus_pat_041,<mus_pat_042,<mus_pat_043,<mus_pat_044
	.byte <mus_pat_045,<mus_pat_046,<mus_pat_047,<mus_pat_048,<mus_pat_049
	.byte <mus_pat_050,<mus_pat_051,<mus_pat_052,<mus_pat_053,<mus_pat_054
	.byte <mus_pat_055,<mus_pat_056,<mus_pat_057,<mus_pat_058
mus_pat_hi:
	.byte >mus_pat_000,>mus_pat_001,>mus_pat_002,>mus_pat_003,>mus_pat_004
	.byte >mus_pat_005,>mus_pat_006,>mus_pat_007,>mus_pat_008,>mus_pat_009
	.byte >mus_pat_010,>mus_pat_011,>mus_pat_012,>mus_pat_013,>mus_pat_014
	.byte >mus_pat_015,>mus_pat_016,>mus_pat_017,>mus_pat_018,>mus_pat_019
	.byte >mus_pat_020,>mus_pat_021,>mus_pat_022,>mus_pat_023,>mus_pat_024
	.byte >mus_pat_025,>mus_pat_026,>mus_pat_027,>mus_pat_028,>mus_pat_029
	.byte >mus_pat_030,>mus_pat_031,>mus_pat_032,>mus_pat_033,>mus_pat_034
	.byte >mus_pat_035,>mus_pat_036,>mus_pat_037,>mus_pat_038,>mus_pat_039
	.byte >mus_pat_040,>mus_pat_041,>mus_pat_042,>mus_pat_043,>mus_pat_044
	.byte >mus_pat_045,>mus_pat_046,>mus_pat_047,>mus_pat_048,>mus_pat_049
	.byte >mus_pat_050,>mus_pat_051,>mus_pat_052,>mus_pat_053,>mus_pat_054
	.byte >mus_pat_055,>mus_pat_056,>mus_pat_057,>mus_pat_058
mus_pat_000:		; eagle.sting1
	.byte $d4,$93,$30,$c7,$9d,$1c,$1c,$00
mus_pat_001:		; eagle.ebass
	.byte $c7,$84,$1c,$1c,$1d,$1c,$d1,$89,$18,$c7,$84,$1c,$1f,$1c,$1c,$1d
	.byte $1c,$d1,$89,$18,$c7,$84,$22,$21,$00
mus_pat_002:		; eagle.sting2
	.byte $c4,$89,$47,$46,$45,$44,$a7,$43,$00
mus_pat_003:		; eagle.etrill
	.byte $c6,$7f,$50,$47,$47,$48,$a7,$47,$43,$00
mus_pat_004:		; eagle.sting3
	.byte $cd,$9d,$34,$34,$93,$34,$00
mus_pat_005:		; eagle.estab
	.byte $89,$60,$cd,$34,$d2,$30,$cd,$34,$60,$34,$d2,$30,$cd,$34,$00
mus_pat_006:		; game_over.gobass
	.byte $c9,$bf,$21,$1f,$1d,$1c,$7f,$80,$21,$00
mus_pat_007:		; game_over.gomel
	.byte $c5,$9f,$40,$3e,$3c,$3b,$3c,$39,$3b,$38,$7f,$80,$39,$00
mus_pat_008:		; game_over.gochord
	.byte $cf,$7f,$80,$2d,$ce,$bf,$29,$28,$cf,$7f,$80,$2d,$00
mus_pat_009:		; high_score.hsb
	.byte $c9,$9f,$1d,$24,$29,$24,$00
mus_pat_010:		; high_score.hsbh
	.byte $c9,$9f,$1d,$24,$00
mus_pat_011:		; high_score.hsmel
	.byte $c3,$af,$39,$8f,$37,$9f,$35,$39,$af,$3e,$8f,$3c,$9f,$39,$35,$af
	.byte $37,$8f,$39,$9f,$3a,$3e,$bf,$3c,$9f,$37,$34,$af,$35,$8f,$37,$9f
	.byte $39,$3c,$af,$3e,$8f,$40,$9f,$41,$3e,$3a,$3e,$3c,$3a,$7f,$60,$39
	.byte $9f,$60,$00
mus_pat_012:		; high_score.hsarpM
	.byte $ce,$bf,$29,$29,$00
mus_pat_013:		; high_score.hsarpm
	.byte $cf,$bf,$29,$29,$00
mus_pat_014:		; high_score.hsarpmh
	.byte $cf,$bf,$29,$00
mus_pat_015:		; high_score.hsarpMh
	.byte $ce,$bf,$29,$00
mus_pat_016:		; home.fanbass
	.byte $c7,$9b,$18,$18,$18,$d3,$8d,$18,$18,$18,$18,$d1,$18,$18,$00
mus_pat_017:		; home.wbass
	.byte $c7,$9b,$18,$60,$1f,$00
mus_pat_018:		; home.tagbass
	.byte $c7,$9b,$1d,$24,$1d,$d1,$8d,$18,$18,$c7,$9b,$18,$d0,$18,$00
mus_pat_019:		; home.fanmel
	.byte $c4,$94,$37,$86,$37,$9b,$3c,$40,$b7,$43,$94,$37,$86,$37,$00
mus_pat_020:		; home.hbmel
	.byte $9b,$39,$37,$3c,$b7,$3b,$94,$37,$86,$37,$9b,$39,$37,$3e,$b7,$3c
	.byte $94,$37,$86,$37,$9b,$43,$40,$3c,$3b,$39,$94,$41,$86,$41,$9b,$40
	.byte $3c,$3e,$7f,$54,$3c,$00
mus_pat_021:		; home.tagmel
	.byte $8d,$41,$45,$48,$45,$41,$45,$43,$47,$9b,$48,$94,$37,$86,$37,$00
mus_pat_022:		; home.fanharm
	.byte $c4,$94,$34,$86,$34,$9b,$37,$3c,$b7,$40,$9b,$60,$00
mus_pat_023:		; home.wstab
	.byte $9b,$60,$ca,$30,$30,$00
mus_pat_024:		; home.wstab7
	.byte $9b,$60,$cc,$30,$30,$00
mus_pat_025:		; home.wstabcg
	.byte $9b,$60,$ca,$30,$cc,$2b,$00
mus_pat_026:		; home.tagstab
	.byte $ca,$8d,$29,$29,$60,$29,$29,$60,$cc,$2b,$2b,$ca,$9b,$30,$60,$00
mus_pat_027:		; life_lost.llbass
	.byte $c9,$97,$24,$23,$22,$7f,$48,$21,$00
mus_pat_028:		; life_lost.llmel
	.byte $c4,$97,$37,$36,$35,$f1,$fb,$ff,$7f,$48,$34,$00
mus_pat_029:		; life_lost.llchord
	.byte $7f,$48,$60,$cf,$2d,$00
mus_pat_030:		; river.rbass
	.byte $c7,$85,$21,$21,$2d,$21,$d1,$8b,$18,$c7,$85,$21,$2d,$21,$21,$2d
	.byte $21,$d1,$8b,$18,$c7,$85,$2d,$21,$00
mus_pat_031:		; river.rbassh
	.byte $c7,$85,$21,$21,$2d,$21,$d1,$8b,$18,$c7,$85,$21,$2d,$00
mus_pat_032:		; river.rbassL
	.byte $c9,$8b,$21,$21,$2d,$21,$21,$21,$2d,$21,$00
mus_pat_033:		; river.introR
	.byte $7f,$9c,$60,$c1,$8b,$34,$38,$3b,$00
mus_pat_034:		; river.melRA
	.byte $97,$39,$a3,$40,$8b,$3e,$3c,$3b,$a3,$3c,$8b,$39,$af,$39,$97,$39
	.byte $a3,$3c,$8b,$3e,$97,$40,$a3,$3e,$8b,$3c,$97,$3b,$37,$39,$a3,$40
	.byte $8b,$43,$97,$45,$8b,$43,$40,$3e,$40,$97,$3c,$39,$a3,$41,$8b,$40
	.byte $97,$3e,$3c,$3e,$3b,$38,$3b,$00
mus_pat_035:		; river.melRB
	.byte $8b,$3c,$3e,$40,$43,$97,$40,$3c,$8b,$3e,$40,$3e,$3b,$97,$37,$3b
	.byte $8b,$39,$3e,$41,$45,$97,$43,$41,$a3,$40,$8b,$3e,$97,$3c,$39,$8b
	.byte $3c,$3e,$40,$43,$97,$48,$43,$8b,$45,$43,$41,$40,$97,$3e,$3b,$a3
	.byte $3c,$8b,$39,$97,$35,$39,$38,$3b,$40,$3e,$00
mus_pat_036:		; river.padRC
	.byte $7f,$60,$40,$41,$40,$3e,$3c,$3c,$3b,$38,$00
mus_pat_037:		; river.soloR
	.byte $85,$39,$3c,$40,$45,$43,$40,$3c,$40,$3e,$3c,$3b,$39,$37,$39,$3b
	.byte $3c,$40,$3e,$3c,$3b,$39,$3b,$3c,$3e,$8b,$40,$45,$40,$3c,$85,$3c
	.byte $39,$35,$39,$3c,$41,$45,$41,$40,$3e,$3c,$3e,$8b,$40,$3c,$85,$3e
	.byte $3b,$37,$3b,$3e,$43,$47,$43,$41,$40,$3e,$40,$8b,$41,$3e,$40,$45
	.byte $48,$45,$40,$45,$48,$4c,$4a,$48,$47,$45,$43,$40,$3e,$40,$85,$41
	.byte $40,$41,$45,$8b,$48,$45,$85,$41,$40,$41,$45,$8b,$48,$45,$47,$43
	.byte $3e,$3b,$38,$3b,$40,$44,$00
mus_pat_038:		; river.rarpm
	.byte $d2,$8b,$30,$cb,$2d,$d2,$24,$cb,$2d,$d2,$24,$cb,$2d,$d2,$24,$cb
	.byte $2d,$00
mus_pat_039:		; river.rarpM
	.byte $d2,$8b,$30,$ca,$2d,$d2,$24,$ca,$2d,$d2,$24,$ca,$2d,$d2,$24,$ca
	.byte $2d,$00
mus_pat_040:		; river.rarpMh
	.byte $d2,$8b,$30,$ca,$2d,$d2,$24,$ca,$2d,$00
mus_pat_041:		; river.rarp2M
	.byte $ca,$91,$2d,$2d,$8b,$2d,$91,$2d,$2d,$8b,$2d,$00
mus_pat_042:		; river.rarp2m
	.byte $cb,$91,$2d,$2d,$8b,$2d,$91,$2d,$2d,$8b,$2d,$00
mus_pat_043:		; title.bassL
	.byte $c7,$8b,$18,$24,$85,$18,$18,$8b,$24,$18,$24,$1f,$24,$00
mus_pat_044:		; title.bassLh
	.byte $c7,$8b,$18,$24,$85,$18,$18,$8b,$24,$00
mus_pat_045:		; title.bassS
	.byte $c7,$8b,$18,$85,$24,$18,$d1,$8b,$18,$c7,$85,$18,$24,$8b,$18,$85
	.byte $24,$18,$d1,$8b,$18,$c7,$85,$24,$18,$00
mus_pat_046:		; title.bassSh
	.byte $c7,$8b,$18,$85,$24,$18,$d1,$8b,$18,$c7,$85,$18,$24,$00
mus_pat_047:		; title.bassF
	.byte $c8,$8b,$18,$85,$24,$18,$d1,$8b,$18,$c8,$85,$18,$24,$8b,$18,$85
	.byte $24,$18,$d1,$8b,$18,$c8,$85,$24,$18,$00
mus_pat_048:		; title.bassFh
	.byte $c8,$8b,$18,$85,$24,$18,$d1,$8b,$18,$c8,$85,$18,$24,$00
mus_pat_049:		; title.intro
	.byte $7f,$c0,$60,$7f,$90,$60,$c1,$8b,$37,$39,$3b,$3e,$00
mus_pat_050:		; title.melA
	.byte $8b,$37,$3c,$91,$40,$85,$3e,$8b,$3c,$40,$97,$43,$45,$8b,$43,$40
	.byte $91,$3c,$85,$3e,$97,$40,$91,$41,$85,$40,$8b,$3e,$3c,$97,$39,$3c
	.byte $8b,$3e,$43,$41,$40,$97,$3e,$3b,$8b,$37,$3c,$91,$40,$85,$3e,$8b
	.byte $3c,$40,$97,$43,$48,$8b,$47,$45,$91,$40,$85,$45,$97,$48,$45,$8b
	.byte $43,$41,$43,$45,$47,$4a,$00
mus_pat_051:		; title.endA1
	.byte $a3,$48,$85,$43,$45,$8b,$43,$40,$3e,$3c,$00
mus_pat_052:		; title.endA2
	.byte $af,$48,$60,$00
mus_pat_053:		; title.melB
	.byte $a3,$39,$8b,$3b,$97,$3c,$40,$a3,$41,$8b,$40,$97,$3e,$3c,$a3,$40
	.byte $8b,$3e,$97,$3c,$37,$a3,$3b,$8b,$39,$97,$37,$3b,$a3,$3c,$8b,$3e
	.byte $97,$40,$45,$a3,$45,$8b,$43,$97,$41,$3c,$3e,$41,$43,$47,$7f,$48
	.byte $4a,$97,$60,$00
mus_pat_054:		; title.solo
	.byte $85,$48,$43,$40,$43,$48,$4c,$4f,$4c,$8b,$48,$43,$40,$43,$85,$45
	.byte $40,$3c,$40,$45,$48,$4c,$48,$8b,$45,$40,$3c,$40,$85,$41,$3c,$39
	.byte $3c,$41,$45,$48,$45,$8b,$41,$3c,$39,$3c,$85,$43,$3e,$3b,$3e,$43
	.byte $47,$4a,$47,$8b,$43,$41,$40,$3e,$a3,$40,$8b,$43,$97,$48,$43,$a3
	.byte $45,$8b,$48,$97,$4c,$48,$41,$8b,$45,$48,$97,$47,$8b,$4a,$47,$af
	.byte $48,$97,$60,$43,$00
mus_pat_055:		; title.arpM
	.byte $ca,$91,$30,$30,$8b,$30,$91,$30,$30,$8b,$30,$00
mus_pat_056:		; title.arpm
	.byte $cb,$91,$30,$30,$8b,$30,$91,$30,$30,$8b,$30,$00
mus_pat_057:		; title.arpMh
	.byte $ca,$91,$30,$30,$8b,$30,$00
mus_pat_058:		; title.arpmh
	.byte $cb,$91,$30,$30,$8b,$30,$00

; ===== instruments (index 0 = silent) =====
; 1=lead 2=leadhi 3=flute 4=brass 5=sadlead 6=trill 7=bass 8=bassf 9=basssoft
; 10=arpmaj 11=arpmin 12=arpdom7 13=arpdim 14=arpslow 15=arpslowm 16=kick
; 17=snare 18=hat 19=tom 20=crash
mus_ins_ad:
	.byte $00,$09,$09,$18,$19,$0a,$08,$09,$09,$09,$08,$08,$08,$08,$09,$09
	.byte $07,$08,$02,$08,$0b
mus_ins_sr:
	.byte $00,$a9,$a9,$a9,$b9,$9a,$a8,$79,$89,$99,$68,$68,$68,$68,$59,$59
	.byte $00,$00,$00,$00,$00
mus_ins_wave:
	.byte $00,$02,$04,$07,$09,$07,$0b,$14,$17,$07,$1a,$1e,$22,$27,$2b,$34
	.byte $3d,$46,$4e,$50,$58
mus_ins_pwlo:
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	.byte $00,$00,$00,$00,$00
mus_ins_pwhi:
	.byte $00,$06,$04,$08,$08,$08,$03,$03,$08,$08,$05,$05,$05,$05,$08,$08
	.byte $08,$08,$08,$08,$08
mus_ins_pwspd:
	.byte $00,$18,$20,$00,$00,$00,$28,$20,$00,$00,$30,$30,$30,$30,$00,$00
	.byte $00,$00,$00,$00,$00
mus_ins_pwmin:
	.byte $00,$03,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02
	.byte $01,$01,$02,$01,$02
mus_ins_pwmax:
	.byte $00,$0c,$0b,$0e,$0e,$0e,$09,$08,$0e,$0e,$0a,$0a,$0a,$0a,$0e,$0e
	.byte $0e,$0e,$0e,$0e,$0e
mus_ins_vdly:
	.byte $00,$0e,$0c,$0a,$0a,$08,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	.byte $00,$00,$00,$00,$00
mus_ins_vspd:
	.byte $00,$02,$02,$02,$02,$03,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	.byte $00,$00,$00,$00,$00
mus_ins_vdep:
	.byte $00,$03,$03,$03,$03,$03,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	.byte $00,$00,$00,$00,$00
mus_ins_filt:
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$01,$00,$00,$00,$00,$00,$00,$00
	.byte $00,$00,$00,$00,$00
mus_ins_flags:
	.byte $00,$01,$01,$00,$00,$00,$01,$01,$00,$00,$01,$01,$01,$01,$00,$00
	.byte $00,$00,$00,$00,$00

; ===== wave table ($FF in wave: jump to note column) =====
mus_wt_wave:
	.byte $00,$ff,$40,$ff,$40,$40,$ff,$10,$ff,$20,$ff,$40,$40,$40,$40,$40
	.byte $40,$40,$40,$ff,$80,$40,$ff,$80,$20,$ff,$40,$40,$40,$ff,$40,$40
	.byte $40,$ff,$40,$40,$40,$40,$ff,$40,$40,$40,$ff,$10,$10,$10,$10,$10
	.byte $10,$10,$10,$ff,$10,$10,$10,$10,$10,$10,$10,$10,$ff,$80,$40,$40
	.byte $40,$40,$40,$40,$40,$ff,$80,$40,$40,$80,$80,$80,$80,$ff,$80,$ff
	.byte $80,$40,$40,$40,$40,$40,$40,$ff,$80,$80,$80,$ff
mus_wt_note:
	.byte $00,$00,$00,$02,$0c,$00,$05,$00,$07,$00,$09,$00,$00,$01,$01,$00
	.byte $00,$01,$01,$0f,$c8,$00,$15,$c8,$00,$18,$00,$04,$07,$1a,$00,$03
	.byte $07,$1e,$00,$04,$07,$0a,$22,$00,$03,$06,$27,$00,$00,$04,$04,$07
	.byte $07,$0c,$0c,$2b,$00,$00,$03,$03,$07,$07,$0c,$0c,$34,$d1,$b0,$ab
	.byte $a7,$a4,$a1,$9f,$9c,$44,$d5,$b7,$b3,$d2,$d0,$ce,$cc,$4c,$de,$4e
	.byte $cd,$ad,$a9,$a6,$a3,$a1,$9f,$56,$de,$da,$d7,$5a

; ===== filter programs (index 0 unused) =====
mus_flt_cut:
	.byte $00,$70
mus_flt_lim:
	.byte $00,$1c
mus_flt_spd:
	.byte $00,$fd
mus_flt_res:
	.byte $00,$60
mus_flt_mode:
	.byte $0f,$1f

; ===== note frequencies, C-0..C-8 =====
mus_freq_lo:		; PAL
	.byte $16,$27,$39,$4b,$5f,$74,$8a,$a1,$ba,$d4,$f0,$0e,$2d,$4e,$71,$96
	.byte $be,$e7,$14,$42,$74,$a9,$e0,$1b,$5a,$9c,$e2,$2d,$7b,$cf,$27,$85
	.byte $e8,$51,$c1,$37,$b4,$38,$c4,$59,$f7,$9d,$4e,$0a,$d0,$a2,$81,$6d
	.byte $67,$70,$89,$b2,$ed,$3b,$9c,$13,$a0,$45,$02,$da,$ce,$e0,$11,$64
	.byte $da,$76,$39,$26,$40,$89,$04,$b4,$9c,$c0,$23,$c8,$b4,$eb,$72,$4c
	.byte $80,$12,$08,$68,$39,$80,$45,$90,$68,$d6,$e3,$99,$00,$24,$10,$ff
	.byte $ff
mus_freq_hi:
	.byte $01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$02,$02,$02,$02,$02
	.byte $02,$02,$03,$03,$03,$03,$03,$04,$04,$04,$04,$05,$05,$05,$06,$06
	.byte $06,$07,$07,$08,$08,$09,$09,$0a,$0a,$0b,$0c,$0d,$0d,$0e,$0f,$10
	.byte $11,$12,$13,$14,$15,$17,$18,$1a,$1b,$1d,$1f,$20,$22,$24,$27,$29
	.byte $2b,$2e,$31,$34,$37,$3a,$3e,$41,$45,$49,$4e,$52,$57,$5c,$62,$68
	.byte $6e,$75,$7c,$83,$8b,$93,$9c,$a5,$af,$b9,$c4,$d0,$dd,$ea,$f8,$ff
	.byte $ff
mus_freqn_lo:		; NTSC
	.byte $0c,$1c,$2d,$3f,$52,$66,$7b,$92,$aa,$c3,$de,$fa,$18,$38,$5a,$7e
	.byte $a4,$cc,$f7,$24,$54,$86,$bc,$f5,$31,$71,$b4,$fc,$48,$98,$ed,$48
	.byte $a7,$0c,$78,$e9,$62,$e2,$69,$f8,$90,$30,$db,$8f,$4e,$19,$f0,$d3
	.byte $c4,$c3,$d1,$f0,$1f,$61,$b6,$1e,$9d,$32,$df,$a6,$88,$86,$a3,$e0
	.byte $3f,$c2,$6b,$3d,$3a,$64,$be,$4c,$0f,$0c,$46,$bf,$7d,$84,$d6,$7a
	.byte $73,$c8,$7d,$97,$1e,$18,$8b,$7f,$fb,$07,$ac,$f4,$e7,$8f,$f9,$2f
	.byte $ff
mus_freqn_hi:
	.byte $01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$02,$02,$02,$02
	.byte $02,$02,$02,$03,$03,$03,$03,$03,$04,$04,$04,$04,$05,$05,$05,$06
	.byte $06,$07,$07,$07,$08,$08,$09,$09,$0a,$0b,$0b,$0c,$0d,$0e,$0e,$0f
	.byte $10,$11,$12,$13,$15,$16,$17,$19,$1a,$1c,$1d,$1f,$21,$23,$25,$27
	.byte $2a,$2c,$2f,$32,$35,$38,$3b,$3f,$43,$47,$4b,$4f,$54,$59,$5e,$64
	.byte $6a,$70,$77,$7e,$86,$8e,$96,$9f,$a8,$b3,$bd,$c8,$d4,$e1,$ee,$fd
	.byte $ff
