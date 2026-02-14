#!/usr/bin/env python3
import json
import re
import sys
from pathlib import Path

HEADER = """{
  pkgs,
  ...
}:

{
  home.packages = with pkgs; [
"""
FOOTER = """  ];
}
"""
PACKAGE_RE = re.compile(r"^[A-Za-z0-9._+\-]+$")


def read_packages(path: Path):
    if not path.exists():
        return []

    text = path.read_text(encoding="utf-8")
    match = re.search(r"home\.packages\s*=\s*with\s+pkgs;\s*\[", text)
    if not match:
        return []

    block_start = match.end()
    closing = re.search(r"^\s*\];\s*$", text[block_start:], flags=re.MULTILINE)
    if not closing:
        return []

    body = text[block_start : block_start + closing.start()]
    packages = []
    for line in body.splitlines():
        trimmed = line.strip()
        if not trimmed or trimmed.startswith("#"):
            continue
        trimmed = trimmed.split("#", 1)[0].strip()
        trimmed = trimmed.rstrip(";, ")
        if PACKAGE_RE.match(trimmed):
            packages.append(trimmed)

    seen = set()
    unique = []
    for pkg in packages:
        if pkg not in seen:
            seen.add(pkg)
            unique.append(pkg)
    return unique


def write_packages(path: Path, packages):
    path.parent.mkdir(parents=True, exist_ok=True)
    normalized = []
    seen = set()
    for pkg in packages:
        value = str(pkg).strip()
        if not value or not PACKAGE_RE.match(value) or value in seen:
            continue
        seen.add(value)
        normalized.append(value)

    lines = [HEADER]
    for pkg in normalized:
        lines.append(f"    {pkg}\n")
    lines.append(FOOTER)
    path.write_text("".join(lines), encoding="utf-8")


def die(message: str):
    print(json.dumps({"error": message}))
    sys.exit(1)


def main():
    if len(sys.argv) < 3:
        die("usage: packages_file.py <read|write|add|remove> <path> [arg]")

    command = sys.argv[1]
    path = Path(sys.argv[2]).expanduser()

    if command == "read":
        print(json.dumps(read_packages(path)))
        return

    if command == "write":
        if len(sys.argv) < 4:
            die("write requires a JSON array argument")
        try:
            items = json.loads(sys.argv[3])
            if not isinstance(items, list):
                raise ValueError("not a list")
        except Exception as exc:
            die(f"invalid JSON array: {exc}")
        write_packages(path, items)
        print(json.dumps(read_packages(path)))
        return

    if command == "add":
        if len(sys.argv) < 4:
            die("add requires a package name")
        pkg = sys.argv[3].strip()
        if not PACKAGE_RE.match(pkg):
            die("package name contains invalid characters")
        items = read_packages(path)
        if pkg not in items:
            items.append(pkg)
            write_packages(path, items)
        print(json.dumps(read_packages(path)))
        return

    if command == "remove":
        if len(sys.argv) < 4:
            die("remove requires a package name")
        pkg = sys.argv[3].strip()
        items = [item for item in read_packages(path) if item != pkg]
        write_packages(path, items)
        print(json.dumps(read_packages(path)))
        return

    die(f"unknown command: {command}")


if __name__ == "__main__":
    main()
