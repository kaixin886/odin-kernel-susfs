# odin-kernel-susfs

将 [SUSFS v2.3.0](https://gitlab.com/simonpunk/susfs4ksu/-/commit/fb16b41a65180979f05eac837681c4dd0addffd1) 移植到小米 MIX 4（odin）的 Inkypen Linux 5.4 内核，并集成固定版本的 BakaSU。当前 `main` 目标是干净、可复现的 2.3.0 移植；图库/文件可见性回归的 2.4 修复不混入此分支。

## 固定版本

- 内核基线：[Inkypen `kernel_xiaomi_odin`](https://github.com/Inkypen79/kernel_xiaomi_odin/commit/50e0141b29b62be21632c768e4818348098ac6cd)，commit `50e0141b29b62be21632c768e4818348098ac6cd`。
- SUSFS：[`simonpunk/susfs4ksu`](https://gitlab.com/simonpunk/susfs4ksu)，`gki-android12-5.10` 上的 2.3.0 commit `fb16b41a65180979f05eac837681c4dd0addffd1`。其补丁面向 5.10，移植时按 pinned 5.4 基线逐处适配；5.4 中不存在的 `fs/proc/bootconfig.c` 不创建。
- BakaSU：[commit `548d1dda`](https://github.com/Baka-SU/BakaSU/commit/548d1dda060ca198823d8808804d01f5209ef4a9)。
- AnyKernel3 固定版本及 AOSP `android-17.0.0_r1` 工具链选择逻辑见 `scripts/build-kernel.sh`。

## 5.4 适配要点

`port/out/` 包含 2.3 核心、5.4 调用点适配及 SELinux 接线。与 2.3 已匹配的基线文件保持原样，不做无必要覆盖；特别是 `fs/notify/fdinfo.c`、`fs/proc/fd.c`、`fs/readdir.c` 和 `fs/statfs.c`。fsnotify 观察器回调使用 5.4 的 `handle_event`/`iter_info` 接口；`fs/stat.c` 保留 5.4 KSTAT 逻辑和 BakaSU stat hooks，不带 2.4 的扩展 KSTAT。

经过对照 2.3 patch 核对，`fs/proc/base.c`、`kernel/kallsyms.c`、`mm/memory.c`、`security/selinux/avc.c` 也已由 pinned 5.4 基线提供相应逻辑，因此同样不重复覆盖。

SELinux fake status/access/context 路径接入 pinned BakaSU 的 helper，不再覆盖 5.4 的 `security/selinux/ss/services.c`，也不引入 2.4 自定义 `ss/susfs.h`。基线 AVC audit fake identity 已与 2.3 逻辑相符，因此不重复改写。

BakaSU 固定版已经包含 2.3 所需的 Kconfig 选项。配置检查器验证这些选项，并拒绝 2.4 的 AVD 和 priority UID filter 选项。

## 构建与验证

```bash
bash scripts/build-kernel.sh
```

脚本从固定 commit 获取内核、BakaSU 与 AnyKernel3，叠加移植、运行 `odin_defconfig`/`olddefconfig` 并构建 arm64 `Image`，随后打包 AnyKernel3 ZIP。默认产物写入仓库 `out/`。也可将 `WORK` 和 `OUT` 指向隔离目录，以避免覆盖已有构建文件；手动触发的 GitHub Actions 运行相同流程。

已通过脚本语法、Kconfig 固定版正负验证、`git diff --check` 与 2.4-only API 扫描。完整隔离构建使用 apt.llvm.org LLVM 21.1.8 fallback 成功生成 arm64 `Image` 和 AnyKernel3 ZIP；SHA256 校验和 ZIP 完整性检查均通过。AOSP Clang sparse checkout 遇到 TLS 错误，但未妨碍 fallback 构建。设备侧刷写、启动、SELinux 策略/AVC 与图库/文件访问仍需真机回归，不能以本地构建代替。

`port-notes.md` 记录来源、5.4 适配决策、静态检查和构建验证结果。
