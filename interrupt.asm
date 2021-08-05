InterruptHandler: subroutine
	sta IntrID
        pla
        sta IntS
        pla
        sta IntA
        stx IntX
        sty IntY
        
        
        lda ATRPC
        clc
        adc BlockSize
        sta ATRPC
        lda ATRPC+1
        adc #0
        sta ATRPC+1
        
        lda IntrID
        and #$f
        bne .ncond
        
	lda IntrID
        sta BranchCode
        lda var0
        sta BranchShift
        
        lda IntS
        pha
        
        lda #0
        plp	; set the proccessor as it was when the interrupt happened
        jsr BranchCode
        
        lda #$ff
        bit BranchShift
        bmi .neg
        lda #0
.neg
	sta var3 ; use this as a temporary second byte for sign extension
        
        clc
        lda ATRPC
        adc BranchShift
        sta ATRPC
        lda ATRPC+1
        adc var3
        sta ATRPC+1
        bne .intdone
.ncond

.intdone

        jmp SetNESPC