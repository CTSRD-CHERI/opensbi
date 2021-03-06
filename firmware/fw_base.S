/*
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Copyright (c) 2019 Western Digital Corporation or its affiliates.
 *
 * Authors:
 *   Anup Patel <anup.patel@wdc.com>
 */

#include <sbi/riscv_asm.h>
#include <sbi/riscv_encoding.h>
#include <sbi/sbi_platform.h>
#include <sbi/sbi_scratch.h>
#include <sbi/sbi_trap.h>

#if __has_feature(capabilities)
#if defined(__CHERI_PURE_CAPABILITY__)
#error "Not implemented yet"
#else
#define SAVE_TRAP_REG(reg, slot, sp) sc c##reg, SBI_TRAP_REGS_OFFSET(slot)(sp)
#define RESTORE_TRAP_REG(reg, slot, sp) lc c##reg, SBI_TRAP_REGS_OFFSET(slot)(sp)
#endif
#else
#define SAVE_TRAP_REG(reg, slot, sp) REG_S	reg, SBI_TRAP_REGS_OFFSET(slot)(sp)
#define RESTORE_TRAP_REG(reg, slot, sp) REG_L	reg, SBI_TRAP_REGS_OFFSET(slot)(sp)
#endif

#define BOOT_STATUS_RELOCATE_DONE	1
#define BOOT_STATUS_BOOT_HART_DONE	2

.macro	MOV_3R __d0, __s0, __d1, __s1, __d2, __s2
	add	\__d0, \__s0, zero
	add	\__d1, \__s1, zero
	add	\__d2, \__s2, zero
.endm

.macro	MOV_5R __d0, __s0, __d1, __s1, __d2, __s2, __d3, __s3, __d4, __s4
	add	\__d0, \__s0, zero
	add	\__d1, \__s1, zero
	add	\__d2, \__s2, zero
	add	\__d3, \__s3, zero
	add	\__d4, \__s4, zero
.endm

/*
 * If __start_reg <= __check_reg and __check_reg < __end_reg then
 *   jump to __pass
 */
.macro BRANGE __start_reg, __end_reg, __check_reg, __jump_lable
	blt	\__check_reg, \__start_reg, 999f
	bge	\__check_reg, \__end_reg, 999f
	j	\__jump_lable
999:
.endm

.macro MOVE_CREG dst, src
#if __has_feature(capabilities)
	cmove c\dst, c\src
#else
	add	\dst, \src, zero
#endif
.endm
.macro INC_CREG dst, src, imm
#if __has_feature(capabilities)
	cincoffset	c\dst, c\src, \imm
#else
	add	\dst, \src, \imm
#endif
.endm

	.section .entry, "ax", %progbits
	.align 3
	.globl _start
	.globl _start_warm
_start:
#if __has_feature(capabilities)
	/* write DDC to MTDC */
	cspecialr ct0, ddc
	cspecialw mtdc, ct0
#endif
	/* Find preferred boot HART id */
	MOV_3R	s0, a0, s1, a1, s2, a2
	call	fw_boot_hart
	add	a6, a0, zero
	MOV_3R	a0, s0, a1, s1, a2, s2
	li	a7, -1
	beq	a6, a7, _try_lottery
	/* Jump to relocation wait loop if we are not boot hart */
	bne	a0, a6, _wait_relocate_copy_done
_try_lottery:
	/* Jump to relocation wait loop if we don't get relocation lottery */
	la	a6, _relocate_lottery
	li	a7, 1
	amoadd.w a6, a7, (a6)
	bnez	a6, _wait_relocate_copy_done

	/* Save load address */
	la	t0, _load_start
	la	t1, _start
	REG_S	t1, 0(t0)

	/* Relocate if load address != link address */
_relocate:
	la	t0, _link_start
	REG_L	t0, 0(t0)
	la	t1, _link_end
	REG_L	t1, 0(t1)
	la	t2, _load_start
	REG_L	t2, 0(t2)
	sub	t3, t1, t0
	add	t3, t3, t2
	beq	t0, t2, _relocate_done
	la	t4, _relocate_done
	sub	t4, t4, t2
	add	t4, t4, t0
	blt	t2, t0, _relocate_copy_to_upper
_relocate_copy_to_lower:
	ble	t1, t2, _relocate_copy_to_lower_loop
	la	t3, _relocate_lottery
	BRANGE	t2, t1, t3, _start_hang
	la	t3, _boot_status
	BRANGE	t2, t1, t3, _start_hang
	la	t3, _relocate
	la	t5, _relocate_done
	BRANGE	t2, t1, t3, _start_hang
	BRANGE	t2, t1, t5, _start_hang
	BRANGE  t3, t5, t2, _start_hang
_relocate_copy_to_lower_loop:
	REG_L	t3, 0(t2)
	REG_S	t3, 0(t0)
	add	t0, t0, SZREG
	add	t2, t2, SZREG
	blt	t0, t1, _relocate_copy_to_lower_loop
	jr	t4
_relocate_copy_to_upper:
	ble	t3, t0, _relocate_copy_to_upper_loop
	la	t2, _relocate_lottery
	BRANGE	t0, t3, t2, _start_hang
	la	t2, _boot_status
	BRANGE	t0, t3, t2, _start_hang
	la	t2, _relocate
	la	t5, _relocate_done
	BRANGE	t0, t3, t2, _start_hang
	BRANGE	t0, t3, t5, _start_hang
	BRANGE	t2, t5, t0, _start_hang
_relocate_copy_to_upper_loop:
	add	t3, t3, -SZREG
	add	t1, t1, -SZREG
	REG_L	t2, 0(t3)
	REG_S	t2, 0(t1)
	blt	t0, t1, _relocate_copy_to_upper_loop
	jr	t4
_wait_relocate_copy_done:
	la	t0, _start
	la	t1, _link_start
	REG_L	t1, 0(t1)
	beq	t0, t1, _wait_for_boot_hart
	la	t2, _boot_status
	la	t3, _wait_for_boot_hart
	sub	t3, t3, t0
	add	t3, t3, t1
1:
	/* waitting for relocate copy done (_boot_status == 1) */
	li	t4, BOOT_STATUS_RELOCATE_DONE
	REG_L	t5, 0(t2)
	/* Reduce the bus traffic so that boot hart may proceed faster */
	nop
	nop
	nop
	bgt     t4, t5, 1b
	jr	t3
_relocate_done:

	/*
	 * Mark relocate copy done
	 * Use _boot_status copy relative to the load address
	 */
	la	t0, _boot_status
	la	t1, _link_start
	REG_L	t1, 0(t1)
	la	t2, _load_start
	REG_L	t2, 0(t2)
	sub	t0, t0, t1
	add	t0, t0, t2
	li	t1, BOOT_STATUS_RELOCATE_DONE
	REG_S	t1, 0(t0)
	fence	rw, rw

	/* At this point we are running from link address */

	/* Reset all registers for boot HART */
	li	ra, 0
	call	_reset_regs

	/* Zero-out BSS */
	la	s4, _bss_start
	la	s5, _bss_end
_bss_zero:
	REG_S	zero, (s4)
	add	s4, s4, SZREG
	blt	s4, s5, _bss_zero

	/* Setup temporary trap handler */
	la	s4, _start_hang
	csrw	CSR_MTVEC, s4

	/* Setup temporary stack */
	la	s4, _fw_end
	li	s5, (SBI_SCRATCH_SIZE * 2)
	add	sp, s4, s5

	/*
	 * Initialize platform
	 * Note: The a0 to a4 registers passed to the
	 * firmware are parameters to this function.
	 */
	MOV_5R	s0, a0, s1, a1, s2, a2, s3, a3, s4, a4
	call	fw_platform_init
	MOV_5R	a0, s0, a1, s1, a2, s2, a3, s3, a4, s4

	/* Allow main firmware to save info */
	MOV_5R	s0, a0, s1, a1, s2, a2, s3, a3, s4, a4
	call	fw_save_info
	MOV_5R	a0, s0, a1, s1, a2, s2, a3, s3, a4, s4

	/* Preload HART details
	 * s7 -> HART Count
	 * s8 -> HART Stack Size
	 */
	la	a4, platform
#if __riscv_xlen == 64
	lwu	s7, SBI_PLATFORM_HART_COUNT_OFFSET(a4)
	lwu	s8, SBI_PLATFORM_HART_STACK_SIZE_OFFSET(a4)
#else
	lw	s7, SBI_PLATFORM_HART_COUNT_OFFSET(a4)
	lw	s8, SBI_PLATFORM_HART_STACK_SIZE_OFFSET(a4)
#endif

	/* Setup scratch space for all the HARTs*/
	la	tp, _fw_end
	mul	a5, s7, s8
	add	tp, tp, a5
	/* Keep a copy of tp */
	add	t3, tp, zero
	/* Counter */
	li	t2, 1
	/* hartid 0 is mandated by ISA */
	li	t1, 0
_scratch_init:
	add	tp, t3, zero
	mul	a5, s8, t1
	sub	tp, tp, a5
	li	a5, SBI_SCRATCH_SIZE
	sub	tp, tp, a5

	/* Initialize scratch space */
	/* Store fw_start and fw_size in scratch space */
	la	a4, _fw_start
	la	a5, _fw_end
	mul	t0, s7, s8
	add	a5, a5, t0
	sub	a5, a5, a4
	REG_S	a4, SBI_SCRATCH_FW_START_OFFSET(tp)
	REG_S	a5, SBI_SCRATCH_FW_SIZE_OFFSET(tp)
	/* Store next arg1 in scratch space */
	MOV_3R	s0, a0, s1, a1, s2, a2
	call	fw_next_arg1
	REG_S	a0, SBI_SCRATCH_NEXT_ARG1_OFFSET(tp)
	MOV_3R	a0, s0, a1, s1, a2, s2
	/* Store next address in scratch space */
	MOV_3R	s0, a0, s1, a1, s2, a2
	call	fw_next_addr
	REG_S	a0, SBI_SCRATCH_NEXT_ADDR_OFFSET(tp)
	MOV_3R	a0, s0, a1, s1, a2, s2
	/* Store next mode in scratch space */
	MOV_3R	s0, a0, s1, a1, s2, a2
	call	fw_next_mode
	REG_S	a0, SBI_SCRATCH_NEXT_MODE_OFFSET(tp)
	MOV_3R	a0, s0, a1, s1, a2, s2
	/* Store warm_boot address in scratch space */
	la	a4, _start_warm
	REG_S	a4, SBI_SCRATCH_WARMBOOT_ADDR_OFFSET(tp)
	/* Store platform address in scratch space */
	la	a4, platform
	REG_S	a4, SBI_SCRATCH_PLATFORM_ADDR_OFFSET(tp)
	/* Store hartid-to-scratch function address in scratch space */
	la	a4, _hartid_to_scratch
	REG_S	a4, SBI_SCRATCH_HARTID_TO_SCRATCH_OFFSET(tp)
	/* Clear tmp0 in scratch space */
	REG_S	zero, SBI_SCRATCH_TMP0_OFFSET(tp)
	/* Store firmware options in scratch space */
	MOV_3R	s0, a0, s1, a1, s2, a2
#ifdef FW_OPTIONS
	li	a4, FW_OPTIONS
#else
	add	a4, zero, zero
#endif
	call	fw_options
	or	a4, a4, a0
	REG_S	a4, SBI_SCRATCH_OPTIONS_OFFSET(tp)
	MOV_3R	a0, s0, a1, s1, a2, s2
	/* Move to next scratch space */
	add	t1, t1, t2
	blt	t1, s7, _scratch_init

	/* Override previous arg1 */
	MOV_3R	s0, a0, s1, a1, s2, a2
	call	fw_prev_arg1
	add	t1, a0, zero
	MOV_3R	a0, s0, a1, s1, a2, s2
	beqz	t1, _prev_arg1_override_done
	add	a1, t1, zero
_prev_arg1_override_done:

	/*
	 * Relocate Flatened Device Tree (FDT)
	 * source FDT address = previous arg1
	 * destination FDT address = next arg1
	 *
	 * Note: We will preserve a0 and a1 passed by
	 * previous booting stage.
	 */
	beqz	a1, _fdt_reloc_done
	/* Mask values in a3 and a4 */
	li	a3, ~(__SIZEOF_POINTER__ - 1)
	li	a4, 0xff
	/* t1 = destination FDT start address */
	MOV_3R	s0, a0, s1, a1, s2, a2
	call	fw_next_arg1
	add	t1, a0, zero
	MOV_3R	a0, s0, a1, s1, a2, s2
	beqz	t1, _fdt_reloc_done
	beq	t1, a1, _fdt_reloc_done
	and	t1, t1, a3
	/* t0 = source FDT start address */
	add	t0, a1, zero
	and	t0, t0, a3
	/* t2 = source FDT size in big-endian */
#if __riscv_xlen == 64
	lwu	t2, 4(t0)
#else
	lw	t2, 4(t0)
#endif
	/* t3 = bit[15:8] of FDT size */
	add	t3, t2, zero
	srli	t3, t3, 16
	and	t3, t3, a4
	slli	t3, t3, 8
	/* t4 = bit[23:16] of FDT size */
	add	t4, t2, zero
	srli	t4, t4, 8
	and	t4, t4, a4
	slli	t4, t4, 16
	/* t5 = bit[31:24] of FDT size */
	add	t5, t2, zero
	and	t5, t5, a4
	slli	t5, t5, 24
	/* t2 = bit[7:0] of FDT size */
	srli	t2, t2, 24
	and	t2, t2, a4
	/* t2 = FDT size in little-endian */
	or	t2, t2, t3
	or	t2, t2, t4
	or	t2, t2, t5
	/* t2 = destination FDT end address */
	add	t2, t1, t2
	/* FDT copy loop */
	ble	t2, t1, _fdt_reloc_done
_fdt_reloc_again:
	REG_L	t3, 0(t0)
	REG_S	t3, 0(t1)
	add	t0, t0, SZREG
	add	t1, t1, SZREG
	blt	t1, t2, _fdt_reloc_again
_fdt_reloc_done:

	/* mark boot hart done */
	li	t0, BOOT_STATUS_BOOT_HART_DONE
	la	t1, _boot_status
	REG_S	t0, 0(t1)
	fence	rw, rw
	j	_start_warm

	/* waiting for boot hart to be done (_boot_status == 2) */
_wait_for_boot_hart:
	li	t0, BOOT_STATUS_BOOT_HART_DONE
	la	t1, _boot_status
	REG_L	t1, 0(t1)
	/* Reduce the bus traffic so that boot hart may proceed faster */
	nop
	nop
	nop
	bne	t0, t1, _wait_for_boot_hart

_start_warm:
	/* Reset all registers for non-boot HARTs */
	li	ra, 0
	call	_reset_regs

	/* Disable and clear all interrupts */
	csrw	CSR_MIE, zero
	csrw	CSR_MIP, zero

	/* Find HART count and HART stack size */
	la	a4, platform
#if __riscv_xlen == 64
	lwu	s7, SBI_PLATFORM_HART_COUNT_OFFSET(a4)
	lwu	s8, SBI_PLATFORM_HART_STACK_SIZE_OFFSET(a4)
#else
	lw	s7, SBI_PLATFORM_HART_COUNT_OFFSET(a4)
	lw	s8, SBI_PLATFORM_HART_STACK_SIZE_OFFSET(a4)
#endif
	REG_L	s9, SBI_PLATFORM_HART_INDEX2ID_OFFSET(a4)

	/* Find HART id */
	csrr	s6, CSR_MHARTID

	/* Find HART index */
	beqz	s9, 3f
	li	a4, 0
1:
#if __riscv_xlen == 64
	lwu	a5, (s9)
#else
	lw	a5, (s9)
#endif
	beq	a5, s6, 2f
	add	s9, s9, 4
	add	a4, a4, 1
	blt	a4, s7, 1b
	li	a4, -1
2:	add	s6, a4, zero
3:	bge	s6, s7, _start_hang

	/* Find the scratch space based on HART index */
	la	tp, _fw_end
	mul	a5, s7, s8
	add	tp, tp, a5
	mul	a5, s8, s6
	sub	tp, tp, a5
	li	a5, SBI_SCRATCH_SIZE
	sub	tp, tp, a5

	/* update the mscratch */
#if __has_feature(capabilities)
install_ctp:
	/* Create a DDC-derived capability for scratch (we need this to
	 * save the first register without switching to capmode). */
	cspecialr	ct0, ddc
	csetaddr	ctp, ct0, tp
	cspecialw	mscratchc, ctp
	cmove	ct0, cnull
#else
	csrw	CSR_MSCRATCH, tp
#endif

	/* Setup stack */
	add	sp, tp, zero

	/* Setup trap handler */
	la	a4, _trap_handler
	csrw	CSR_MTVEC, a4

	/* Initialize SBI runtime */
#if __has_feature(capabilities)
	cspecialr	ca0, mscratchc
#else
	csrr	a0, CSR_MSCRATCH
#endif
	call	sbi_init

	/* We don't expect to reach here hence just hang */
	j	_start_hang

	.align 3
_relocate_lottery:
	RISCV_ADDR	0
_boot_status:
	RISCV_ADDR	0
_load_start:
	RISCV_ADDR	_fw_start
_link_start:
	RISCV_ADDR	_fw_start
_link_end:
	RISCV_ADDR	_fw_reloc_end

	.section .entry, "ax", %progbits
	.align 3
	.globl _hartid_to_scratch
_hartid_to_scratch:
	/*
	 * a0 -> HART ID (passed by caller)
	 * a1 -> HART Index (passed by caller)
	 * t0 -> HART Stack Size
	 * t1 -> HART Stack End
	 * t2 -> Temporary
	 */
	la	t2, platform
#if __riscv_xlen == 64
	lwu	t0, SBI_PLATFORM_HART_STACK_SIZE_OFFSET(t2)
	lwu	t2, SBI_PLATFORM_HART_COUNT_OFFSET(t2)
#else
	lw	t0, SBI_PLATFORM_HART_STACK_SIZE_OFFSET(t2)
	lw	t2, SBI_PLATFORM_HART_COUNT_OFFSET(t2)
#endif
	sub	t2, t2, a1
	mul	t2, t2, t0
	la	t1, _fw_end
	add	t1, t1, t2
	li	t2, SBI_SCRATCH_SIZE
	sub	a0, t1, t2
	ret

	.section .entry, "ax", %progbits
	.align 3
	.globl _start_hang
_start_hang:
	wfi
	j	_start_hang

	.section .entry, "ax", %progbits
	.align 3
	.globl fw_platform_init
	.weak fw_platform_init
fw_platform_init:
	ret

	.section .entry, "ax", %progbits
	.align 3
	.globl _trap_handler
_trap_handler:
	/* Swap TP and MSCRATCH */
#if __has_feature(capabilities)
	cspecialrw	ctp, mscratchc, ctp
	/* Save CT0 in scratch space (we don't have an immediate) */
	cincoffset ctp, ctp, SBI_SCRATCH_TMP0_OFFSET
	sc.cap	ct0, 0(ctp)
	cincoffset ctp, ctp, -SBI_SCRATCH_TMP0_OFFSET
	/* swap caller DDC with mtdc */
	cspecialr	ct0, mtdc
	cspecialrw	ct0, ddc, ct0
	cspecialw	mtdc, ct0
#else
	csrrw	tp, CSR_MSCRATCH, tp
	/* Save T0 in scratch space */
	REG_S	t0, SBI_SCRATCH_TMP0_OFFSET(tp)
#endif

	/* Check which mode we came from */
	csrr	t0, CSR_MSTATUS
	srl	t0, t0, MSTATUS_MPP_SHIFT
	and	t0, t0, PRV_M
	xori	t0, t0, PRV_M
	beq	t0, zero, _trap_handler_m_mode


	/* We came from S-mode or U-mode */
_trap_handler_s_mode:
	/* Set T0 to original SP */
	MOVE_CREG	t0, sp

	/* Setup exception stack */
	INC_CREG	sp, tp, -(SBI_TRAP_REGS_SIZE)

	/* Jump to code common for all modes */
	j	_trap_handler_all_mode

	/* We came from M-mode */
_trap_handler_m_mode:
	/* Set T0 to original SP */
	MOVE_CREG	t0, sp

	/* Re-use current SP as exception stack */
	INC_CREG	sp, sp, -(SBI_TRAP_REGS_SIZE)

_trap_handler_all_mode:
	/* Save original SP (from T0) on stack */
	SAVE_TRAP_REG(t0, sp, sp)

	/* Restore T0 from scratch space */
#if __has_feature(capabilities)
	lc	ct0, SBI_SCRATCH_TMP0_OFFSET(tp)
#else
	REG_L	t0, SBI_SCRATCH_TMP0_OFFSET(tp)
#endif

	/* Save T0 on stack */
	SAVE_TRAP_REG(t0, t0, sp)

	/* Swap TP and MSCRATCH */
#if __has_feature(capabilities)
	cspecialrw	ctp, mscratchc, ctp
#else
	csrrw	tp, CSR_MSCRATCH, tp
#endif

	/* Save MEPC and MSTATUS CSRs */
#if __has_feature(capabilities)
	cspecialr	ct0, mepcc
	SAVE_TRAP_REG(t0, mepcc, sp)
#else
	csrr	t0, CSR_MEPC
	SAVE_TRAP_REG(t0, mepc, sp)
#endif
	csrr	t0, CSR_MSTATUS
	REG_S	t0, SBI_TRAP_REGS_OFFSET(mstatus)(sp)
	REG_S	zero, SBI_TRAP_REGS_OFFSET(mstatusH)(sp)
#if __riscv_xlen == 32
	csrr	t0, CSR_MISA
	srli	t0, t0, ('H' - 'A')
	andi	t0, t0, 0x1
	beq	t0, zero, _skip_mstatush_save
	csrr	t0, CSR_MSTATUSH
	REG_S	t0, SBI_TRAP_REGS_OFFSET(mstatusH)(sp)
_skip_mstatush_save:
#endif

	/* Save all general regisers except SP and T0 */
#if __has_feature(capabilities)
	/* Caller DDC was stashed in mtdc */
	cspecialr	ct0, mtdc
	SAVE_TRAP_REG(t0, ddc, sp)
#else
	SAVE_TRAP_REG(zero, zero, sp)
#endif
	SAVE_TRAP_REG(ra, ra, sp)
	SAVE_TRAP_REG(gp, gp, sp)
	SAVE_TRAP_REG(tp, tp, sp)
	SAVE_TRAP_REG(t1, t1, sp)
	SAVE_TRAP_REG(t2, t2, sp)
	SAVE_TRAP_REG(s0, s0, sp)
	SAVE_TRAP_REG(s1, s1, sp)
	SAVE_TRAP_REG(a0, a0, sp)
	SAVE_TRAP_REG(a1, a1, sp)
	SAVE_TRAP_REG(a2, a2, sp)
	SAVE_TRAP_REG(a3, a3, sp)
	SAVE_TRAP_REG(a4, a4, sp)
	SAVE_TRAP_REG(a5, a5, sp)
	SAVE_TRAP_REG(a6, a6, sp)
	SAVE_TRAP_REG(a7, a7, sp)
	SAVE_TRAP_REG(s2, s2, sp)
	SAVE_TRAP_REG(s3, s3, sp)
	SAVE_TRAP_REG(s4, s4, sp)
	SAVE_TRAP_REG(s5, s5, sp)
	SAVE_TRAP_REG(s6, s6, sp)
	SAVE_TRAP_REG(s7, s7, sp)
	SAVE_TRAP_REG(s8, s8, sp)
	SAVE_TRAP_REG(s9, s9, sp)
	SAVE_TRAP_REG(s10, s10, sp)
	SAVE_TRAP_REG(s11, s11, sp)
	SAVE_TRAP_REG(t3, t3, sp)
	SAVE_TRAP_REG(t4, t4, sp)
	SAVE_TRAP_REG(t5, t5, sp)
	SAVE_TRAP_REG(t6, t6, sp)

	/* Call C routine */
	MOVE_CREG	a0, sp
	call	sbi_trap_handler

	/* Restore all general regisers except SP and T0 */
	RESTORE_TRAP_REG(ra, ra, sp)
	RESTORE_TRAP_REG(gp, gp, sp)
	RESTORE_TRAP_REG(tp, tp, sp)
	RESTORE_TRAP_REG(t1, t1, sp)
	RESTORE_TRAP_REG(t2, t2, sp)
	RESTORE_TRAP_REG(s0, s0, sp)
	RESTORE_TRAP_REG(s1, s1, sp)
	RESTORE_TRAP_REG(a0, a0, sp)
	RESTORE_TRAP_REG(a1, a1, sp)
	RESTORE_TRAP_REG(a2, a2, sp)
	RESTORE_TRAP_REG(a3, a3, sp)
	RESTORE_TRAP_REG(a4, a4, sp)
	RESTORE_TRAP_REG(a5, a5, sp)
	RESTORE_TRAP_REG(a6, a6, sp)
	RESTORE_TRAP_REG(a7, a7, sp)
	RESTORE_TRAP_REG(s2, s2, sp)
	RESTORE_TRAP_REG(s3, s3, sp)
	RESTORE_TRAP_REG(s4, s4, sp)
	RESTORE_TRAP_REG(s5, s5, sp)
	RESTORE_TRAP_REG(s6, s6, sp)
	RESTORE_TRAP_REG(s7, s7, sp)
	RESTORE_TRAP_REG(s8, s8, sp)
	RESTORE_TRAP_REG(s9, s9, sp)
	RESTORE_TRAP_REG(s10, s10, sp)
	RESTORE_TRAP_REG(s11, s11, sp)
	RESTORE_TRAP_REG(t3, t3, sp)
	RESTORE_TRAP_REG(t4, t4, sp)
	RESTORE_TRAP_REG(t5, t5, sp)
	RESTORE_TRAP_REG(t6, t6, sp)

	/* Restore MEPC and MSTATUS CSRs */
#if __has_feature(capabilities)
	RESTORE_TRAP_REG(t0, mepcc, sp)
	cspecialw	mepcc, ct0
#else
	RESTORE_TRAP_REG(t0, mepc, sp)
	csrw	CSR_MEPC, t0
#endif
	REG_L	t0, SBI_TRAP_REGS_OFFSET(mstatus)(sp)
	csrw	CSR_MSTATUS, t0
#if __riscv_xlen == 32
	csrr	t0, CSR_MISA
	srli	t0, t0, ('H' - 'A')
	andi	t0, t0, 0x1
	beq	t0, zero, _skip_mstatush_restore
	REG_L	t0, SBI_TRAP_REGS_OFFSET(mstatusH)(sp)
	csrw	CSR_MSTATUSH, t0
_skip_mstatush_restore:
#endif


#if __has_feature(capabilities)
	/* Make csp stack capability rather than an address */
	cspecialr	ct0, ddc
	csetaddr	csp, ct0, sp
	cspecialrw	ct0, mtdc, ct0 /* Restore MTDC */
	cspecialw	ddc, ct0 /* Restore caller DDC */

	/* Restore (c)t0 */
	cincoffset csp, csp, SBI_TRAP_REGS_OFFSET(t0)
	lc.cap ct0, 0(csp)
	cincoffset csp, csp, -SBI_TRAP_REGS_OFFSET(t0)
	/* Restore (c)sp */
	cincoffset csp, csp, SBI_TRAP_REGS_OFFSET(sp)
	lc.cap csp, 0(csp)
#else
	/* Restore T0 */
	RESTORE_TRAP_REG(t0, t0, sp)
	/* Restore SP */
	RESTORE_TRAP_REG(sp, sp, sp)
#endif

	mret

	.section .entry, "ax", %progbits
	.align 3
	.globl _reset_regs
_reset_regs:

	/* flush the instruction cache */
	fence.i
	/* Reset all registers except ra, a0, a1 and a2 */
	li sp, 0
	li gp, 0
	li tp, 0
	li t0, 0
	li t1, 0
	li t2, 0
	li s0, 0
	li s1, 0
	li a3, 0
	li a4, 0
	li a5, 0
	li a6, 0
	li a7, 0
	li s2, 0
	li s3, 0
	li s4, 0
	li s5, 0
	li s6, 0
	li s7, 0
	li s8, 0
	li s9, 0
	li s10, 0
	li s11, 0
	li t3, 0
	li t4, 0
	li t5, 0
	li t6, 0
	# Zero mscratch
#if __has_feature(capabilities)
	cspecialw mscratchc, ct6  # Note: can't use cnull due to it encoding a no-op
#else
	csrw CSR_MSCRATCH, 0
#endif

	ret
