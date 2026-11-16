#!/usr/bin/env bash
# Reproducible Xiaomi MIX 4 (odin) 5.4 kernel build with BakaSU + SUSFS v2.3.0.
# Run from any directory; artifacts are written to <repo>/out/.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="${WORK:-$ROOT/work}"
OUT="${OUT:-$ROOT/out}"
KSRC="$WORK/kernel"
KOUT="$WORK/kout"
TOOLBIN="$WORK/toolchain/bin"

KERNEL_URL="https://github.com/Inkypen79/kernel_xiaomi_odin.git"
KERNEL_REF="50e0141b29b62be21632c768e4818348098ac6cd"
BAKASU_REF="548d1dda060ca198823d8808804d01f5209ef4a9"
BAKASU_URL="https://github.com/Baka-SU/BakaSU.git"
CLANG_WANT="clang-r574158"
AK3_REF="41f04bdb4ee30a44e429c2c1131d5e8bb32b15f1"
JOBS="${JOBS:-$(nproc)}"

step() { printf '\n===== %s =====\n' "$*"; }
fail() { echo "ERROR: $*" >&2; exit 1; }

[[ -d "$ROOT/port/out" ]] || fail "run this script from the repository checkout"
[[ -f "$ROOT/port/out/security/selinux/selinuxfs.c" ]] || fail "missing completed selinuxfs.c port"
[[ -f "$ROOT/port/out/security/selinux/hooks.c" ]] || fail "missing 5.4 SELinux setprocattr integration"
[[ -f "$ROOT/port/out/fs/susfs.c" ]] || fail "missing SUSFS core"

if [[ "${INSTALL_DEPS:-1}" == 1 ]]; then
  step "install host build dependencies"
  sudo apt-get update -qq
  sudo apt-get install -y -qq --no-install-recommends \
    bc bison flex libssl-dev libelf-dev libdw-dev dwarves lsb-release software-properties-common \
    cpio zip unzip rsync python3 git curl wget xz-utils zstd patch \
    build-essential gcc-aarch64-linux-gnu
fi

# Always start from clean pinned trees/configuration; never reuse a partially
# patched kernel tree after a failed build.
rm -rf "$KSRC" "$KOUT" "$WORK/clang-prebuilts" "$WORK/ak3"
rm -rf "$OUT"
mkdir -p "$WORK" "$OUT" "$TOOLBIN"

step "fetch pinned Inkypen 5.4 susfs baseline"
git init -q "$KSRC"
git -C "$KSRC" remote add origin "$KERNEL_URL"
git -C "$KSRC" fetch --depth=1 origin "$KERNEL_REF"
git -C "$KSRC" checkout --detach -q FETCH_HEAD
[[ "$(git -C "$KSRC" rev-parse HEAD)" == "$KERNEL_REF" ]] || fail "kernel checkout is not the pinned $KERNEL_REF"
: > "$KSRC/.scmversion"

step "fetch AOSP clang ($CLANG_WANT preferred)"
CLANG_HOME=""
if git -c http.version=HTTP/1.1 clone --depth 1 --filter=blob:none --sparse --branch android-17.0.0_r1 \
    https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86 \
    "$WORK/clang-prebuilts" 2>"$WORK/clang-clone.log"; then
  cd "$WORK/clang-prebuilts"
  mapfile -t CLANG_DIRS < <(git ls-tree --name-only HEAD | grep -E '^clang-r[0-9]+$' | sort -V)
  PICK=""
  for candidate in "${CLANG_DIRS[@]}"; do
    [[ "$candidate" == "$CLANG_WANT" ]] && PICK="$candidate"
  done
  if [[ -z "$PICK" && ${#CLANG_DIRS[@]} -gt 0 ]]; then
    PICK="${CLANG_DIRS[-1]}"
  fi
  if [[ -n "$PICK" ]]; then
    for attempt in 1 2 3; do
      if git -c http.version=HTTP/1.1 sparse-checkout set "$PICK"; then
        CLANG_HOME="$WORK/clang-prebuilts/$PICK"
        break
      fi
      echo "AOSP clang sparse checkout attempt $attempt failed"
      [[ "$attempt" -eq 3 ]] || sleep $((attempt * 5))
    done
  fi
  cd "$ROOT"
else
  echo "AOSP clang sparse clone failed; see $WORK/clang-clone.log"
fi

if [[ -z "$CLANG_HOME" || ! -x "$CLANG_HOME/bin/clang" ]]; then
  step "fallback to apt.llvm.org clang 21"
  wget -q https://apt.llvm.org/llvm.sh -O "$WORK/llvm.sh"
  sudo bash "$WORK/llvm.sh" 21
  sudo apt-get install -y -qq lld-21 llvm-21
  CLANG_HOME="/usr/lib/llvm-21"
fi
for tool in "$CLANG_HOME/bin/"*; do
  [[ -e "$tool" ]] && ln -sf "$tool" "$TOOLBIN/$(basename "$tool")"
done
if [[ ! -e "$TOOLBIN/clang" ]]; then
  for tool in clang clang++ ld.lld llvm-ar llvm-nm llvm-objcopy llvm-objdump llvm-strip llvm-as; do
    source_tool="$(command -v "$tool-21" || true)"
    [[ -n "$source_tool" ]] && ln -sf "$source_tool" "$TOOLBIN/$tool"
  done
fi
export PATH="$TOOLBIN:$PATH"
clang --version | head -2

MAKE_ARGS=(
  -C "$KSRC" O="$KOUT" ARCH=arm64
  CC=clang HOSTCC=clang HOSTCXX=clang++
  CLANG_TRIPLE=aarch64-linux-gnu-
  CROSS_COMPILE=aarch64-linux-gnu-
  LD=ld.lld AR=llvm-ar NM=llvm-nm
  OBJCOPY=llvm-objcopy OBJDUMP=llvm-objdump STRIP=llvm-strip
)

step "integrate pinned BakaSU"
curl -fsSL "https://raw.githubusercontent.com/Baka-SU/BakaSU/$BAKASU_REF/kernel/setup.sh" \
  -o "$WORK/bakasu-setup.sh"
(cd "$KSRC" && bash "$WORK/bakasu-setup.sh" "$BAKASU_REF")
[[ -d "$KSRC/KernelSU/.git" ]] || fail "BakaSU setup did not create KernelSU git checkout"
git -C "$KSRC/KernelSU" checkout --detach -q "$BAKASU_REF"
[[ "$(git -C "$KSRC/KernelSU" rev-parse HEAD)" == "$BAKASU_REF" ]] || fail "BakaSU checkout is not pinned"

step "overlay the SUSFS v2.3.0 port"
cp -a "$ROOT/port/out/." "$KSRC/"
grep -q 'SUSFS_VERSION "v2.3.0"' "$KSRC/include/linux/susfs.h" || fail "overlay is not SUSFS v2.3.0"
for required in \
  fs/susfs.c security/selinux/selinuxfs.c security/selinux/hooks.c \
  fs/exec.c fs/namei.c fs/namespace.c fs/stat.c \
  fs/proc/task_mmu.c fs/proc_namespace.c kernel/sys.c; do
  [[ -s "$KSRC/$required" ]] || fail "missing overlay file $required"
done
grep -q 'susfs_is_current_proc_umounted_for_zygote_next' "$ROOT/port/out/fs/namespace.c" || fail "missing SUSFS 2.3 zygote-next mount filter"
if grep -RqsE 'KSU_SUSFS_AVD|KSU_SUSFS_PRIORITY_UID_FILTER|susfs_is_priority_uid_filtered|susfs_is_uid_allowed_for_sus_path|susfs_is_inode_sus_kstat|susfs_sus_kstat_spoof_proc_fd_seq_show|susfs_statfs_by_dentry|calculate_f_flags_wrapper|STATX_SUS_KSTAT_FUSE|susfs_is_inode_sus_type|SUSFS_IS_INODE_SUS_TYPE' "$ROOT/port/out"; then
  fail "2.4-only AVD, UID-filter, or extended KSTAT code remains in the v2.3 overlay"
fi

step "add 5.4 BakaSU compatibility export"
python3 - "$KSRC/fs/namespace.c" <<'PYEOF'
import sys
from pathlib import Path

path = Path(sys.argv[1])
source = path.read_text()
if "EXPORT_SYMBOL(do_mount);" in source:
    print("fs/namespace.c: do_mount export already present")
    raise SystemExit(0)
anchor = "long do_mount(const char *dev_name, const char __user *dir_name,"
if source.count(anchor) != 1:
    raise SystemExit("ERROR: expected exactly one 5.4 do_mount definition")
start = source.index(anchor)
end = source.find("\n}\n", start)
if end < 0:
    raise SystemExit("ERROR: could not find end of do_mount definition")
end += len("\n}\n")
source = source[:end] + "EXPORT_SYMBOL(do_mount);\n" + source[end:]
path.write_text(source)
print("exported do_mount for BakaSU's pre-5.9 mount compatibility path")
PYEOF

step "validate pinned BakaSU SUSFS v2.3 Kconfig features"
python3 "$ROOT/scripts/add-bakasu-susfs-kconfig.py" "$KSRC/KernelSU/kernel/Kconfig"

step "audit BakaSU/SUSFS wiring"
[[ -L "$KSRC/drivers/kernelsu" ]] || fail "drivers/kernelsu is not the BakaSU symlink"
[[ "$(readlink -f "$KSRC/drivers/kernelsu/Kconfig")" == "$(readlink -f "$KSRC/KernelSU/kernel/Kconfig")" ]] || fail "BakaSU Kconfig symlink does not resolve to pinned source"
if grep -q 'bakasu-wired' "$KSRC/KernelSU/kernel/compat/kernel_compat.c" "$KSRC/include/linux/susfs_def.h"; then
  fail "v2.1-only compatibility glue was copied into the v2.3 build"
fi
for hook in \
  ksu_handle_setresuid ksu_handle_execveat ksu_handle_faccessat \
  ksu_handle_stat ksu_handle_vfs_fstat ksu_handle_sys_read \
  ksu_handle_sys_reboot ksu_handle_input_handle_event; do
  grep -Rqs "$hook" "$KSRC/fs" "$KSRC/kernel" "$KSRC/drivers/input" || fail "missing BakaSU inline hook call site: $hook"
done
for hook in my_setprocattr my_write_context my_write_access; do
  grep -Rqs "$hook" "$KSRC/security/selinux" "$KSRC/KernelSU/kernel/feature/selinux_hide.c" || fail "missing BakaSU SELinux helper wiring: $hook"
done

step "configure odin_defconfig"
make "${MAKE_ARGS[@]}" odin_defconfig
CFG="$KOUT/.config"
"$KSRC/scripts/config" --file "$CFG" \
  --enable KSU --enable KPROBES --enable KALLSYMS_ALL \
  --enable EXT4_FS --enable HEADERS_INSTALL \
  --enable KSU_SUSFS --enable KSU_SUSFS_SUS_PATH \
  --enable KSU_SUSFS_SUS_MOUNT --enable KSU_SUSFS_SUS_KSTAT \
  --enable KSU_SUSFS_OPEN_REDIRECT --enable KSU_SUSFS_SUS_MAP
make "${MAKE_ARGS[@]}" olddefconfig
for config in CONFIG_KSU CONFIG_KSU_SUSFS CONFIG_KSU_SUSFS_SUS_PATH \
  CONFIG_KSU_SUSFS_SUS_MOUNT CONFIG_KSU_SUSFS_SUS_KSTAT \
  CONFIG_KSU_SUSFS_OPEN_REDIRECT CONFIG_KSU_SUSFS_SUS_MAP; do
  grep -q "^$config=y$" "$CFG" || fail "$config was dropped by olddefconfig"
done

step "install UAPI headers for BakaSU preinit codegen"
make "${MAKE_ARGS[@]}" headers_install
test -f "$KOUT/usr/include/linux/unistd.h" || fail "headers_install did not produce linux/unistd.h"

step "build arm64 Image (jobs=$JOBS)"
make "${MAKE_ARGS[@]}" -j"$JOBS" Image

step "collect kernel artifacts"
cp "$KOUT/arch/arm64/boot/Image" "$OUT/Image"
cp "$CFG" "$OUT/kernel.config"
grep -o '"[^"]*"' "$KOUT/include/generated/utsrelease.h" | head -1 | tr -d '"' > "$OUT/utsrelease.txt" || true

step "package AnyKernel3 for odin / Horizon Kernel Flasher"
AK3_DIR="$WORK/ak3"
mkdir -p "$AK3_DIR"
git -C "$AK3_DIR" init -q
git -C "$AK3_DIR" remote add origin https://github.com/osm0sis/AnyKernel3.git
git -C "$AK3_DIR" fetch -q --depth=1 origin "$AK3_REF"
git -C "$AK3_DIR" checkout -q --detach FETCH_HEAD
rm -rf "$AK3_DIR/.git" "$AK3_DIR/.github"
cp "$ROOT/scripts/ak3/anykernel.sh" "$AK3_DIR/anykernel.sh"
cp "$OUT/Image" "$AK3_DIR/Image"
(cd "$AK3_DIR" && zip -r -q "$OUT/odin-susfs-v2.3.0-bakasu-ak3.zip" .)
(cd "$OUT" && sha256sum Image kernel.config odin-susfs-v2.3.0-bakasu-ak3.zip > SHA256SUMS)

step "build complete"
cat "$OUT/utsrelease.txt" || true
ls -lh "$OUT"
