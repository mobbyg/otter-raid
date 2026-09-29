; Otter Raid river prototype constants

SCREEN_RAM       = $0400
COLOR_RAM        = $D800
VIC_CTRL1        = $D011
VIC_RASTER       = $D012
VIC_BORDER       = $D020
VIC_BACKGROUND   = $D021

HUD_ROWS         = 2
PLAY_START       = 2
PLAY_END         = 23
SCREEN_COLS      = 40
RIVER_MIN_WIDTH  = 16
RIVER_MAX_WIDTH  = 30
SECTION_ROWS     = 160
SECTION_COUNT    = 40

zp_fine_scroll   = $20
zp_frame_counter = $21
zp_world_row     = $22
zp_section       = $23
zp_section_row   = $24
zp_center        = $25
zp_width         = $26
zp_left          = $27
zp_right         = $28
zp_tmp           = $29
zp_tmp2          = $2A
zp_seed          = $2B
zp_src_lo        = $2C
zp_src_hi        = $2D
zp_dst_lo        = $2E
zp_dst_hi        = $2F

river_cp0_x      = $30
river_cp0_w      = $31
river_cp1_x      = $32
river_cp1_w      = $33
river_cp2_x      = $34
river_cp2_w      = $35

CHAR_WATER       = $20
CHAR_BANK        = $23
COLOR_WATER      = 3
COLOR_BANK       = 5
COLOR_HUD        = 1
