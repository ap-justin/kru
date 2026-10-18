#!/bin/bash
# Every local skills/<name>/... path and every backticked repo path must exist and be whole tokens.
set -euo pipefail
cd "$(dirname "$0")/.." || exit 2
root=$PWD

exec python3 - "$root" << 'PY'
import os
import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
skills_root = root / "skills"
known_tops = {p.name for p in skills_root.iterdir() if p.is_dir()} if skills_root.is_dir() else set()

LOCAL = re.compile(
    r"(?<!(?:\.claude/))(?<![\w./])"
    r"(skills/[a-z0-9][a-z0-9-]*(?:/[A-Za-z0-9_.-]+)*)"
)

PREFIXES = (
    "${CLAUDE_PLUGIN_ROOT}/",
    "skills/",
    "references/",
    "scripts/",
    "agents/",
    "hooks/",
)

GARBLED = re.compile(
    r"(?i)(?:referencesthe|skillsthe|scripts/assetthe|skills`skills/|bundled the bundled|the built-in run skill\.sh)"
)

BACKTICK = re.compile(r"`([^`]+)`")

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

SKIP_FILES = {root / "scripts" / "check-skill-paths.sh"}


def iter_files():
    extra = os.environ.get("CHECK_SKILL_PATHS_EXTRA", "")
    for p in extra.split(":"):
        if p:
            fp = Path(p)
            if fp.is_file():
                yield fp
    for base in SCAN_ROOTS:
        if not base.is_dir():
            continue
        for p in base.rglob("*"):
            if p.suffix in {".md", ".sh"} and p.is_file():
                if p in SKIP_FILES:
                    continue
                if "check-skill-paths" in p.name and p.name.endswith(".test.sh"):
                    continue
                yield p
    for p in SCAN_FILES:
        if p.is_file():
            yield p


def clean(path: str) -> str:
    return path.rstrip(".,;:)`\"'")


def rel_path(f: Path) -> str:
    try:
        return str(f.relative_to(root))
    except ValueError:
        return str(f)


def is_path_like_token(token: str) -> bool:
    if "/" not in token:
        return False
    return any(token.startswith(p) for p in PREFIXES)


def is_template(token: str) -> bool:
    if any(c in token for c in "<>*{|"):
        return True
    if token.endswith("/") and token.count("/") <= 2:
        return True
    return False


def resolve_repo_path(token: str) -> Path:
    if token.startswith("${CLAUDE_PLUGIN_ROOT}/"):
        return root / token[len("${CLAUDE_PLUGIN_ROOT}/") :]
    return root / token


fail = 0
seen = set()

for f in iter_files():
    try:
        text = f.read_text(encoding="utf-8")
    except OSError:
        continue
    rel = rel_path(f)

    for m in BACKTICK.finditer(text):
        token = m.group(1)
        if not is_path_like_token(token):
            continue
        if GARBLED.search(token):
            print(f"garbled path token `{token}` (from {rel})")
            fail = 1
            continue
        if is_template(token) or re.search(r"\s", token):
            continue
        # Existence: concrete repo paths only (not agents/ metadata stubs).
        if token.startswith("${CLAUDE_PLUGIN_ROOT}/"):
            sub = token[len("${CLAUDE_PLUGIN_ROOT}/") :]
            if not sub.startswith(("skills/", "references/", "scripts/", "hooks/")):
                continue
            full = root / sub
        elif token.startswith("skills/"):
            full = root / token
        else:
            # Skill-local `references/...` backticks are relative to the skill dir — garbled-only here.
            continue
        if not full.exists():
            print(f"missing path `{token}` (from {rel})")
            fail = 1

    for m in LOCAL.finditer(text):
        path = clean(m.group(1))
        if path.endswith("...") or "/..." in path:
            continue
        if "main/skills" in path or "/blob/" in path:
            continue
        top = path.split("/", 2)[1] if path.startswith("skills/") else ""
        if top not in known_tops:
            continue
        key = (path, rel)
        if key in seen:
            continue
        seen.add(key)
        full = root / path
        if not full.exists():
            print(f"missing path {path} (from {rel})")
            fail = 1

sys.exit(fail)
PY
