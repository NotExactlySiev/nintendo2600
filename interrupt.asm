InterruptHandler: subroutine
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
        bvc .intdone
        

.sync
	; Sync Interrupt


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
        bvc .intdone
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
        bvc .intdone
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
        bvc .intdone


.stack
	; Stack Interrupt
	lsr
        bcc .rw
        lsr
        bcc .txs
	lda IntS
        sta IntX
        bvc .intdone
.txs
	lda IntX
        sta IntS
        bvc .intdone
.rw


.intdone
	lda var0
        sta ATRPC
        lda var1
        sta ATRPC+1

        jmp SetNESPC
        
        
LineSync: subroutine
	lda #2
        bit VSYNC
        beq .nvsync
        lda #-37
        sta ScanLine
        bne .syncdone
.nvsync
	ldy ScanLine
        iny
        sty ScanLine
        ; we don't do anything if in vblank
        cpy #192
        bcs .syncdone
        ;visible scanlines 1-192

	ldy #2
        jmp .readpf

        ldy #0       
.readpf        
        lda PlayField,y
        rol PF0
        rol
        rol PF0
        rol
        sta PlayField,y
        iny
        cpy #$4
        bcc .readpf
        
        
        tya
        and #$7
        bne .nupdate
        ; 8 rows completed. draw the playfield bytes  
.nupdate

.syncdone
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