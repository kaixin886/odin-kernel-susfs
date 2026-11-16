#!/usr/bin/env python3
"""Add the SUSFS v2.4 Kconfig entries missing from the BakaSU tree.

sync-up era BakaSU already carries KSU_SUSFS_PRIORITY_UID_FILTER natively;
only KSU_SUSFS_AVD is still missing. Handle each symbol independently:
validate any existing block (must depend on KSU_SUSFS and default y),
append only the missing ones before the closing menu pair.
"""

from pathlib import Path
import sys

SYMBOLS = {
    "KSU_SUSFS_AVD": '''config KSU_SUSFS_AVD
    bool "Enable SUSFS AVD and sus_type rules"
    depends on KSU_SUSFS
    default y
''',
    "KSU_SUSFS_PRIORITY_UID_FILTER": '''config KSU_SUSFS_PRIORITY_UID_FILTER
    bool "Enable SUSFS priority UID filter"
    depends on KSU_SUSFS
    default y
''',
}


def block_of(text: str, symbol: str) -> str:
    start = text.index(f"config {symbol}\n")
    end = text.find("\nconfig ", start + 1)
    if end < 0:
        end = text.find("\nendmenu", start + 1)
    return text[start:end if end >= 0 else len(text)]


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit(f"usage: {sys.argv[0]} <BakaSU-kernel-Kconfig>")

    path = Path(sys.argv[1])
    text = path.read_text()

    missing = []
    for symbol in SYMBOLS:
        count = text.count(f"config {symbol}\n")
        if count > 1:
            raise SystemExit(f"duplicated SUSFS Kconfig entry: {symbol}")
        if count == 1:
            block = block_of(text, symbol)
            if "depends on KSU_SUSFS" not in block or "default y" not in block:
                raise SystemExit(
                    f"existing {symbol} lacks the expected SUSFS dependency/default")
            print(f"{symbol}: already present, block OK")
        else:
            missing.append(symbol)

    if not missing:
        print("BakaSU SUSFS v2.4 Kconfig entries already present")
        return

    if text.count('menu "KernelSU - SUSFS"') != 1:
        raise SystemExit("expected exactly one KernelSU - SUSFS menu")
    anchor = "\nendmenu\n\nendmenu\n"
    if text.count(anchor) != 1:
        raise SystemExit("expected the unique closing SUSFS/KernelSU menu pair")

    additions = "\n" + "".join(SYMBOLS[s] + "\n" for s in missing)
    text = text.replace(anchor, additions + anchor.lstrip("\n"), 1)
    # The replace above consumed the anchor's leading newline layout;
    # rebuild precisely: additions end with a blank line, then the pair.
    for symbol in SYMBOLS:
        if text.count(f"config {symbol}\n") != 1:
            raise SystemExit(f"Kconfig symbol {symbol} not present exactly once")
    path.write_text(text)
    print("added " + " and ".join(missing))


if __name__ == "__main__":
    main()
