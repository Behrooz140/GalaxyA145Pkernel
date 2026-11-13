/* SPDX-License-Identifier: GPL-2.0 */
#ifndef _LINUX_VERMAGIC_H
#define _LINUX_VERMAGIC_H

#ifndef INCLUDE_VERMAGIC
#error "This header can be included from kernel/module.c or *.mod.c only"
#endif

#include <generated/utsrelease.h>
#include <asm/vermagic.h>

/* Simply sanity version stamp for modules. */
#ifdef CONFIG_SMP
#define MODULE_VERMAGIC_SMP "SMP "
#else
#define MODULE_VERMAGIC_SMP ""
#endif
#ifdef CONFIG_PREEMPT_BUILD
#define MODULE_VERMAGIC_PREEMPT "preempt "
#elif defined(CONFIG_PREEMPT_RT)
#define MODULE_VERMAGIC_PREEMPT "preempt_rt "
#else
#define MODULE_VERMAGIC_PREEMPT ""
#endif
#ifdef CONFIG_MODULE_UNLOAD
#define MODULE_VERMAGIC_MODULE_UNLOAD "mod_unload "
#else
#define MODULE_VERMAGIC_MODULE_UNLOAD ""
#endif
#ifdef CONFIG_MODVERSIONS
#define MODULE_VERMAGIC_MODVERSIONS "modversions "
#else
#define MODULE_VERMAGIC_MODVERSIONS ""
#endif
#ifdef RANDSTRUCT
#include <generated/randstruct_hash.h>
#define MODULE_RANDSTRUCT "RANDSTRUCT_" RANDSTRUCT_HASHED_SEED
#else
#define MODULE_RANDSTRUCT
#endif

/*
 * A145P "behi" kernel: the UTS release string is branded (see
 * CONFIG_LOCALVERSION in gki_defconfig) so Settings / uname show the custom
 * kernel name and version.
 *
 * The vermagic stamp is part of the module load ABI: every stock module in
 * /vendor/lib/modules was linked against the stock release string. Keep
 * it pinned to the exact stock value, otherwise all vendor modules are
 * rejected at load time (the v1.1 bootloop class of failure). The value below
 * must match the stock firmware exactly:
 *
 *   <UTS_RELEASE> SMP preempt mod_unload modversions aarch64
 *
 * CI verifies that this string is present in the built Image, and the KMI gate
 * keeps the exported symbol CRCs identical to v1.0.
 */
#define A145P_STOCK_VERMAGIC \
	"6.6.92-android15-8-abA145PXXSDDZH1-4k SMP preempt mod_unload modversions aarch64"

#define VERMAGIC_STRING A145P_STOCK_VERMAGIC

#endif /* _LINUX_VERMAGIC_H */
