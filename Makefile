all:	ramchk64.dsk

clean:
	-rm -f ramchk64.bin ramchk64.dsk ramchk64.dsk.bak

test:	ramchk64.bin
	xroar -machine coco -load ramchk64.bin

ramchk64.bin:	ramchk64.asm
	lwasm -9 -b -o $@ ramchk64.asm

ramchk64.dsk:	ramchk64.bin
	imgtool create coco_jvc_rsdos $@
	imgtool put coco_jvc_rsdos $@ ramchk64.bin ramchk64.bin

