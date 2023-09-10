# ramchk64 for the Tandy Color Computer 1 & 2

Checks RAM on the Tandy CoCo 1 & 2 from $0000 thru $feff (or $7fff for 32k RAM CoCo's, and $3fff for 16k), inclusive, using a set of hard-coded bit patterns. Will also run on the CoCo 3, but only checks the bottom 65280 bytes.

Assembles with `lwasm` from [lwtools](http://www.lwtools.ca/), but should also assemble under `EDTASM` on a real CoCo with the addition of line numbers. The default make target also builds a disk image using `imgtool` from [MAME](https://www.mamedev.org/).
