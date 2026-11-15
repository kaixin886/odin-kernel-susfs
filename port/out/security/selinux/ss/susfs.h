/* SPDX-License-Identifier: GPL-2.0 */
#ifndef _SELINUX_SS_SUSFS_H_
#define _SELINUX_SS_SUSFS_H_

#include <linux/gfp.h>
#include "security.h"

struct av_decision;

#ifdef CONFIG_KSU_SUSFS
int susfs_security_context_to_sid(struct selinux_state *state,
		const char *scontext, u32 scontext_len,
		u32 *sid, gfp_t gfp);
int susfs_security_context_str_to_sid(struct selinux_state *state,
		const char *scontext, u32 *sid, gfp_t gfp);
void susfs_security_compute_av_user(struct selinux_state *state,
		u32 ssid, u32 tsid, u16 tclass,
		struct av_decision *avd);
#endif

#endif /* _SELINUX_SS_SUSFS_H_ */
