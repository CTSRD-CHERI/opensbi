/*
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Copyright (c) 2020 Western Digital Corporation or its affiliates.
 *
 * Authors:
 *   Atish Patra <atish.patra@wdc.com>
 */

#ifndef __SBI_CSR_DETECT__H
#define __SBI_CSR_DETECT__H

#include <sbi/riscv_encoding.h>
#include <sbi/sbi_hart.h>

#ifdef __CHERI_PURE_CAPABILITY__
/* We have to use mtcc instead of mtvec for purecap */
#define SWAP_MTVEC(r1, r2) "cspecialrw" r1 ", mtcc, " r2 "\n"
#define SET_MTVEC(value) "cspecialw mtcc, " value "\n"
#else
#define SWAP_MTVEC(r1, r2) "csrrw " r1 ", " STR(CSR_MTVEC) ", " r2 "\n"
#define SET_MTVEC(value) "csrw " STR(CSR_MTVEC) ", " value "\n"
#endif

#define csr_read_allowed(csr_num, trap)					\
	({								\
	register ulong tinfo asm("a3") = (ulong)trap;			\
	register ulong ttmp asm("a4");					\
	register mtvec_t mtvec = sbi_hart_expected_trap_addr();		\
	register ulong ret = 0;						\
	asm volatile(							\
		"add %[ttmp], %[tinfo], zero\n"				\
		SWAP_MTVEC("%[mtvec]", "%[mtvec]")			\
		"csrr %[ret], %[csr]\n"					\
		SET_MTVEC("%[mtvec]")					\
	    : [mtvec] "+&r"(mtvec), [tinfo] "+&r"(tinfo),		\
	      [ttmp] "+&r"(ttmp), [ret] "=&r" (ret)			\
	    : [csr] "i" (csr_num)					\
	    : "memory");						\
	ret;								\
	})								\

#define csr_write_allowed(csr_num, trap, value)				\
	({								\
	register ulong tinfo asm("a3") = (ulong)trap;			\
	register ulong ttmp asm("a4");					\
	register mtvec_t mtvec = sbi_hart_expected_trap_addr();		\
	asm volatile(							\
		"add %[ttmp], %[tinfo], zero\n"				\
		SWAP_MTVEC("%[mtvec]", "%[mtvec]")			\
		"csrw %[csr], %[val]\n"					\
		SET_MTVEC("%[mtvec]")					\
	    : [mtvec] "+&r"(mtvec),					\
	      [tinfo] "+&r"(tinfo), [ttmp] "+&r"(ttmp)			\
	    : [csr] "i" (csr_num), [val] "r" (value)			\
	    : "memory");						\
	})								\

#endif
