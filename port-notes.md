# susfs v2.4.0 → odin 5.4 回移植笔记

新仓：kaixin886/odin-kernel-susfs（public，2026-11-15 建）。原仓 odin-kernel 封存为已验收救援线（BakaSU＋susfs v2.1.0）。

## 底稿与基线（2026-11-15 实查）
- 移植底稿：susfs4ksu `gki-android12-5.10` 分支，SUSFS_VERSION **v2.4.0**（HEAD 2026-11-15 仍在更新）。
  本地克隆：`inspect/susfs-510/`（GitHub 镜像 ShirkNeko/susfs4ksu）。
  补丁 `kernel_patches/50_add_susfs_in_gki-android12-5.10.patch`：3268 行、27 个文件；
  核心 fs/susfs.c 2560 行（86623 字节）、include/linux/susfs.h 261 行、susfs_def.h 172 行。
- 上游 `kernel-5.4` 分支停在 **v1.5.9**（老于现行 2.1.0），不可用；v2 线无 5.4 分支。
- 基线树：Inkypen susfs 分支（lineage-24.0＋susfs v2.1.0 导入，20 文件 2942 行，已适配 5.4）。
  本地克隆：`inspect/inkypen-susfs/`（进行中）。

## 头文件层结论（已比对实证）
- v2.4.0 的 susfs_def.h **自带** TIF 位定义：TIF_PROC_UMOUNTED 33、TIF_PROC_NO_SU 34、
  TIF_PROC_UMOUNTED_FOR_ZYGOTE_NEXT 35（头内自包含，不动 arch thread_info）。
- v2.4.0 相对 2.1.0 在 def.h 新增的正是 BakaSU 需要、我们之前拿桩顶的接口：
  no_su 家族（is/set/clear）、zygote_next 家族（is/set/clear）、clear_current_proc_umounted、
  susfs_is_current_app_uid。2.1.0 的 susfs_fname_arg/len 辅助在 2.4 已移除。
- **推论**：移植完成后，上一仓给 BakaSU 打的两处胶水必须拆除——
  ①追加进 susfs_def.h 的 4 个 no_su 声明（2.4 头自带、且为 static inline，重复声明/定义会冲突）；
  ②compat/kernel_compat.c 里的胶水定义块（同名 static inline 已在头中，.c 再定义必冲突）。
  sid 三空桩（susfs_set_ksu_sid 等）是否保留看 BakaSU selinux.h 声明与 2.4 susfs.c 是否提供真实现，移植时核对。

## 打法（已定）
以 Inkypen susfs 分支为底做 2.1→2.4 增量升级：核心三文件（fs/susfs.c、susfs.h、susfs_def.h）
整换为 2.4 版并做 5.4 API 适配；27 个调用点文件逐个比对 5.10 补丁与 2.1 在树形态的差异，
只搬增量、不重打全量。BakaSU 集成沿用上一仓脚本（钉版 548d1dda、SUSFS 内联钩、接线脚本），
去掉胶水段。构建/AK3/HKF 流程与上一仓一致，变体名暂定 resukisu（新仓内唯一变体）。

## Delta 地图（2026-11-15 本地比对实证）
- 全量克隆 Inkypen 树超时（出口慢），改逐文件拉取：2.4 补丁触及的 30 个文件已拉 28 个到
  `inspect/inkypen/files/`（susfs 分支）。**两个文件在 5.4 不存在**：fs/proc/bootconfig.c、
  security/selinux/status.c——对应 hunk 直接丢弃（cmdline 伪造在 5.4 走 fs/proc/cmdline 路径另核）。
- 核心 fs/susfs.c：1494 行（2.1 在树）→ 2560 行（2.4）。2.4 新增整块子系统：
  per-app/per-UID 的 sus_path 过滤（priority apps 机制）、sus_type/AVD 规则（RCU+hash）、
  sdcard inode 事件处理重做、mnt_id 翻译（susfs_get_non_sus_mnt_id_from_mnt 等）、
  susfs_restore_creds、kstat 的 inotify fdinfo 伪造。移除：susfs_get_data_path、旧 open_redirect show 实现（换 srcu 版）。
- 调用点增量（2.4 补丁新增 susfs 行数）：多为个位数到 21 行（namei.c 最多）。
  **2.1 在树为零、2.4 新增的调用点**：block/ioprio.c(3)、fs/super.c(5)、
  security/selinux/hooks.c(4)、selinuxfs.c(11)、ss/services.c(15)——2.4 的 SELinux 集成比 2.1 深得多
  （2.1 在树只有 avc.c），移植时重点核 5.4 的 selinux ss API 差异。

## 5.4 API 审计结论（2026-11-15，移植可行性实证）
- 底稿钉版：susfs-510 分支 HEAD **6dff25f**（v2.4.0），CI 集成时按此 commit 钉死。
- 核心三文件对 5.4 **基本干净**：2.4 相对 2.1 只多 6 个 include（bitmap/hash/limits/rcupdate/
  security/string，5.4 全有）；susfs.c 不用 mnt_idmap/vfsuid/kfree_sensitive/path_mount/
  CLASS/guard 等任何 5.4 后 API（strscpy 15 处，5.4 有）。
- 全补丁新增行里唯一的 5.4 后 API：**selinux 的 state->policy 指针（2 处）**，
  5.4 须改走 state->ss->policydb 形态，是 selinuxfs/services 两处的手工适配点。
  policydb/selinux_state/real_mount 等其余引用 5.4 均有对应物。
- 构造法（CI 脚本）：克隆 Inkypen susfs 分支→核心三文件整换 2.4（钉版克隆取）→
  打手工 authored 的 callsite 补丁（以 inspect/inkypen/files 为工作副本本地产出）→
  BakaSU 集成（沿用旧脚本、删胶水段）。

## KSU 接口兼容性核查（2026-11-15，决定性结论）
2.4 补丁新增行引用的全部 ksu_* 符号逐个核过 BakaSU 源码：**全兼容、无缺口**。
- 11 个 handler（execveat/faccessat/stat/sys_read/sys_reboot/setresuid/input/vfs_fstat/
  sucompat 前后置/preinit 一对）BakaSU 均有定义——补丁自带的 KSU 接线可原样采用，
  **新仓不再需要上一仓的手写接线脚本**。
- ksu_selinux_hide_enabled/running 由 BakaSU 的 feature/selinux_hide.c 定义（56/58 行），
  2.4 的 selinux hunk 正是挂它；susfs_ksu_sid 在 BakaSU selinux.c:126 定义。
- 其余 MISS 均为子串假阳性（局部变量 is_ksu_preinit_session、susfs_is_current_ksu_domain 等）。
- 待构造时核：susfs_set_ksu_sid/set_init_sid/set_priv_app_sid 三个 setter 在 2.4 侧
  是否有真定义（BakaSU selinux.h 有声明且调用），没有才保留旧仓的空桩。
- 基线钉版：Inkypen susfs 分支 HEAD **50e0141b**；susfs-510 钉 **6dff25f**；BakaSU 钉 548d1dda（同旧仓）。

## 待办
- [x] Inkypen susfs 分支文件备齐＋delta 地图（整树克隆改逐文件拉取）
- [x] 核心三文件 5.4 API 审计（结论：可移植，风险集中在 selinux 两处）
- [x] KSU 接口兼容性核查（全兼容，架构简化：移植文件自带接线）
- [ ] 调用点逐文件搬增量（含 selinux 三处新点位、ioprio/super 两处新点位）
- [ ] 写新仓 scripts/build-kernel.sh＋给用户的 build.yaml 工作流文本
- [ ] 首轮构建→按日志迭代（老规矩：先通知用户再修再推）
- **2026-11-15 stat.c 移植完成（1/25）**：port/out/fs/stat.c。删 Inkypen 的 2.1 三处块（generic_fillattr 内调用、getattr_nosec 括号块、顶部两 extern），入 2.4 形态：susfs_def include＋"internal.h"（filename_lookup/getname_flags 在此）、KSU extern 块、getattr_nosec 探针＋括号处理（**丢弃 stat->mnt_id 两处赋值**——5.4 kstat 无此字段、statx ABI 不暴露，子功能自然无效）、vfs_statx 的 fname/filename_lookup 流程＋result_mask 清位、init_rc 钩移植进 vfs_statx_fd（5.4 无 vfs_fstat 函数）。另核：2.4 susfs.c 内唯一的 stat->mnt_id 赋值上游已用 `#if LINUX_VERSION_CODE >= 5.10` 自守，核心文件零改动。
- **2026-11-15 exec.c 移植完成（2/25）**：port/out/fs/exec.c。5.4 的 do_execveat_common 是薄包装、主体在 __do_execve_file，故 2.4 的头/尾逻辑全移植进 __do_execve_file：IS_ERR 后入头逻辑（no_su→sdcard 键二选 execveat/_sucompat→pid1 preinit 设立），orig_flow 标签置于 NPROC 注释前（与 5.10 同位）；尾部在 exec_binprm 成功后入 post_sucompat＋preinit post。5.4 专属适配：preinit 重跑前除 free_bprm 外还要 kfree(pathbuf)、pathbuf/file 置 NULL（file 已交 bprm 释放）；preinit 返回 false 时 5.10 的 goto out_free 在 5.4 改为穿落正常成功收尾（rseq/acct/in_exec 复位必须走）。sdcard 静态键在 susfs.c:2373 有定义。
- **2026-11-15 open.c 移植完成（3/25）**：port/out/fs/open.c。Inkypen 的 OPEN_REDIRECT 块（do_sys_open 内）与 2.4 核心接口逐字兼容（susfs_open_redirect_spoof_do_sys_openat 同签名、WITHOUT_UID_CHECK 宏两版都在），原样保留；只加 2.4 的 faccessat 三件：susfs_def include、extern 块、retry 处 fname/filename_lookup 流程（handler 第四参按上游传 NULL；5.4 的 do_faccessat 是 3 参非 static、旧 override_cred 结构，不碍事）。
- **2026-11-15 read_write.c 移植完成（4/25）**：port/out/fs/read_write.c。Inkypen 树零标记，纯加 2.4 的 sys_read 钩：SYSCALL_DEFINE3(read) 头部查 ksu_is_init_rc_hook_enabled 静态键→ksu_handle_sys_read(fd)；5.4 的 ksys_read/read 形态与 5.10 一致、零适配。
- **2026-11-15 readdir.c 移植完成（5/25）**：port/out/fs/readdir.c。Inkypen 2.1 在树版的 fill* 检查块与 2.4 逐字等价（ilookup→susfs_is_inode_sus_path→跳过），保留；但 5 个 syscall 包装器（old_readdir/getdents/ksys_getdents64/compat×2）带 FUSE 特判、调用 2.4 已删除的 susfs_get_data_path，必须换成 2.4 的一行式 buf.sb = f.file->f_inode->i_sb，并删 path_err/path 局部与尾部 path_put；include 块同步换 2.4 形态（susfs_def 守卫改 CONFIG_KSU_SUSFS、sus_path extern 带 hot 属性）。脚本化替换、计数断言全过（5/5/5/1），get_data_path 残留引用 0。
- **2026-11-15 sys.c 移植完成（6/25）**：port/out/kernel/sys.c。Inkypen 在树仅有 newuname 伪造块、与 2.4 逐字一致（不动）；新增 2.4 三件：PRIORITY_UID_FILTER extern＋setpriority/getpriority 两处同文分支检查（cred->uid.val>=10000 && susfs_is_priority_uid_filtered→out_unlock，脚本替换计数断言 2/2）、setresuid extern＋__sys_setresuid 入口以原始参数调 ksu_handle_setresuid（5.4 无 bool 三声明、插在 kuid_t 声明后 make_kuid 前）。susfs_is_priority_uid_filtered 在 2.4 susfs.c:2189、同名 CONFIG 守卫下有定义。
- **2026-11-15 reboot.c 移植完成（7/25）**：port/out/kernel/reboot.c。Inkypen 零标记，纯加 2.4 两件：DEFINE_MUTEX 后 extern、SYSCALL_DEFINE4(reboot) 头部 ksu_handle_sys_reboot 通道（ret 非 0→orig_flow 走真重启、0→已消费直接 return）——susfs 用户态命令通道即走此路。5.4 形态同 5.10、零适配。
- 备忘：补丁 27 文件已拆分至 /tmp/patch24/<path with __>.diff 供逐文件取用（/tmp 易失，仅本轮）。
- **2026-11-15 Kconfig 符号审计（决定性）**：2.4 代码引用的 CONFIG_KSU_SUSFS* 共 12 个；BakaSU 自带 Kconfig 符号集（manager/app/src/main/cpp/ksu_kconfig_overrides.h 镜像）有 16 个，**独缺 2.4 新增的两个：KSU_SUSFS_AVD（sus_type/AVD 规则子系统）、KSU_SUSFS_PRIORITY_UID_FILTER（priority apps）**。不补则两子系统静默编译掉、其余照常；移植要全须在 build 脚本里给 BakaSU 的 Kconfig（drivers/kernelsu/Kconfig 的 SUSFS 菜单）追加这两个 config 条目再 scripts/config 开启。BakaSU 另有 AUTO_ADD_* 等 2.1 时代符号、2.4 不引用，无害。
- **2026-11-15 input.c 移植完成（8/25）**：port/out/drivers/input/input.c。Inkypen 零标记、input_handle_event 形态与 5.10 一致，2.4 两段（extern＋静态键查 ksu_handle_input_handle_event）逐字植入、零适配。至此 BakaSU inline_hook_check 的 7 个必查文件（stat/exec/open/read_write/sys/reboot/input）全部就位。
- **2026-11-15 fs/Makefile 与 kernel/kallsyms.c 核验免移植（9、10/25）**：Inkypen 树里 Makefile 的 obj-$(CONFIG_KSU_SUSFS) += susfs.o 与 2.4 补丁一致；kallsyms.c 的 HIDE_KSU_SUSFS_SYMBOLS 块（include＋s_show 18 前缀过滤表）与 2.4 逐字一致。两文件构建时直接用树内原版、不进 port/out。
- **2026-11-15 namei.c 移植完成（11/25）**：port/out/fs/namei.c。Inkypen 在树版与 2.4 逐块比对：SUS_PATH 全部块（nameidata.state、lookup_dcache/__lookup_hash/lookup_fast 双路/__lookup_slow、walk_component、lookup_last、lookup_open、do_last 置 OPEN_LAST、vfs_readlink 双路）与 2.4 逻辑逐字等价、原样保留；两处动手：①link_path_walk 的 sus_path 检查由 may_lookup 之后移到之前（2.4 原位，顺带满足 gnu89 声明在前）；②**补 2.4 新增的 OPEN_REDIRECT 三块**（其树没有）：do_tmpfile、do_o_path 在 path_lookupat 后换 path，path_openat 在 walk 循环后以 fake_filename 重走（terminate/restore/set_nameidata＋path_init＋link_path_walk/do_last 循环，do_last 版循环带 trailing_symlink 步，complete_walk 在 do_last 内已跑、nd->path 即最终 dentry、检查位成立），尾部 nd->name 复原＋putname。顶部补 do_sys_openat 解析函数的 OPEN_REDIRECT extern。
- **2026-11-15 open.c 修订**：删掉 Inkypen 2.1 的 do_sys_open 重定向块（extern＋局部＋retry 检查）——2.4 已把拦截迁入 namei 的 path_openat/do_o_path/do_tmpfile，open.c 只留 faccessat 三件，避免双重拦截偏离上游形态。
- **2026-11-15 namespace.c 移植完成（12/25）**：port/out/fs/namespace.c。Inkypen 在树版与 2.4 逐块核对：include/extern/CL_COPY_MNT_NS 定义、mnt_free_id 跳过、mnt_alloc_group_id 的 KSU 组号、两个 alloc 助手、vfs_create_mount、clone_mnt 双路＋标志位、copy_mnt_ns、尾部两个 non_sus 取值函数——全部在位且逻辑一致（仅 mnt_free_id 少 unlikely()、尾部守卫用 SUS_MOUNT，均等价）。**唯一缺件是 2.4 新增的 __lookup_mnt umounted 伪装块**（zygote_next 派生进程查挂载时只返回 mnt_id < DEFAULT_KSU_MNT_ID 的正牌挂载），已按上游原文补入。
- **2026-11-15 proc_namespace.c 移植完成（13/25）**：port/out/fs/proc_namespace.c。此文件 2.1→2.4 是设计级变更：2.1 用全局 bool（susfs_hide_sus_mnts_for_non_su_procs，2.4 核心已删除、只留静态键）＋show_* 内 READ_ONCE 早退；2.4 改为静态键 susfs_is_hide_sus_mnts_for_non_su_procs_enabled＋三份平行 susfs_show_*（过滤 mnt_id>=DEFAULT_KSU_MNT_ID）＋三个 open 处按「键开且非 ksu 域」分发。移植：删 3 处旧块与 bool extern、换静态键 extern、susfs_show_* 以 Inkypen 自己的 5.4 函数体为底复制生成（保留其 show_options2 分支，不用补丁的 5.10 体）、补分发块；脚本断言全过、旧 bool 引用清零。
- **2026-11-15 statfs.c 移植完成（14/25）**：port/out/fs/statfs.c。2.1→2.4 变更：删 OPEN_REDIRECT 的 vfs_statfs 块（其调的 susfs_open_redirect_spoof_vfs_statfs 在 2.4 核心已删除）；SUS_MOUNT umounted 块换 2.4 形态（局部声明入块、等指针分支内联普通调用）；新增 SUS_KSTAT 全套：extern 对、statfs_by_dentry_wrapper/calculate_f_flags_wrapper（2.4 susfs.c:867-906 实际调用）、susfs_statfs_by_dentry、vfs_statfs 头部 app-uid 检查块。include 守卫换 CONFIG_KSU_SUSFS（保留其 "mount.h"）。
- **2026-11-15 super.c（15/25）与 block/ioprio.c（16/25）移植完成**：均为其树零标记的 2.4 新增。super.c：susfs_def include＋SUS_MOUNT extern＋get_anon_bdev 头部块（ksu 域从 DEFAULT_KSU_MNT_MINOR_DEV 起分配匿名设备号，def.h:51 有定义；ida_alloc_range 5.4 有）。ioprio.c：PRIORITY_UID_FILTER extern＋ioprio_set/get 的 WHO_USER 分支各一处过滤（脚本断言 2/2）。
- **2026-11-15 mm/memory.c 核验免移植（17/25）**：Inkypen 的 SUS_MAP 三块（susfs_def include、__access_remote_vm 入口 find_vma 预取、循环内 SUSFS_IS_INODE_SUS_MAP 断开）与 2.4 逐字一致。
- **2026-11-15 fs/notify/fdinfo.c 移植完成（18/25）**：port/out/fs/notify/fdinfo.c。其 2.1 版已有三参 show_fdinfo 设计（SUS_MOUNT 守卫；fanotify 的二参回调照样传入、本树 CI 实证可编，故照旧）；2.4 增量只有 SUS_KSTAT：include 守卫放宽为 CONFIG_KSU_SUSFS、补 KSTAT extern 对、签名/调用守卫放宽为 MOUNT||KSTAT、inotify_fdinfo 内在 MOUNT 块之前插入 kstat 伪造块（app uid＋sus_kstat 命中时以伪造 ino/dev 输出并 return）。
- **2026-11-15 fs/proc/base.c 核验免移植（19/25）**：Inkypen 的 include 守卫、do_proc_readlink 的 OPEN_REDIRECT 块（susfs_open_redirect_spoof_do_proc_readlink 在 2.4 susfs.c:1698 有定义）、map_files 的 SUS_MAP 跳过块均与 2.4 一致。
- **2026-11-15 fs/proc/fd.c 移植完成（20/25）**：port/out/fs/proc/fd.c。删其 OPEN_REDIRECT 块与 extern（susfs_open_redirect_spoof_seq_show 在 2.4 核心已删除）及 mnt_id/ino 局部；补 2.4 的 SUS_KSTAT 块（app uid＋sus_kstat 命中→susfs_sus_kstat_spoof_proc_fd_seq_show 伪造 mnt_id/ino 后 goto bypass）；其 SUS_MOUNT 块与 2.4 逻辑等价保留，标签守卫由 MOUNT||OPEN_REDIRECT 改 MOUNT||KSTAT；include 守卫换 CONFIG_KSU_SUSFS。
- **2026-11-15 fs/proc/task_mmu.c 移植完成（21/25）**：port/out/fs/proc/task_mmu.c。其余块（include 守卫、KSTAT extern、show_smap/rollup/pagemap 的 SUS_MAP 跳过）与 2.4 等价保留；唯一换代的是 show_map_vma 的 OPEN_REDIRECT：2.1 的缓冲版 susfs_open_redirect_spoof_show_map_vma（char* 出参＋尾部打印/kfree＋orig_flow 标签）整体换成 2.4 的 srcu 版（susfs_srcu_open_redirect 在 2.4 susfs.c:1463 DEFINE_SRCU；char** 出参、锁内打印完直接 return），本地声明与尾部块一并删除。5.4 适配：task_mmu.c 与 susfs_def.h 均未引 srcu.h，在 extern 块内补 #include <linux/srcu.h> 保险。
