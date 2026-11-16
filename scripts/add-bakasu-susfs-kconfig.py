#!/usr/bin/env python3
"""Validate SUSFS 2.3 Kconfig support in the pinned BakaSU source.

SUSFS 2.3 requires no extra Kconfig entries beyond the pinned BakaSU options;
this intentionally rejects the later v2.4 AVD and priority UID filter options.
"""

from pathlib import Path
import re
import sys

REQUIRED = (
    "KSU_SUSFS",
    "KSU_SUSFS_SUS_PATH",
    "KSU_SUSFS_SUS_MOUNT",
    "KSU_SUSFS_SUS_KSTAT",
    "KSU_SUSFS_OPEN_REDIRECT",
    "KSU_SUSFS_SUS_MAP",
)
FORBIDDEN = ("KSU_SUSFS_AVD", "KSU_SUSFS_PRIORITY_UID_FILTER")


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit(f"usage: {sys.argv[0]} <BakaSU-kernel-Kconfig>")

    path = Path(sys.argv[1])
    text = path.read_text()
    missing = [
        symbol
        for symbol in REQUIRED
        if len(re.findall(rf"(?m)^config {re.escape(symbol)}\s*$", text)) != 1
    ]
    forbidden = [
        symbol
        for symbol in FORBIDDEN
        if re.search(rf"(?m)^config {re.escape(symbol)}\s*$", text)
    ]
    if missing:
        raise SystemExit(f"missing or duplicate SUSFS 2.3 Kconfig symbols: {missing}")
    if forbidden:
        raise SystemExit(f"2.4-only Kconfig symbols must not be enabled in v2.3: {forbidden}")

    print("pinned BakaSU contains the expected SUSFS 2.3 Kconfig symbols; no additions needed")


if __name__ == "__main__":
    main()
