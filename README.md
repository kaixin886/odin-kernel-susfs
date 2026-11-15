# odin-kernel-susfs

susfs v2.4.0 回移植到小米 MIX 4（odin）Inkypen 5.4 内核树 + BakaSU 集成的备料仓。
现行已验收的 BakaSU + susfs v2.1.0 在 kaixin886/odin-kernel，本仓只放 2.4 移植稿。

## 钉版

- 基线树：Inkypen kernel_xiaomi_odin 的 susfs 分支，HEAD 50e0141b（树内含 susfs v2.1.0）
- 移植底稿：susfs4ksu 的 gki-android12-5.10 分支 v2.4.0，HEAD 6dff25f
  （补丁 kernel_patches/50_add_susfs_in_gki-android12-5.10.patch，3268 行 / 27 文件）
- BakaSU：548d1dda（同旧仓）

## 内容

- `port/out/`：适配完成的全文件替换稿，构造时覆盖基线树同名文件。
  核心三件（fs/susfs.c、include/linux/susfs.h、include/linux/susfs_def.h）为 2.4 整换，
  其余为逐文件手工适配的调用点。
- `port-notes.md`：全部实证笔记（逐文件比对、5.4 API 审计、KSU 接口兼容性、Kconfig 符号审计）。

## 进度与未完

- 调用点文件 25 个完成 23；fs/Makefile、kernel/kallsyms.c、mm/memory.c、fs/proc/base.c、
  security/selinux/avc.c 经核验与 2.4 等价，免移植、不在 out 内。
- 未完一：security/selinux/selinuxfs.c 在 out 内但差最后一段函数体；
  security/selinux/ss/services.c 未动。两文件各有一处 state->policy 需改 5.4 的
  state->ss->policydb 形态。
- 未完二：构建脚本未写（构造法见 port-notes.md）；BakaSU 的 Kconfig 需补
  KSU_SUSFS_AVD 与 KSU_SUSFS_PRIORITY_UID_FILTER 两个符号，否则两子系统会被静默编译掉。
- 移植后旧仓的两处 no_su 胶水必须拆除（2.4 头文件自带），细节见 port-notes.md。
