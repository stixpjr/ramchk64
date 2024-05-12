* ramchk64 20240512
* stix@stix.id.au
* - give ourselves 4KiB for growth.
* - low copy at $0000, high copy at $1000
* -- $0000 code
* -- $0e00 stack
* -- $0e00 video RAM
* -- $1000 end

	org	$1000
zb	jmp	start
	fdb	ze-zb
* disable interrupts
start	orcc	#$50
* hide ROM
	clr	romset
* detect 32k/64k
* some hw/emulators mirror 32KiB banks
* some hw just return $ff for upper 32KiB
* also check for $00 return.
	lda	#$ff
	leax	maxpag,pcr
	leax	$8000,x
	sta	,x
	tst	maxpag,pcr
	bne	det32k
	clr	,x
	tst	,x
	bne	det32k
	sta	,x
	cmpa	,x
	bne	det32k
	sta	maxpag,pcr
	bra	logclr
* now check 16k/32k
det32k	clr	maxpag,pcr
	leax	maxpag,pcr
	leax	$4000,x
	sta	,x
	tst	maxpag,pcr
	bne	det16k
	clr	,x
	tst	,x
	bne	det16k
	sta	,x
	cmpa	,x
	bne	det16k
	lda	#$80
	sta	maxpag,pcr
	bra	logclr
det16k	lda	#$40
	sta	maxpag,pcr
* clear error log
logclr	clra
	ldb	#$60
	leax	errlog,pcr
logcl1	sta	,x+
	decb
	bne	logcl1
* jump to the low ram check
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
* check blocks:
* from $1000-$fe00 for 64k
* from $1000-$8000 for 32k
* from $1000-$4000 for 16k
	lda	#$10
loop1	bsr	chk
	cmpa	maxpag,pcr
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
* move video RAM to page $f, @$1e00
phigh	clr	f0set+0
	clr	f0set+2
	clr	f0set+4
	clr	f0set+6
	clr	f0clr+8
	clr	f0clr+10
	clr	f0clr+12
	ldd	#$1e00
	std	vidram,pcr
* set up stack
	lds	#$1e00
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
chk	ldy	#$89
* prints page # from a
	lbsr	prthex
* patterns from the list
	leau	patn,pcr
* print pattern # in b
chk1	ldb	,u+
	cmpb	#$01
	beq	chk2
	ldy	#$a9
	exg	a,b
	bsr	prthex
	exg	a,b
	bsr	chkblk
	bra	chk1
chk2	inca
* poll for the BREAK key
	ldb	#$fb
	stb	pia0+2
	ldb	pia0
	bitb	#$40
	beq	basic
	rts
basic	clr	$71
	clr	romclr
	jmp	[reset]

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
*** corrupt every byte for testing?
	if 0
	com	-1,x
	endif
*** corrupt a bit for testing?
	if 0
	cmpx	#$1234
	bne	nocorr
	ldb	-1,x
	eorb	#$40
	stb	-1,x
	clrb
	endif
nocorr	leay	-1,y
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
prthex	pshs	a,b,y
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
	puls	a,b,y,pc
prthe1	adda	#$70
	cmpa	#$79
	bls	prthe2
	suba	#$39
prthe2	sta	,y+
	rts

* prtscr
* print text headers, cycle & error count
* clobbers: a,b,x,y
prtscr	lbsr	cls
	ldy	#0
	leax	strttl,pcr
	lbsr	prtstr
	ldy	#$20
	leax	straut,pcr
	bsr	prtstr
	ldy	#$60
	leax	strmem,pcr
	bsr	prtstr
	ldy	#$69
	lda	maxpag,pcr
	cmpa	#$ff
	beq	prtsc6
	cmpa	#$80
	beq	prtsc3
prtsc1	leax	str16k,pcr
	bra	prtsc2
prtsc3	leax	str32k,pcr
	bra	prtsc2
prtsc6	leax	str64k,pcr
prtsc2	bsr	prtstr
	ldy	#$80
	leax	strpg,pcr
	bsr	prtstr
	ldy	#$a0
	leax	strpat,pcr
	bsr	prtstr
	ldy	#$c0
	leax	strcyc,pcr
	bsr	prtstr
	ldy	#$c9
	lda	cycles,pcr
	lbsr	prthex
	ldy	#$e0
	leax	strerr,pcr
	bsr	prtstr
	ldy	#$f0
	leax	strbit,pcr
	bsr	prtstr
	bsr	prterr
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
* - inc error counter
* - update error bits
* - update error log
* - update on screen
* inputs:
* a: expected pattern
* x: error addr + 1
error	pshs	a,b,x,y,u
	leax	-1,x
* get the error bits
	eora	,x
	ora	errbit,pcr
	sta	errbit,pcr
* update error log
* is address known?
	lda	#$20
	leay	errlog,pcr
err1	cmpx	,y
	beq	err3
	leay	3,y
	deca
	bne	err1
* not found, so shuffle error log down
	lda	#$1f
	leay	errlog,pcr
	leay	$5d,y
err2	ldx	-3,y
	ldb	-1,y
	stx	,y
	stb	2,y
	leay	-3,y
	deca
	bne	err2
* store into error log
err3	lda	,s
	ldx	2,s
	leax	-1,x
	eora	,x
	stx	,y
	ora	2,y
	sta	2,y
* inc error counter
	inc	errors,pcr
	bsr	prterr
	puls	a,b,x,y,u,pc

* prterr - update errors on screen
prterr	lda	errors,pcr
	ldy	#$e9
	lbsr	prthex
	lda	errbit,pcr
	ldy	#$f9
	lbsr	prthex
	ldb	#$20
	stb	prterc,pcr
	leax	errlog,pcr
	ldy	#$100
prter1	lda	,x+
	lbsr	prthex
	leay	2,y
	lda	,x+
	lbsr	prthex
	leay	2,y
	ldd	vidram,pcr
	tfr	y,u
	leau	d,u
	lda	#':'+$40
	sta	,u
	leay	1,y
	lda	,x+
	lbsr	prthex
	leay	3,y
	dec	prterc,pcr
	bne	prter1
	rts
prterc	fcb	0

* vars
vidram	fdb	0
maxpag	fcb	0
cycles	fcb	0
errors	fcb	0
errbit	fcb	0

* error log
* keep the last 32 error addresses
* 2 byte address, 1 byte for error bits
*   = 3 bytes per entry
errlog	rmb	96

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
strttl	fcc	"RAMCHK64 20240512"
	fcb	0
straut	fcc	"BY PAUL RIPKE STIX@STIX.ID.AU"
	fcb	0
strmem	fcc	"RAM:"
	fcb	0
strpg	fcc	"PAGE:"
	fcb	0
strpat	fcc	"PATTERN:"
	fcb	0
strcyc	fcc	"CYCLES:"
	fcb	0
strerr	fcc	"ERRORS:"
	fcb	0
strbit	fcc	"ERRBITS:"
	fcb	0
str16k	fcc	"16K"
	fcb	0
str32k	fcc	"32K"
	fcb	0
str64k	fcc	"64K"
	fcb	0

* equates
pia0	equ	$ff00
romclr	equ	$ffde
romset	equ	$ffdf
f0clr	equ	$ffc6
f0set	equ	$ffc7
reset	equ	$fffe

ze	equ	*
	end	zb
