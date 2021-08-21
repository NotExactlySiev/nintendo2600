InterruptHandler: subroutine
	nop
	php
        sta IntA
        stx IntX
        sty IntY
        pla
        sta IntP

        
	ldy BlockIndex

        
        lda JINTLO,y
        sta var0
        lda JINTHI,y
        sta var1
        

        lda JNESHI,y
        lsr
        lsr
        lsr
        sta IntrID
        lsr
        bcs .jors
        lsr
        bcs .sync
        ; Conditional Interrupt
        asl
        asl
	sta IntrID
        lda #$e3
        sta IntrID+1
        
        lda IntP
        pha
        lda #0
        ldx JINTREL,y
        plp
        jsr JumpToBranchCheck
        
        ldx #0
        tay
        bpl .pos
        ldx #$ff
.pos
        stx var2 ; used as bit extension
        
        clc
        adc var0
        sta var0
        lda var1
        adc var2
        sta var1
        jmp .intdone
        

.sync
	; Sync Interrupt
	jsr LineSync
        jmp .intdone

.jors	lsr
	bcs .stack
        ; Jump Interrupt
	lsr
        bcc .table
        ; -- RTS
        jsr PullStack
        sta var0
        jsr PullStack
        sta var1
        jmp .intdone
.table
	lsr
        bcc .direct
        ; -- JMP()
        ldy #0
        lda (var0),y
        pha
        iny
        lda (var0),y
        sta var1
        pla
        sta var0
        jmp .intdone
.direct
	lsr
        bcc .npush
        ; -- JSR
        lda ATRPC
        clc
        adc JINTREL,y
        sta ATRPC
        lda ATRPC+1
        adc #0
        jsr PushStack
        lda ATRPC
        jsr PushStack
.npush	
	; -- JMP
        jmp .intdone


.stack
	; Stack Interrupt
	lsr
        bcc .rw
        lsr
        bcc .txs
        ; TSX
	lda IntS
        sta IntX
        jmp .intdone
.txs
	; TXS
	lda IntX
        sta IntS
        jmp .intdone
.rw
	lsr
        bcc .pull
        ; PHx
        ldx IntA
        lsr
        bcc .ac
        ldx IntP
.ac
	txa
        jsr PushStack
	jmp .intdone
.pull
	; PLx
	sta var2
        jsr PullStack
        bit var2
        bne .proc
        ; PLA
        sta IntA
        jmp .intdone
.proc
	; PLP
	sta IntP

.intdone
	lda var0
        sta ATRPC
        lda var1
        sta ATRPC+1

        jmp SetNESPC
        
        
LineSync: subroutine
	; TODO: reflection and the latter 20 tiles should also be translated
	lda #2
        bit VSYNC
        beq .nvsync
        inc $201
        lda #-37
        sta ScanLine
        lda #5
        sta PaletteCounter
        lda #0
        sta ColorSection
        jmp .syncdone
.nvsync
	ldy ScanLine
        ; we don't do anything if in vblank
        cpy #192
        bcc .screen
        jmp .syncdone
.screen
        ;visible scanlines 0-191
        tya
        lsr
        bcs .odd	; only odd scanlines are processed and drawn
        
        ; reading playfield data
        ldx #0
        ldy #2
.loop
        lda PlayField-2,y
        rol PF0,x
        rol
        rol PF0,x
        rol
        sta PlayField-2,y
        
        iny
        tya
        and #$3
        bne .nnextpf
        inx
        cpx #3
        beq .syncdone
.nnextpf
        jmp .loop

.odd
	and #$3
        cmp #3
        bne .syncdone
        
        ; after 8 scanlines, copy the converted playfield data to buffer
        
        ; PPU Address
        lda ScanLine
        rol
        rol
        rol
        and #$3
        ora #$20
        sta DrawAddr
        
        ldy ScanLine
        iny
        tya
        asl
        asl
        sta DrawAddr+1
        
        
        ; Tiles
        ldy #0
        ldx #0
.copy 
        lda PlayField,x
        sta DrawBuffer,x
        tya
        sta PlayField,x
        inx
        cpx #20
        bne .copy                

	
        ldx PaletteCounter
        dex
        bne .paldone
        ; after 6 tiles (48 scanlines) set the palettes
        
        lda COLUBK
        asl
        asl
        and #$30
        sta $2 ; we can use this as a temporary var
        lda COLUBK
        lsr
        lsr
        lsr
        lsr
        ora $2
        sta BGColor
        
        lda COLUPF
        asl
        asl
        and #$30
        sta $2 ; we can use this as a temporary var
        lda COLUPF
        lsr
        lsr
        lsr
        lsr
        ora $2
        sta PFColor

	inc ColorSection
	lda ColorSection
        sta UpdateColor
        
	ldx #5
.paldone
	stx PaletteCounter

.syncdone
	
        inc ScanLine
	rts
        
PushStack: subroutine
	sta var2
        lda IntS
        sta AddrLo
        lda #1
        sta AddrHi
        jsr MirrorAddr
        dec IntS
        
        ldy #0
        lda var2
        sta (NESAddrLo),y
        rts
        
PullStack: subroutine
        inc IntS
	lda IntS
        sta AddrLo
        lda #1
        sta AddrHi
        jsr MirrorAddr
        
        ldy #0
        lda (NESAddrLo),y
        rts
        
JumpToBranchCheck: subroutine
	jmp (IntrID)