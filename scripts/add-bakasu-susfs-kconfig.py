#!/usr/bin/env python3
"""Add the SUSFS v2.4 Kconfig entries missing from the pinned BakaSU tree."""

from pathlib import Path
import sys


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit(f"usage: {sys.argv[0]} <BakaSU-kernel-Kconfig>")

    path = Path(sys.argv[1])
    text = path.read_text()
    symbols = ("KSU_SUSFS_AVD", "KSU_SUSFS_PRIORITY_UID_FILTER")
    present = {symbol: text.count(f"config {symbol}\n") for symbol in symbols}

    if all(count == 1 for count in present.values()):
        for symbol in symbols:
            start = text.index(f"config {symbol}\n")
            end = text.find("\nconfig ", start + 1)
            if end < 0:
                end = text.find("\nendmenu", start + 1)
            block = text[start:end if end >= 0 else len(text)]
            if "depends on KSU_SUSFS" not in block or "default y" not in block:
                raise SystemExit(f"existing {symbol} lacks the expected SUSFS dependency/default")
        print("BakaSU SUSFS v2.4 Kconfig entries already present")
        return
    if any(present.values()):
        raise SystemExit(f"partial or duplicated SUSFS Kconfig patch detected: {present}")

    menu = 'menu "KernelSU - SUSFS"'
    if text.count(menu) != 1:
        raise SystemExit("expected exactly one KernelSU - SUSFS menu")
    if text.count('config KSU_SUSFS_SUS_MAP\n') != 1:
        raise SystemExit("expected exactly one KSU_SUSFS_SUS_MAP anchor")

    anchor = "\nendmenu\n\nendmenu\n"
    if text.count(anchor) != 1:
        raise SystemExit("expected the unique closing SUSFS/KernelSU menu pair")

    additions = """
config KSU_SUSFS_AVD
    bool "Enable SUSFS AVD and sus_type rules"
    depends on KSU_SUSFS
    default y

config KSU_SUSFS_PRIORITY_UID_FILTER
    bool "Enable SUSFS priority UID filter"
    depends on KSU_SUSFS
    default y
"""
    text = text.replace(anchor, "\n" + additions + anchor, 1)
    if any(text.count(f"config {symbol}\n") != 1 for symbol in symbols):
        raise SystemExit("Kconfig symbols were not inserted exactly once")
    path.write_text(text)
    print("added KSU_SUSFS_AVD and KSU_SUSFS_PRIORITY_UID_FILTER")


if __name__ == "__main__":
    main()
