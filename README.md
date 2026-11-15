# odin-kernel-susfs

将 SUSFS v2.4.0 移植到小米 MIX 4（odin）的 Inkypen 5.4 内核，并集成 BakaSU 的工作仓。已经验收的 BakaSU + SUSFS v2.1.0 位于 `kaixin886/odin-kernel`；本仓保存 v2.4 移植和可复现构建流程。

## 固定版本

- 内核基线：Inkypen `kernel_xiaomi_odin`，commit `50e0141b29b62be21632c768e4818348098ac6cd`。
- SUSFS 来源：`ShirkNeko/susfs4ksu`，commit `6dff25f2b2508f91df309e537771d612dccd201a`；`gki-android12-5.10` 的 v2.4.0 补丁。
- BakaSU：commit `548d1dda060ca198823d8808804d01f5209ef4a9`。
- AnyKernel3：固定到构建脚本中的 commit。工具链从固定的 AOSP `android-17.0.0_r1` release tag 选择；优先 `clang-r574158`，若不存在则使用该 tag 中最高版本目录，克隆失败时回退到 LLVM 21。

## 当前状态

- 25 个调用点文件均已审计：20 个需要修改的文件适配后放在 `port/out/`，另有 5 个与 v2.4.0 等价的文件保留基线版本；`port/out/` 还包括 SUSFS 核心三文件。
- SELinux 两个缺口已补：`selinuxfs.c` 中 `access` 写入处理器，以及适配 5.4 `policydb`、`sidtab` 与策略锁结构的 `security/selinux/ss/services.c`。
- 新增固定版本构建脚本、手动触发的 GitHub Actions 工作流、AnyKernel3 包装模板，以及幂等的 BakaSU Kconfig 补丁工具。缺失的 `KSU_SUSFS_AVD` 和 `KSU_SUSFS_PRIORITY_UID_FILTER` 会被添加并在配置阶段验证。
- 移植稿未复制旧 v2.1 的 `no_su` 兼容胶水。
- **从干净 pinned 源码完整构建和打包已通过**：版本为 `5.4.302-inkypen-v2`，使用 AOSP `android-17.0.0_r1` 中的 `clang-r596125`（Android Clang 22.0.2），生成 arm64 `Image` 和 AnyKernel3 ZIP。
- Image、配置与 ZIP 的 SHA-256 校验通过；ZIP 完整性检查通过，最终配置启用了 `KSU_SUSFS_AVD` 和 `KSU_SUSFS_PRIORITY_UID_FILTER`。
- 脚本语法、Kconfig 幂等/异常路径、Actions 工作流静态检查和 `git diff --check` 均已检查通过。**设备侧刷写及 SELinux 策略、布尔值、AVC 回归仍未验证。**

## 构建

在有网络、Bash、Git、Python 3、sudo 和足够磁盘空间的 Linux 环境中运行：

```bash
bash scripts/build-kernel.sh
```

脚本从固定 commit 获取内核、BakaSU 与 AnyKernel3，叠加移植稿，补齐并开启 Kconfig 选项，运行 `odin_defconfig`、`olddefconfig` 和 arm64 `Image` 构建。生成的 Image、内核配置、SHA-256 校验文件和可刷入的 AnyKernel3 ZIP 放在仓库的 `out/` 目录。GitHub Actions 也可从 Actions 页手动触发相同构建。

`port-notes.md` 记录逐文件审计、5.4 API 适配和此次 SELinux/构建接线依据。
