# C64 Sound System

Music player, music and sound effects for Otter Raid. Everything lives in
`$8000-$9FFF` and uses zero page `$E0-$EF` only. It never calls ROM code.

## Files and include order

| File | Kind | Notes |
| --- | --- | --- |
| `c64/sound/sound_ids.asm` | constants only | `MUS_*`, `SFX_*`, `MUS_COUNT`, `SFX_COUNT`. Include early. |
| `c64/sound/sound.asm` | code + variables | Player, SFX engine, tables, variables. |
| `c64/sound/music_data.asm` | generated | Songs, patterns, instruments, wave table, filters, frequency tables. |
| `c64/sound/sfx_data.asm` | generated | SFX priorities and programs. |
| `c64/sound/sound_test.asm` | test harness | Standalone PRG, not part of the game. |
| `tools/music.py` | generator | `music/*.txt` -> the two generated files. |
| `music/*.txt` | sources | `instruments.txt`, `sfx.txt`, one file per tune. |

The game includes them like this:

```asm
	include "sound/sound_ids.asm"	; early, constants only
	...
	org $8000
	include "sound/sound.asm"
	include "sound/music_data.asm"
	include "sound/sfx_data.asm"
```

None of these files contain `org`, and none of them include other files.
Every label starts with `snd_`, `mus_` or `sfx_`, apart from the five entry
points. Every constant starts with `SND_`, `MUS_` or `SFX_`.

Current size: 5599 bytes in total (`$8000-$95DE`), so 2593 bytes of
`$8000-$9FFF` are still free.

| Part | Bytes |
| --- | --- |
| Code and tables | 2168 |
| Variables | 134 |
| Music data | 2596 |
| SFX data | 701 |

## Interface (frozen)

| Symbol | In | Effect |
| --- | --- | --- |
| `sound_init` | - | Silences the SID and clears all state. Call it once at startup. Safe while IRQs run, because it uses `php`/`sei`/`plp` internally. It does not touch `snd_ntsc`. |
| `music_play` | A = tune | Starts the tune from the beginning at the next `sound_update`. `MUS_STOP` (0) stops the music. Any SFX in flight finishes normally. |
| `sfx_play` | A = 1..`SFX_COUNT` | Requests an effect on voice 3. Out-of-range values are ignored. Keeps A, X and Y, and is reentrant: it uses only the stack and briefly holds off IRQs, so the game may call it from the main loop or from an IRQ. |
| `sound_update` | - | Call it exactly once per frame from the raster IRQ. The caller saves A/X/Y. |
| `sound_pause` | A = 1 / 0 | 1 = all gates off, music frozen, any playing SFX is cut. 0 = resume. Each voice comes back at its next note. New SFX still play while paused (for menu blips). |
| `snd_ntsc` | byte | Set it to 1 on NTSC machines, before or after `sound_init`. |

`music_play`, `sfx_play` and `sound_pause` only post a request byte. The
next `sound_update` acts on it. That makes them safe to call from the main
loop while the IRQ is running. `music_play` and `sound_pause` keep X and Y.

Read-only status bytes:

- `snd_music_busy`: the number of music voices still running. 0 means a
  non-looping tune has finished, or no music is playing.
- `snd_mus_loops`: how many times the current tune has wrapped around its
  loop (counted on voice 1).
- `sfx_cur`: the SFX now playing, or 0 for none.
- `snd_voice_mask`: debug only. The voices that are audible when a tune
  starts (bit 0 = voice 1). Set it before `music_play`. The default is 7.

**Start latency.** A tune's first notes sound 5 frames after the update that
handles `music_play`. An effect sounds 2 frames after the update that
handles `sfx_play`: one frame of hard restart, then the first frame of the
effect.

### Tunes

| # | Name | Length | End behaviour |
| --- | --- | --- | --- |
| 1 | `MUS_TITLE` | 7.7 s intro + 61.4 s loop | Loops. |
| 2 | `MUS_RIVER` | 3.8 s intro + 76.8 s loop | Loops. Voice 3 is expendable. |
| 3 | `MUS_EAGLE` | 1.6 s sting + 6.4 s loop | **Loops** until the game calls `music_play` again (normally `MUS_RIVER` when the eagle has gone). |
| 4 | `MUS_LIFE_LOST` | 2.9 s | Plays once, then ends silent (`snd_music_busy` = 0). |
| 5 | `MUS_GAME_OVER` | 7.7 s, plus a ~1.5 s release | Plays once, then ends silent. |
| 6 | `MUS_HOME` | 3.4 s fanfare + 16.8 s loop | **Loops**: the fanfare plays once, then Happy Birthday plus the party tag repeat. The first pass lasts 20.2 s, and `snd_mus_loops` becomes 1 when it ends. |
| 7 | `MUS_HIGH_SCORE` | 20.5 s loop | Loops. |

What each tune sounds like:

- **TITLE** (C major, 125 bpm). A bouncy, singable pulse lead with delayed
  vibrato. Voice 1 carries an octave-jumping bass, with snare hits woven in
  from the second section. Voice 3 plays shimmering 50 Hz chord arpeggios in
  a 3-3-2 rhythm. The sections are: theme, theme on a brighter
  octave-chirp lead, a bridge in A minor (filtered saw bass with a cutoff
  sweep on every note, saw lead), and a Hubbard-style 16th-note solo.
- **RIVER** (A minor, 125 bpm). A driving 16th bass with snare on voice 1
  and a heroic minor lead on voice 2. Voice 3 has hi-hats and offbeat chord
  stabs. The sections are: theme, a brighter relative-major section, the
  theme on the chirp lead, a breakdown (soft triangle bass, flute pad,
  sustained chords) to stop it from getting tiring, and a solo.
- **EAGLE** (E phrygian, 150 bpm). A crash and a chromatic brass sting,
  then a menacing bass ostinato that rises a semitone, a high semitone
  trill, and diminished stabs.
- **LIFE_LOST**. A drooping brass "wah wah wah waaah" over a chromatic bass.
  The last note slides down and lands on A minor.
- **GAME_OVER**. A slow lament in A minor (bass Am - G - F - E - Am) on a
  soft triangle lead with slow vibrato and gentle arpeggios.
- **HOME** (3/4, 107 bpm). A two-bar brass fanfare in harmony, then "Happy
  Birthday to You" as a festive waltz: brass melody, oom-pah bass, and chord
  stabs on beats 2 and 3, with C7 and G7 colour. The two-bar party tag
  climbs to a high C and ends on the next "Hap-py" pickup.
- **HIGH_SCORE** (F major, 94 bpm). A relaxed flute melody, a rolling
  triangle bass, and slow two-frame arpeggios.

### Sound effects and priorities

A higher priority wins. A request with **equal** priority restarts the
effect. If two requests arrive in the same frame, the higher one is kept.

| # | Name | Prio | Length | Sound |
| --- | --- | --- | --- | --- |
| 1 | `SFX_MENU_MOVE` | 1 | 0.18 s | Two-note pulse blip |
| 2 | `SFX_MENU_SELECT` | 3 | 0.62 s | Rising C major arpeggio with PWM |
| 3 | `SFX_SPLASH_DIVE` | 3 | 0.48 s | Falling noise splash, then a bubble drop |
| 4 | `SFX_SURFACE` | 2 | 0.38 s | Two rising triangle bubbles and a spray |
| 5 | `SFX_BANK_BUMP` | 1 | 0.22 s | Click and low thud |
| 6 | `SFX_GATOR_CHOMP` | 6 | 0.60 s | Two snaps with saw crunch, then a hiss |
| 7 | `SFX_HURT` | 6 | 0.62 s | "Ouch" pitch drop |
| 8 | `SFX_CRAWFISH_PICKUP` | 5 | 0.84 s | Sparkling arpeggio up to A#7, then a twinkle |
| 9 | `SFX_INVULN_ENDING` | 3 | 1.02 s | Three ding-dong warning blips |
| 10 | `SFX_EAGLE_SCREECH` | 6 | 1.20 s | Wavering high screech, then a falling cry |
| 11 | `SFX_EAGLE_SWOOP` | 4 | 1.16 s | Noise whoosh, rising then falling |
| 12 | `SFX_EAGLE_CATCH` | 8 | 1.52 s | Alarm trill, crash, long falling saw |
| 13 | `SFX_HEART_GAINED` | 7 | 1.30 s | Cheerful five-note jingle |
| 14 | `SFX_MILESTONE` | 2 | 0.54 s | Soft two-tone ding |
| 15 | `SFX_GATOR_SPLASH` | 2 | 0.32 s | Short falling splash |
| 16 | `SFX_FISH_EAT` | 5 | 0.40 s | Two noise crunches with low thumps ("munch munch"), a rising triangle gulp, then a small blip up |
| 17 | `SFX_GIFT` | 6 | 0.80 s | Magical triangle-bell chime in D major: D, F#, A, D, each with a one-frame octave "ping", then a high shimmer. Softer and brighter than the pulse-based pickup and heart effects |

**Voice 3.** Effects always play on SID voice 3. While one plays, the music
keeps advancing on voice 3 but writes nothing to its registers. When the
effect ends, voice 3 rejoins at the music's next hard restart and note. That
note writes all seven registers from the music's own state, so instrument,
ADSR and pulse are correct. This happens within one note, which is 4-19
frames in the tests. Music never routes voice 3 through the filter. If a tune
ever did, the routing bit is masked while an effect plays. Voices 1 and 2
are never touched by effects.

## Cycle budget

Measured in exact cycles, including the `jsr`/`rts` (12 cycles).

| Case | Cycles |
| --- | --- |
| Idle (no music, no SFX) | 133 |
| Typical frame with all three voices busy | 760-830 |
| Worst music-only frame, all tunes over intro + 2 loops | 1217 |
| Worst music frame with voice 3 muted by an SFX | 1052 |
| Worst SFX frame cost above idle | 337 |
| Upper bound with an SFX playing (sum of the two above) | 1391 |
| Worst seen in random SFX-hammering simulations | 1386 |
| Worst seen by the harness's CIA timer in VICE | 1303 (PAL 6581 session, incl. tune+SFX same-frame starts and a dense SFX barrage), 1171 (PAL 8580), 1264 (NTSC) |

**Rule that keeps the bound:** every pattern event (note, rest or tie) must
be at least 5 frames long. `tools/music.py` rejects anything shorter. Long
events are split into chunks, none shorter than 5 frames.

The cost stays bounded because of how the work is spread out:

- Pattern reads are staggered. Voice 1 reads its next event 4 frames before
  it is due, voice 2 at 3 frames, and voice 3 at 2. All voices hard-restart
  at 2.
- A voice in hard restart skips its effects for those frames.
- The first frame of a note runs only the wave table and the register
  writes.
- The filter registers are only written while sweeping or after a change.
- SFX programs use composite opcodes (`setup`, `sweep`, `ctrl`+`note`).

## Player architecture

Per-voice state lives in five 21-byte blocks. Each block holds seven
interleaved variables, indexed by the voice offset `X` = 0, 7 or 14, so
`sta $D400+reg,x` addresses the right SID registers directly. Zero page
holds only `$E0/$E1` (pattern pointer), `$E2/$E3` (order list pointer),
`$E4/$E5` (SFX program pointer) and `$E6` (scratch).

Each frame, `sound_update` does the following:

1. **NTSC skip.** With `snd_ntsc` = 1, every 6th call returns immediately,
   so music and SFX run at an effective 50 Hz. Tempo, arpeggio and sweep
   rates match PAL. Pitch uses the separate NTSC frequency table, so it
   matches too.
2. Handle a pending pause/resume request, then a pending music request. A
   tune start costs about 800 cycles and skips the voices for that frame.
3. Update each voice. For an event of length n frames:
   - Every frame: wave table step, pulse width sweep (ping-pong between
     min/max), vibrato, slide, then write freq, PW and ctrl.
   - `snd_read_at` frames left: read ahead to the next pattern event, stepping
     the order list as needed.
   - 2 frames left (hard restart): if the next event is a retriggered note,
     set gate off and ADSR to $0000, preload the instrument, and keep the
     voice silent. A legato note, tie or rest skips this.
   - 0 frames left: start the next event. For a note: set the note,
     transpose, reset offsets and the slide, gate on, write AD/SR, start the
     filter program or leave the filter. Then run the wave table and write
     the registers.
4. Filter. There is one global cutoff sweep, started by notes whose
   instrument has a filter program. Voices with such instruments are
   routed; other notes un-route their voice.
5. SFX. Take a pending request after a priority check. A new effect gets a
   one-frame hard restart on voice 3. Then run the program's bytecode until
   the next wait, and apply the per-frame slide and PWM.

The mute bits in `snd_v_mute` are:

- `$80`: hard mute. An SFX owns voice 3, or the music is paused.
- `$40`: rejoin at the next hard restart.
- `$20`: the hard restart is in progress.
- `$01`: debug solo mask.

## Data formats (generated)

**Order list** (one per voice, at most 255 bytes):

| Byte | Meaning |
| --- | --- |
| `$00-$7F` | Play pattern n. |
| `$80-$BF` | Transpose = value - `$A0` (-32..+31). |
| `$C0-$EF` | Instrument for the next note, so a pattern can be reused with another sound. |
| `$FE nn` | Jump to index nn (loop). |
| `$FF` | End of voice. |

**Pattern** (at most 255 bytes):

| Byte | Meaning |
| --- | --- |
| `$00` | End of pattern. |
| `$01-$5F` | Note (C-0 = 0, A-4 = 57). |
| `$60` | Rest (gate off). |
| `$61` | Tie (keep sounding). |
| `$7F nn` | Duration nn frames. |
| `$80-$BF` | Duration 1-64 frames. |
| `$C0-$EF` | Instrument 0-47. |
| `$F0` | The next note is legato: no retrigger, pitch change only. |
| `$F1 lo hi` | Slide (signed frequency change per frame) for the next note. |

Durations and instruments persist until they change.

**Instruments.** These are parallel tables `mus_ins_*`, indexed by
instrument number; instrument 0 is silent:

- `ad`, `sr`: envelope.
- `wave`: wave table start.
- `pwlo`, `pwhi`: start pulse width.
- `pwspd`: pulse width change per frame.
- `pwmin`, `pwmax`: ping-pong limits.
- `vdly`, `vspd`, `vdep`: vibrato delay, speed and depth.
- `filt`: filter program.
- `flags`: bit 0 = keep the PWM running across notes.

**Wave table.** Two parallel columns, one entry per frame:

- `mus_wt_wave`: the control byte without the gate bit. `$00` keeps the
  previous waveform. `$FF` is a jump to the index in the note column.
- `mus_wt_note`: `$00-$7F` is a relative semitone offset (7-bit wrap, so
  `$7F` = -1). `$80+n` is absolute note n, used for drums.

**Filter programs.** `mus_flt_cut`, `lim`, `spd`, `res`, `mode`: cutoff high
byte start, limit and signed speed, plus the resonance nibble and the mode
bits.

**SFX bytecode:**

| Bytes | Meaning |
| --- | --- |
| `00` | End. |
| `01 n` | Wait n frames. |
| `02 c` | Control register. |
| `03 ad sr` | Envelope. |
| `04 note` | Pitch from a note. |
| `05 lo hi` | Raw frequency. |
| `06 lo hi` | Slide. |
| `07 lo hi` | Pulse width. |
| `08 s` | Pulse width change per frame. |
| `09 n` | Loop count. |
| `0A d` | Loop back d bytes. |
| `0B note n` | Note + wait. |
| `0C ad sr pl ph ps c` | Setup. |
| `0D fl fh sl sh n` | Sweep: frequency, slide, wait. |
| `0E c note n` | Control + note + wait. |

## Writing music

Run `python3 tools/music.py` after editing anything in `music/`. It prints
each tune's length and loop, each SFX's length, and the data size. Its
output is deterministic and free of timestamps, so the generated files can
be committed. `--check` fails if the generated files are stale.
`--dump TUNE` prints a note grid for checking harmony.

### Tune files

One tune per file in `music/` (MML style):

```
tune TITLE            # must match MUS_TITLE in sound_ids.asm
tempo 6               # frames per 16th note (6 = 125 bpm at 50 Hz)
bar 16                # 16ths per bar, used to check '|' (12 for 3/4)
pat bass
  @bass o2 c8 > c8 < c16 c16 > c8 < c8 > c8 < g8 > c8 |
pat melody upbeat 4   # starts 4 16ths before a bar line
  ...
v1: intro LOOP bass bass+5 bass+7*2
v2: @lead melody @leadhi melody
v3: ...
```

The pattern notation:

| Token | Meaning |
| --- | --- |
| `c d e f g a b` | Note. Add `+` or `#` for sharp, `-` for flat. |
| length suffix | `4`, `8.`, `16`, `12` (triplet) or `:n` frames. Lengths must come out as whole frames. |
| `r` | Rest. |
| `^len` | Tie, extending the previous note. |
| `_` prefix | Legato note. |
| `o4`, `>`, `<` | Set the octave, or go up / down one. |
| `l8` | Default length. |
| `@inst` | Instrument. |
| `s-1,60` | Slide the next note by -1 semitone over 60 frames. |
| `[ ... ]3` | Repeat the bracketed part 3 times. |
| `|` | Bar line, checked against `bar`. |

The order-list items are:

| Item | Meaning |
| --- | --- |
| `name` | Play the pattern. |
| `name+5` | Play it transposed by +5. |
| `name*3` | Play it 3 times. |
| `@inst` | Instrument for the next pattern. |
| `LOOP` | Loop point. Without it, the voice ends. |
| `END` | End the voice. |

The compiler also checks the tune:

- Voices loop in sync, with equal intro and loop lengths.
- Notes plus transpose plus arpeggio stay in range.
- Patterns and order lists stay under 255 bytes.
- The data stays within the budget.

Identical patterns are shared across tunes.

### Instruments

Instruments live in `music/instruments.txt`; the format is described at the
top of that file. Write drums as wave programs with absolute notes, for
example `81:=a6 41:=c4 41:=g3 ...`. Keep filter cutoffs within
`$18-$90`, and use the filter only on voices 1 and 2. The two SID chips
differ a lot here: the 6581 is much darker at low cutoffs than the 8580.
Avoid combined waveforms ($31, $61, ...), because they are nearly silent on
the 6581.

### Sound effects

Effects live in `music/sfx.txt`; the format is described at the top of that
file. Keep the number of commands between two `wait`s small, because they
all run in one frame. Start each effect with `setup`. To add an effect:

1. Add `SFX_NAME = n` to `sound_ids.asm`.
2. Raise `SFX_COUNT`.
3. Add `sfx NAME prio p ... end` to `sfx.txt`.
4. Regenerate.

### Adding a tune

1. Add `MUS_NAME = n` to `sound_ids.asm` and raise `MUS_COUNT`.
2. Create `music/<name>.txt` with `tune NAME`.
3. Regenerate.

## Test harness

Build and run it like this:

```
python3 tools/music.py
vasm6502_oldstyle -Fbin -cbm-prg -dotdir -quiet \
    -o build/sound_test.prg c64/sound/sound_test.asm
x64sc -autostart build/sound_test.prg
```

Keys:

| Key | Action |
| --- | --- |
| `1`-`7` | Play a tune. |
| `0` | Stop the music. |
| `A`-`O` | SFX 1-15. |
| `Q`, `R` | SFX 16, 17. |
| `P` | Pause / resume. |
| `SPACE` | Reset the cycle maximum. |

The screen shows the current tune and SFX, the playing SFX, the busy and
loop counters, the pause and NTSC flags, and the last and maximum
`sound_update` cycles. These are measured with CIA2 timer A, and include the
`jsr`/`rts`. The border colour also marks the time spent in the IRQ.

The VICE monitor interface uses fixed addresses:

- `$0340`: command mailbox. A second command at `$0341` runs in the same
  frame. The commands are:
  - `$01-$07`: tune.
  - `$08`: stop.
  - `$80+n`: SFX n.
  - `$20` / `$21`: pause / resume.
  - `$30`: reset the cycle maximum.
  - `$40-$47`: voice mask.
  - `$50` / `$51`: start / stop the script at `$C000`.
  - `$60` / `$61`: `snd_ntsc`.
- `$C000`: a script of (command, wait lo, wait hi) triplets, ending with
  command 0. A wait of 0 runs the next command in the same frame.
- `$0342`: last cycle count. `$0344`: maximum. `$0346`: frame counter.
  `$0348`: the frame of the maximum.
- `$CE00/$CF00`: per-frame cycle history.

## Listening previews

To regenerate listenable WAVs of every tune and an SFX reel on both SID
chips, run:

```
python3 tools/sound_preview.py              # 6581 and 8580, ~10 min
python3 tools/sound_preview.py --sid 8580   # one model, ~5 min
python3 tools/sound_preview.py --seconds 20 # shorter tune clips
```

The script assembles `build/sound_test.prg` and starts one headless VICE
session through `tools/vicetest.py`. That session uses a private Xvfb, so
no window appears, and its remote monitor port is 6545 (change it with
`--port`). The script records a WAV and plays every tune through the
harness mailbox: looping tunes run long enough to hear the loop point, and
one-shot tunes include their release. It then plays the SFX reel
(SFX 1..`SFX_COUNT`, 2.2 s apart).

The recording is cut into these files:

- `build/sound_preview/<n>_<tune>_<6581|8580>.wav`
- `build/sound_preview/sfx_reel_<6581|8580>.wav`

Emulation runs in real time, because warp mode mutes the SID.

## Verification done

- Every file assembles without errors or warnings with
  `vasm6502_oldstyle -Fbin -dotdir`.
- **Offline.** A py65 6502 simulation of the real PRG, driving the public
  entry points, confirmed:
  - The cycle counts above are exact.
  - Every looping tune repeats frame-exactly.
  - The one-shot tunes end with `snd_music_busy` = 0.
  - Voice 3 resumes after an SFX with registers identical to a run without
    the effect, and voices 1 and 2 are never touched.
  - Pause silences every gate, and after resume the music continues exactly
    where it stopped.
  - The priority rules hold.
  - The Happy Birthday note sequence and rhythm are correct.
- **VICE 3.10.** One headless session per video standard, recording a WAV
  and driven by a script uploaded through the remote monitor. It ran every
  SFX and every tune past its loop point, the voice-3 steal with solo
  masks, the pause, a same-frame tune + SFX start, and a dense SFX barrage.
  The PAL session covered the 6581 and then the 8580. The WAV analysis
  found:
  - No dropouts in any tune.
  - Loops repeat: chroma similarity one loop apart is 0.78-0.95, against
    0.33-0.67 for a half-loop control.
  - The one-shot tunes go silent after they end.
  - Voice 3 returns after an SFX at its pre-SFX level.
  - The pause sits at the noise floor.
  - The soloed Happy Birthday melody has all 44 notes within 13 cents on
    both chips; the error comes from the frequency table rounding and
    vibrato.
  - With `-ntsc`, the same melody has the same pitches and stays aligned on
    50 Hz ticks for 22 s, so the tempo is matched.
  - No sample-step outliers (clicks) at SFX, pause or loop boundaries.

## Known limitations

- `sweep` / `freq` / `slide` in SFX are raw PAL frequency values, so on
  NTSC those glides sound about 0.6 semitone higher. Note-based SFX and all
  music use the NTSC table and are exact.
- An effect starts after a one-frame hard restart (20 ms). A voice-3 music
  note rejoins only at its next note, so a long note that was cut by an
  effect stays silent until the next one.
- The very first `sound_init` volume write can click on a 6581, like any
  SID program that sets `$D418`.
