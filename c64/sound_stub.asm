; ==========================================================
; Otter Raid - silent sound interface (engine tests only)
; Build with -DSOUND_STUB=1 to use it instead of c64/sound.
; ==========================================================
sound_init:
music_play:
sfx_play:
sound_update:
sound_pause:
	rts
snd_ntsc:
	.byte 0
