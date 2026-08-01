#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""Python port of scripts/export-codebase.ps1.

Exports human-readable source, configuration, workflow, test, and handoff files
into a single UTF-8 bundle. Excludes Markdown, generated/build directories,
Xcode derived data, package caches, vendor/dependency directories, the .git
directory, binary libraries/frameworks, images, archives, and the bundle itself.
Includes untracked source files, sorts by stable relative path, and prefixes
every file with a clear header. The bundle header records branch, HEAD, and the
short working-tree status. This exporter never runs tests.
"""
from __future__ import annotations

import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_OUTPUT = ROOT / "handoff" / "obsidian-sync-ios-codebase.txt"

EXCLUDED_DIRS = {
    ".git", ".build", ".swiftpm", ".xcodeproj", ".xcworkspace", "build", "Build",
    "DerivedData", "xcuserdata", "node_modules", "vendor", "coverage",
    ".coverage", ".pytest_cache", "__pycache__",
}
EXCLUDED_EXTS = {
    ".md", ".markdown", ".png", ".jpg", ".jpeg", ".gif", ".webp", ".pdf",
    ".zip", ".tar", ".gz", ".7z", ".a", ".o", ".dylib", ".so", ".dll", ".exe",
    ".pdb", ".xcframework",
}


def git(*args: str) -> str:
    r = subprocess.run(["git", *args], cwd=str(ROOT), capture_output=True, text=True)
    return r.stdout.strip()


def relative(path: Path) -> str:
    return path.relative_to(ROOT).as_posix()


def is_excluded(path: Path) -> bool:
    parts = path.relative_to(ROOT).parts
    if any(part in EXCLUDED_DIRS for part in parts):
        return True
    return path.suffix.lower() in EXCLUDED_EXTS


def main(output: Path = DEFAULT_OUTPUT) -> int:
    output = output.resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    files = sorted(
        (p for p in ROOT.rglob("*") if p.is_file() and not is_excluded(p) and p.resolve() != output),
        key=relative,
    )
    branch = git("branch", "--show-current")
    head = git("log", "-1", "--pretty=format:%H %s")
    status = git("status", "--short") or "clean"
    lines: list[str] = [
        "OBSIDIAN SYNC IOS - SOURCE HANDOFF BUNDLE",
        f"Generated: {__import__('datetime').datetime.now().astimezone().isoformat()}",
        f"Repository: {ROOT}",
        f"Branch: {branch}",
        f"HEAD: {head}",
        "Working tree status:",
        status,
        f"Files included: {len(files)}",
        "Markdown, generated/build directories, and binary assets are intentionally excluded.",
        "=" * 80,
    ]
    for path in files:
        rel = relative(path)
        lines.append("=" * 80)
        lines.append(f"FILE: {rel}")
        lines.append("=" * 80)
        try:
            lines.append(path.read_text(encoding="utf-8", errors="replace"))
        except OSError as exc:
            lines.append(f"<unreadable: {exc}>")
        lines.append("")
    output.write_text("\n".join(lines), encoding="utf-8", newline="\n")
    print(f"Exported {len(files)} source/configuration files to {output}")
    return 0


if __name__ == "__main__":
    target = Path(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT_OUTPUT
    raise SystemExit(main(target))
