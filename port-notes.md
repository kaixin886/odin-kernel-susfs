# SUSFS v2.3.0 → odin 5.4 移植记录

本分支把 SUSFS 2.3.0 移植回 Xiaomi MIX 4（odin）的 pinned Linux 5.4 基线。上游补丁面向 Linux 5.10，不能直接应用于 5.4；所有差异均以实际基线 API 为准。5.4 树中没有 `fs/proc/bootconfig.c`，因此不创建该文件。

| 组件 | 固定参考 |
|---|---|
| SUSFS 2.3.0 | [`simonpunk/susfs4ksu` commit `fb16b41a65180979f05eac837681c4dd0addffd1`](https://gitlab.com/simonpunk/susfs4ksu/-/commit/fb16b41a65180979f05eac837681c4dd0addffd1)，`gki-android12-5.10` |
| 5.4 内核基线 | [`Inkypen79/kernel_xiaomi_odin` commit `50e0141b29b62be21632c768e4818348098ac6cd`](https://github.com/Inkypen79/kernel_xiaomi_odin/commit/50e0141b29b62be21632c768e4818348098ac6cd) |
| BakaSU | [`Baka-SU/BakaSU` commit `548d1dda060ca198823d8808804d01f5209ef4a9`](https://github.com/Baka-SU/BakaSU/commit/548d1dda060ca198823d8808804d01f5209ef4a9) |

## 移植决策

`fs/susfs.c` 和 SUSFS 头文件来自固定 2.3.0。经对照 2.3 patch 核对，基线已提供相应逻辑的八个文件保持原样：`fs/proc/fd.c`、`fs/statfs.c`、`fs/proc/base.c`、`fs/notify/fdinfo.c`、`fs/readdir.c`、`mm/memory.c`、`security/selinux/avc.c`、`kernel/kallsyms.c`。`fs/namespace.c` 保留 2.3 的 zygote-next mount filter；proc mount 视图沿用 5.4 基线的 `show_options2` 支持。fsnotify 观察器使用 5.4 的 `handle_event`/`iter_info` 回调接口，`susfs_def.h` 明确包含 cred 定义。

`fs/stat.c` 保留 pinned 5.4 的 KSTAT API，叠加 BakaSU stat hooks 和 SUSFS 2.3 generic-fillattr 调用；为新增的 `filename_lookup()` 调用包含 5.4 私有 `internal.h`。SUSFS 2.3 的 map KSTAT 由对应调用点支持；没有 2.4 的 inode-KSTAT、STATX、statfs、fdinfo 或 proc-fd 扩展。Linux 5.4 的 `kstat` 没有 5.10 patch 使用的 `mnt_id` 字段，相关 5.10 赋值和未使用的 mount-ID 声明均不移植。另将 `KSTAT_SPOOF_CTIME_TV_SEC` 修正为 bit 8，避免比较表达式退化为 bit 0。

2.4 专属的 priority UID filter、AVD/SUS_TYPE 逻辑及其配置要求已移除；也不再覆盖 2.4 新增的 `block/ioprio.c`、`fs/super.c` 和 SELinux `ss/services.c`/`ss/susfs.h`。BakaSU 固定版已有 2.3 所需 Kconfig 选项，因此 helper 只验证选项并拒绝 AVD/priority UID filter，不再添加新菜单项。

## SELinux 接线

`selinuxfs.c` 的 fake status 路径继续使用 BakaSU fake-status helper；fake `access` 和 `context` 查询走 BakaSU `my_write_access`、`my_write_context`，不移植 5.10 的 fake-state/policy 实现。`hooks.c` 将 app UID 的 `current` context 写入路由到固定版 BakaSU 的 `my_setprocattr`。基线 AVC audit fake identity 已与 SUSFS 2.3 行为相符，因此不重复改写。

## 验证与限制

已通过构建脚本语法、Python 编译、固定版 BakaSU Kconfig 正向验证及 2.4 符号负向验证、`git diff --check`，以及 2.4-only AVD/priority UID filter/扩展 KSTAT 静态扫描。另对照官方 2.3 patch 检查了关键调用点；5.4 的差异包括 `namei`/`stat` API 与 `proc_namespace` 的 `show_options2` 分支。隔离构建使用 apt.llvm.org LLVM 21.1.8 fallback，成功生成 arm64 `Image` 和 AnyKernel3 ZIP；SHA256 校验文件的三项均通过，ZIP 内部完整性测试通过，配置中的 KSU 和全部 SUSFS 2.3 功能符号均为 `y`。AOSP Clang sparse checkout 由于 TLS 错误未完成，但 fallback 成功，构建退出码为 0。

本地构建不等于设备验证；尚未刷写或验证启动、SELinux 策略/布尔值/AVC，以及真实相册和文件访问。`main` 以原 2.4 基点 `36fed1a7eeee519952e578c1775ab287009a7142` 为基础，仅包含 SUSFS 2.3.0 移植；用户已明确授权将远端 `main` 上该基点后的 4 个提交替换为本次 2.3.0 提交。`2.4-fix` 保持独立，不混入 2.3；其两项候选改动虽已通过 arm64 构建，但尚无设备验证，不能据此确认图库/文件访问回归已解决。

## 构建

运行 `bash scripts/build-kernel.sh`。默认产物位于 `out/`；设置 `WORK=/some/isolated/path` 和 `OUT=/some/isolated/path` 可把构建临时目录与产物放到隔离位置。GitHub Actions 手动触发后运行同一脚本。
