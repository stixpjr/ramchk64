* ramchk64 20221228
* stix@stix.id.au
* - assumes a 64k machine for now
* - give ourselves 4KiB for growth.
* - low copy at $0000, high copy at $7000
* -- $0000 code
* -- $0e00 stack
* -- $0e00 video RAM
* -- $1000 end

	org	$7000
zb	jmp	start
	fdb	ze-zb
* disable interrupts
start	orcc	#$50
* hide ROM
	clr	romset
	jmp	phigh
* copy ourselves to page 0
loop	ldx	#zb
	ldy	#0
copy1	ldd	,x++
	std	,y++
	cmpx	#ze
	bls	copy1
* jump into copy
	jmp	plow-zb
* move video RAM to page $7, @$0e00
plow	clr	f0set+0
	clr	f0set+2
	clr	f0set+4
	clr	f0clr+6
	clr	f0clr+8
	clr	f0clr+10
	clr	f0clr+12
	ldd	#$0e00
	std	vidram,pcr
* set up stack
	lds	#$0e00
	lbsr	prtscr
* check blocks from $1000-$fe00
	lda	#$10
loop1	bsr	chk
	cmpa	#$ff
	bne	loop1
	inc	cycles,pcr
* copy ourselves back to $ORG
	ldx	#0
	ldy	#zb
copy2	ldd	,x++
	std	,y++
	cmpy	#ze
	bls	copy2
* jump into copy
	jmp	phigh
* move video RAM to page $3f, @$7e00
phigh	clr	f0set+0
	clr	f0set+2
	clr	f0set+4
	clr	f0set+6
	clr	f0set+8
	clr	f0set+10
	clr	f0clr+12
	ldd	#$7e00
	std	vidram,pcr
* set up stack
	lds	#$7e00
	lbsr	prtscr
* check blocks from $0000-$0f00
	clra
loop2	bsr	chk
	cmpa	#$10
	bne	loop2
	lbra	loop

* subroutines

* chk - check a page with all patterns
* inputs:
* a: 256 byte block number
chk	ldy	#$69
* prints page # from a
	lbsr	prthex
* patterns from the list
	leau	patn,pcr
* print pattern # in b
chk1	ldb	,u+
	ldy	#$89
	exg	a,b
	bsr	prthex
	exg	a,b
	bsr	chkblk
	cmpb	#$01
	bne	chk1
	inca
	rts

* chkblk
* inputs:
* a: 256 byte block number
* b: fill pattern
* clobbers: x,y
chkblk	pshs	a,b
* 1st pass, same pattern every byte
	clrb
	ldx	#0
	leax	d,x
	lda	1,s
	ldy	#$100
* fill loop
chkbl1	sta	,x+
	leay	-1,y
	bne	chkbl1
	ldx	#0
	lda	,s
	leax	d,x
	lda	1,s
	ldy	#$100
* verify loop
chkbl2	cmpa	,x+
	beq	chkbl3
	lbsr	error
chkbl3	leay	-1,y
	bne	chkbl2
	lda	,s
* 2nd pass, flip bits every 2nd byte
	ldx	#0
	leax	d,x
	lda	1,s
	ldy	#$100
* fill loop
chkbl4	sta	,x+
	coma
	leay	-1,y
	bne	chkbl4
	ldx	#0
	lda	,s
	leax	d,x
	lda	1,s
	ldy	#$100
* verify loop
chkbl5	cmpa	,x+
	beq	chkbl6
	lbsr	error
chkbl6	coma
	leay	-1,y
	bne	chkbl5
	puls	a,b,pc

* prthex
* inputs:
* a: hex byte to print
* y: screen offset
prthex	pshs	a,b
	ldd	vidram,pcr
	leay	d,y
	lda	,s
	lsra
	lsra
	lsra
	lsra
	bsr	prthe1
	lda	,s
	anda	#$0f
	bsr	prthe1
	puls	a,b,pc
prthe1	adda	#$70
	cmpa	#$79
	bls	prthe2
	suba	#$39
prthe2	sta	,y+
	rts

* prtscr
* print text headers, cycle & error count
* clobbers: a,b,x,y
prtscr	bsr	cls
	ldy	#0
	leax	strttl,pcr
	bsr	prtstr
	ldy	#$20
	leax	straut,pcr
	bsr	prtstr
	ldy	#$60
	leax	strpg,pcr
	bsr	prtstr
	ldy	#$80
	leax	strpat,pcr
	bsr	prtstr
	ldy	#$a0
	leax	strcyc,pcr
	bsr	prtstr
	ldy	#$a9
	lda	cycles,pcr
	bsr	prthex
	ldy	#$c0
	leax	strerr,pcr
	bsr	prtstr
	ldy	#$c9
	lda	errors,pcr
	bsr	prthex
	rts

* prtstr - print ascii string
* inputs:
* x: null-terminated str ptr
* y: screen offset
* clobbers: a,b
prtstr	ldd	vidram,pcr
	leay	d,y
prtst1	lda	,x+
	beq	prtst3
	cmpa	#$40
	bhs	prtst2
	adda	#$40
prtst2	sta	,y+
	bra	prtst1
prtst3	rts

* cls - clear screen at vidram
* clobbers a,b,x,y
cls	ldd	#$6060
	ldx	vidram,pcr
	ldy	#$200
cls1	std	,x++
	leay	-2,y
	bne	cls1
	rts

* error
* inc error counter, and update on screen
error	inc	errors,pcr
	pshs	a,b,x,y
	lda	errors,pcr
	ldy	#$c9
	lbsr	prthex
	puls	a,b,x,y,pc

* vars
vidram	fdb	0
cycles	fcb	0
errors	fcb	0

* patterns used for checks
patn	fcb	$00
	fcb	$ff
	fcb	$0f
	fcb	$f0
	fcb	$33
	fcb	$cc
	fcb	$55
	fcb	$aa
	fcb	$81
	fcb	$c3
	fcb	$e7
	fcb	$7e
	fcb	$3c
	fcb	$18
	fcb	$01	* end of patns

* strings
strttl	fcc	"RAMCHK64 20221228"
	fcb	0
straut	fcc	"BY PAUL RIPKE STIX@STIX.ID.AU"
	fcb	0
strpg	fcc	"PAGE:"
	fcb	0
strpat	fcc	"PATTERN:"
	fcb	0
strcyc	fcc	"CYCLES:"
	fcb	0
strerr	fcc	"ERRORS:"
	fcb	0

* equates
romclr	equ	$ffde
romset	equ	$ffdf
f0clr	equ	$ffc6
f0set	equ	$ffc7

ze	equ	*
	end	zb
