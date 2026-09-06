/* Deterministic 386-era DOS .COM workload.  Assemble with GNU as --32. */
.code16
.global _start

_start:
	movw $0x1234, %ax
	movw $0xabcd, %bx
	movw $0x0f0f, %si
	movl $20000, %ebp             /* easy-to-adjust outer iteration count */
	movl $0x13579bdf, %eax
	movl $0x2468ace1, %ebx
	movl $0xf00dcafe, %esi

outer:
	movw $64, %cx
inner:
	addl %ebx, %eax
	xorl %esi, %eax
	roll $5, %eax
	imull $1664525, %eax, %eax
	addl $1013904223, %eax
	xorl %eax, %ebx
	roll $11, %ebx
	addl %ebx, %esi
	xorl %eax, %esi
	andw $0x00fe, %bx
	movw %ax, buffer(%bx)
	andw $0x00fe, %si
	xorw buffer(%si), %ax
	addw %ax, %bx
	xorw %bx, %si
	loop inner
	decl %ebp
	jnz outer

	/* Fold both register widths and guest-memory state into one result. */
	xorl %ebx, %eax
	xorl %esi, %eax
	movw $buffer, %si
	movw $128, %cx
fold:
	xorl (%si), %eax
	addw $2, %si
	loop fold

	movw $result_prefix, %si
	call puts
	movw $8, %cx
hex_loop:
	roll $4, %eax
	movb %al, %dl
	andb $15, %dl
	cmpb $10, %dl
	jb digit
	addb $'A'-10, %dl
	jmp emit
digit:
	addb $'0', %dl
emit:
	movb $2, %ah
	int $0x21
	loop hex_loop
	movw $crlf, %si
	call puts
	movw $0x4c00, %ax
	int $0x21

puts:
	lodsb
	testb %al, %al
	jz puts_done
	movb %al, %dl
	movb $2, %ah
	int $0x21
	jmp puts
puts_done:
	ret

result_prefix: .asciz "PI286_CPU_BENCH_RESULT="
crlf: .asciz "\r\n"
.balign 2
buffer: .space 256
