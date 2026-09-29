#!/bin/bash
# a fastmcp server package
set -e
mkdir -p src/donors_mcp tests
cat > pyproject.toml <<'J'
[project]
name = "donors-mcp"
version = "0.1.0"
requires-python = ">=3.11"
dependencies = ["mcp>=1.14,<2"]

[project.scripts]
donors-mcp = "donors_mcp.server:main"

[build-system]
requires = ["hatchling"]
build-backend = "hatchling.build"
J
cat > src/donors_mcp/__init__.py <<'J'
J
cat > src/donors_mcp/data.py <<'J'
DONORS = {
    "ana@example.org": {"name": "Ana Reyes", "gifts_cents": [2500, 10000]},
    "ben@example.org": {"name": "Ben Ode", "gifts_cents": []},
}
J
cat > src/donors_mcp/server.py <<'J'
from mcp.server.fastmcp import FastMCP

from donors_mcp.data import DONORS

mcp = FastMCP("donors")


@mcp.tool()
def count_donors() -> int:
    """How many donors are on file."""
    return len(DONORS)


def main() -> None:
    mcp.run()
J
git init -q && git add -A && git -c user.email=e@e -c user.name=e commit -qm init
