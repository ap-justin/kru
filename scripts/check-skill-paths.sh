#!/bin/bash
# Every local skills/<name>/... path referenced in docs must exist under the plugin root.
set -euo pipefail
cd "$(dirname "$0")/.." || exit 2
root=$PWD

exec python3 - "$root" << 'PY'
import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
skills_root = root / "skills"
known_tops = {p.name for p in skills_root.iterdir() if p.is_dir()} if skills_root.is_dir() else set()

# paths like skills/foo/bar — first segment must be a real skill dir
LOCAL = re.compile(
    r"(?<!(?:\.claude/))(?<![\w./])"
    r"(skills/[a-z0-9][a-z0-9-]*(?:/[A-Za-z0-9_.-]+)*)"
)

SCAN_ROOTS = [
    root / "skills",
    root / "references",
    root / "hooks",
    root / "scripts",
]
SCAN_FILES = [
    root / "ROSTER.md",
    root / "README.md",
    root / "SOURCES.md",
    root / "TRACKER.md",
    root / "PREFERENCES.md",
]

def iter_files():
    for base in SCAN_ROOTS:
        if not base.is_dir():
            continue
        for p in base.rglob("*"):
            if p.suffix in {".md", ".sh"} and p.is_file():
                if p.name.endswith(".test.sh") and "check-skill-paths" in p.name:
                    continue
                yield p
    for p in SCAN_FILES:
        if p.is_file():
            yield p

def clean(path: str) -> str:
    return path.rstrip(".,;:)`\"'")

fail = 0
seen = set()

for f in iter_files():
    try:
        text = f.read_text(encoding="utf-8")
    except OSError:
        continue
    for m in LOCAL.finditer(text):
        path = clean(m.group(1))
        if path.endswith("...") or "/..." in path:
            continue
        if "main/skills" in path or "/blob/" in path:
            continue
        top = path.split("/", 2)[1] if path.startswith("skills/") else ""
        if top not in known_tops:
            continue
        key = (path, str(f.relative_to(root)))
        if key in seen:
            continue
        seen.add(key)
        full = root / path
        if not full.exists():
            print(f"missing path {path} (from {f.relative_to(root)})")
            fail = 1

sys.exit(fail)
PY
