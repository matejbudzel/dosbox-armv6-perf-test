/* Deterministic mode-13h + PC-speaker DOS .COM workload (386-era). */
.code16
.global _start

_start:
	/* 320x200x256 VGA mode. */
	movw $0x0013, %ax
	int $0x10

	/* Enable a 440 Hz PC speaker tone while the VGA workload runs. */
	movb $0xb6, %al
	outb %al, $0x43
	movw $2712, %ax
	outb %al, $0x42
	movb %ah, %al
	outb %al, $0x42
	inb $0x61, %al
	orb $3, %al
	outb %al, $0x61

	movw $0xa000, %ax
	movw %ax, %es
	movl $0x13579bdf, %eax
	movl $0x2468ace1, %ebx
	movl $16, %ebp                 /* frames; intentionally easy to tune */

frame:
	xorw %di, %di
	movw $32000, %cx               /* 64 KiB mode-13 framebuffer / 2 */
pixel:
	addl %ebx, %eax
	roll $3, %eax
	xorl %eax, %ebx
	movw %ax, %es:(%di)
	addw $2, %di
	loop pixel
	decl %ebp
	jnz frame

	/* Fold sampled video RAM into a deterministic result. */
	xorw %di, %di
	movw $256, %cx
fold:
	xorw %es:(%di), %ax
	addw $251, %di
	loop fold
	xorl %ebx, %eax

	/* Silence the PC speaker before returning to text mode. */
	inb $0x61, %al
	andb $0xfc, %al
	outb %al, $0x61
	movw $0x0003, %ax
	int $0x10

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

result_prefix: .asciz "PI286_AV_BENCH_RESULT="
crlf: .asciz "\r\n"
