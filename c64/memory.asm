; ==========================================================
; Otter Raid - memory map and zero-page allocation
;
; This is the ONLY place where fixed RAM addresses are chosen.
; Every module takes its zero-page bytes and buffers from here
; so that nothing overlaps. (Small module-private variables
; declared with .byte inside the code are placed by the
; assembler and cannot overlap anything.)
; See docs/c64-memory-map.md.
;
; KERNAL and BASIC are banked out ($01 = $35): the game owns
; all of zero page and RAM except the I/O area.
; ==========================================================

; ===== RAM layout =====
; $0002-$00FF  zero page (below)
; $0100-$01FF  stack
; $0200-$03FF  small buffers (below)
; $0400-$07FF  river row ring buffer (below)
; $0801-$3FFF  program code and tables
; $4000-$7FFF  VIC bank 1: screens, charsets, sprites
; $8000-$9FFF  sound engine, music and SFX data
; $A000-$BFFF  free (RAM under BASIC)
; $C000-$CFFF  free
; $E000-$FFF9  free (RAM under KERNAL)
; $FFFA-$FFFF  hardware vectors (RAM)

; ===== VIC bank 1 ($4000-$7FFF) =====
VIC_BANK         = $4000
SCREEN_A         = $4000	; HUD rows 0-1 + playfield buffer A
SCREEN_B         = $4400	; playfield buffer B
CHARSET_GAME     = $4800	; multicolor river charset (2 KB)
CHARSET_TEXT     = $5000	; hires HUD / text charset (2 KB)
SPRITE_DATA      = $5800	; 160 sprite slots up to $7FFF
SPR_PTR_BASE     = (SPRITE_DATA-VIC_BANK)/64
SPR_PTRS_A       = SCREEN_A+$3F8
SPR_PTRS_B       = SCREEN_B+$3F8
VIC_IDLE_BYTE    = $7FFF	; shown in idle lines; must be 0

; $DD00 value bits 0-1 for VIC bank 1
CIA2_BANK1       = %10

; $D018 values (screen offset / $400 << 4 | charset offset / $800 << 1)
D018_HUD         = ((SCREEN_A-VIC_BANK)/$400)<<4|((CHARSET_TEXT-VIC_BANK)/$800)<<1
D018_PLAY_A      = ((SCREEN_A-VIC_BANK)/$400)<<4|((CHARSET_GAME-VIC_BANK)/$800)<<1
D018_PLAY_B      = ((SCREEN_B-VIC_BANK)/$400)<<4|((CHARSET_GAME-VIC_BANK)/$800)<<1

; ===== Zero page =====
; $02-$0F  IRQ-only scratch (never touched by the main thread)
zi_t0            = $02
zi_t1            = $03
zi_ptr           = $04		; 2 bytes

; $10-$1F  main-thread scratch. Callee-clobbered: a routine may
; trash these unless its header comment says otherwise.
zp_t0            = $10
zp_t1            = $11
zp_t2            = $12
zp_t3            = $13
zp_t4            = $14
zp_t5            = $15
zp_t6            = $16
zp_t7            = $17
zp_ptr0          = $18		; 2 bytes
zp_ptr1          = $1A		; 2 bytes
zp_ptr2          = $1C		; 2 bytes
zp_ptr3          = $1E		; 2 bytes

; $20-$3F  display / scroll engine
frame_count      = $20		; incremented every frame by the IRQ
next_valid       = $21		; main -> IRQ: next frame state is ready
cur_fine         = $22		; latched fine scroll (0-7) being shown
cur_front        = $23		; latched front buffer (0 = A, 1 = B)
next_fine        = $24
next_front       = $25
scroll_sub       = $26		; sub-pixel accumulator (1/16 px)
scroll_speed     = $27		; speed in 1/16 px per frame
fine_pos         = $28		; main's fine scroll position 0-7
front_buf        = $29		; main's front buffer 0/1
back_ready       = $2A		; back buffer holds the next coarse step
copy_stage       = $2B		; back buffer preparation step
top_world        = $2C		; 2 bytes: world row in screen row 2
is_ntsc          = $2E		; 1 on NTSC machines
hud_bg_color     = $2F
disp_mode        = $30		; DM_GAME / DM_TEXT / DM_BLANK

; $40-$5F  river generator (+ row render scratch $58-$5F)
emit_world       = $40		; 2 bytes: next row handed to the display
base_world       = $42		; 2 bytes: next row the generator builds
sec_index        = $44		; journey section 0..SECTION_COUNT-1
sec_row          = $45		; boundary index inside the section 0..64
sec_kind         = $46
sec_c0           = $47		; section start center (MC pixels)
sec_w0           = $48		; start width
sec_c1           = $49		; end center
sec_w1           = $4A		; end width
sec_iw           = $4B		; island peak width (0 = none)
edge_l           = $4C		; latest boundary sample (rate limited)
edge_r           = $4D
edge_il          = $4E		; island left/right (equal = no island)
edge_ir          = $4F
rng_lo           = $50		; 16-bit LFSR state
rng_hi           = $51
scen_rate        = $52		; scenery stamp chance per row (0-255)
fish_rate        = $53		; crawfish chance per row (0-255)
island_next      = $54		; next section should be an island
row_seed         = $55		; texture hash seed of the row being built
river_end        = $56		; set once the final section is reached
run_seed         = $57		; per-run variation of the river
rb_la            = $58		; left bank edge chars la..lb
rb_lb            = $59
rb_ra            = $5A		; right bank edge chars ra..rb
rb_rb            = $5B
rb_ila           = $5C		; island edges (valid if rb_island)
rb_irb           = $5D
rb_island        = $5E
water_frame      = $5F
; $60-$7F  game state / player
in_held          = $60		; input bits held (see input.asm)
in_new           = $61		; input bits pressed this frame
in_override      = $62		; test hook: nonzero replaces input
game_state       = $63
scroll_delta     = $64		; pixels the world moved this frame
ply_x            = $65		; Ollie sprite left edge, MC pixels
ply_xf           = $66		; fraction of ply_x
ply_vx           = $67		; signed, 1/64 MC pixel per frame
ply_y            = $68		; sprite Y register value
ply_speed        = $69		; 0 slow, 1 normal, 2 fast
ply_dive         = $6A		; dive state (DIVE_*)
ply_dive_t       = $6B		; frames in the current dive state
ply_under_lo     = $6C		; frames spent underwater (16 bit)
ply_under_hi     = $6D
ply_invuln       = $6E		; crawfish protection frames left
ply_hurt         = $6F		; post-hit grace frames left
ply_anim         = $70		; animation counter
lp_lo            = $71		; Life Points 0-10000 (16 bit)
lp_hi            = $72
hearts           = $73
heart_prog_lo    = $74		; LP earned since the last heart loss
heart_prog_hi    = $75
score            = $76		; 3 bytes BCD, low byte first
safe_rows        = $79		; rows since the last hit (recovery)
lim_l            = $7A		; river limits at Ollie (MC pixels)
lim_r            = $7B
lim_il           = $7C		; island span (lim_il = lim_ir: none)
lim_ir           = $7D
ply_bump         = $7E		; bank contact this frame
; $80-$9F  world objects: the eagle (gators live in RAM, below)
e_state          = $80
e_t              = $81		; frames into the swoop
e_timer_lo       = $82		; frames until the next attack
e_timer_hi       = $83
e_xf             = $84		; x: fraction, low, high
e_xl             = $85
e_xh             = $86
e_yf             = $87		; y: fraction, value
e_y              = $88
e_dxf            = $89		; per-frame x step (16 bit signed)
e_dxl            = $8A
e_dyf            = $8B		; per-frame y step (8.8 signed)
e_dyl            = $8C
e_anim           = $8D
e_side           = $8E		; 0 attack from the left, 1 right
; $A0-$DF  game / screens
hi_score         = $A0		; 3 bytes BCD, low byte first
loss_cause       = $A3		; set by hazards: LOSS_LP / LOSS_EAGLE
state_t          = $A4		; frames in the current game state
last_top         = $A5		; top_world low byte seen last frame
home_row_lo      = $A6		; world row where the home scene is
home_row_hi      = $A7
menu_sel         = $A8
ready_t          = $B2		; GET READY frames left
last_sec         = $B3		; section number seen last frame
home_house_col   = $B4		; screen column of Auntie's house
home_dock_col    = $B5		; screen column of the dock
demo_mode        = $B7		; 1 while the attract demo plays
demo_t_hi        = $B8		; demo length counter (state_t wraps)
idle_seq         = $B9		; title idle sequence: scores -> demo
pop_t            = $BA		; crawfish pop ring frames left
pop_col          = $BB		; its screen column
pop_world        = $BC		; 2 bytes: its world row
snack_rate       = $C0		; fish (Life Point snack) chance per row
gift_rate        = $C1		; gift-for-Auntie chance per row
gifts            = $C2		; gifts collected this game
pk_kind          = $C3		; pickup being collected (PK_*)
pk_left          = $C4		; its left-half character code
gifts_shown      = $C5		; gift counter value on the HUD
home_gift_t      = $C6		; homecoming: gifts left to tally
ts_mode          = $A9		; title sub-screen: 0 menu, 1 scores, ; 2 controls, 3 name entry
ts_idle_lo       = $AA
ts_idle_hi       = $AB
hs_slot          = $AC		; entry being edited
hs_letter        = $AD		; 0..2 letter being edited
home_spot_x      = $AE		; Ollie's party x (MC pixels)
home_t_hi        = $AF		; state_t high byte for long scenes
home_spot_y      = $B6		; sprite Y of the party
fx_splash_t      = $B0		; splash frames left
fx_bump_t        = $B1		; bump sound cool-down
; $E0-$EF  sound engine (owned by c64/sound)
; $F0-$FF  free

; ===== Small buffers $0200-$03FF =====
row_buf          = $0200	; 40 bytes: freshly generated top row
spr_shadow       = $0240	; sprite register shadow (see below)
SPR_SH_X         = spr_shadow+0	; 8 bytes, low 8 bits of X
SPR_SH_Y         = spr_shadow+8	; 8 bytes
SPR_SH_PTR       = spr_shadow+16	; 8 bytes
SPR_SH_COLOR     = spr_shadow+24	; 8 bytes
SPR_SH_XMSB      = spr_shadow+32	; X bit 8 of all sprites
SPR_SH_ENABLE    = spr_shadow+33
SPR_SH_MCOLOR    = spr_shadow+34
SPR_SH_EXPX      = spr_shadow+35
SPR_SH_EXPY      = spr_shadow+36
SPR_SH_PRIO      = spr_shadow+37
SPR_SH_SIZE      = 38

; ===== River buffers $0400-$07FF =====
RIVER_RING       = $0400	; 8 rows x 40 chars, row = world & 7
RIVER_RING_ROWS  = 8
BND_L            = $0540	; 64-entry rings of boundary samples,
BND_R            = $0580	; index = world boundary & 63
BND_IL           = $05C0
BND_IR           = $0600
NOISE            = $0700	; 256 random bytes for texture hashing

; ===== Object and generator tables ($0300-$03FF, $0640-$06FF) =====
stamps_land      = $0640	; 32 bytes each
stamps_water     = $0660
stamps_shore_l   = $0680
stamps_shore_r   = $06A0
stamp_counts     = $06C0	; 4 counts, indexed by class
land_var_tab     = $06D0	; 16 grass variant chars
g_state          = $0300
g_x              = $0304
g_xf             = $0308
g_y              = $030C
g_dir            = $0310		; 0 = swimming right, 1 = left
g_speed          = $0314		; 1/16 MC pixel per frame
g_timer          = $0318
g_anim           = $031C
gator_spawn_t    = $0320		; frames until the next spawn try

; ===== Scenery placement tables ($0280-$02D7) =====
row_la           = $0280	; 8 bytes each, per river ring row:
row_lb           = $0288	; left bank edge chars la..lb,
row_ra           = $0290	; right bank edge chars ra..rb,
row_rb           = $0298	; island land il..ir-1 (il = ir:
row_il           = $02A0	; no island)
row_ir           = $02A8
occ_top          = $02B0	; 40 bytes: top row of scenery per column
