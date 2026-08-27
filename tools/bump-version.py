#!/usr/bin/env python3
"""Поднять <Version> в src/cf/Configuration.xml (формат YYMMDD.XX).

Канон: docs/ai/versioning.md
"""
from __future__ import annotations

import argparse
import datetime
import re
import subprocess
import sys
from pathlib import Path

REPO_REL = Path("src/cf/Configuration.xml")
VERSION_RE = re.compile(r"(<Version>)([^<]*)(</Version>)")
YYMMDD_RE = re.compile(r"\d{6}(?:\.\d+)?")


def next_version(current: str, today: str) -> str:
    current = (current or "").strip()
    date, seq = "000000", 0
    if YYMMDD_RE.fullmatch(current):
        parts = current.split(".")
        date = parts[0]
        seq = int(parts[1]) if len(parts) > 1 else 0
    if date == today:
        return f"{today}.{seq + 1:02d}"
    return f"{today}.01"


def extract_version(xml: str) -> str:
    m = VERSION_RE.search(xml)
    if not m:
        raise SystemExit(f"нет <Version> в {REPO_REL.as_posix()}")
    return m.group(2)


def replace_version(xml: str, new: str) -> str:
    new_xml, n = VERSION_RE.subn(rf"\g<1>{new}\g<3>", xml, count=1)
    if n != 1:
        raise SystemExit(f"не удалось заменить <Version> в {REPO_REL.as_posix()}")
    return new_xml


def version_from_head(rel: Path) -> str | None:
    r = subprocess.run(
        ["git", "show", f"HEAD:{rel.as_posix()}"],
        capture_output=True,
        text=True,
        encoding="utf-8",
    )
    if r.returncode != 0:
        return None
    return extract_version(r.stdout)


def today_yymmdd() -> str:
    return datetime.date.today().strftime("%y%m%d")


def self_test() -> None:
    assert next_version("260209.01", "260827") == "260827.01"
    assert next_version("260827.01", "260827") == "260827.02"
    assert next_version("260827.09", "260827") == "260827.10"
    assert next_version("", "260827") == "260827.01"
    assert next_version("1.0", "260827") == "260827.01"
    assert next_version("260827", "260827") == "260827.01"
    xml = "\t\t\t<Version>260209.01</Version>\n"
    assert extract_version(xml) == "260209.01"
    assert replace_version(xml, "260827.01") == "\t\t\t<Version>260827.01</Version>\n"
    print("ok")


def main() -> int:
    p = argparse.ArgumentParser(description="Bump configuration <Version> YYMMDD.XX")
    p.add_argument("--dry-run", action="store_true", help="печатать, не писать")
    p.add_argument("--print", action="store_true", dest="print_current", help="текущая версия файла")
    p.add_argument("--self-test", action="store_true")
    args = p.parse_args()

    if args.self_test:
        self_test()
        return 0

    root = Path(
        subprocess.check_output(
            ["git", "rev-parse", "--show-toplevel"], text=True, encoding="utf-8"
        ).strip()
    )
    path = root / REPO_REL
    if not path.is_file():
        raise SystemExit(f"нет файла {path}")

    raw = path.read_bytes()
    xml = raw.decode("utf-8")
    file_ver = extract_version(xml)

    if args.print_current:
        print(file_ver)
        return 0

    today = today_yymmdd()
    base = version_from_head(REPO_REL) or file_ver
    new = next_version(base, today)

    if file_ver == new:
        print(f"{file_ver} (уже)")
        return 0

    print(f"{file_ver} -> {new}")
    if args.dry_run:
        return 0

    path.write_bytes(replace_version(xml, new).encode("utf-8"))
    return 0


if __name__ == "__main__":
    sys.exit(main())
