;
;  spriteDemo
;  A demonstration of the GraphicsScientist sprite tool
;
;  Created by Quinn Dunki on May 19, 2024
;

; Zero page allocation
ENDMARK			=	$00			; End marker for various iteration jobs
RENDERPOS_X		=	$01			; Current X render position (8 bit only)
RENDERPOS_Y		=	$02			; Current Y render position
RENDER_BYTEX	=	$03			; Current X render byte
SPRITEPTR_L		=	$04			; Current rendering sprite pointer (low byte)
SPRITEPTR_H		=	$05			; Current rendering sprite pointer (high byte)
RENDER_COLEND	=	$06			; Current column end (in bytes) while rendering
RENDER_ROWEND	=	$07			; Current row endwhile rendering
PIXELPTR_L		=	$08			; Current pointer to pixel data (low byte)
PIXELPTR_H		=	$09			; Current pointer to pixel data (high byte)
DIV7TABLE_L		=	$0a			; Pointer to division-by-7 table for current sprite render
DIV7TABLE_H		=	$0b			; Pointer to division-by-7 table for current sprite render


; Softswitches
TEXT = $c050
TEXT2 = $c051
PAGE0 = $c054
PAGE1 = $c055
HIRES1 = $c057
HIRES2 = $c058

; ROM entry points
ROMWAIT = $fca8



.segment "STARTUP"
.segment "LOCODE"


.org $0800
main:

	; Clear both hi-res pages
	jsr enableHiRes
	jsr erasePage

	; Demonstrate image blitter
	jsr spriteResolution140
	lda #00
	sta RENDERPOS_X
	lda #80
	sta RENDERPOS_Y
	lda #<helloWorld
	sta SPRITEPTR_L
	lda #>helloWorld
	sta SPRITEPTR_H
	jsr blitImage

	; Demonstrate sprite blitter
	jsr spriteResolution280
	lda #0
	sta loopCounter

runLoop:
	lda loopCounter			; Find the animation frame
	and #$03
	asl
	tay
	lda animation,y
	sta SPRITEPTR_L
	lda animation+1,y
	sta SPRITEPTR_H

	lda loopCounter			; Draw the sprite
	sta RENDERPOS_X
	lda #0
	sta RENDERPOS_Y
	jsr blitSprite

	lda #$80				; Wait
	jsr ROMWAIT

	;jsr eraseSprite			; Erase the sprite

	ldx loopCounter			; Next frame
	inx
	bne loopContinue
	ldx #0
loopContinue:
	stx loopCounter
	jmp runLoop
	

loopCounter:
	.byte $00

animation:
	.addr	runFrame0
	.addr	runFrame1
	.addr	runFrame2
	.addr	runFrame3


; Enable Hi-Res graphics
;
enableHiRes:
	sta TEXT
	sta HIRES1
	sta HIRES2
	sta	PAGE0
	rts



; Erase hi-res page 0
;
erasePage:
	ldx #$20
	txa
	clc
	adc #$20
	sta ENDMARK

	lda #0

erasePageOuter:
	stx erasePageInner+2
	ldy #$00

erasePageInner:
	sta $2000,y		; Upper byte of address is self-modified
	iny
	bne erasePageInner
	inx
	cpx ENDMARK
	bne erasePageOuter
	rts



; Set sprite resolution to 140
;
spriteResolution140:
	lda #<hiResRowsDiv7_2
	sta DIV7TABLE_L
	lda #>hiResRowsDiv7_2
	sta DIV7TABLE_H
	rts


; Set sprite resolution to 280
;
spriteResolution280:
	lda #<hiResRowsDiv7
	sta DIV7TABLE_L
	lda #>hiResRowsDiv7
	sta DIV7TABLE_H
	rts



; Blit a sprite
; Renders at (RENDERPOS_X,RENDERPOS_Y) with sprite in SPRITEPTR
; Trashes RENDERPOS_Y
;
blitSprite:
	ldy RENDERPOS_X			; Calculate horizontal byte to render on
	lda (DIV7TABLE_L),y
	sta RENDER_BYTEX

	ldy #0					; Set horizontal end marker
	clc
	adc (SPRITEPTR_L),y
	sta RENDER_COLEND
	
	iny
	lda RENDERPOS_Y			; Set vertical end marker
	clc
	adc (SPRITEPTR_L),y
	sta RENDER_ROWEND
	
	ldy RENDERPOS_X			; Find pointer to our shifted sprite
	lda hiResRowsMod7,y
	tay
	iny						; Skip dimensions to get to jump table
	iny
	lda (SPRITEPTR_L),y
	sta PIXELPTR_L
	iny
	lda (SPRITEPTR_L),y
	sta PIXELPTR_H

	ldy #0

blitSpriteRowLoop:
	ldx	RENDERPOS_Y
	lda hiResRowsHi,x		; Prepare next row
	sta blitSpriteStore+2
	lda hiResRowsLo,x
	sta blitSpriteStore+1

	ldx RENDER_BYTEX

blitSpriteColLoop:
	lda	(PIXELPTR_L),y		; Copy pixels from image data to screen
blitSpriteStore:
	sta $2000,x				; Self-modifying code target
	iny
	inx
	cpx RENDER_COLEND
	bne blitSpriteColLoop

	ldx RENDERPOS_Y			; See if we're done all the rows
	inx
	cpx RENDER_ROWEND
	beq blitSpriteDone
	stx RENDERPOS_Y
	jmp blitSpriteRowLoop

blitSpriteDone:
	rts



; Blits a simple image
; Renders at (RENDERPOS_X,RENDERPOS_Y) with image in SPRITEPTR
; Trashes RENDERPOS_Y
;
blitImage:
	ldy RENDERPOS_X			; Calculate horizontal byte to render on
	lda (DIV7TABLE_L),y
	sta RENDER_BYTEX

	ldy #0					; Set horizontal end marker
	clc
	adc (SPRITEPTR_L),y
	sta RENDER_COLEND
	
	iny
	lda RENDERPOS_Y			; Set vertical end marker
	clc
	adc (SPRITEPTR_L),y
	sta RENDER_ROWEND
	
	ldy #2					; Skip dimensions to get to pixels

blitImageRowLoop:
	ldx	RENDERPOS_Y
	lda hiResRowsHi,x		; Prepare next row
	sta blitImageStore+2
	lda hiResRowsLo,x
	sta blitImageStore+1

	ldx RENDER_BYTEX

blitImageColLoop:
	lda	(SPRITEPTR_L),y		; Copy pixels from image data to screen
blitImageStore:
	sta $2000,x				; Self-modifying code target
	iny
	inx
	cpx RENDER_COLEND
	bne blitImageColLoop

	ldx RENDERPOS_Y			; See if we're done all the rows
	inx
	cpx RENDER_ROWEND
	beq blitImageDone
	stx RENDERPOS_Y
	jmp blitImageRowLoop

blitImageDone:
	rts


; Erase a rectangle
; Renders black rectangle at (RENDER_BYTEX,RENDERPOS_Y)->(RENDER_COLEND,RENDER_ROWEND)
; Trashes RENDERPOS_Y
;
eraseRect:
	ldx	RENDERPOS_Y
	lda hiResRowsHi,x		; Prepare next row
	sta eraseRectStore+2
	lda hiResRowsLo,x
	sta eraseRectStore+1

	ldx RENDER_BYTEX
	lda	#0
	
eraseRectStore:
	sta $2000,x				; Self-modifying code target
	inx
	cpx RENDER_COLEND
	bne eraseRectStore

	ldx RENDERPOS_Y			; See if we're done all the rows
	inx
	cpx RENDER_ROWEND
	beq eraseRectDone
	stx RENDERPOS_Y
	jmp eraseRect

eraseRectDone:
	rts




;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Sprite data generated by GraphicsScientist
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


runFrame0:
	.byte $02,$0d		; Width in bytes, Height
	.addr runFrame0_Shift0
	.addr runFrame0_Shift1
	.addr runFrame0_Shift2
	.addr runFrame0_Shift3
	.addr runFrame0_Shift4
	.addr runFrame0_Shift5
	.addr runFrame0_Shift6

runFrame0_Shift0:
	.byte	$40,$00,$60,$01,$60,$01,$78,$00,$64,$01,$30,$02,$30,$00,$70,$00,$5c,$01,$00,$01,$00,$01,$00,$00,$00,$00
runFrame0_Shift1:
	.byte	$00,$01,$40,$03,$40,$03,$70,$01,$48,$03,$60,$04,$60,$00,$60,$01,$38,$03,$00,$02,$00,$02,$00,$00,$00,$00
runFrame0_Shift2:
	.byte	$00,$02,$00,$07,$00,$07,$60,$03,$10,$07,$40,$09,$40,$01,$40,$03,$70,$06,$00,$04,$00,$04,$00,$00,$00,$00
runFrame0_Shift3:
	.byte	$00,$04,$00,$0e,$00,$0e,$40,$07,$20,$0e,$00,$13,$00,$03,$00,$07,$60,$0d,$00,$08,$00,$08,$00,$00,$00,$00
runFrame0_Shift4:
	.byte	$00,$08,$00,$1c,$00,$1c,$00,$0f,$40,$1c,$00,$26,$00,$06,$00,$0e,$40,$1b,$00,$10,$00,$10,$00,$00,$00,$00
runFrame0_Shift5:
	.byte	$00,$10,$00,$38,$00,$38,$00,$1e,$00,$39,$00,$4c,$00,$0c,$00,$1c,$00,$37,$00,$20,$00,$20,$00,$00,$00,$00
runFrame0_Shift6:
	.byte	$00,$20,$00,$70,$00,$70,$00,$3c,$00,$72,$00,$18,$00,$18,$00,$38,$00,$6e,$00,$40,$00,$40,$00,$00,$00,$00
runFrame1:
	.byte $02,$0d		; Width in bytes, Height
	.addr runFrame1_Shift0
	.addr runFrame1_Shift1
	.addr runFrame1_Shift2
	.addr runFrame1_Shift3
	.addr runFrame1_Shift4
	.addr runFrame1_Shift5
	.addr runFrame1_Shift6

runFrame1_Shift0:
	.byte	$20,$00,$70,$00,$70,$00,$30,$00,$38,$00,$3c,$00,$58,$01,$38,$00,$38,$00,$3c,$00,$30,$00,$00,$00,$00,$00
runFrame1_Shift1:
	.byte	$40,$00,$60,$01,$60,$01,$60,$00,$70,$00,$78,$00,$30,$03,$70,$00,$70,$00,$78,$00,$60,$00,$00,$00,$00,$00
runFrame1_Shift2:
	.byte	$00,$01,$40,$03,$40,$03,$40,$01,$60,$01,$70,$01,$60,$06,$60,$01,$60,$01,$70,$01,$40,$01,$00,$00,$00,$00
runFrame1_Shift3:
	.byte	$00,$02,$00,$07,$00,$07,$00,$03,$40,$03,$60,$03,$40,$0d,$40,$03,$40,$03,$60,$03,$00,$03,$00,$00,$00,$00
runFrame1_Shift4:
	.byte	$00,$04,$00,$0e,$00,$0e,$00,$06,$00,$07,$40,$07,$00,$1b,$00,$07,$00,$07,$40,$07,$00,$06,$00,$00,$00,$00
runFrame1_Shift5:
	.byte	$00,$08,$00,$1c,$00,$1c,$00,$0c,$00,$0e,$00,$0f,$00,$36,$00,$0e,$00,$0e,$00,$0f,$00,$0c,$00,$00,$00,$00
runFrame1_Shift6:
	.byte	$00,$10,$00,$38,$00,$38,$00,$18,$00,$1c,$00,$1e,$00,$6c,$00,$1c,$00,$1c,$00,$1e,$00,$18,$00,$00,$00,$00
runFrame2:
	.byte $02,$0d		; Width in bytes, Height
	.addr runFrame2_Shift0
	.addr runFrame2_Shift1
	.addr runFrame2_Shift2
	.addr runFrame2_Shift3
	.addr runFrame2_Shift4
	.addr runFrame2_Shift5
	.addr runFrame2_Shift6

runFrame2_Shift0:
	.byte	$20,$00,$70,$00,$70,$00,$30,$00,$38,$00,$7c,$00,$3c,$03,$78,$00,$78,$00,$3c,$00,$18,$00,$00,$00,$00,$00
runFrame2_Shift1:
	.byte	$40,$00,$60,$01,$60,$01,$60,$00,$70,$00,$78,$01,$78,$06,$70,$01,$70,$01,$78,$00,$30,$00,$00,$00,$00,$00
runFrame2_Shift2:
	.byte	$00,$01,$40,$03,$40,$03,$40,$01,$60,$01,$70,$03,$70,$0d,$60,$03,$60,$03,$70,$01,$60,$00,$00,$00,$00,$00
runFrame2_Shift3:
	.byte	$00,$02,$00,$07,$00,$07,$00,$03,$40,$03,$60,$07,$60,$1b,$40,$07,$40,$07,$60,$03,$40,$01,$00,$00,$00,$00
runFrame2_Shift4:
	.byte	$00,$04,$00,$0e,$00,$0e,$00,$06,$00,$07,$40,$0f,$40,$37,$00,$0f,$00,$0f,$40,$07,$00,$03,$00,$00,$00,$00
runFrame2_Shift5:
	.byte	$00,$08,$00,$1c,$00,$1c,$00,$0c,$00,$0e,$00,$1f,$00,$6f,$00,$1e,$00,$1e,$00,$0f,$00,$06,$00,$00,$00,$00
runFrame2_Shift6:
	.byte	$00,$10,$00,$38,$00,$38,$00,$18,$00,$1c,$00,$3e,$00,$5e,$00,$3c,$00,$3c,$00,$1e,$00,$0c,$00,$00,$00,$00
runFrame3:
	.byte $02,$0d		; Width in bytes, Height
	.addr runFrame3_Shift0
	.addr runFrame3_Shift1
	.addr runFrame3_Shift2
	.addr runFrame3_Shift3
	.addr runFrame3_Shift4
	.addr runFrame3_Shift5
	.addr runFrame3_Shift6

runFrame3_Shift0:
	.byte	$20,$00,$70,$00,$70,$00,$3e,$00,$70,$01,$18,$00,$18,$00,$7c,$00,$6e,$00,$46,$00,$00,$00,$00,$00,$00,$00
runFrame3_Shift1:
	.byte	$40,$00,$60,$01,$60,$01,$7c,$00,$60,$03,$30,$00,$30,$00,$78,$01,$5c,$01,$0c,$01,$00,$00,$00,$00,$00,$00
runFrame3_Shift2:
	.byte	$00,$01,$40,$03,$40,$03,$78,$01,$40,$07,$60,$00,$60,$00,$70,$03,$38,$03,$18,$02,$00,$00,$00,$00,$00,$00
runFrame3_Shift3:
	.byte	$00,$02,$00,$07,$00,$07,$70,$03,$00,$0f,$40,$01,$40,$01,$60,$07,$70,$06,$30,$04,$00,$00,$00,$00,$00,$00
runFrame3_Shift4:
	.byte	$00,$04,$00,$0e,$00,$0e,$60,$07,$00,$1e,$00,$03,$00,$03,$40,$0f,$60,$0d,$60,$08,$00,$00,$00,$00,$00,$00
runFrame3_Shift5:
	.byte	$00,$08,$00,$1c,$00,$1c,$40,$0f,$00,$3c,$00,$06,$00,$06,$00,$1f,$40,$1b,$40,$11,$00,$00,$00,$00,$00,$00
runFrame3_Shift6:
	.byte	$00,$10,$00,$38,$00,$38,$00,$1f,$00,$78,$00,$0c,$00,$0c,$00,$3e,$00,$37,$00,$23,$00,$00,$00,$00,$00,$00

helloWorld:
	.byte $19,$0a		; Width in bytes, Height
	.byte	$15,$00,$15,$00,$00,$00,$a8,$29,$01,$00,$00,$00,$00,$15,$28,$01,$2a,$00,$00,$00,$00,$a0,$85,$00,$28,$15,$00,$15,$00,$00,$00,$a8
	.byte	$29,$01,$00,$00,$00,$00,$15,$28,$05,$0a,$00,$00,$00,$00,$a0,$85,$00,$28,$15,$00,$15,$00,$00,$00,$a8,$29,$01,$00,$00,$00,$00,$15
	.byte	$28,$45,$0a,$00,$00,$00,$00,$a0,$85,$00,$28,$55,$2a,$15,$50,$2a,$01,$a8,$29,$41,$aa,$85,$00,$00,$14,$2a,$45,$0a,$20,$55,$00,$aa
	.byte	$a5,$85,$55,$2a,$55,$2a,$15,$54,$20,$05,$a8,$29,$d1,$aa,$95,$00,$00,$54,$2a,$45,$0a,$28,$51,$02,$aa,$a5,$85,$55,$2a,$55,$2a,$15
	.byte	$54,$20,$05,$a8,$29,$d1,$82,$95,$00,$00,$54,$0a,$55,$0a,$2a,$40,$0a,$aa,$a0,$85,$05,$28,$15,$00,$15,$54,$2a,$05,$a8,$29,$d1,$82
	.byte	$94,$00,$00,$54,$0a,$54,$02,$2a,$40,$0a,$8a,$a0,$85,$05,$28,$15,$00,$15,$54,$00,$00,$a8,$29,$d1,$82,$95,$00,$00,$54,$0a,$54,$02
	.byte	$2a,$40,$02,$8a,$a0,$85,$05,$2a,$15,$00,$15,$54,$2a,$05,$a8,$29,$41,$aa,$95,$00,$00,$50,$02,$54,$02,$28,$55,$02,$8a,$a0,$85,$55
	.byte	$2a,$15,$00,$15,$50,$2a,$01,$a8,$29,$01,$aa,$85,$00,$00,$50,$02,$54,$02,$20,$55,$00,$8a,$a0,$85,$54,$28




; Lookup tables to linearize video memory. High bytes are for page 0, but EORed with $60 to get page 2
hiResRowsHi:		; High byte of row start
	.byte	$20,$24,$28,$2C,$30,$34,$38,$3C
	.byte	$20,$24,$28,$2C,$30,$34,$38,$3C
	.byte	$21,$25,$29,$2D,$31,$35,$39,$3D
	.byte	$21,$25,$29,$2D,$31,$35,$39,$3D
	.byte	$22,$26,$2A,$2E,$32,$36,$3A,$3E
	.byte	$22,$26,$2A,$2E,$32,$36,$3A,$3E
	.byte	$23,$27,$2B,$2F,$33,$37,$3B,$3F
	.byte	$23,$27,$2B,$2F,$33,$37,$3B,$3F
	.byte	$20,$24,$28,$2C,$30,$34,$38,$3C
	.byte	$20,$24,$28,$2C,$30,$34,$38,$3C
	.byte	$21,$25,$29,$2D,$31,$35,$39,$3D
	.byte	$21,$25,$29,$2D,$31,$35,$39,$3D
	.byte	$22,$26,$2A,$2E,$32,$36,$3A,$3E
	.byte	$22,$26,$2A,$2E,$32,$36,$3A,$3E
	.byte	$23,$27,$2B,$2F,$33,$37,$3B,$3F
	.byte	$23,$27,$2B,$2F,$33,$37,$3B,$3F
	.byte	$20,$24,$28,$2C,$30,$34,$38,$3C
	.byte	$20,$24,$28,$2C,$30,$34,$38,$3C
	.byte	$21,$25,$29,$2D,$31,$35,$39,$3D
	.byte	$21,$25,$29,$2D,$31,$35,$39,$3D
	.byte	$22,$26,$2A,$2E,$32,$36,$3A,$3E
	.byte	$22,$26,$2A,$2E,$32,$36,$3A,$3E
	.byte	$23,$27,$2B,$2F,$33,$37,$3B,$3F
	.byte	$23,$27,$2B,$2F,$33,$37,$3B,$3F

hiResRowsLo:		; Low byte of row start
	.byte	$00,$00,$00,$00,$00,$00,$00,$00
	.byte	$80,$80,$80,$80,$80,$80,$80,$80
	.byte	$00,$00,$00,$00,$00,$00,$00,$00
	.byte	$80,$80,$80,$80,$80,$80,$80,$80
	.byte	$00,$00,$00,$00,$00,$00,$00,$00
	.byte	$80,$80,$80,$80,$80,$80,$80,$80
	.byte	$00,$00,$00,$00,$00,$00,$00,$00
	.byte	$80,$80,$80,$80,$80,$80,$80,$80
	.byte	$28,$28,$28,$28,$28,$28,$28,$28
	.byte	$A8,$A8,$A8,$A8,$A8,$A8,$A8,$A8
	.byte	$28,$28,$28,$28,$28,$28,$28,$28
	.byte	$A8,$A8,$A8,$A8,$A8,$A8,$A8,$A8
	.byte	$28,$28,$28,$28,$28,$28,$28,$28
	.byte	$A8,$A8,$A8,$A8,$A8,$A8,$A8,$A8
	.byte	$28,$28,$28,$28,$28,$28,$28,$28
	.byte	$A8,$A8,$A8,$A8,$A8,$A8,$A8,$A8
	.byte	$50,$50,$50,$50,$50,$50,$50,$50
	.byte	$D0,$D0,$D0,$D0,$D0,$D0,$D0,$D0
	.byte	$50,$50,$50,$50,$50,$50,$50,$50
	.byte	$D0,$D0,$D0,$D0,$D0,$D0,$D0,$D0
	.byte	$50,$50,$50,$50,$50,$50,$50,$50
	.byte	$D0,$D0,$D0,$D0,$D0,$D0,$D0,$D0
	.byte	$50,$50,$50,$50,$50,$50,$50,$50
	.byte	$D0,$D0,$D0,$D0,$D0,$D0,$D0,$D0

hiResRowsDiv7_2:		; Addition to low byte for pixel index (division by 7) (0-140)
	.byte	$00,$00,$00,$00,$00,$00,$00
	.byte	$02,$02,$02,$02,$02,$02,$02
	.byte	$04,$04,$04,$04,$04,$04,$04
	.byte	$06,$06,$06,$06,$06,$06,$06
	.byte	$08,$08,$08,$08,$08,$08,$08
	.byte	$0a,$0a,$0a,$0a,$0a,$0a,$0a
	.byte	$0c,$0c,$0c,$0c,$0c,$0c,$0c
	.byte	$0e,$0e,$0e,$0e,$0e,$0e,$0e
	.byte	$10,$10,$10,$10,$10,$10,$10
	.byte	$12,$12,$12,$12,$12,$12,$12
	.byte	$14,$14,$14,$14,$14,$14,$14
	.byte	$16,$16,$16,$16,$16,$16,$16
	.byte	$18,$18,$18,$18,$18,$18,$18
	.byte	$1a,$1a,$1a,$1a,$1a,$1a,$1a
	.byte	$1c,$1c,$1c,$1c,$1c,$1c,$1c
	.byte	$1e,$1e,$1e,$1e,$1e,$1e,$1e
	.byte	$20,$20,$20,$20,$20,$20,$20
	.byte	$22,$22,$22,$22,$22,$22,$22
	.byte	$24,$24,$24,$24,$24,$24,$24
	.byte	$26,$26,$26,$26,$26,$26,$26

hiResRowsDiv7:		; Addition to low byte for pixel index (division by 7) (0-280)
	.byte	$00,$00,$00,$00,$00,$00,$00
	.byte	$01,$01,$01,$01,$01,$01,$01
	.byte	$02,$02,$02,$02,$02,$02,$02
	.byte	$03,$03,$03,$03,$03,$03,$03
	.byte	$04,$04,$04,$04,$04,$04,$04
	.byte	$05,$05,$05,$05,$05,$05,$05
	.byte	$06,$06,$06,$06,$06,$06,$06
	.byte	$07,$07,$07,$07,$07,$07,$07
	.byte	$08,$08,$08,$08,$08,$08,$08
	.byte	$09,$09,$09,$09,$09,$09,$09
	.byte	$0a,$0a,$0a,$0a,$0a,$0a,$0a
	.byte	$0b,$0b,$0b,$0b,$0b,$0b,$0b
	.byte	$0c,$0c,$0c,$0c,$0c,$0c,$0c
	.byte	$0d,$0d,$0d,$0d,$0d,$0d,$0d
	.byte	$0e,$0e,$0e,$0e,$0e,$0e,$0e
	.byte	$0f,$0f,$0f,$0f,$0f,$0f,$0f
	.byte	$10,$10,$10,$10,$10,$10,$10
	.byte	$11,$11,$11,$11,$11,$11,$11
	.byte	$12,$12,$12,$12,$12,$12,$12
	.byte	$13,$13,$13,$13,$13,$13,$13
	.byte	$14,$14,$14,$14,$14,$14,$14
	.byte	$15,$15,$15,$15,$15,$15,$15
	.byte	$16,$16,$16,$16,$16,$16,$16
	.byte	$17,$17,$17,$17,$17,$17,$17
	.byte	$18,$18,$18,$18,$18,$18,$18
	.byte	$19,$19,$19,$19,$19,$19,$19
	.byte	$1a,$1a,$1a,$1a,$1a,$1a,$1a
	.byte	$1b,$1b,$1b,$1b,$1b,$1b,$1b
	.byte	$1c,$1c,$1c,$1c,$1c,$1c,$1c
	.byte	$1d,$1d,$1d,$1d,$1d,$1d,$1d
	.byte	$1e,$1e,$1e,$1e,$1e,$1e,$1e
	.byte	$1f,$1f,$1f,$1f,$1f,$1f,$1f
	.byte	$20,$20,$20,$20,$20,$20,$20
	.byte	$21,$21,$21,$21,$21,$21,$21
	.byte	$22,$22,$22,$22,$22,$22,$22
	.byte	$23,$23,$23,$23,$23,$23,$23
	.byte	$24,$24,$24,$24,$24,$24,$24
	.byte	$25,$25,$25,$25,$25,$25,$25
	.byte	$26,$26,$26,$26,$26,$26,$26
	.byte	$27,$27,$27,$27,$27,$27,$27

hiResRowsMod7:		; Pointer into sprite shift table for every X position
	.byte $00,$02,$04,$06,$08,$0a,$0c
	.byte $00,$02,$04,$06,$08,$0a,$0c
	.byte $00,$02,$04,$06,$08,$0a,$0c
	.byte $00,$02,$04,$06,$08,$0a,$0c
	.byte $00,$02,$04,$06,$08,$0a,$0c
	.byte $00,$02,$04,$06,$08,$0a,$0c
	.byte $00,$02,$04,$06,$08,$0a,$0c
	.byte $00,$02,$04,$06,$08,$0a,$0c
	.byte $00,$02,$04,$06,$08,$0a,$0c
	.byte $00,$02,$04,$06,$08,$0a,$0c
	.byte $00,$02,$04,$06,$08,$0a,$0c
	.byte $00,$02,$04,$06,$08,$0a,$0c
	.byte $00,$02,$04,$06,$08,$0a,$0c
	.byte $00,$02,$04,$06,$08,$0a,$0c
	.byte $00,$02,$04,$06,$08,$0a,$0c
	.byte $00,$02,$04,$06,$08,$0a,$0c
	.byte $00,$02,$04,$06,$08,$0a,$0c
	.byte $00,$02,$04,$06,$08,$0a,$0c
	.byte $00,$02,$04,$06,$08,$0a,$0c
	.byte $00,$02,$04,$06,$08,$0a,$0c
	.byte $00,$02,$04,$06,$08,$0a,$0c
	.byte $00,$02,$04,$06,$08,$0a,$0c
	.byte $00,$02,$04,$06,$08,$0a,$0c
	.byte $00,$02,$04,$06,$08,$0a,$0c
	.byte $00,$02,$04,$06,$08,$0a,$0c
	.byte $00,$02,$04,$06,$08,$0a,$0c
	.byte $00,$02,$04,$06,$08,$0a,$0c
	.byte $00,$02,$04,$06,$08,$0a,$0c
	.byte $00,$02,$04,$06,$08,$0a,$0c
	.byte $00,$02,$04,$06,$08,$0a,$0c
	.byte $00,$02,$04,$06,$08,$0a,$0c
	.byte $00,$02,$04,$06,$08,$0a,$0c
	.byte $00,$02,$04,$06,$08,$0a,$0c
	.byte $00,$02,$04,$06,$08,$0a,$0c
	.byte $00,$02,$04,$06,$08,$0a,$0c
	.byte $00,$02,$04,$06,$08,$0a,$0c
	.byte $00,$02,$04,$06,$08,$0a,$0c
	.byte $00,$02,$04,$06,$08,$0a,$0c
	.byte $00,$02,$04,$06,$08,$0a,$0c
	.byte $00,$02,$04,$06,$08,$0a,$0c

