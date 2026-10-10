; ==========================================================
; Otter Raid - C64 hardware definitions
; ==========================================================

; ===== CPU port =====
CPU_DDR          = $00
CPU_PORT         = $01
CPU_IO_ONLY      = $35		; RAM everywhere except I/O at $D000
CPU_ALL_RAM      = $34		; RAM everywhere (no I/O)

; ===== VIC-II =====
VIC_SPR0_X       = $D000
VIC_SPR0_Y       = $D001
VIC_SPR_X_MSB    = $D010
VIC_CTRL1        = $D011
VIC_RASTER       = $D012
VIC_SPR_ENABLE   = $D015
VIC_CTRL2        = $D016
VIC_SPR_EXPAND_Y = $D017
VIC_MEM          = $D018
VIC_IRQ_STATUS   = $D019
VIC_IRQ_ENABLE   = $D01A
VIC_SPR_PRIORITY = $D01B
VIC_SPR_MCOLOR   = $D01C
VIC_SPR_EXPAND_X = $D01D
VIC_SPR_SPR_COLL = $D01E
VIC_SPR_BG_COLL  = $D01F
VIC_BORDER       = $D020
VIC_BG0          = $D021
VIC_BG1          = $D022
VIC_BG2          = $D023
VIC_BG3          = $D024
VIC_SPR_MC0      = $D025
VIC_SPR_MC1      = $D026
VIC_SPR0_COLOR   = $D027

; $D011 bits
D011_YSCROLL     = %00000111
D011_RSEL        = %00001000
D011_DEN         = %00010000
D011_BMM         = %00100000
D011_ECM         = %01000000

; $D016 bits
D016_CSEL        = %00001000
D016_MCM         = %00010000

; ===== SID =====
SID_BASE         = $D400
SID_VOLUME       = $D418

; ===== Color RAM =====
COLOR_RAM        = $D800
COLOR_MC         = %00001000	; color RAM bit 3: multicolor char

; ===== CIA 1 (keyboard / joysticks) =====
CIA1_PRA         = $DC00
CIA1_PRB         = $DC01
CIA1_DDRA        = $DC02
CIA1_DDRB        = $DC03
CIA1_ICR         = $DC0D
CIA1_CRA         = $DC0E
CIA1_CRB         = $DC0F

; ===== CIA 2 (VIC bank / serial) =====
CIA2_PRA         = $DD00
CIA2_DDRA        = $DD02
CIA2_ICR         = $DD0D
CIA2_CRA         = $DD0E
CIA2_CRB         = $DD0F

; ===== Hardware vectors (RAM, KERNAL banked out) =====
VEC_NMI          = $FFFA
VEC_RESET        = $FFFC
VEC_IRQ          = $FFFE

; ===== Colors =====
COL_BLACK        = 0
COL_WHITE        = 1
COL_RED          = 2
COL_CYAN         = 3
COL_PURPLE       = 4
COL_GREEN        = 5
COL_BLUE         = 6
COL_YELLOW       = 7
COL_ORANGE       = 8
COL_BROWN        = 9
COL_LIGHT_RED    = 10
COL_DARK_GREY    = 11
COL_GREY         = 12
COL_LIGHT_GREEN  = 13
COL_LIGHT_BLUE   = 14
COL_LIGHT_GREY   = 15
