; =====================================================================
; Otter Raid - SID sound system: music player and sound effects
; =====================================================================
; Assembled at $8000 by the main program, followed by the generated
; data files music_data.asm and sfx_data.asm. See docs/c64-sound.md.
;
; Entry points:
;   sound_init    reset SID and all state (call once; IRQs may run)
;   music_play    A = tune (0 = stop music). Starts on next update.
;   sfx_play      A = sfx 1..SFX_COUNT, priority filtered.
;                 Preserves A, X and Y; reentrant.
;   sound_update  once per frame from the raster IRQ.
;   sound_pause   A = 1 pause (gates off, music frozen), A = 0 resume.
;   snd_ntsc      byte: set to 1 on NTSC machines (tempo correction).
; music_play, sfx_play and sound_pause only post a request that the
; next sound_update carries out, so they are safe from main code
; while the IRQ runs. music_play / sound_pause keep X and Y.
;
; Status bytes (read only):
;   snd_music_busy  number of music voices still running (0 = done)
;   snd_mus_loops   counts how often the tune has looped (voice 1)
;   sfx_cur         sfx number playing now, 0 = none
;
; Zero page: only $E0-$EF. No ROM calls. Self contained code.

; ===== SID registers =====
SND_SID		= $D400		; voice regs: SND_SID + voice offset
SND_FC_LO	= $D415
SND_FC_HI	= $D416
SND_RES_FILT	= $D417
SND_MODE_VOL	= $D418
SND_V3_FREQ	= $D40E
SND_V3_PW	= $D410
SND_V3_CTRL	= $D412
SND_V3_AD	= $D413
SND_V3_SR	= $D414

; ===== zero page ($E0-$EF only) =====
snd_zp_ptr	= $E0		; pattern read pointer (2)
snd_zp_ord	= $E2		; order list read pointer (2)
sfx_zp_ptr	= $E4		; sfx program pointer (2)
snd_zp_tmp	= $E6		; scratch (1)

; ===== player constants =====
SND_HR_FRAMES	= 2		; hard restart: frames before a note
SND_EV_REST	= $60		; pattern event: gate off
SND_EV_TIE	= $61		; pattern event: keep sounding
SND_EV_END	= $FF		; internal: voice finished
SND_ST_RUN	= $80		; voice state: running
SND_ST_PEND	= $40		; voice state: next event fetched
SND_MUTE_HARD	= $80		; mute: sfx owns voice / paused
SND_MUTE_WAIT	= $40		; mute: resume at next hard restart
SND_MUTE_HR	= $20		; mute: hard restart in progress
SND_MUTE_FORCE	= $01		; mute: debug solo mask
SND_NX_LEGATO	= $80		; next-note flag: no retrigger
SND_NX_SLIDE	= $40		; next-note flag: slide value given
SND_IF_KEEPPW	= $01		; instrument flag: keep pulse state

; =====================================================================
; Public entry points
; =====================================================================

; ===== sound_init =====
; Silence the SID and reset every player/sfx variable.
; snd_ntsc is left untouched so it can be set before or after.
sound_init:
	php
	sei
	lda #0
	ldx #$18
snd_init_sid:
	sta SND_SID,x
	dex
	bpl snd_init_sid
	ldx #snd_vars_end-snd_vars-1
snd_init_var:
	sta snd_vars,x
	dex
	bne snd_init_var
	sta snd_vars
	lda #$FF
	sta snd_mreq
	sta snd_preq
	lda #7
	sta snd_voice_mask
	lda #$0F
	sta snd_f_mode
	sta SND_MODE_VOL
	plp
	rts

; ===== music_play =====
; A = tune number (MUS_*), 0 stops the music. Takes effect at the
; next sound_update (a single store, safe while the IRQ runs).
music_play:
	sta snd_mreq
	rts

; ===== sound_pause =====
; A = 1: gate off all voices, freeze music. A = 0: resume (voices
; re-enter at their next note). Sound effects still work while
; paused (e.g. for menu blips); a playing effect is cut on pause.
sound_pause:
	sta snd_preq
	rts

; ===== sfx_play =====
; A = sfx number 1..SFX_COUNT. Keeps the higher priority one of
; this and an already pending request; sound_update then checks
; it against the effect that is currently playing.
; Reentrant (stack only, IRQs held off briefly): callable from main
; code and from an IRQ. Preserves A, X and Y.
sfx_play:
	cmp #SFX_COUNT+1
	bcs sfx_play_out
	php
	sei
	pha
	txa
	pha
	tya
	pha
	tsx
	lda $0103,x		; the sfx number
	tay
	beq sfx_play_rest
	ldx sfx_req
	beq sfx_play_take
	lda sfx_prio_tbl,x
	cmp sfx_prio_tbl,y
	beq sfx_play_take
	bcs sfx_play_rest	; pending one is more important
sfx_play_take:
	sty sfx_req
sfx_play_rest:
	pla
	tay
	pla
	tax
	pla
	plp
sfx_play_out:
	rts

; ===== sound_update =====
; Once per frame. Worst case is bounded (see docs/c64-sound.md).
sound_update:
	lda snd_ntsc
	beq snd_upd_go
	dec snd_ntsc_cnt	; NTSC: skip every 6th frame so
	bpl snd_upd_go		; the tempo matches 50 Hz PAL
	lda #5
	sta snd_ntsc_cnt
	rts
snd_upd_go:
	lda snd_preq		; pause / resume request
	bmi snd_upd_mreq
	ldx #$FF
	stx snd_preq
	cmp snd_paused
	beq snd_upd_mreq
	sta snd_paused
	tax
	beq snd_upd_resume
	jsr snd_do_pause
	jmp snd_upd_mreq
snd_upd_resume:
	jsr snd_do_resume
snd_upd_mreq:
	lda snd_mreq		; music start / stop request
	bmi snd_upd_voices
	ldx #$FF
	stx snd_mreq
	jsr snd_start_tune
	jmp snd_upd_filter
snd_upd_voices:
	lda snd_paused
	bne snd_upd_sfx
	ldx #0
	jsr snd_voice
	ldx #7
	jsr snd_voice
	ldx #14
	jsr snd_voice
snd_upd_filter:
	lda snd_f_spd		; filter: sweep, or rewrite when the
	ora snd_f_dirty		; routing / mode changed
	beq snd_upd_sfx
	jsr snd_filter
snd_upd_sfx:
	jmp sfx_update

; =====================================================================
; Music: tune start / stop, pause
; =====================================================================

; ===== snd_start_tune =====
; A = tune number. Stops all music voices, then sets up the order
; lists. The first notes start 5 frames later, after the usual
; staggered reads and hard restart.
snd_start_tune:
	sta snd_mus_cur
	ldx #0
	jsr snd_stop_voice
	ldx #7
	jsr snd_stop_voice
	ldx #14
	jsr snd_stop_voice
	lda #0
	sta snd_f_route
	sta snd_f_spd
	sta snd_mus_loops
	sta snd_music_busy
	lda #$0F
	sta snd_f_mode
	sta snd_f_dirty
	lda snd_mus_cur
	beq snd_st_rts
	cmp #MUS_COUNT+1
	bcs snd_st_rts
	sec
	sbc #1
	sta snd_zp_tmp
	asl
	adc snd_zp_tmp
	asl			; (tune - 1) * 6
	tay
	ldx #0
	jsr snd_init_voice
	ldx #7
	jsr snd_init_voice
	ldx #14
	jsr snd_init_voice
	lda #3
	sta snd_music_busy
snd_st_rts:
	rts

; ===== snd_stop_voice =====
; X = voice offset. Stop the voice, let the current note release.
snd_stop_voice:
	lda #0
	sta snd_v_state,x
	sta snd_v_gate,x
	lda snd_v_mute,x
	bne snd_sv_rts
	lda snd_v_ctrl,x
	sta SND_SID+4,x
snd_sv_rts:
	rts

; ===== snd_init_voice =====
; X = voice offset, Y = offset into mus_song_tbl (advanced by 2).
snd_init_voice:
	lda mus_song_tbl,y
	sta snd_v_ord_lo,x
	iny
	lda mus_song_tbl,y
	sta snd_v_ord_hi,x
	iny
	lda #0
	sta snd_v_ord_pos,x
	sta snd_v_pat_pos,x
	sta snd_v_trans,x
	sta snd_v_ins,x
	sta snd_v_wptr,x
	sta snd_v_sl_lo,x
	sta snd_v_sl_hi,x
	sta snd_v_ofs_lo,x
	sta snd_v_ofs_hi,x
	sta snd_v_pw_spd,x
	lda #<snd_empty_pat
	sta snd_v_pat_lo,x
	lda #>snd_empty_pat
	sta snd_v_pat_hi,x
	lda #5			; first reads stagger like all others
	sta snd_v_cnt,x
	lda #6
	sta snd_v_dur,x
	lda #SND_ST_RUN
	sta snd_v_state,x
	lda snd_voice_mask	; debug solo: force-mute voices
	and snd_voice_bit,x
	cmp #1
	lda #0
	bcs snd_iv_audible
	lda #SND_MUTE_FORCE
snd_iv_audible:
	cpx #14
	bne snd_iv_mute
	pha
	lda sfx_cur		; sfx owns voice 3 right now
	beq snd_iv_nosfx
	pla
	ora #SND_MUTE_HARD
	bne snd_iv_mute
snd_iv_nosfx:
	pla
snd_iv_mute:
	sta snd_v_mute,x
	rts

; ===== snd_do_pause =====
; Gate off every voice (music and sfx), music is then skipped.
snd_do_pause:
	ldx #0
	jsr snd_gate_off
	ldx #7
	jsr snd_gate_off
	ldx #14
	jsr snd_gate_off
	lda sfx_cur
	beq snd_dp_rts
	lda sfx_ctrl
	and #$FE
	sta SND_V3_CTRL
	lda #0
	sta sfx_cur
	sta sfx_prio
snd_dp_rts:
	rts

snd_gate_off:
	lda #0
	sta snd_v_gate,x
	lda snd_v_mute,x
	bne snd_go_rts
	lda snd_v_ctrl,x
	sta SND_SID+4,x
snd_go_rts:
	rts

; ===== snd_do_resume =====
; Voices come back cleanly at their next hard restart / note.
snd_do_resume:
	ldx #0
	jsr snd_mute_wait
	ldx #7
	jsr snd_mute_wait
	ldx #14
	lda sfx_cur
	beq snd_mute_wait
	rts

; X = voice: mute until the next hard restart (keeps solo bit)
snd_mute_wait:
	lda snd_v_mute,x
	and #SND_MUTE_FORCE
	ora #SND_MUTE_WAIT
	sta snd_v_mute,x
	rts

; =====================================================================
; Music: per-voice frame update
; =====================================================================
; Timeline of one event (note) of length n frames:
;   n frames left ... the event plays, effects run every frame
;   snd_read_at   next event read from the pattern (staggered per
;                 voice so three voices do not parse in one frame)
;   2 frames left hard restart for a retriggered note: gate off,
;                 ADSR 0, instrument preloaded, voice silent
;   0             snd_apply starts the next event

; ===== snd_voice =====
; X = voice offset (0, 7, 14). Advances timing, fetches pattern
; events, runs instrument effects and writes the SID registers.
snd_voice:
	lda snd_v_state,x
	bmi snd_vc_run
snd_vc_rts:
	rts
snd_vc_run:
	dec snd_v_cnt,x
	beq snd_vc_apply
	lda snd_v_cnt,x
	cmp #SND_HR_FRAMES
	beq snd_vc_hr
	bcc snd_fx
	cmp snd_read_at,x
	bne snd_fx
	jsr snd_read_event	; read ahead, effects still run
	jmp snd_fx
snd_vc_hr:
	jsr snd_hr
	jmp snd_fx

snd_vc_apply:
	jsr snd_apply
	lda snd_v_mute,x
	bne snd_vc_rts
	lda snd_v_state,x
	bpl snd_vc_rts		; voice just ended
	ldy snd_v_wptr,x	; first frame of an event: wave table
	lda mus_wt_wave,y	; only, pulse / vibrato / slide were
	beq snd_fx1_wt_keep	; just reset
	cmp #$FF
	bne snd_fx1_wt_set
	lda mus_wt_note,y
	tay
	lda mus_wt_wave,y
	beq snd_fx1_wt_keep
snd_fx1_wt_set:
	sta snd_v_ctrl,x
snd_fx1_wt_keep:
	lda mus_wt_note,y
	bmi snd_fx1_wt_abs
	clc
	adc snd_v_note,x
snd_fx1_wt_abs:
	and #$7F
	sta snd_v_cur,x
	iny
	tya
	sta snd_v_wptr,x
	jmp snd_fx_regs

; ===== snd_fx =====
; X = voice. Wave table, pulse sweep, vibrato, slide, then write
; frequency, pulse width and control (gate) to the SID. Skipped
; while the voice is muted or in its hard restart.
snd_fx:
	lda snd_v_mute,x
	bne snd_vc_rts
	ldy snd_v_wptr,x	; ----- wave table step
	lda mus_wt_wave,y
	beq snd_fx_wt_keep	; $00: keep waveform
	cmp #$FF
	bne snd_fx_wt_set
	lda mus_wt_note,y	; jump (target is never a jump)
	tay
	lda mus_wt_wave,y
	beq snd_fx_wt_keep
snd_fx_wt_set:
	sta snd_v_ctrl,x
snd_fx_wt_keep:
	lda mus_wt_note,y
	bmi snd_fx_wt_abs
	clc			; relative note (7-bit wrap)
	adc snd_v_note,x
snd_fx_wt_abs:
	and #$7F
	sta snd_v_cur,x
	iny
	tya
	sta snd_v_wptr,x

	lda snd_v_pw_spd,x	; ----- pulse width sweep
	beq snd_fx_pw_done
	bmi snd_fx_pw_dn
	clc
	adc snd_v_pw_lo,x
	sta snd_v_pw_lo,x
	lda snd_v_pw_hi,x
	adc #0
	sta snd_v_pw_hi,x
	ldy snd_v_ins,x
	cmp mus_ins_pwmax,y
	bcc snd_fx_pw_done
	bcs snd_fx_pw_flip
snd_fx_pw_dn:
	clc
	adc snd_v_pw_lo,x
	sta snd_v_pw_lo,x
	lda snd_v_pw_hi,x
	adc #$FF
	sta snd_v_pw_hi,x
	ldy snd_v_ins,x
	cmp mus_ins_pwmin,y
	bcs snd_fx_pw_done
snd_fx_pw_flip:
	lda #0
	sec
	sbc snd_v_pw_spd,x
	sta snd_v_pw_spd,x
snd_fx_pw_done:

	ldy snd_v_ins,x		; ----- vibrato
	lda mus_ins_vspd,y
	beq snd_fx_vib_done
	lda snd_v_vib_dly,x
	beq snd_fx_vib_run
	dec snd_v_vib_dly,x
	bne snd_fx_vib_done
	jsr snd_vib_step
	jmp snd_fx_vib_done
snd_fx_vib_run:
	lda snd_v_vib_dir,x
	bne snd_fx_vib_sub
	clc
	lda snd_v_ofs_lo,x
	adc snd_v_vib_st_lo,x
	sta snd_v_ofs_lo,x
	lda snd_v_ofs_hi,x
	adc snd_v_vib_st_hi,x
	sta snd_v_ofs_hi,x
	dec snd_v_vib_cnt,x
	bne snd_fx_vib_done
	beq snd_fx_vib_turn
snd_fx_vib_sub:
	sec
	lda snd_v_ofs_lo,x
	sbc snd_v_vib_st_lo,x
	sta snd_v_ofs_lo,x
	lda snd_v_ofs_hi,x
	sbc snd_v_vib_st_hi,x
	sta snd_v_ofs_hi,x
	dec snd_v_vib_cnt,x
	bne snd_fx_vib_done
snd_fx_vib_turn:
	lda mus_ins_vspd,y
	asl
	sta snd_v_vib_cnt,x
	lda snd_v_vib_dir,x
	eor #1
	sta snd_v_vib_dir,x
snd_fx_vib_done:

	lda snd_v_sl_lo,x	; ----- slide
	ora snd_v_sl_hi,x
	beq snd_fx_regs
	clc
	lda snd_v_ofs_lo,x
	adc snd_v_sl_lo,x
	sta snd_v_ofs_lo,x
	lda snd_v_ofs_hi,x
	adc snd_v_sl_hi,x
	sta snd_v_ofs_hi,x

snd_fx_regs:
	ldy snd_v_cur,x		; ----- register writes
	lda snd_ntsc
	bne snd_fx_ntsc
	clc
	lda mus_freq_lo,y
	adc snd_v_ofs_lo,x
	sta SND_SID+0,x
	lda mus_freq_hi,y
	adc snd_v_ofs_hi,x
	sta SND_SID+1,x
	jmp snd_fx_out
snd_fx_ntsc:
	clc
	lda mus_freqn_lo,y
	adc snd_v_ofs_lo,x
	sta SND_SID+0,x
	lda mus_freqn_hi,y
	adc snd_v_ofs_hi,x
	sta SND_SID+1,x
snd_fx_out:
	lda snd_v_pw_lo,x
	sta SND_SID+2,x
	lda snd_v_pw_hi,x
	sta SND_SID+3,x
	lda snd_v_ctrl,x
	ora snd_v_gate,x
	sta SND_SID+4,x
	rts

; ===== snd_vib_step =====
; X = voice, Y = instrument. Vibrato delay is over: step size is
; (freq(note+1) - freq(note)) >> depth, then oscillate around 0.
snd_vib_step:
	lda mus_ins_vdep,y
	sta snd_zp_tmp
	lda mus_ins_vspd,y
	sta snd_v_vib_cnt,x
	lda #0
	sta snd_v_vib_dir,x
	ldy snd_v_note,x
	sec
	lda mus_freq_lo+1,y
	sbc mus_freq_lo,y
	sta snd_v_vib_st_lo,x
	lda mus_freq_hi+1,y
	sbc mus_freq_hi,y
	ldy snd_zp_tmp
	beq snd_vs_done
snd_vs_shift:
	lsr
	ror snd_v_vib_st_lo,x
	dey
	bne snd_vs_shift
snd_vs_done:
	sta snd_v_vib_st_hi,x
	ldy snd_v_ins,x
	rts

; ===== snd_hr =====
; X = voice, SND_HR_FRAMES before the event ends. Makes sure the
; next event is read; a retriggered note starts the hard restart
; (gate off, ADSR 0, instrument preloaded, effects paused).
snd_hr:
	lda snd_v_state,x
	and #SND_ST_PEND
	bne snd_hr_have
	jsr snd_read_event
snd_hr_have:
	lda snd_v_nx_note,x
	cmp #SND_EV_REST
	bcs snd_hr_rts		; rest, tie or end: no restart
	lda snd_v_nx_flag,x
	bmi snd_hr_rts		; legato
	lda #0
	sta snd_v_gate,x
	lda snd_v_mute,x
	beq snd_hr_regs
	cmp #SND_MUTE_WAIT
	bne snd_hr_quiet	; still muted: state only
	lda #0			; resume after sfx / pause
snd_hr_regs:
	ora #SND_MUTE_HR
	sta snd_v_mute,x
	lda #0
	sta SND_SID+5,x
	sta SND_SID+6,x
	lda snd_v_ctrl,x
	sta SND_SID+4,x
	jmp snd_load_ins
snd_hr_quiet:
	ora #SND_MUTE_HR
	sta snd_v_mute,x
	jmp snd_load_ins
snd_hr_rts:
	rts

; ===== snd_load_ins =====
; X = voice. Take the pending instrument (if any) and preload the
; per-note instrument state (wave table, pulse, vibrato delay).
; SND_IF_KEEPPW instruments keep sweeping the pulse across notes
; as long as the instrument does not change.
snd_load_ins:
	lda #0
	sta snd_zp_tmp		; 0 = same instrument as before
	lda snd_v_nx_ins,x
	bmi snd_li_same
	cmp snd_v_ins,x
	beq snd_li_same
	sta snd_v_ins,x
	inc snd_zp_tmp
snd_li_same:
	ldy snd_v_ins,x
	lda mus_ins_wave,y
	sta snd_v_wptr,x
	lda mus_ins_vdly,y
	sta snd_v_vib_dly,x
	lda snd_zp_tmp
	bne snd_li_pw		; new instrument: always reset pulse
	lda mus_ins_flags,y
	and #SND_IF_KEEPPW
	bne snd_li_rts
snd_li_pw:
	lda mus_ins_pwlo,y
	sta snd_v_pw_lo,x
	lda mus_ins_pwhi,y
	sta snd_v_pw_hi,x
	lda mus_ins_pwspd,y
	sta snd_v_pw_spd,x
snd_li_rts:
	rts

; ===== snd_read_event =====
; X = voice. Parse pattern bytes up to the next event and store it
; as pending (nx_*). Pattern format: see docs/c64-sound.md.
snd_read_event:
	lda #$FF
	sta snd_v_nx_ins,x
	lda #0
	sta snd_v_nx_flag,x
	lda snd_v_pat_lo,x
	sta snd_zp_ptr
	lda snd_v_pat_hi,x
	sta snd_zp_ptr+1
	ldy snd_v_pat_pos,x
snd_re_loop:
	lda (snd_zp_ptr),y
	iny
	cmp #SND_EV_TIE+1
	bcc snd_re_event	; $00 end, $01-$5F note, rest, tie
	cmp #$80
	bcc snd_re_long		; $7F nn: long duration
	cmp #$C0
	bcc snd_re_dur		; $80-$BF: duration 1-64
	cmp #$F0
	bcc snd_re_ins		; $C0-$EF: instrument 0-47
	beq snd_re_legato	; $F0: next note legato
	lda (snd_zp_ptr),y	; $F1 lo hi: slide for next note
	iny
	sta snd_v_nx_sl_lo,x
	lda (snd_zp_ptr),y
	iny
	sta snd_v_nx_sl_hi,x
	lda #SND_NX_SLIDE
	bne snd_re_flag
snd_re_legato:
	lda #SND_NX_LEGATO
snd_re_flag:
	ora snd_v_nx_flag,x
	sta snd_v_nx_flag,x
	jmp snd_re_loop
snd_re_ins:
	and #$3F
	sta snd_v_nx_ins,x
	jmp snd_re_loop
snd_re_dur:
	and #$3F
	clc
	adc #1
	sta snd_v_dur,x
	jmp snd_re_loop
snd_re_long:
	lda (snd_zp_ptr),y
	iny
	sta snd_v_dur,x
	jmp snd_re_loop
snd_re_event:
	cmp #0
	beq snd_re_patend
	sta snd_v_nx_note,x
	tya
	sta snd_v_pat_pos,x
	lda snd_v_dur,x
snd_re_store:
	sta snd_v_nx_dur,x
	lda snd_v_state,x
	ora #SND_ST_PEND
	sta snd_v_state,x
	rts
snd_re_patend:
	jsr snd_next_pattern
	bcc snd_re_loop
	lda #SND_EV_END		; order list finished
	sta snd_v_nx_note,x
	lda #1
	bne snd_re_store

; ===== snd_next_pattern =====
; X = voice. Step the order list to the next pattern. Returns
; C=0 with snd_zp_ptr / Y=0 at the new pattern, C=1 at the end.
; Order bytes: $00-$7F pattern, $80-$BF transpose (value-$A0),
; $C0-$EF instrument for the next note, $FE nn jump to index nn
; (loop), $FF end of voice.
snd_next_pattern:
	lda snd_v_ord_lo,x
	sta snd_zp_ord
	lda snd_v_ord_hi,x
	sta snd_zp_ord+1
	ldy snd_v_ord_pos,x
snd_np_loop:
	lda (snd_zp_ord),y
	iny
	cmp #$80
	bcc snd_np_pat
	cmp #$C0
	bcc snd_np_trans
	cmp #$FE
	bcc snd_np_ins
	beq snd_np_jump
	sec			; $FF: voice ends
	rts
snd_np_trans:
	adc #$60		; C=0 here: A - $A0
	sta snd_v_trans,x
	jmp snd_np_loop
snd_np_ins:
	and #$3F
	sta snd_v_nx_ins,x
	jmp snd_np_loop
snd_np_jump:
	lda (snd_zp_ord),y
	tay
	cpx #0
	bne snd_np_loop
	inc snd_mus_loops
	jmp snd_np_loop
snd_np_pat:
	sta snd_zp_tmp
	tya
	sta snd_v_ord_pos,x
	ldy snd_zp_tmp
	lda mus_pat_lo,y
	sta snd_v_pat_lo,x
	sta snd_zp_ptr
	lda mus_pat_hi,y
	sta snd_v_pat_hi,x
	sta snd_zp_ptr+1
	ldy #0
	clc
	rts

; ===== snd_apply =====
; X = voice. The current event ended: start the pending one.
snd_apply:
	lda snd_v_mute,x	; hard restart is over
	and #~SND_MUTE_HR&$FF
	sta snd_v_mute,x
	lda snd_v_state,x
	and #SND_ST_PEND
	bne snd_ap_have
	jsr snd_read_event	; event shorter than the restart
	lda snd_v_nx_note,x
	cmp #SND_EV_REST
	bcs snd_ap_have
	lda snd_v_nx_flag,x
	bmi snd_ap_have
	jsr snd_load_ins
snd_ap_have:
	lda snd_v_state,x
	and #~SND_ST_PEND&$FF
	sta snd_v_state,x
	lda snd_v_nx_dur,x
	sta snd_v_cnt,x
	lda snd_v_nx_note,x
	cmp #SND_EV_REST
	bcc snd_ap_note
	beq snd_ap_rest
	cmp #SND_EV_TIE
	beq snd_ap_rts
	lda #0			; end of voice
	sta snd_v_state,x
	dec snd_music_busy
snd_ap_rest:
	lda #0
	sta snd_v_gate,x
	lda snd_v_mute,x
	bne snd_ap_rts
	lda snd_v_ctrl,x
	sta SND_SID+4,x
snd_ap_rts:
	rts
snd_ap_note:
	clc
	adc snd_v_trans,x
	sta snd_v_note,x
	lda #0
	sta snd_v_ofs_lo,x
	sta snd_v_ofs_hi,x
	sta snd_v_sl_lo,x
	sta snd_v_sl_hi,x
	lda snd_v_nx_flag,x
	beq snd_ap_trig
	and #SND_NX_SLIDE
	beq snd_ap_legato
	lda snd_v_nx_sl_lo,x
	sta snd_v_sl_lo,x
	lda snd_v_nx_sl_hi,x
	sta snd_v_sl_hi,x
snd_ap_legato:
	lda snd_v_nx_flag,x
	bmi snd_ap_rts		; legato: pitch change only
snd_ap_trig:
	lda #1
	sta snd_v_gate,x
	ldy snd_v_ins,x
	lda mus_ins_filt,y
	beq snd_ap_nofilt
	jsr snd_filter_trigger
	jmp snd_ap_regs
snd_ap_nofilt:
	lda snd_voice_bit,x	; leave the filter if routed
	and snd_f_route
	beq snd_ap_regs
	eor snd_f_route
	sta snd_f_route
	inc snd_f_dirty
snd_ap_regs:
	lda snd_v_mute,x
	bne snd_ap_rts
	lda mus_ins_ad,y
	sta SND_SID+5,x
	lda mus_ins_sr,y
	sta SND_SID+6,x
	rts

; =====================================================================
; Music: global filter
; =====================================================================

; ===== snd_filter_trigger =====
; A = filter program, X = voice, Y = instrument (kept).
snd_filter_trigger:
	sty snd_zp_tmp
	tay
	lda mus_flt_cut,y
	sta snd_f_cut
	lda mus_flt_spd,y
	sta snd_f_spd
	lda mus_flt_lim,y
	sta snd_f_lim
	lda mus_flt_res,y
	sta snd_f_res
	lda mus_flt_mode,y
	sta snd_f_mode
	lda snd_voice_bit,x
	ora snd_f_route
	sta snd_f_route
	inc snd_f_dirty
	ldy snd_zp_tmp
	rts

; ===== snd_filter =====
; Cutoff sweep towards the limit, then write the filter registers.
; Voice 3 is never routed to the filter while an sfx plays.
snd_filter:
	lda snd_f_spd
	beq snd_flt_out
	bmi snd_flt_down
	clc
	adc snd_f_cut
	sta snd_f_cut
	cmp snd_f_lim
	bcc snd_flt_out
	bcs snd_flt_stop
snd_flt_down:
	clc
	adc snd_f_cut
	sta snd_f_cut
	cmp snd_f_lim
	beq snd_flt_stop
	bcs snd_flt_out
snd_flt_stop:
	lda snd_f_lim
	sta snd_f_cut
	lda #0
	sta snd_f_spd
snd_flt_out:
	lda #0
	sta snd_f_dirty
	lda snd_f_cut
	sta SND_FC_HI
	lda snd_f_route
	ldy sfx_cur
	beq snd_flt_route
	and #3
snd_flt_route:
	ora snd_f_res
	sta SND_RES_FILT
	lda snd_f_mode
	sta SND_MODE_VOL
	rts

; =====================================================================
; Sound effects (voice 3)
; =====================================================================
; Program bytes (generated into sfx_data.asm by tools/music.py):
;   $00            end (gate off, music voice 3 resumes)
;   $01 n          wait n frames
;   $02 c          control register (waveform | gate)
;   $03 ad sr      envelope
;   $04 note       frequency from note table
;   $05 lo hi      frequency (raw)
;   $06 lo hi      frequency slide per frame (signed)
;   $07 lo hi      pulse width
;   $08 s          pulse width change per frame (signed)
;   $09 n          loop counter = n
;   $0A d          if --counter: jump back d bytes (from after $0A d)
;   $0B note n     frequency from note, then wait n frames
;   $0C ad sr pl ph ps c   setup: envelope, pulse, pulse change,
;                  control
;   $0D fl fh sl sh n      sweep: frequency, slide, wait n frames
;   $0E c note n   control, frequency from note, wait n frames

; ===== sfx_update =====
sfx_update:
	lda sfx_req
	beq sfx_up_run
	ldy #0
	sty sfx_req
	tay
	lda sfx_cur
	beq sfx_up_start
	lda sfx_prio_tbl,y
	cmp sfx_prio
	bcc sfx_up_run		; less important than current one
sfx_up_start:
	sty sfx_cur
	lda sfx_prio_tbl,y
	sta sfx_prio
	lda sfx_ptr_lo,y
	sta sfx_zp_ptr
	lda sfx_ptr_hi,y
	sta sfx_zp_ptr+1
	lda #0			; one frame hard restart on voice 3
	sta sfx_slide_lo
	sta sfx_slide_hi
	sta sfx_pwspd
	sta SND_V3_AD
	sta SND_V3_SR
	lda #$08
	sta sfx_ctrl
	sta SND_V3_CTRL
	lda #1
	sta sfx_wait
	lda snd_f_route		; voice 3 leaves the filter (only
	and #4			; rewrite when music routed it)
	ora snd_f_dirty
	sta snd_f_dirty
	lda snd_v_mute+14	; music voice 3 is silenced
	and #SND_MUTE_FORCE
	ora #SND_MUTE_HARD
	sta snd_v_mute+14
	rts
sfx_up_run:
	lda sfx_cur
	beq sfx_up_rts
	dec sfx_wait
	bne sfx_sweep
	ldy #0
sfx_exec:
	lda (sfx_zp_ptr),y
	iny
	asl
	tax
	lda sfx_cmd_tbl+1,x
	pha
	lda sfx_cmd_tbl,x
	pha
sfx_up_rts:
	rts			; dispatch (or plain return)

sfx_cmd_tbl:
	.word sfx_c_end-1, sfx_c_wait-1, sfx_c_ctrl-1, sfx_c_adsr-1
	.word sfx_c_note-1, sfx_c_freq-1, sfx_c_slide-1, sfx_c_pw-1
	.word sfx_c_pwspd-1, sfx_c_lset-1, sfx_c_loop-1, sfx_c_notew-1
	.word sfx_c_setup-1, sfx_c_sweep-1, sfx_c_cnote-1

sfx_c_adsr:
	lda (sfx_zp_ptr),y
	iny
	sta SND_V3_AD
	lda (sfx_zp_ptr),y
	iny
	sta SND_V3_SR
	jmp sfx_exec

sfx_c_notew:
	jsr sfx_note
sfx_c_wait:
	lda (sfx_zp_ptr),y
	iny
	sta sfx_wait
	tya			; advance program pointer
	clc
	adc sfx_zp_ptr
	sta sfx_zp_ptr
	bcc sfx_sweep
	inc sfx_zp_ptr+1
sfx_sweep:
	lda sfx_slide_lo	; ----- per-frame slide / pwm
	ora sfx_slide_hi
	beq sfx_sw_pw
	clc
	lda sfx_freq_lo
	adc sfx_slide_lo
	sta sfx_freq_lo
	lda sfx_freq_hi
	adc sfx_slide_hi
	sta sfx_freq_hi
sfx_sw_pw:
	lda sfx_freq_lo
	sta SND_V3_FREQ
	lda sfx_freq_hi
	sta SND_V3_FREQ+1
	lda sfx_pwspd
	beq sfx_sw_rts
	ldx #0
	cmp #$80
	bcc sfx_sw_pos
	dex
sfx_sw_pos:
	clc
	adc sfx_pw_lo
	sta sfx_pw_lo
	sta SND_V3_PW
	txa
	adc sfx_pw_hi
	and #$0F
	sta sfx_pw_hi
	sta SND_V3_PW+1
sfx_sw_rts:
	rts

sfx_c_note:
	jsr sfx_note
	jmp sfx_exec

; read a note number, set sfx_freq from the PAL or NTSC table
sfx_note:
	lda (sfx_zp_ptr),y
	iny
	tax
	lda snd_ntsc
	bne sfx_note_ntsc
	lda mus_freq_lo,x
	sta sfx_freq_lo
	lda mus_freq_hi,x
	sta sfx_freq_hi
	rts
sfx_note_ntsc:
	lda mus_freqn_lo,x
	sta sfx_freq_lo
	lda mus_freqn_hi,x
	sta sfx_freq_hi
	rts

sfx_c_freq:
	lda (sfx_zp_ptr),y
	iny
	sta sfx_freq_lo
	lda (sfx_zp_ptr),y
	iny
	sta sfx_freq_hi
	jmp sfx_exec

sfx_c_slide:
	lda (sfx_zp_ptr),y
	iny
	sta sfx_slide_lo
	lda (sfx_zp_ptr),y
	iny
	sta sfx_slide_hi
	jmp sfx_exec

sfx_c_pw:
	lda (sfx_zp_ptr),y
	iny
	sta sfx_pw_lo
	sta SND_V3_PW
	lda (sfx_zp_ptr),y
	iny
	sta sfx_pw_hi
	sta SND_V3_PW+1
	jmp sfx_exec

sfx_c_pwspd:
	lda (sfx_zp_ptr),y
	iny
	sta sfx_pwspd
	jmp sfx_exec

sfx_c_lset:
	lda (sfx_zp_ptr),y
	iny
	sta sfx_lcnt
	jmp sfx_exec

sfx_c_loop:
	lda (sfx_zp_ptr),y
	iny
	dec sfx_lcnt
	beq sfx_c_loop_done
	sta snd_zp_tmp
	tya			; pointer += y - d
	clc
	adc sfx_zp_ptr
	sta sfx_zp_ptr
	bcc sfx_c_loop_back
	inc sfx_zp_ptr+1
sfx_c_loop_back:
	sec
	sbc snd_zp_tmp
	sta sfx_zp_ptr
	bcs sfx_c_loop_y
	dec sfx_zp_ptr+1
sfx_c_loop_y:
	ldy #0
sfx_c_loop_done:
	jmp sfx_exec

sfx_c_setup:
	lda (sfx_zp_ptr),y
	iny
	sta SND_V3_AD
	lda (sfx_zp_ptr),y
	iny
	sta SND_V3_SR
	lda (sfx_zp_ptr),y
	iny
	sta sfx_pw_lo
	sta SND_V3_PW
	lda (sfx_zp_ptr),y
	iny
	sta sfx_pw_hi
	sta SND_V3_PW+1
	lda (sfx_zp_ptr),y
	iny
	sta sfx_pwspd
sfx_c_ctrl:
	lda (sfx_zp_ptr),y
	iny
	sta sfx_ctrl
	sta SND_V3_CTRL
	jmp sfx_exec

sfx_c_sweep:
	lda (sfx_zp_ptr),y
	iny
	sta sfx_freq_lo
	lda (sfx_zp_ptr),y
	iny
	sta sfx_freq_hi
	lda (sfx_zp_ptr),y
	iny
	sta sfx_slide_lo
	lda (sfx_zp_ptr),y
	iny
	sta sfx_slide_hi
	jmp sfx_c_wait

sfx_c_cnote:
	lda (sfx_zp_ptr),y
	iny
	sta sfx_ctrl
	sta SND_V3_CTRL
	jmp sfx_c_notew

sfx_c_end:
	lda sfx_ctrl
	and #$FE
	sta SND_V3_CTRL
	lda #0
	sta sfx_cur
	sta sfx_prio
	lda snd_f_route		; filter rewrite only if music
	and #4			; routes voice 3
	ora snd_f_dirty
	sta snd_f_dirty
	lda snd_v_mute+14	; music voice 3 comes back at
	and #SND_MUTE_FORCE	; its next hard restart
	ora #SND_MUTE_WAIT
	sta snd_v_mute+14
	rts

; =====================================================================
; Tables
; =====================================================================

; filter routing bit for each voice offset (0, 7, 14)
snd_voice_bit:
	.byte 1,0,0,0,0,0,0,2,0,0,0,0,0,0,4

; frames-left count at which each voice reads its next event
; (voice 3 reads at the hard restart itself)
snd_read_at:
	.byte 4,0,0,0,0,0,0,3,0,0,0,0,0,0,2

; order position before the first pattern: an empty pattern
snd_empty_pat:
	.byte 0

; =====================================================================
; Variables (all cleared by sound_init, except snd_ntsc)
; =====================================================================

snd_ntsc:
	.byte 0			; 1 = NTSC (60 Hz) machine

snd_vars:
; per-voice variables: seven interleaved per 21-byte block,
; indexed with the voice offset X = 0, 7, 14
snd_vblk_a:
	.blk 21,0
snd_vblk_b:
	.blk 21,0
snd_vblk_c:
	.blk 21,0
snd_vblk_d:
	.blk 21,0
snd_vblk_e:
	.blk 21,0

snd_ntsc_cnt:	.byte 0		; NTSC frame skip counter
snd_mreq:	.byte 0		; music request ($FF none)
snd_preq:	.byte 0		; pause request ($FF none)
snd_paused:	.byte 0
snd_mus_cur:	.byte 0		; current tune number
snd_mus_loops:	.byte 0		; tune loop counter (voice 1)
snd_music_busy:	.byte 0		; music voices still running
snd_voice_mask:	.byte 0		; debug: voices audible at start
snd_f_cut:	.byte 0		; filter cutoff (high byte)
snd_f_spd:	.byte 0		; cutoff change per frame
snd_f_lim:	.byte 0		; cutoff sweep end
snd_f_res:	.byte 0		; resonance (bits 4-7 of $D417)
snd_f_mode:	.byte 0		; $D418 value (mode | volume)
snd_f_route:	.byte 0		; voices routed to the filter
snd_f_dirty:	.byte 0		; filter registers need a rewrite

sfx_req:	.byte 0		; requested sfx (0 none)
sfx_cur:	.byte 0		; playing sfx (0 none)
sfx_prio:	.byte 0
sfx_wait:	.byte 0
sfx_ctrl:	.byte 0
sfx_freq_lo:	.byte 0
sfx_freq_hi:	.byte 0
sfx_slide_lo:	.byte 0
sfx_slide_hi:	.byte 0
sfx_pw_lo:	.byte 0
sfx_pw_hi:	.byte 0
sfx_pwspd:	.byte 0
sfx_lcnt:	.byte 0
snd_vars_end:

; block a: sequencing
snd_v_cnt	= snd_vblk_a+0	; frames left in this event
snd_v_state	= snd_vblk_a+1	; SND_ST_* bits
snd_v_mute	= snd_vblk_a+2	; SND_MUTE_* bits
snd_v_ord_pos	= snd_vblk_a+3	; order list index
snd_v_pat_pos	= snd_vblk_a+4	; pattern byte index
snd_v_pat_lo	= snd_vblk_a+5	; pattern address
snd_v_pat_hi	= snd_vblk_a+6
; block b: sequencing / next event
snd_v_ord_lo	= snd_vblk_b+0	; order list address
snd_v_ord_hi	= snd_vblk_b+1
snd_v_trans	= snd_vblk_b+2	; transpose (semitones)
snd_v_dur	= snd_vblk_b+3	; current note length (frames)
snd_v_nx_note	= snd_vblk_b+4	; pending event
snd_v_nx_dur	= snd_vblk_b+5
snd_v_nx_ins	= snd_vblk_b+6	; pending instrument ($FF none)
; block c
snd_v_nx_flag	= snd_vblk_c+0	; SND_NX_* bits
snd_v_nx_sl_lo	= snd_vblk_c+1	; pending slide
snd_v_nx_sl_hi	= snd_vblk_c+2
snd_v_note	= snd_vblk_c+3	; note incl. transpose
snd_v_ins	= snd_vblk_c+4	; instrument
snd_v_wptr	= snd_vblk_c+5	; wave table position
snd_v_ctrl	= snd_vblk_c+6	; waveform bits (gate separate)
; block d
snd_v_gate	= snd_vblk_d+0	; 1 = gate on
snd_v_pw_lo	= snd_vblk_d+1	; pulse width
snd_v_pw_hi	= snd_vblk_d+2
snd_v_pw_spd	= snd_vblk_d+3	; pulse change per frame
snd_v_cur	= snd_vblk_d+4	; sounding note (after arpeggio)
snd_v_vib_dly	= snd_vblk_d+5	; frames until vibrato
snd_v_vib_cnt	= snd_vblk_d+6	; frames until direction change
; block e
snd_v_vib_dir	= snd_vblk_e+0	; 0 up, 1 down
snd_v_vib_st_lo	= snd_vblk_e+1	; vibrato step
snd_v_vib_st_hi	= snd_vblk_e+2
snd_v_ofs_lo	= snd_vblk_e+3	; frequency offset (vib + slide)
snd_v_ofs_hi	= snd_vblk_e+4
snd_v_sl_lo	= snd_vblk_e+5	; slide per frame
snd_v_sl_hi	= snd_vblk_e+6
