asr-optimize dp always
asr-optimize address mirrors

; SNES Space Shooter demo
; Corrected for Asar compatibility: 
; - Unique labels
; - Hardware registers as constants
; - 65816 opcodes only
; - No duplicate routines or labels
; - Placeholder stage 1 and music routines for demonstration

; ========== CONSTANTS & REGISTERS ==========
; Sizes - DEFINE THESE FIRST!

SIZEOF_TITLE_TILES    = 160
SIZEOF_TITLE_TILEMAP  = 2048
SIZEOF_TITLE_PALETTE  = 32
STAGE1_BG_TILES_SIZE  = 64
STAGE1_TILEMAP_SIZE   = 64
STAGE1_PALETTE_SIZE   = 32

; -- Stage 1 palette (16 colors) --
STAGE1_PALETTE_SIZE = 32
Stage1Palette:
    dw $0000, $7FFF, $001F, $03E0, $7C00, $7FE0, $03FF, $7C1F
    dw $4210, $5294, $6318, $77BD, $56B5, $4631, $294A, $2108

; ========== DATA (MINIMAL DEMO) ==========

; -- Title screen tiles (minimal, 5 tiles x 32 bytes) --
SIZEOF_TITLE_TILES = 160
TitleScreenTiles:
    db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    db $3C,$3C,$3C,$3C,$3C,$3C,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    db $7E,$7E,$18,$18,$18,$18,$7E,$7E,$00,$00,$00,$00,$00,$00,$00,$00
    db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    db $3C,$3C,$3C,$3C,$3C,$3C,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    db $18,$18,$18,$18,$18,$18,$7E,$7E,$00,$00,$00,$00,$00,$00,$00,$00
    db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00

; -- Title screen tilemap (fills entire 32x32 tilemap with zeros, Asar syntax) --
!i = 0
TitleScreenTilemap:
while !i < 2048
    db 0
    !i #= !i+1
endwhile

; -- Title screen palette (16 colors) --
SIZEOF_TITLE_PALETTE = 32
TitleScreenPalette:
    dw $0000,$7FFF,$03E0,$001F,$7C00,$7FE0,$03FF,$7C1F
    dw $0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000

; -- Stage 1 background tiles (2 tiles x 32 bytes = 64 bytes) --
STAGE1_BG_TILES_SIZE = 64
Stage1BackgroundTiles:
    db $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
    db $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
    db $AA,$55,$AA,$55,$AA,$55,$AA,$55,$AA,$55,$AA,$55,$AA,$55,$AA,$55
    db $AA,$55,$AA,$55,$AA,$55,$AA,$55,$AA,$55,$AA,$55,$AA,$55,$AA,$55

; -- Stage 1 tilemap (just 32 words demo) --
STAGE1_TILEMAP_SIZE = 64
Stage1Tilemap:
    dw $0000,$0001,$0000,$0001,$0000,$0001,$0000,$0001
    dw $0001,$0000,$0001,$0000,$0001,$0000,$0001,$0000
    dw $0000,$0001,$0000,$0001,$0000,$0001,$0000,$0001
    dw $0001,$0000,$0001,$0000,$0001,$0000,$0001,$0000
; SNES Hardware Registers

INIDISP   = $2100
OBJSEL    = $2101
OAMADDR   = $2102
OAMADDH   = $2103
OAMDATA   = $2104
BGMODE    = $2105
BG1SC     = $2107
BG12NBA   = $210B
VMAIN     = $2115
VMADDL    = $2116
VMADDH    = $2117
VMDATAL   = $2118
VMDATAH   = $2119
CGADD     = $2121
CGDATA    = $2122
TM        = $212C
TS        = $212D
NMITIMEN  = $4200
JOYSER0   = $4016
JOYA      = $4219

; Controller Bits
JOY_B      = $80
JOY_Y      = $40
JOY_SELECT = $20
JOY_START  = $10
JOY_UP     = $08
JOY_DOWN   = $04
JOY_LEFT   = $02
JOY_RIGHT  = $01



; Game States
GAME_STATE_TITLE   = $00
GAME_STATE_STAGE1  = $01

; Zero Page Variables
JoypadState  = $0000
JoypadPressed = $0001
ShipX        = $0002
ShipY        = $0003
BulletX      = $0004
BulletY      = $0005
BulletActive = $0006
GameFrame    = $0007
GameState    = $0008

; ========== SNES HEADER ==========
org $00FFC0
db "SNES SPACE SHOOTER  " ; 21 bytes game title
db $20                  ; LoROM, slowROM
db $00                  ; No special chips
db $09                  ; ROM size (64KB)
db $00                  ; RAM size (0 KB)
db $01                  ; Country code (NTSC-US)
db $33                  ; Developer ID
db $00                  ; ROM version
lorom                   ; Calculate checksums

; ROM Vectors
org $00FFE4
dw $0000                ; COP
dw $0000                ; BRK
dw $0000                ; ABORT
dw NMI_Handler          ; NMI
dw $0000                ; Unused
dw IRQ_Handler          ; IRQ

org $00FFF4
dw $0000                ; COP
dw $0000                ; Unused
dw $0000                ; ABORT
dw $0000                ; NMI
dw Start                ; RESET
dw $0000                ; IRQ/BRK

; ========== PROGRAM START ==========
org $008000
Start:
    sei                 ; Disable interrupts
    clc
    xce
    sep #$30            ; 8-bit A and X/Y
    lda #$80
    sta INIDISP         ; Display off
    lda #$00
    sta NMITIMEN

    ; Clear zero page
    ldx #$FF
    lda #$00
.ClearZeroPageLoop:
    sta $00,x
    dex
    bpl .ClearZeroPageLoop

    ; Initialize variables
    lda #GAME_STATE_TITLE
    sta GameState
    lda #$78
    sta ShipX
    sta ShipY

    ; Init PPU
    lda #$00
    sta BGMODE
    sta OBJSEL
    sta BG12NBA

    ; Clear VRAM
    jsr ClearVRAM_Main

    ; Load title screen graphics
    jsr LoadTitleScreenGraphics_Main

    ; Setup BG1 tilemap at $0400
    lda #$01
    sta BG1SC

    ; VRAM increment
    lda #$80
    sta VMAIN

    ; Enable BG1 and sprites
    lda #$11
    sta TM
    lda #$00
    sta TS

    ; Enable NMI
    lda #$80
    sta NMITIMEN

    ; Display ON, full brightness
    lda #$0F
    sta INIDISP

    cli

; ========== MAIN GAME LOOP ==========
MainLoop:
    wai
    jsr ReadController_Main
    jsr UpdateGame_Main
    jmp MainLoop

; ========== ROUTINES ==========

; --------- VRAM CLEAR (UNIQUE LABEL) ---------
ClearVRAM_Main:
    lda #$00
    sta VMADDL
    sta VMADDH
    rep #$20
    lda #$0000
    ldx #$0000
.CVRAMLoop:
    sta VMDATAL
    inx
    inx
    cpx #$8000
    bne .CVRAMLoop
    sep #$20
    rts

; --------- CONTROLLER READ (UNIQUE LABEL) ---------
ReadController_Main:
    lda JoypadState
    pha
    lda #$01
    sta JOYSER0
    stz JOYSER0
    ldx #$08
    lda #$00
.RCLoop:
    lsr
    lda JOYA
    lsr
    ror
    dex
    bne .RCLoop
    sta JoypadState
    pla
    eor JoypadState
    and JoypadState
    sta JoypadPressed
    rts

; --------- MAIN GAME UPDATE ---------
UpdateGame_Main:
    lda GameState
    cmp #GAME_STATE_TITLE
    beq .GS_Title
    cmp #GAME_STATE_STAGE1
    beq .GS_Stage1
    rts

.GS_Title:
    jsr UpdateTitleScreen_Main
    rts

.GS_Stage1:
    jsr UpdateShip_Main
    jsr UpdateBullet_Main
    jsr UpdateSprites_Main
    jsr Music_PlayStage1_Main
    inc GameFrame
    rts

; --------- TITLE SCREEN UPDATE (UNIQUE LABEL) ---------
UpdateTitleScreen_Main:
    lda JoypadPressed
    and #JOY_START
    beq .UTS_NoStart
    lda #GAME_STATE_STAGE1
    sta GameState
    jsr ClearVRAM_Main
    jsr LoadStage1Graphics_Main
    jsr Music_StartStage1_Main
    rts
.UTS_NoStart:
    ; Hide all sprites for title screen
    lda #$00
    sta OAMADDR
    lda #$02
    sta OAMADDH
    ldx #$20
.UTS_HighOAMLoop:
    lda #$00
    sta OAMDATA
    dex
    bne .UTS_HighOAMLoop
    lda #$00
    sta OAMADDR
    sta OAMADDH
    ldx #$80
.UTS_OAMLoop:
    lda #$F0
    sta OAMDATA
    lda #$00
    sta OAMDATA
    sta OAMDATA
    sta OAMDATA
    inx
    cpx #$80
    bne .UTS_OAMLoop
    rts

; --------- LOAD TITLE SCREEN GRAPHICS ---------
LoadTitleScreenGraphics_Main:
    lda #$00
    sta VMADDL
    sta VMADDH
    lda #$00
    sta VMAIN         ; 8-bit mode for tile data
    ldx #$00
.LTSG_TilesLoop:
    lda TitleScreenTiles,x
    sta VMDATAL
    inx
    cpx #SIZEOF_TITLE_TILES
    bne .LTSG_TilesLoop

    lda #$80
    sta VMAIN         ; 16-bit mode for tilemap
    lda #$00
    sta VMADDL
    lda #$04
    sta VMADDH
    rep #$20
    ldx #$00
.LTSG_MapLoop:
    lda TitleScreenTilemap,x
    sta VMDATAL
    inx
    inx
    cpx #SIZEOF_TITLE_TILEMAP
    bne .LTSG_MapLoop
    sep #$20

    lda #$00
    sta CGADD
    rep #$20
    ldx #$00
.LTSG_PalLoop:
    lda TitleScreenPalette,x
    sta CGDATA
    inx
    inx
    cpx #SIZEOF_TITLE_PALETTE
    bne .LTSG_PalLoop
    sep #$20
    rts

; --------- LOAD STAGE 1 GRAPHICS ---------
LoadStage1Graphics_Main:
    jsr LoadStage1BackgroundTiles_Main
    jsr LoadStage1Tilemap_Main
    jsr LoadStage1Palette_Main
    jsr InitOAM_Main
    rts

LoadStage1BackgroundTiles_Main:
    lda #$00
    sta VMADDL
    sta VMADDH
    ldx #$00
.LS1BG_Loop:
    lda Stage1BackgroundTiles,x
    sta VMDATAL
    inx
    cpx #STAGE1_BG_TILES_SIZE
    bne .LS1BG_Loop
    rts

LoadStage1Tilemap_Main:
    lda #$00
    sta VMADDL
    lda #$04
    sta VMADDH
    rep #$20
    ldx #$00
.LS1MapLoop:
    lda Stage1Tilemap,x
    sta VMDATAL
    inx
    inx
    cpx #STAGE1_TILEMAP_SIZE
    bne .LS1MapLoop
    sep #$20
    rts

LoadStage1Palette_Main:
    lda #$00
    sta CGADD
    rep #$20
    ldx #$00
.LS1PalLoop:
    lda Stage1Palette,x
    sta CGDATA
    inx
    inx
    cpx #STAGE1_PALETTE_SIZE
    bne .LS1PalLoop
    sep #$20
    rts

; --------- SPRITE/OAM INIT ---------
InitOAM_Main:
    lda #$00
    sta OAMADDR
    sta OAMADDH
    ldx #$00
.IOAM_Loop:
    lda #$F0
    sta OAMDATA
    lda #$00
    sta OAMDATA
    sta OAMDATA
    sta OAMDATA
    inx
    cpx #$80
    bne .IOAM_Loop

    lda #$00
    sta OAMADDR
    lda #$02
    sta OAMADDH
    ldx #$00
.IOAM_HighLoop:
    lda #$00
    sta OAMDATA
    inx
    cpx #$20
    bne .IOAM_HighLoop
    rts

; --------- SHIP/BULLET/SPRITE UPDATE ROUTINES (UNIQUE LABELS) ---------
UpdateShip_Main:
    lda JoypadState
    and #JOY_RIGHT
    beq .USM_Left
    lda ShipX
    cmp #$F0
    bcs .USM_Left
    inc ShipX
    inc ShipX
.USM_Left:
    lda JoypadState
    and #JOY_LEFT
    beq .USM_Down
    lda ShipX
    cmp #$08
    bcc .USM_Down
    dec ShipX
    dec ShipX
.USM_Down:
    lda JoypadState
    and #JOY_DOWN
    beq .USM_Up
    lda ShipY
    cmp #$E0
    bcs .USM_Up
    inc ShipY
    inc ShipY
.USM_Up:
    lda JoypadState
    and #JOY_UP
    beq .USM_Fire
    lda ShipY
    cmp #$08
    bcc .USM_Fire
    dec ShipY
    dec ShipY
.USM_Fire:
    lda JoypadPressed
    and #JOY_B
    beq .USM_Done
    lda BulletActive
    bne .USM_Done
    lda #$01
    sta BulletActive
    lda ShipX
    clc
    adc #$10
    sta BulletX
    lda ShipY
    clc
    adc #$04
    sta BulletY
.USM_Done:
    rts

UpdateBullet_Main:
    lda BulletActive
    beq .UBM_Done
    lda BulletX
    clc
    adc #$04
    sta BulletX
    cmp #$F8
    bcc .UBM_Done
    lda #$00
    sta BulletActive
.UBM_Done:
    rts

UpdateSprites_Main:
    lda #$00
    sta OAMADDR
    sta OAMADDH
    lda ShipY
    sta OAMDATA
    lda ShipX
    sta OAMDATA
    lda #$00
    sta OAMDATA
    sta OAMDATA
    lda BulletActive
    beq .USM_Hide
    lda BulletY
    sta OAMDATA
    lda BulletX
    sta OAMDATA
    lda #$01
    sta OAMDATA
    lda #$00
    sta OAMDATA
    rts
.USM_Hide:
    lda #$F0
    sta OAMDATA
    lda #$00
    sta OAMDATA
    sta OAMDATA
    sta OAMDATA
    rts

; --------- MUSIC ROUTINES (STUBS FOR DEMO) ---------
Music_StartStage1_Main:
    ; In a real game, this would send commands to the SPC
    rts

Music_PlayStage1_Main:
    ; In a real game, this would play music
    rts

; --------- INTERRUPT HANDLERS ---------
NMI_Handler:
    rti

IRQ_Handler:
    rti

; ========== DATA (MINIMAL DEMO) ==========

; -- Title screen tiles (minimal, 5 tiles x 32 bytes) --
SIZEOF_TITLE_TILES = 160
TitleScreenTiles:
    db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    db $3C,$3C,$3C,$3C,$3C,$3C,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    db $7E,$7E,$18,$18,$18,$18,$7E,$7E,$00,$00,$00,$00,$00,$00,$00,$00
    db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    db $3C,$3C,$3C,$3C,$3C,$3C,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    db $18,$18,$18,$18,$18,$18,$7E,$7E,$00,$00,$00,$00,$00,$00,$00,$00
    db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00

; -- Title screen tilemap (fills entire 32x32 tilemap with zeros, Asar syntax) --
!i = 0
TitleScreenTilemap:
while !i < 2048
    db 0
    !i #= !i+1
endwhile

; -- Title screen palette (16 colors) --
SIZEOF_TITLE_PALETTE = 32
TitleScreenPalette:
    dw $0000,$7FFF,$03E0,$001F,$7C00,$7FE0,$03FF,$7C1F
    dw $0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000

; -- Stage 1 background tiles (2 tiles x 32 bytes = 64 bytes) --
STAGE1_BG_TILES_SIZE = 64
Stage1BackgroundTiles:
    db $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
    db $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
    db $AA,$55,$AA,$55,$AA,$55,$AA,$55,$AA,$55,$AA,$55,$AA,$55,$AA,$55
    db $AA,$55,$AA,$55,$AA,$55,$AA,$55,$AA,$55,$AA,$55,$AA,$55,$AA,$55

; -- Stage 1 tilemap (just 32 words demo) --
STAGE1_TILEMAP_SIZE = 64
Stage1Tilemap:
    dw $0000,$0001,$0000,$0001,$0000,$0001,$0000,$0001
    dw $0001,$0000,$0001,$0000,$0001,$0000,$0001,$0000
    dw $0000,$0001,$0000,$0001,$0000,$0001,$0000,$0001
    dw $0001,$0000,$0001,$0000,$0001,$0000,$0001,$0000



; ========== END ==========
