; SNES Space Shooter Game - BLACK SCREEN FIXES
; Asar optimization settings to silence warnings
optimize dp always
optimize address mirrors

;clear old assembly data
    ldx #$FF        ; Start from the highest address
    lda #$00        ; Load zero into A
.clearRamLoop:
    sta $00,x       ; Store zero in address $00 to $FF
    dex             ; Move to next memory address
    bpl .clearRamLoop  ; Loop until all addresses are cleared

;Clear VRAM (Prevent Graphical Artifacts)
    stz VMADDL      ; Set VRAM address to $0000
    stz VMADDH

    rep #$20        ; Set accumulator to 16-bit mode
    lda #$0000      ; Load zero
    ldx #$8000      ; 32KB VRAM

.clearVRAMLoop:
    sta VMDATAL     ; Write 16-bit zeros to VRAM
    dex
    bne .clearVRAMLoop

    sep #$20        ; Return to 8-bit mode


; Constants
GAME_STATE_TITLE  = $00
GAME_STATE_PLAYING = $01

; Memory locations for variables (in zero page for asar compatibility)
JoypadState  = $0000    ; Controller state
JoypadPressed = $0001   ; New button presses
ShipX        = $0002    ; Ship X position (8-bit)
ShipY        = $0003    ; Ship Y position (8-bit)
BulletX      = $0004    ; Bullet X position (8-bit)
BulletY      = $0005    ; Bullet Y position (8-bit)
BulletActive = $0006    ; Bullet active flag (0=inactive, 1=active)
GameFrame    = $0007    ; Frame counter
GameState    = $0008    ; Game state (Title vs. Playing)

; SNES Register Constants
INIDISP     = $2100   ; Display control
OBJSEL      = $2101   ; Object size & tile address
OAMADDR     = $2102   ; OAM address low byte
OAMADDH     = $2103   ; OAM address high byte
OAMDATA     = $2104   ; OAM data write
BGMODE      = $2105   ; BG Mode and tile size
BG1SC       = $2107   ; BG1 Tilemap address
BG12NBA     = $210B   ; BG1/BG2 Tileset address
VMAIN       = $2115   ; VRAM address increment
VMADDL      = $2116   ; VRAM address low byte
VMADDH      = $2117   ; VRAM address high byte
VMDATAL     = $2118   ; VRAM data write low byte
VMDATAH     = $2119   ; VRAM data write high byte
CGADD       = $2121   ; CGRAM address
CGDATA      = $2122   ; CGRAM data write
TM          = $212C   ; Main screen designation
TS          = $212D   ; Sub screen designation
NMITIMEN    = $4200   ; Interrupt enable
JOYSER0     = $4016   ; Controller 1 data/serial strobe
JOYA        = $4219   ; Controller 1 data register L

; Controller Bits (SNES standard bit layout after inversion)
JOY_B       = $80
JOY_Y       = $40
JOY_SELECT  = $20
JOY_START   = $10
JOY_UP      = $08
JOY_DOWN    = $04
JOY_LEFT    = $02
JOY_RIGHT   = $01

; **SNES Header (64KB LoROM)**
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

; **ROM Vectors**
; Native mode vectors
org $00FFE4
dw $0000                ; COP
dw $0000                ; BRK
dw $0000                ; ABORT
dw NMI_Handler          ; NMI
dw $0000                ; Unused
dw IRQ_Handler          ; IRQ
;org TitleScreenTilemap + (333 * 2)  ;not sure where this goes

; Emulation mode vectors
org $00FFF4
dw $0000                ; COP
dw $0000                ; Unused
dw $0000                ; ABORT
dw $0000                ; NMI
dw start                ; RESET
dw $0000                ; IRQ/BRK

; **Program Start**
org $008000
start:
    sei                 ; Disable interrupts
    clc                 ; Clear carry flag
    xce                 ; Enable the CPU to access the WRAM

    ; Set processor to 8-bit A and 8-bit index registers
    sep #$30            ; Set M=1 (8-bit A) and X=1 (8-bit X,Y)

    ; Turn off display during setup
    lda #$80            ; Force VBlank
    sta INIDISP

    ; Disable all interrupts during setup
    stz NMITIMEN

    ; Clear zero page
    ldx #$FF
    lda #$00

.clearZeroPage:
    
    sta $00,x
    dex
    bpl .clearZeroPage

    ; Initialize game variables
    lda #GAME_STATE_TITLE  ; Start in title screen
    sta GameState
    
    lda #$78            ; Ship starts in middle
    sta ShipX
    lda #$78
    sta ShipY

    ; Initialize PPU registers
    stz BGMODE          ; BG Mode 0
    stz OBJSEL          ; 8x8 sprites, pattern at $0000

    ; Clear all VRAM first
    jsr ClearVRAM

    ; Load initial graphics data (Title Screen)
    jsr LoadTitleScreenGraphics

    ; Setup background for initial state
    lda #$01            ; BG1 tilemap at $0400
    sta BG1SC
    stz BG12NBA         ; BG tiles at $0000

    ; Setup VRAM increment
    lda #$80
    sta VMAIN

    ; Enable layers
    lda #$11            ; Enable BG1 and sprites
    sta TM
    stz TS              ; Nothing on subscreen

    ; Enable NMI
    lda #$80
    sta NMITIMEN

    ; Turn on display with full brightness
    lda #$0F
    sta INIDISP

    ; Enable interrupts
    cli

; **Main Game Loop**
MainLoop:
    wai                 ; Wait for VBlank
    jsr ReadController
    jsr UpdateGame
    jmp MainLoop

; **Update Game Logic**
UpdateGame:
    lda GameState
    cmp #GAME_STATE_TITLE
    beq .doTitleScreen
    cmp #GAME_STATE_PLAYING
    beq .doGameplay
    ; Add more game states here if needed

.doTitleScreen:
    jsr UpdateTitleScreen
    jmp .doneUpdateGame

.doGameplay:
    jsr UpdateShip
    jsr UpdateBullet
    jsr UpdateSprites
    inc GameFrame

.doneUpdateGame:
    rts

; **Update Title Screen Logic**
UpdateTitleScreen:
    ; Check for START button press to transition to game
    lda JoypadPressed
    and #JOY_START
    beq .noStartPress

    ; Transition to game state
    lda #GAME_STATE_PLAYING
    sta GameState

    ; Re-initialize graphics for gameplay
    jsr ClearVRAM
    jsr LoadGameplayGraphics
    jmp .doneTitleScreen

.noStartPress:
    ; You can add animations or other title screen specific updates here
    ; For now, let's ensure sprites are hidden on title screen
    stz OAMADDR
    lda #$02
    sta OAMADDH
    ldx #$20
.hideHighOamLoop:
    stz OAMDATA
    dex
    bne .hideHighOamLoop
    stz OAMADDR
    stz OAMADDH
    ldx #$80
.hideOamLoop:
    lda #$F0            ; Y position off screen
    sta OAMDATA
    stz OAMDATA         ; X position
    stz OAMDATA         ; Tile
    stz OAMDATA         ; Attributes
    inx
    cpx #$80            ; 128 sprites
    bne .hideOamLoop


.doneTitleScreen:
    rts

LoadTitleScreenGraphics:
    ; Load title screen tiles
    ; Set VRAM address to $0000 (BG tiles)
    stz VMADDL
    stz VMADDH

    stz VMAIN           ; <--- NEW: Set VRAM increment to 8-bit transfers (important for DB data)

    ldx #$00
.loadTitleTilesLoop:
    lda TitleScreenTiles,x
    sta VMDATAL         ; Write 8-bit data
    inx
    cpx #SIZEOF_TITLE_TILES
    bne .loadTitleTilesLoop

    lda #$80            ; <--- NEW: Set VRAM increment back to 16-bit transfers for DW data
    sta VMAIN

    ; Load title screen tilemap
    ; Set VRAM address to $0400 (BG1 tilemap)
    lda #$00
    sta VMADDL
    lda #$04
    sta VMADDH

    rep #$20            ; Accumulator and Index registers to 16-bit
    ldx #$00
.loadTitleMapLoop:
    lda TitleScreenTilemap,x
    sta VMDATAL         ; Write tile number (low byte = tile, high byte = attributes)
    inx
    inx                 ; Increment by 2 (16-bit words)
    cpx #SIZEOF_TITLE_TILEMAP
    bne .loadTitleMapLoop
    sep #$20            ; Back to 8-bit A and I

    ; Load title screen palette
    stz CGADD           ; Start at color 0
    
    rep #$20            ; <--- NEW: Set accumulator to 16-bit for palette (DW) data
    ldx #$00
.loadTitlePalLoop:
    lda TitleScreenPalette,x ; Load 16-bit color word
    sta CGDATA          ; Write 16-bit color word
    inx
    inx                 ; <--- NEW: Increment by 2 because we're loading words
    cpx #SIZEOF_TITLE_PALETTE
    bne .loadTitlePalLoop
    sep #$20            ; <--- NEW: Set accumulator back to 8-bit
    rts

LoadGameplayGraphics:

    jsr LoadBackgroundTiles
    jsr LoadSpriteTiles
    jsr LoadPalettes
    jsr LoadTilemap
    jsr InitOAM
    rts

; **Clear VRAM**
ClearVRAM:
    ; Set VRAM address to $0000
    stz VMADDL
    stz VMADDH

    ; Clear 32KB of VRAM
    rep #$20            ; 16-bit A
    lda #$0000
    ldx #$00
.clearLoop:
    sta VMDATAL         ; Write $0000 to VRAM
    inx
    inx                 ; Increment by 2 (16-bit writes)
    cpx #$00            ; Loop until X wraps to 0 (256 iterations = 32KB)
    bne .clearLoop

    sep #$20            ; Back to 8-bit A
    rts

; **Load Background Tiles**
LoadBackgroundTiles:
    ; Set VRAM address to $0000 (BG tiles)
    stz VMADDL
    stz VMADDH

    ; Load tile data
    ldx #$00
.loadLoop:
    lda BackgroundTiles,x
    sta VMDATAL
    inx
    cpx #$80            ; 4 tiles * 32 bytes each
    bne .loadLoop
    rts

; **Load Sprite Tiles**
LoadSpriteTiles:
    ; Set VRAM address to $4000 (sprite tiles)
    stz VMADDL
    lda #$40
    sta VMADDH

    ; Load sprite data
    ldx #$00
.loadLoop:
    lda SpriteTiles,x
    sta VMDATAL
    inx
    cpx #$80            ; 2 tiles * 64 bytes each (4bpp)
    bne .loadLoop
    rts

; **Load Tilemap**
LoadTilemap:
    ; Set VRAM address to $0400 (BG1 tilemap)
    lda #$00
    sta VMADDL
    lda #$04
    sta VMADDH

    ; Fill screen with tile pattern
    rep #$20            ; 16-bit A and X/Y (assuming X/Y follow A)
    ldy #$00
.tilemapLoop:
    tya
    and #$0003          ; Use tiles 0-3
    sta VMDATAL         ; Write tile number (low byte = tile, high byte = attributes)
    iny
    cpy #$0400          ; 32x32 = 1024 entries
    bne .tilemapLoop

    sep #$20            ; Back to 8-bit A and X/Y
    rts

; **Load Palettes**
LoadPalettes:
    ; Load background palette
    stz CGADD           ; Start at color 0

    ldx #$00
.bgPalLoop:
    lda BackgroundPalette,x
    sta CGDATA
    inx
    cpx #$20            ; 16 colors * 2 bytes
    bne .bgPalLoop

    ; Load sprite palette
    lda #$80            ; Sprite palette starts at color 128
    sta CGADD

    ldx #$00
.spritePalLoop:
    lda SpritePalette,x
    sta CGDATA
    inx
    cpx #$20
    bne .spritePalLoop
    rts

; **Initialize OAM**
InitOAM:
    ; Clear OAM address
    stz OAMADDR
    stz OAMADDH

    ; Hide all sprites
    ldx #$00
.oamLoop:
    lda #$F0            ; Y position off screen
    sta OAMDATA
    stz OAMDATA         ; X position
    stz OAMDATA         ; Tile
    stz OAMDATA         ; Attributes
    inx
    cpx #$80            ; 128 sprites
    bne .oamLoop

    ; Clear high OAM table
    stz OAMADDR
    lda #$02
    sta OAMADDH

    ldx #$00
.highOamLoop:
    stz OAMDATA
    inx
    cpx #$20
    bne .highOamLoop
    rts

; **Read Controller**
ReadController:
    lda JoypadState
    pha                 ; Save previous state

    ; Strobe controller
    lda #$01
    sta JOYSER0
    stz JOYSER0

    ; Read 8 bits
    ldx #$08
    lda #$00
.readLoop:
    lsr
    lda JOYA
    lsr
    ror
    dex
    bne .readLoop

    sta JoypadState

    ; Calculate newly pressed
    pla                 ; Get previous state
    eor JoypadState
    and JoypadState
    sta JoypadPressed
    rts

; **Update Ship**
UpdateShip:
    ; Right movement
    lda JoypadState
    and #JOY_RIGHT
    beq .checkLeft
    lda ShipX
    cmp #$F0
    bcs .checkLeft
    inc ShipX
    inc ShipX

.checkLeft:
    lda JoypadState
    and #JOY_LEFT
    beq .checkDown
    lda ShipX
    cmp #$08
    bcc .checkDown
    dec ShipX
    dec ShipX

.checkDown:
    lda JoypadState
    and #JOY_DOWN

    beq .checkUp
    lda ShipY
    cmp #$E0
    bcs .checkUp
    inc ShipY
    inc ShipY

.checkUp:
    lda JoypadState
    and #JOY_UP
    beq .checkFire
    lda ShipY
    cmp #$08
    bcc .checkFire
    dec ShipY
    dec ShipY

.checkFire:
    lda JoypadPressed
    and #JOY_B
    beq .done

    lda BulletActive
    bne .done

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

.done:
    rts

; **Update Bullet**
UpdateBullet:
    lda BulletActive
    beq .done

    lda BulletX
    clc
    adc #$04
    sta BulletX
    cmp #$F8
    bcc .done

    stz BulletActive    ; Deactivate when off screen
.done:
    rts

; **Update Sprites**
UpdateSprites:
    ; Reset OAM
    stz OAMADDR
    stz OAMADDH

    ; Ship sprite
    lda ShipY
    sta OAMDATA
    lda ShipX
    sta OAMDATA
    stz OAMDATA         ; Tile 0
    stz OAMDATA         ; Palette 0

    ; Bullet sprite
    lda BulletActive
    beq .hideBullet

    lda BulletY
    sta OAMDATA
    lda BulletX
    sta OAMDATA
    lda #$01            ; Tile 1
    sta OAMDATA
    stz OAMDATA         ; Palette 0
    jmp .done

.hideBullet:
    lda #$F0            ; Off screen
    sta OAMDATA
    stz OAMDATA
    stz OAMDATA
    stz OAMDATA

.done:
    rts

; **Interrupt Handlers**
NMI_Handler:
    rti

IRQ_Handler:
    rti

; Place graphics data starting at $C08000 to satisfy the warning.
org $C08000

; Background tiles (4 tiles, 2bpp format)
BackgroundTiles:
    ; Tile 0 - Empty
    db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00

    ; Tile 1 - Small dot
    db $00,$00,$00,$00,$00,$00,$18,$18,$18,$18,$00,$00,$00,$00,$00,$00
    db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00

    ; Tile 2 - Medium star
    db $00,$00,$00,$00,$18,$18,$3C,$3C,$7E,$7E,$3C,$3C,$18,$18,$00,$00
    db $00,$00,$00,$00,$00,$00,$18,$18,$24,$24,$18,$18,$00,$00,$00,$00

    ; Tile 3 - Large star
    db $18,$18,$18,$18,$3C,$3C,$7E,$7E,$FF,$FF,$7E,$7E,$3C,$3C,$18,$18
    db $00,$00,$18,$18,$24,$24,$42,$42,$81,$81,$42,$42,$24,$24,$18,$18

; Sprite tiles (2 tiles, 4bpp format - doubled for proper 4bpp)
SpriteTiles:
    ; Tile 0 - Ship (4bpp)
    db $00,$00,$18,$00,$3C,$00,$7E,$00,$FF,$00,$7E,$00,$3C,$00,$18,$00
    db $00,$00,$00,$00,$18,$00,$3C,$00,$7E,$00,$18,$00,$00,$00,$00,$00
    db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00

    ; Tile 1 - Bullet (4bpp)
    db $00,$00,$00,$00,$18,$00,$3C,$00,$3C,$00,$18,$00,$00,$00,$00,$00
    db $00,$00,$00,$00,$00,$00,$18,$00,$18,$00,$00,$00,$00,$00,$00,$00
    db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00

; Background palette
BackgroundPalette:
    dw $0000, $7FFF, $39CE, $2108, $001F, $03E0, $7C00, $7FE0
    dw $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000

; Sprite palette
SpritePalette:
    dw $0000, $7FFF, $001F, $03E0, $7C00, $7C1F, $03FF, $7FE0
    dw $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000

; Title Screen Palette (2bpp, 16 colors)
TitleScreenPalette:
    dw $0000, $7FFF, $03E0, $001F, $7C00, $7FE0, $03FF, $7C1F ; Example colors (Black, White, Green, Blue, Red, Yellow, Cyan, Magenta)
    dw $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000

; Hardcoded size as '*' is not supported by your assembler
;SIZEOF_TITLE_PALETTE = 32 ; 16 colors * 2 bytes/color, wrong location most likely
; **Boilerplate Title Screen Data**
; You will want to replace these with your actual title screen graphics.
; These are 2bpp (background) tiles.
; Each tile is 32 bytes (16 bytes per plane, 2 planes for 2bpp).
; Example: a simple "TITLE" text.

TitleScreenTiles:
    ; Tile 0 - Empty (or whatever you want for background)
    db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00

    ; Tile 1 - Letter T (replace with YOUR actual 2bpp 'T' tile data - 32 bytes total)
    db $00,$00,$00,$00,$3C,$3C,$3C,$3C,$3C,$3C,$00,$00,$00,$00,$00,$00  ; Plane 0
    db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00  ; Plane 1

    ; Tile 2 - Letter I (replace with YOUR actual 2bpp 'I' tile data - 32 bytes total)
    db $00,$00,$00,$00,$7E,$7E,$18,$18,$18,$18,$7E,$7E,$00,$00,$00,$00  ; Plane 0
    db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00  ; Plane 1

    ; Tile 3 - Letter T (replace with YOUR actual 2bpp 'T' tile data, or reuse Tile 1 - 32 bytes total)
    db $00,$00,$00,$00,$3C,$3C,$3C,$3C,$3C,$3C,$00,$00,$00,$00,$00,$00  ; Plane 0
    db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00  ; Plane 1

    ; Tile 4 - Letter L (replace with YOUR actual 2bpp 'L' tile data - 32 bytes total)
    db $00,$00,$00,$00,$18,$18,$18,$18,$18,$18,$7E,$7E,$00,$00,$00,$00  ; Plane 0
    db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00  ; Plane 1

    ; Tile 5 - Letter E (replace with YOUR actual 2bpp 'E' tile data - 32 bytes total)
    db $00,$00,$00,$00,$7E,$7E,$18,$18,$7C,$7C,$18,$18,$7E,$7E,$00,$00  ; Plane 0
    db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00  ; Plane 1

    ; ... if you have other background tiles, place them here,
    ; making sure their indices match any tilemap entries.placed after the letters)
    ; Ensure SIZEOF_TITLE_TILES is updated if you add new tiles.
 ; New, corrected lines:

SIZEOF_TITLE_TILES = 160        ; 5 tiles * 32 bytes/tile
; ... (your TitleScreenTiles data) ...

SIZEOF_TITLE_TILEMAP = 2048     ; 1024 words * 2 bytes/word (for a 32x32 tilemap)
; ... (your TitleScreenTilemap data) ...

SIZEOF_TITLE_PALETTE = 32       ; 16 colors * 2 bytes/color
; ... (your TitleScreenPalette data) ...

; Example Title Screen Tilemap (partial for a simple text)
; This assumes a simple "TITLE" text centered on the screen.
; Adjust this to your actual title screen layout.
; Each entry is 2 bytes (tile number + attributes)
TitleScreenTilemap:
    ; Start with a full map of empty tiles (32x32 tiles = 1024 entries * 2 bytes/entry = 2048 bytes total)
    ; Manually expanded from 'fill 2048, $00'
    ;.fill_start_of_map:
    ; This block needs to contain 2048 bytes of $00.
    ; I'm providing a small example here. You'll need to repeat 'dw $0000' 1024 times.
    ;fill 2048, $00   ; asar incompatible it seems

    dw $0000  ;1
    dw $0000  ;2
    dw $0000  ;3
    dw $0000  ;4
    dw $0000  ;5
    dw $0000  ;6
    dw $0000  ;7
    dw $0000  ;8
    dw $0000  ;9
    dw $0000  ;10
    dw $0000  ;11
    dw $0000  ;12
    dw $0000  ;13
    dw $0000  ;14
    dw $0000  ;15
    dw $0000  ;16
    dw $0000  ;17
    dw $0000  ;18
    dw $0000  ;19
    dw $0000  ;20
    dw $0000  ;21
    dw $0000  ;22
    dw $0000  ;23
    dw $0000  ;24
    dw $0000  ;25
    dw $0000  ;26
    dw $0000  ;27
    dw $0000  ;28
    dw $0000  ;29
    dw $0000  ;30
    dw $0000  ;31
    dw $0000  ;32
    dw $0000  ;33
    dw $0000  ;34
    dw $0000  ;35
    dw $0000  ;36
    dw $0000  ;37
    dw $0000  ;38
    dw $0000  ;39
    dw $0000  ;40
    dw $0000  ;41
    dw $0000  ;42
    dw $0000  ;43
    dw $0000  ;44
    dw $0000  ;45
    dw $0000  ;46
    dw $0000  ;47
    dw $0000  ;48
    dw $0000  ;49
    dw $0000  ;50
    dw $0000  ;51
    dw $0000  ;52
    dw $0000  ;53
    dw $0000  ;54
    dw $0000  ;55
    dw $0000  ;56
    dw $0000  ;57
    dw $0000  ;58
    dw $0000  ;59
    dw $0000  ;60
    dw $0000  ;61
    dw $0000  ;62
    dw $0000  ;63
    dw $0000  ;64
    dw $0000  ;65
    dw $0000  ;66
    dw $0000  ;67
    dw $0000  ;68
    dw $0000  ;69
    dw $0000  ;70
    dw $0000  ;71
    dw $0000  ;72
    dw $0000  ;73
    dw $0000  ;74
    dw $0000  ;75
    dw $0000  ;76
    dw $0000  ;77
    dw $0000  ;78
    dw $0000  ;79
    dw $0000  ;80
    dw $0000  ;81
    dw $0000  ;82
    dw $0000  ;83
    dw $0000  ;84
    dw $0000  ;85
    dw $0000  ;86
    dw $0000  ;87
    dw $0000  ;88
    dw $0000  ;89
    dw $0000  ;90
    dw $0000  ;91
    dw $0000  ;92
    dw $0000  ;93
    dw $0000  ;94
    dw $0000  ;95
    dw $0000  ;96
    dw $0000  ;97
    dw $0000  ;98
    dw $0000  ;99
    dw $0000  ;100
    dw $0000  ;101
    dw $0000  ;102
    dw $0000  ;103 
    dw $0000  ;104
    dw $0000  ;105
    dw $0000  ;106
    dw $0000  ;107
    dw $0000  ;108
    dw $0000  ;109
    dw $0000  ;110
    dw $0000  ;111
    dw $0000  ;112
    dw $0000  ;113
    dw $0000  ;114
    dw $0000  ;115
    dw $0000  ;116
    dw $0000  ;117
    dw $0000  ;118
    dw $0000  ;119
    dw $0000  ;120
    dw $0000  ;121
    dw $0000  ;122
    dw $0000  ;123
    dw $0000  ;124
    dw $0000  ;125
    dw $0000  ;126
    dw $0000  ;127
    dw $0000  ;128
    dw $0000  ;129
    dw $0000  ;130
    dw $0000  ;131
    dw $0000  ;132
    dw $0000  ;133
    dw $0000  ;134
    dw $0000  ;135
    dw $0000  ;136
    dw $0000  ;137
    dw $0000  ;138
    dw $0000  ;139
    dw $0000  ;140
    dw $0000  ;141
    dw $0000  ;142
    dw $0000  ;143
    dw $0000  ;144
    dw $0000  ;145
    dw $0000  ;146
    dw $0000  ;147
    dw $0000  ;148
    dw $0000  ;149
    dw $0000  ;150
    dw $0000  ;151
    dw $0000  ;152
    dw $0000  ;153
    dw $0000  ;154
    dw $0000  ;155
    dw $0000  ;156
    dw $0000  ;157
    dw $0000  ;158
    dw $0000  ;159
    dw $0000  ;160
    dw $0000  ;161
    dw $0000  ;162
    dw $0000  ;163
    dw $0000  ;164
    dw $0000  ;165
    dw $0000  ;166
    dw $0000  ;167
    dw $0000  ;168
    dw $0000  ;169
    dw $0000  ;170
    dw $0000  ;171
    dw $0000  ;172
    dw $0000  ;173
    dw $0000  ;174
    dw $0000  ;175
    dw $0000  ;176
    dw $0000  ;177
    dw $0000  ;178
    dw $0000  ;179
    dw $0000  ;180
    dw $0000  ;181
    dw $0000  ;182
    dw $0000  ;183
    dw $0000  ;184
    dw $0000  ;185
    dw $0000  ;186
    dw $0000  ;187
    dw $0000  ;188
    dw $0000  ;189
    dw $0000  ;190
    dw $0000  ;191
    dw $0000  ;192
    dw $0000  ;193
    dw $0000  ;194
    dw $0000  ;195
    dw $0000  ;196
    dw $0000  ;197
    dw $0000  ;198
    dw $0000  ;199
    dw $0000  ;   200
    dw $0000  ;201
    dw $0000  ;202
    dw $0000  ;203
    dw $0000  ;204
    dw $0000  ;205
    dw $0000  ;206
    dw $0000  ;207
    dw $0000  ;208
    dw $0000  ;209
    dw $0000  ;210   
    dw $0000  ;211
    dw $0000  ;212
    dw $0000  ;213
    dw $0000  ;214
    dw $0000  ;215
    dw $0000  ;216
    dw $0000  ;217
    dw $0000  ;218
    dw $0000  ;219
    dw $0000  ;220
    dw $0000  ;221
    dw $0000  ;222
    dw $0000  ;223
    dw $0000  ;224
    dw $0000  ;225
    dw $0000  ;226
    dw $0000  ;227
    dw $0000  ;228
    dw $0000  ;229
    dw $0000  ;230
    dw $0000  ;231 
    dw $0000  ;232
    dw $0000  ;233
    dw $0000  ;234
    dw $0000  ;235
    dw $0000  ;236
    dw $0000  ;237 
    dw $0000  ;238
    dw $0000  ;239
    dw $0000  ;240
    dw $0000  ;241
    dw $0000  ;242
    dw $0000  ;243
    dw $0000  ;244
    dw $0000  ;245
    dw $0000  ;246
    dw $0000  ;247
    dw $0000  ;248
    dw $0000  ;249
    dw $0000  ;250
    dw $0000  ;251
    dw $0000  ;252
    dw $0000  ;253
    dw $0000  ;254
    dw $0000  ;255
    dw $0000  ;256
    dw $0000  ;257
    dw $0000  ;258
    dw $0000  ;259
    dw $0000  ;260
    dw $0000  ;261
    dw $0000  ;262
    dw $0000  ;263
    dw $0000  ;264
    dw $0000  ;265
    dw $0000  ;266
    dw $0000  ;267
    dw $0000  ;268
    dw $0000  ;269
    dw $0000  ;270
    dw $0000  ;271
    dw $0000  ;272
    dw $0000  ;273
    dw $0000  ;274
    dw $0000  ;275
    dw $0000  ;276
    dw $0000  ;277
    dw $0000  ;278
    dw $0000  ;279
    dw $0000  ;280
    dw $0000  ;281
    dw $0000  ;282
    dw $0000  ;283
    dw $0000  ;284
    dw $0000  ;285
    dw $0000  ;286
    dw $0000  ;287
    dw $0000  ;288
    dw $0000  ;289
    dw $0000  ;290 
    dw $0000  ;291
    dw $0000  ;292
    dw $0000  ;293 
    dw $0000  ;294
    dw $0000  ;295
    dw $0000  ;296 
    dw $0000  ;297
    dw $0000  ;298
    dw $0000  ;299
    dw $0000  ;300
    dw $0000  ;301
    dw $0000  ;302
    dw $0000  ;303
    dw $0000  ;304
    dw $0000  ;305
    dw $0000  ;306
    dw $0000  ;307
    dw $0000  ;308
    dw $0000  ;309
    dw $0000  ;310
    dw $0000  ;311
    dw $0000  ;312
    dw $0000  ;313
    dw $0000  ;314 
    dw $0000  ;315
    dw $0000  ;316
    dw $0000  ;317
    dw $0000  ;318 
    dw $0000  ;319
    dw $0000  ;320 
    dw $0000  ;321
    dw $0000  ;322
    dw $0000  ;323
    dw $0000  ;324
    dw $0000  ;325
    dw $0000  ;326
    dw $0000  ;327
    dw $0000  ;328
    dw $0000  ;329
    dw $0000  ;330
    dw $0000  ;331
    dw $0000  ;332
    dw $0000  ;333
    dw $0001  ;334 T
    dw $0002  ;335 I (assuming this is your second tile)
    dw $0003  ;336 T
    dw $0004  ;337 L
    dw $0005  ;338 E (assuming these are your tiles)
    dw $0000  ;1
    dw $0000  ;2
    dw $0000  ;3
    dw $0000  ;4
    dw $0000  ;5
    dw $0000  ;6
    dw $0000  ;7
    dw $0000  ;8
    dw $0000  ;9
    dw $0000  ;10
    dw $0000  ;11
    dw $0000  ;12
    dw $0000  ;13
    dw $0000  ;14
    dw $0000  ;15
    dw $0000  ;16
    dw $0000  ;17
    dw $0000  ;18
    dw $0000  ;19
    dw $0000  ;20
    dw $0000  ;21
    dw $0000  ;22
    dw $0000  ;23
    dw $0000  ;24
    dw $0000  ;25
    dw $0000  ;26
    dw $0000  ;27
    dw $0000  ;28
    dw $0000  ;29
    dw $0000  ;30
    dw $0000  ;31
    dw $0000  ;32
    dw $0000  ;33
    dw $0000  ;34
    dw $0000  ;35
    dw $0000  ;36
    dw $0000  ;37
    dw $0000  ;38
    dw $0000  ;39
    dw $0000  ;40
    dw $0000  ;41
    dw $0000  ;42
    dw $0000  ;43
    dw $0000  ;44
    dw $0000  ;45
    dw $0000  ;46
    dw $0000  ;47
    dw $0000  ;48
    dw $0000  ;49
    dw $0000  ; 50
    dw $0000  ;51
    dw $0000  ;52
    dw $0000  ;53
    dw $0000  ;54
    dw $0000  ;55
    dw $0000  ;56
    dw $0000  ;57
    dw $0000  ;58
    dw $0000  ;59
    dw $0000  ;60
    dw $0000  ;61
    dw $0000  ;62
    dw $0000  ;63
    dw $0000  ;64
    dw $0000  ;65
    dw $0000  ;66
    dw $0000  ;67
    dw $0000  ;68
    dw $0000  ;69
    dw $0000  ;70
    dw $0000  ;71
    dw $0000  ;72
    dw $0000  ;73
    dw $0000  ;74
    dw $0000  ;75
    dw $0000  ;76
    dw $0000  ;77
    dw $0000  ;78
    dw $0000  ;79
    dw $0000  ;80
    dw $0000  ;81
    dw $0000  ;82
    dw $0000  ;83
    dw $0000  ;84
    dw $0000  ;85
    dw $0000  ;86
    dw $0000  ;87
    dw $0000  ;88
    dw $0000  ;89
    dw $0000  ;90
    dw $0000  ;91
    dw $0000  ;92
    dw $0000  ;93
    dw $0000  ;94
    dw $0000  ;95
    dw $0000  ;96
    dw $0000  ;97
    dw $0000  ;98
    dw $0000  ;99
    dw $0000  ;100
    dw $0000  ;101
    dw $0000  ;102
    dw $0000  ;103 
    dw $0000  ;104
    dw $0000  ;105
    dw $0000  ;106
    dw $0000  ;107
    dw $0000  ;108
    dw $0000  ;109
    dw $0000  ;110
    dw $0000  ;111
    dw $0000  ;112
    dw $0000  ;113
    dw $0000  ;114
    dw $0000  ;115
    dw $0000  ;116
    dw $0000  ;117
    dw $0000  ;118
    dw $0000  ;119
    dw $0000  ;120
    dw $0000  ;121
    dw $0000  ;122
    dw $0000  ;123
    dw $0000  ;124
    dw $0000  ;125
    dw $0000  ;126
    dw $0000  ;127
    dw $0000  ;128
    dw $0000  ;129
    dw $0000  ;130
    dw $0000  ;131
    dw $0000  ;132
    dw $0000  ;133
    dw $0000  ;134
    dw $0000  ;135
    dw $0000  ;136
    dw $0000  ;137
    dw $0000  ;138
    dw $0000  ;139
    dw $0000  ;140
    dw $0000  ;141
    dw $0000  ;142
    dw $0000  ;143
    dw $0000  ;144
    dw $0000  ;145
    dw $0000  ;146
    dw $0000  ;147
    dw $0000  ;148
    dw $0000  ;149
    dw $0000  ;150
    dw $0000  ;151
    dw $0000  ;152
    dw $0000  ;153
    dw $0000  ;154
    dw $0000  ;155
    dw $0000  ;156
    dw $0000  ;157
    dw $0000  ;158
    dw $0000  ;159
    dw $0000  ;160
    dw $0000  ;161
    dw $0000  ;162
    dw $0000  ;163
    dw $0000  ;164
    dw $0000  ;165
    dw $0000  ;166
    dw $0000  ;167
    dw $0000  ;168
    dw $0000  ;169
    dw $0000  ;170
    dw $0000  ;171
    dw $0000  ;172
    dw $0000  ;173
    dw $0000  ;174
    dw $0000  ;175
    dw $0000  ;176
    dw $0000  ;177
    dw $0000  ;178
    dw $0000  ;179
    dw $0000  ;180
    dw $0000  ;181
    dw $0000  ;182
    dw $0000  ;183
    dw $0000  ;184
    dw $0000  ;185
    dw $0000  ;186
    dw $0000  ;187
    dw $0000  ;188
    dw $0000  ;189
    dw $0000  ;190
    dw $0000  ;191
    dw $0000  ;192
    dw $0000  ;193
    dw $0000  ;194
    dw $0000  ;195
    dw $0000  ;196
    dw $0000  ;197
    dw $0000  ;198
    dw $0000  ;199
    dw $0000  ;   200
    dw $0000  ;201
    dw $0000  ;202
    dw $0000  ;203
    dw $0000  ;204
    dw $0000  ;205
    dw $0000  ;206
    dw $0000  ;207
    dw $0000  ;208
    dw $0000  ;209
    dw $0000  ;210   
    dw $0000  ;211
    dw $0000  ;212
    dw $0000  ;213
    dw $0000  ;214
    dw $0000  ;215
    dw $0000  ;216
    dw $0000  ;217
    dw $0000  ;218
    dw $0000  ;219
    dw $0000  ;220
    dw $0000  ;221
    dw $0000  ;222
    dw $0000  ;223
    dw $0000  ;224
    dw $0000  ;225
    dw $0000  ;226
    dw $0000  ;227
    dw $0000  ;228
    dw $0000  ;229
    dw $0000  ;230
    dw $0000  ;231 
    dw $0000  ;232
    dw $0000  ;233
    dw $0000  ;234
    dw $0000  ;235
    dw $0000  ;236
    dw $0000  ;237 
    dw $0000  ;238
    dw $0000  ;239
    dw $0000  ;240
    dw $0000  ;241
    dw $0000  ;242
    dw $0000  ;243
    dw $0000  ;244
    dw $0000  ;245
    dw $0000  ;246
    dw $0000  ;247
    dw $0000  ;248
    dw $0000  ;249
    dw $0000  ;250
    dw $0000  ;251
    dw $0000  ;252
    dw $0000  ;253
    dw $0000  ;254
    dw $0000  ;255
    dw $0000  ;256
    dw $0000  ;257
    dw $0000  ;258
    dw $0000  ;259
    dw $0000  ;260
    dw $0000  ;261
    dw $0000  ;262
    dw $0000  ;263
    dw $0000  ;264
    dw $0000  ;265
    dw $0000  ;266
    dw $0000  ;267
    dw $0000  ;268
    dw $0000  ;269
    dw $0000  ;270
    dw $0000  ;271
    dw $0000  ;272
    dw $0000  ;273
    dw $0000  ;274
    dw $0000  ;275
    dw $0000  ;276
    dw $0000  ;277
    dw $0000  ;278
    dw $0000  ;279
    dw $0000  ;280
    dw $0000  ;281
    dw $0000  ;282
    dw $0000  ;283
    dw $0000  ;284
    dw $0000  ;285
    dw $0000  ;286
    dw $0000  ;287
    dw $0000  ;288
    dw $0000  ;289
    dw $0000  ;290 
    dw $0000  ;291
    dw $0000  ;292
    dw $0000  ;293 
    dw $0000  ;294
    dw $0000  ;295
    dw $0000  ;296 
    dw $0000  ;297
    dw $0000  ;298
    dw $0000  ;299
    dw $0000  ;300
    dw $0000  ;301
    dw $0000  ;302
    dw $0000  ;303
    dw $0000  ;304
    dw $0000  ;305
    dw $0000  ;306
    dw $0000  ;307
    dw $0000  ;308
    dw $0000  ;309
    dw $0000  ;310
    dw $0000  ;311
    dw $0000  ;312
    dw $0000  ;313
    dw $0000  ;314 
    dw $0000  ;315
    dw $0000  ;316
    dw $0000  ;317
    dw $0000  ;318 
    dw $0000  ;319
    dw $0000  ;320 
    dw $0000  ;321
    dw $0000  ;322
    dw $0000  ;323
    dw $0000  ;324
    dw $0000  ;325
    dw $0000  ;326
    dw $0000  ;327
    dw $0000  ;328
    dw $0000  ;329
    dw $0000  ;330
    dw $0000  ;331
    dw $0000  ;332
    dw $0000  ;333  second 333 666
    dw $0000  ;1   
    dw $0000  ;2
    dw $0000  ;3
    dw $0000  ;4
    dw $0000  ;5
    dw $0000  ;6
    dw $0000  ;7
    dw $0000  ;8
    dw $0000  ;9
    dw $0000  ;10
    dw $0000  ;11
    dw $0000  ;12
    dw $0000  ;13
    dw $0000  ;14
    dw $0000  ;15
    dw $0000  ;16
    dw $0000  ;17
    dw $0000  ;18
    dw $0000  ;19
    dw $0000  ;20
    dw $0000  ;21
    dw $0000  ;22
    dw $0000  ;23
    dw $0000  ;24
    dw $0000  ;25
    dw $0000  ;26
    dw $0000  ;27
    dw $0000  ;28
    dw $0000  ;29
    dw $0000  ;30
    dw $0000  ;31
    dw $0000  ;32
    dw $0000  ;33
    dw $0000  ;34
    dw $0000  ;35
    dw $0000  ;36
    dw $0000  ;37
    dw $0000  ;38
    dw $0000  ;39
    dw $0000  ;40
    dw $0000  ;41
    dw $0000  ;42
    dw $0000  ;43
    dw $0000  ;44
    dw $0000  ;45
    dw $0000  ;46
    dw $0000  ;47
    dw $0000  ;48
    dw $0000  ;49
    dw $0000  ; 50
    dw $0000  ;51
    dw $0000  ;52
    dw $0000  ;53
    dw $0000  ;54
    dw $0000  ;55
    dw $0000  ;56
    dw $0000  ;57
    dw $0000  ;58
    dw $0000  ;59
    dw $0000  ;60
    dw $0000  ;61
    dw $0000  ;62
    dw $0000  ;63
    dw $0000  ;64
    dw $0000  ;65
    dw $0000  ;66
    dw $0000  ;67
    dw $0000  ;68
    dw $0000  ;69
    dw $0000  ;70
    dw $0000  ;71
    dw $0000  ; 72
    dw $0000  ;73
    dw $0000  ;74
    dw $0000  ;75
    dw $0000  ;76
    dw $0000  ;77
    dw $0000  ;78
    dw $0000  ;79
    dw $0000  ;80
    dw $0000  ;81
    dw $0000  ;82
    dw $0000  ;83
    dw $0000  ;84
    dw $0000  ;85
    dw $0000  ;86
    dw $0000  ;87
    dw $0000  ;88
    dw $0000  ;89
    dw $0000  ;90
    dw $0000  ;91
    dw $0000  ;92
    dw $0000  ;93
    dw $0000  ;94
    dw $0000  ;95
    dw $0000  ;96
    dw $0000  ;97
    dw $0000  ;98
    dw $0000  ;99
    dw $0000  ;100
    dw $0000  ;101
    dw $0000  ;102
    dw $0000  ;103 
    dw $0000  ;104
    dw $0000  ;105
    dw $0000  ;106
    dw $0000  ;107
    dw $0000  ;108
    dw $0000  ;109
    dw $0000  ;110
    dw $0000  ;111
    dw $0000  ;112
    dw $0000  ;113
    dw $0000  ;114
    dw $0000  ;115
    dw $0000  ;116
    dw $0000  ;117
    dw $0000  ;118
    dw $0000  ;119
    dw $0000  ;120
    dw $0000  ;121
    dw $0000  ;122
    dw $0000  ;123
    dw $0000  ;124
    dw $0000  ;125
    dw $0000  ;126
    dw $0000  ;127
    dw $0000  ;128
    dw $0000  ;129
    dw $0000  ;130
    dw $0000  ;131
    dw $0000  ;132
    dw $0000  ;133
    dw $0000  ;134
    dw $0000  ;135
    dw $0000  ;136
    dw $0000  ;137
    dw $0000  ;138
    dw $0000  ;139
    dw $0000  ;140
    dw $0000  ;141
    dw $0000  ;142
    dw $0000  ;143
    dw $0000  ;144
    dw $0000  ;145
    dw $0000  ;146
    dw $0000  ;147
    dw $0000  ;148
    dw $0000  ;149
    dw $0000  ;150
    dw $0000  ;151
    dw $0000  ;152
    dw $0000  ;153
    dw $0000  ;154
    dw $0000  ;155
    dw $0000  ;156
    dw $0000  ;157
    dw $0000  ;158
    dw $0000  ;159
    dw $0000  ;160
    dw $0000  ;161
    dw $0000  ;162
    dw $0000  ;163
    dw $0000  ;164
    dw $0000  ;165
    dw $0000  ;166
    dw $0000  ;167
    dw $0000  ;168
    dw $0000  ;169
    dw $0000  ;170
    dw $0000  ;171
    dw $0000  ;172
    dw $0000  ;173
    dw $0000  ;174
    dw $0000  ;175
    dw $0000  ;176
    dw $0000  ;177
    dw $0000  ;178
    dw $0000  ;179
    dw $0000  ;180
    dw $0000  ;181
    dw $0000  ;182
    dw $0000  ;183
    dw $0000  ;184
    dw $0000  ;185
    dw $0000  ;186
    dw $0000  ;187
    dw $0000  ;188
    dw $0000  ;189
    dw $0000  ;190
    dw $0000  ;191
    dw $0000  ;192
    dw $0000  ;193
    dw $0000  ;194
    dw $0000  ;195
    dw $0000  ;196
    dw $0000  ;197
    dw $0000  ;198
    dw $0000  ;199
    dw $0000  ;   200
    dw $0000  ;201
    dw $0000  ;202
    dw $0000  ;203
    dw $0000  ;204
    dw $0000  ;205
    dw $0000  ;206
    dw $0000  ;207
    dw $0000  ;208
    dw $0000  ;209
    dw $0000  ;210   
    dw $0000  ;211
    dw $0000  ;212
    dw $0000  ;213
    dw $0000  ;214
    dw $0000  ;215
    dw $0000  ;216
    dw $0000  ;217
    dw $0000  ;218
    dw $0000  ;219
    dw $0000  ;220
    dw $0000  ;221
    dw $0000  ;222
    dw $0000  ;223
    dw $0000  ;224
    dw $0000  ;225
    dw $0000  ;226
    dw $0000  ;227
    dw $0000  ;228
    dw $0000  ;229
    dw $0000  ;230
    dw $0000  ;231 
    dw $0000  ;232
    dw $0000  ;233
    dw $0000  ;234
    dw $0000  ;235
    dw $0000  ;236
    dw $0000  ;237 
    dw $0000  ;238
    dw $0000  ;239
    dw $0000  ;240
    dw $0000  ;241
    dw $0000  ;242
    dw $0000  ;243
    dw $0000  ;244
    dw $0000  ;245
    dw $0000  ;246
    dw $0000  ;247
    dw $0000  ;248
    dw $0000  ;249
    dw $0000  ;250
    dw $0000  ;251
    dw $0000  ;252
    dw $0000  ;253
    dw $0000  ;254
    dw $0000  ;255
    dw $0000  ;256
    dw $0000  ;257
    dw $0000  ;258
    dw $0000  ;259
    dw $0000  ;260
    dw $0000  ;261
    dw $0000  ;262
    dw $0000  ;263
    dw $0000  ;264
    dw $0000  ;265
    dw $0000  ;266
    dw $0000  ;267
    dw $0000  ;268
    dw $0000  ;269
    dw $0000  ;270
    dw $0000  ;271
    dw $0000  ;272
    dw $0000  ;273
    dw $0000  ;274
    dw $0000  ;275
    dw $0000  ;276
    dw $0000  ;277
    dw $0000  ;278
    dw $0000  ;279
    dw $0000  ;280
    dw $0000  ;281
    dw $0000  ;282
    dw $0000  ;283
    dw $0000  ;284
    dw $0000  ;285
    dw $0000  ;286
    dw $0000  ;287
    dw $0000  ;288
    dw $0000  ;289
    dw $0000  ;290 
    dw $0000  ;291
    dw $0000  ;292
    dw $0000  ;293 
    dw $0000  ;294
    dw $0000  ;295
    dw $0000  ;296 
    dw $0000  ;297
    dw $0000  ;298
    dw $0000  ;299
    dw $0000  ;300
    dw $0000  ;301
    dw $0000  ;302
    dw $0000  ;303
    dw $0000  ;304
    dw $0000  ;305
    dw $0000  ;306
    dw $0000  ;307
    dw $0000  ;308
    dw $0000  ;309
    dw $0000  ;310
    dw $0000  ;311
    dw $0000  ;312
    dw $0000  ;313
    dw $0000  ;314 
    dw $0000  ;315
    dw $0000  ;316
    dw $0000  ;317
    dw $0000  ;318 
    dw $0000  ;319
    dw $0000  ;320 
    dw $0000  ;321
    dw $0000  ;322
    dw $0000  ;323
    dw $0000  ;324
    dw $0000  ;325
    dw $0000  ;326
    dw $0000  ;327
    dw $0000  ;328
    dw $0000  ;329
    dw $0000  ;330
    dw $0000  ;331
    dw $0000  ;332
    dw $0000  ;333 third 333 999
    dw $0000  ;1000    
    dw $0000  ;1001
    dw $0000  ;1002
    dw $0000  ;1003
    dw $0000  ;1004
    dw $0000  ;1005
    dw $0000  ;1006
    dw $0000  ;1007
    dw $0000  ;1008
    dw $0000  ;1009
    dw $0000  ;1010
    dw $0000  ;1011
    dw $0000  ;1012
    dw $0000  ;1013
    dw $0000  ;1014
    dw $0000  ;1015
    dw $0000  ;1016
    dw $0000  ;1017
    dw $0000  ;1018
    dw $0000  ;1019 offset for 1019 for title inserted
   ;dw $0000  ;1020
   ;dw $0000  ;1021
   ;dw $0000  ;1022
   ;dw $0000  ;1023
   ;dw $0000  ;1024 

; Define the end of the code
org $7FC0
    



