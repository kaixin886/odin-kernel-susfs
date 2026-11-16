# 下一轮构建备料（2.4＋最新 BakaSU＋动态优化＋熄屏档）

定案（2026-11-16 13:03 用户）：基线 SUSFS 2.4（本仓线），BakaSU 换最新版，
动态优化层合并进来，Cue 清单第 3/4 项（熄屏关 boost、熄屏限频档）做成可开关；
旧动态包（odin-kernel run 39）搁置不测。ReKernel 不内建（12:33 定案，KP 模块顶）。

## BakaSU：548d1dda → sync-up 252b15203940c00570c65c0d33db12d9e76c4dff

兼容核对（2026-11-16 已完成，本地 resukisu 克隆实证）：
- 移植层需要的 5 个 extern（ksu_selinux_hide_running / _enabled、fake_status、
  fake_status_initialize_key、initialize_fake_status）在 sync-up 的
  kernel/feature/selinux_hide.c 全部仍在 ✓
- **登记调用已随上游同步进 sync-up**：sepolicy.c 第 22-23 行 extern 声明、
  add_rule_raw 内第 351 行 susfs_add_sus_avd_allowed_by_type、
  add_type 内第 778 行 susfs_add_sus_type → LSPosed 暴露缺口本轮自动闭合 ✓
- 8 个 inline hook 处理函数（ksu_handle_*）在 sync-up 全部存在 ✓
- Kconfig：PRIORITY_UID_FILTER 已原生（块含 depends on KSU_SUSFS＋default y），
  KSU_SUSFS_AVD 仍缺 → 旧 helper 遇「一个有一个没有」会硬失败，已重写
  （prep-opt/add-bakasu-susfs-kconfig.py，逐符号独立处理，已对 sync-up
  Kconfig 实测：只补 AVD、重复运行幂等）✓
- setup.sh 接口不变（commit-or-tag 参数）✓
- BAKASU_REF 改 252b15203940c00570c65c0d33db12d9e76c4dff（sync-up 是活动分支，
  钉 SHA 保证可复现；内核侧版本号约 35261，与测试版管理器同线）

## 构建脚本改动清单（对 scripts/build-kernel.sh）

1. BAKASU_REF 换 sync-up SHA（上）。
2. scripts/add-bakasu-susfs-kconfig.py 换 prep-opt 的新版。
3. BakaSU 集成与 port/out 覆盖之后、defconfig 之前，加优化层：
   - 拷贝 prep 备料 drivers/wakelock-blocker（自 odin-kernel/prep-rekernel-opt，
     需复制一份进本仓，如 prep-opt/drivers/wakelock-blocker）＋应用
     wakelock-blocker-callsites.patch（锚点须按 CI 真实顺序在 post-BakaSU 树上
     重验——旧教训：setup.sh 先改 drivers/Kconfig、drivers/Makefile 文件尾；
     本地 sim 全序模拟通过才算数）＋4 道 grep 审计（hook 在场、Kconfig 接线、
     Makefile 接线、默认名单为空）。
   - 熄屏档驱动（见下，待 sim 树上设计验证后落）。
4. defconfig 之后、olddefconfig 之前，加动态配置层（照搬旧仓 battery 层）：
   scripts/config --disable CPU_FREQ_DEFAULT_GOV_PERFORMANCE
   --enable CPU_FREQ_DEFAULT_GOV_SCHEDUTIL --enable TCP_CONG_ADVANCED
   --enable TCP_CONG_BBR --enable DEFAULT_BBR --disable DEFAULT_CUBIC
   --enable IDLE_PAGE_TRACKING --enable BOEFFLA_WL_BLOCKER
   （＋熄屏档的 CONFIG，默认关或默认开待设计定）
   rcu_nocbs：CONFIG_CMDLINE 追加 " rcu_nocbs=0-7"（CMDLINE_EXTEND 既有）。
   zram：zram_drv.c default_compressor 字面量 lzo-rle → lz4（python 断言替换）。
5. olddefconfig 后硬审计（照搬旧仓）：SCHEDUTIL 默认、HZ=250、BBR/DEFAULT_BBR、
   IDLE_PAGE_TRACKING、CMDLINE 含 rcu_nocbs、BOEFFLA_WL_BLOCKER=y；
   保留既有 KSU_SUSFS_AVD/PRIORITY_UID_FILTER=y 审计。
6. 产物名：沿用 odin-susfs-v2.4.0-bakasu（或加 -opt 后缀区分，推送前定）。

## 熄屏两项（Cue 3/4）设计要点（待 sim 树验证）

- 目标：sysfs 可开关、默认关（关＝等于没装，用户既定偏好）；熄屏持续空闲
  一段时间后压低各 cluster 的 CPU 最高频（freq_qos 压 max，不碰 min），
  亮屏立即恢复；输入 boost 在熄屏期一并关（先查本树 boost 载体：
  cpu_input_boost / msm_performance / power HAL perf_lock 哪条在本树生效）。
- 载体候选：fb_notifier（或 drm_panel_notifier）＋delayed_work＋per-policy
  freq_qos_add_request(FREQ_QOS_MAX)。来电/闹钟都会点亮屏幕，unblank 恢复
  即覆盖 Cue 的「立即恢复」要求。
- 频率上限不拍脑袋：sysfs 给每 cluster 的 cap 值，默认给保守档，
  刷后按实测逐档下试（Cue 第 4 项原话）。

## 刷后验收（Cue 1/2＋既有清单）

- BakaSU 工作中、SuSFS v2.4.0、Termux su、NoActive 经 KP 重挂 ReKernel 后已连接
- Duck 复测：LSPosed 卡应回落到仅 logcat 乌龙（登记表已喂）
- scaling_governor=schedutil（且查 Power HAL/Scene 没改掉）、/proc/cmdline 含 rcu_nocbs=0-7
- Scene 里 zram 对齐 lz4＋16384
- 过夜抓唤醒源：%/h 对 0.9 基线、wakeup_sources、suspend_stats、cpuidle 驻留
  （Cue 第 2 项；wakelock 名单仍空，等这批数据再定点）
