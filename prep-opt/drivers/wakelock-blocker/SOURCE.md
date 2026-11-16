# Boeffla Wakelock Blocker — 来源与版本记录

- 上游：Boeffla generic wakelock blocker，作者 andip71，**v1.1.0**
  （2017-09-01，文件头与 `BOEFFLA_WL_BLOCKER_VERSION "1.1.0"` 双处实证），GPLv2。
- 本副本取自：**engstk/op7（blu_spark 血统）的
  `drivers/base/power/boeffla_wl_blocker.c` 与 `boeffla_wl_blocker.h`**
  （2026-11-15 拉取）。选此副本的理由：blu_spark 是 lahaina（OP9）现行
  仍在用此驱动的同作者血统；且该副本头文件里 `LIST_WL_DEFAULT` 已经是
  **空字符串**——与本项目「默认名单必须为空」的定案天然一致，无需改
  任何代码，只加了说明注释。
- 旁证：DerpFest-Devices/kernel_oneplus_sm8250（5.4）树内有同一
  v1.1.0 头文件（其 LIST_WL_DEFAULT 是该机型的设备名单，**未采用**）；
  Inkypen odin 树全文检索 "boeffla" 为 0，无同名符号/文件冲突。
- 与上游形态的差异（仅布局与接线，驱动代码零改动）：
  - 驱动从上游的 `drivers/base/power/` 改放 `drivers/wakelock-blocker/`，
    与 ReKernel 的进树形态对齐（自带 Kconfig/Makefile，脚本显式开启符号）；
  - Kconfig 符号沿用上游名 `BOEFFLA_WL_BLOCKER`，但 default 改为 n
    （上游为 y），由 build 脚本只对 resukisu 变体 `--enable`；
  - wakeup.c 的挂钩（全局量＋`check_for_block()`＋`report_event` 守卫）
    逐字沿用 blu_spark 的接法，落在补丁
    `patches/wakelock-blocker-callsites.patch`；wakeup.c 引用头文件走
    `<../../wakelock-blocker/boeffla_wl_blocker.h>` 相对路径，与
    ReKernel 的 `<../rekernel/rekernel.h>` 同一先例。
- 默认名单：**空**。`LIST_WL_DEFAULT ""`、用户名单初值空，搜索串为
  `";;;"`（长度 3），`build_search_string()` 据此置
  `wl_blocker_active = false`，wakeup.c 钩子直接放行——空名单时与
  现行内核行为零差异。build 脚本另有硬审计：头文件里默认名单非空
  直接 FATAL。名单启用（往 sysfs 写名字）留待真机
  `/sys/kernel/wakeup_sources` 取证后的下一轮决定，本轮不预置任何条目。
