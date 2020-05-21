/*
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Copyright (c) 2019 Western Digital Corporation or its affiliates.
 *
 * Authors:
 *   Anup Patel <anup.patel@wdc.com>
 */

#ifndef __SBI_TRAP_H__
#define __SBI_TRAP_H__

/* clang-format off */

/** Index of zero member in sbi_trap_regs */
#define SBI_TRAP_REGS_zero			0
/** Index of ra member in sbi_trap_regs */
#define SBI_TRAP_REGS_ra			1
/** Index of sp member in sbi_trap_regs */
#define SBI_TRAP_REGS_sp			2
/** Index of gp member in sbi_trap_regs */
#define SBI_TRAP_REGS_gp			3
/** Index of tp member in sbi_trap_regs */
#define SBI_TRAP_REGS_tp			4
/** Index of t0 member in sbi_trap_regs */
#define SBI_TRAP_REGS_t0			5
/** Index of t1 member in sbi_trap_regs */
#define SBI_TRAP_REGS_t1			6
/** Index of t2 member in sbi_trap_regs */
#define SBI_TRAP_REGS_t2			7
/** Index of s0 member in sbi_trap_regs */
#define SBI_TRAP_REGS_s0			8
/** Index of s1 member in sbi_trap_regs */
#define SBI_TRAP_REGS_s1			9
/** Index of a0 member in sbi_trap_regs */
#define SBI_TRAP_REGS_a0			10
/** Index of a1 member in sbi_trap_regs */
#define SBI_TRAP_REGS_a1			11
/** Index of a2 member in sbi_trap_regs */
#define SBI_TRAP_REGS_a2			12
/** Index of a3 member in sbi_trap_regs */
#define SBI_TRAP_REGS_a3			13
/** Index of a4 member in sbi_trap_regs */
#define SBI_TRAP_REGS_a4			14
/** Index of a5 member in sbi_trap_regs */
#define SBI_TRAP_REGS_a5			15
/** Index of a6 member in sbi_trap_regs */
#define SBI_TRAP_REGS_a6			16
/** Index of a7 member in sbi_trap_regs */
#define SBI_TRAP_REGS_a7			17
/** Index of s2 member in sbi_trap_regs */
#define SBI_TRAP_REGS_s2			18
/** Index of s3 member in sbi_trap_regs */
#define SBI_TRAP_REGS_s3			19
/** Index of s4 member in sbi_trap_regs */
#define SBI_TRAP_REGS_s4			20
/** Index of s5 member in sbi_trap_regs */
#define SBI_TRAP_REGS_s5			21
/** Index of s6 member in sbi_trap_regs */
#define SBI_TRAP_REGS_s6			22
/** Index of s7 member in sbi_trap_regs */
#define SBI_TRAP_REGS_s7			23
/** Index of s8 member in sbi_trap_regs */
#define SBI_TRAP_REGS_s8			24
/** Index of s9 member in sbi_trap_regs */
#define SBI_TRAP_REGS_s9			25
/** Index of s10 member in sbi_trap_regs */
#define SBI_TRAP_REGS_s10			26
/** Index of s11 member in sbi_trap_regs */
#define SBI_TRAP_REGS_s11			27
/** Index of t3 member in sbi_trap_regs */
#define SBI_TRAP_REGS_t3			28
/** Index of t4 member in sbi_trap_regs */
#define SBI_TRAP_REGS_t4			29
/** Index of t5 member in sbi_trap_regs */
#define SBI_TRAP_REGS_t5			30
/** Index of t6 member in sbi_trap_regs */
#define SBI_TRAP_REGS_t6			31
/** Index of mepc member in sbi_trap_regs */
#if __has_feature(capabilities)
#define SBI_TRAP_REGS_mepcc			32
#else
#define SBI_TRAP_REGS_mepc			32
#endif
/** Index of mstatus member in sbi_trap_regs */
#define SBI_TRAP_REGS_mstatus			33
/** Index of mstatusH member in sbi_trap_regs */
#define SBI_TRAP_REGS_mstatusH			34
/** Last member index in sbi_trap_regs */
#define SBI_TRAP_REGS_last			35

/** Index of cause member in sbi_trap_info */
#define SBI_TRAP_INFO_cause			0
/** Index of tval member in sbi_trap_info */
#define SBI_TRAP_INFO_tval			1
/** Index of tval2 member in sbi_trap_info */
#define SBI_TRAP_INFO_tval2			2
/** Index of tinst member in sbi_trap_info */
#define SBI_TRAP_INFO_tinst			3
/** Index of epc member in sbi_trap_info */
#define SBI_TRAP_INFO_epc			4
#if __has_feature(capabilities)
/* One extra long padding */
#define SBI_TRAP_INFO_last			6
#else
#define SBI_TRAP_INFO_last			5
#endif
/** Last member index in sbi_trap_info */

/* clang-format on */

#if __has_feature(capabilities)
/* XXX: We use __uintcap_t for everything (also integers( to simplify the offsets */
#define TRAP_REG_SIZE __SIZEOF_CHERI_CAPABILITY__
#else
#define TRAP_REG_SIZE __SIZEOF_POINTER__
#endif


/** Get offset of member with name 'x' in sbi_trap_regs */
#define SBI_TRAP_REGS_OFFSET(x) ((SBI_TRAP_REGS_##x) * TRAP_REG_SIZE)
/** Size (in bytes) of sbi_trap_regs */
#define SBI_TRAP_REGS_SIZE SBI_TRAP_REGS_OFFSET(last)

/** Get offset of member with name 'x' in sbi_trap_info */
#define SBI_TRAP_INFO_OFFSET(x) ((SBI_TRAP_INFO_##x) * __SIZEOF_LONG__)
/** Size (in bytes) of sbi_trap_info */
#define SBI_TRAP_INFO_SIZE SBI_TRAP_INFO_OFFSET(last)

#ifndef __ASSEMBLY__

#include <sbi/sbi_types.h>

#if __has_feature(capabilities)
/*
 * XXX: We use __uintcap_t for everything (also integers) to simplify the
 * offsets. Assembly sometimes stores integers but that works as expected
 * since we only support little endian
 */
#if __BYTE_ORDER__ != __ORDER_LITTLE_ENDIAN__
#error "Must be little endian"
#endif
typedef union {
    __uintcap_t value;
    unsigned long intval;
    void* __capability ptrval;
} trap_reg_t;
#else
typedef union {
	unsigned long value;
	void* ptrval;
	unsigned long intval;
} trap_reg_t;
#endif

/** Representation of register state at time of trap/interrupt */
struct sbi_trap_regs {
	/** zero register state */
	trap_reg_t zero;
	/** ra register state */
	trap_reg_t ra;
	/** sp register state */
	trap_reg_t sp;
	/** gp register state */
	trap_reg_t gp;
	/** tp register state */
	trap_reg_t tp;
	/** t0 register state */
	trap_reg_t t0;
	/** t1 register state */
	trap_reg_t t1;
	/** t2 register state */
	trap_reg_t t2;
	/** s0 register state */
	trap_reg_t s0;
	/** s1 register state */
	trap_reg_t s1;
	/** a0 register state */
	trap_reg_t a0;
	/** a1 register state */
	trap_reg_t a1;
	/** a2 register state */
	trap_reg_t a2;
	/** a3 register state */
	trap_reg_t a3;
	/** a4 register state */
	trap_reg_t a4;
	/** a5 register state */
	trap_reg_t a5;
	/** a6 register state */
	trap_reg_t a6;
	/** a7 register state */
	trap_reg_t a7;
	/** s2 register state */
	trap_reg_t s2;
	/** s3 register state */
	trap_reg_t s3;
	/** s4 register state */
	trap_reg_t s4;
	/** s5 register state */
	trap_reg_t s5;
	/** s6 register state */
	trap_reg_t s6;
	/** s7 register state */
	trap_reg_t s7;
	/** s8 register state */
	trap_reg_t s8;
	/** s9 register state */
	trap_reg_t s9;
	/** s10 register state */
	trap_reg_t s10;
	/** s11 register state */
	trap_reg_t s11;
	/** t3 register state */
	trap_reg_t t3;
	/** t4 register state */
	trap_reg_t t4;
	/** t5 register state */
	trap_reg_t t5;
	/** t6 register state */
	trap_reg_t t6;
	/** mepc register state */
	trap_reg_t mepc;
	/** mstatus register state */
	unsigned long mstatus;
#if __has_feature(capabilities)
	unsigned long _pad_mstatus;
#endif
	/** mstatusH register state (only for 32-bit) */
	unsigned long mstatusH;
#if __has_feature(capabilities)
	unsigned long _pad_mstatusH;
#endif
} __packed __attribute__((aligned(_Alignof(trap_reg_t))));

/** Representation of trap details */
struct sbi_trap_info {
	/** cause Trap exception cause */
	unsigned long cause;
	/** tval Trap value */
	unsigned long tval;
	/** tval2 Trap value 2 */
	unsigned long tval2;
	/** tinst Trap instruction */
	unsigned long tinst;
	/** epc Trap program counter */
	trap_reg_t epc;
};

int sbi_trap_redirect(struct sbi_trap_regs *regs,
		      struct sbi_trap_info *trap);

void sbi_trap_handler(struct sbi_trap_regs *regs);

#endif

#endif
