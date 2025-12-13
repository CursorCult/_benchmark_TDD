#!/usr/bin/env bash
set -euo pipefail

mode="${1:?usage: ./setup.sh <on|off>}"

mkdir -p "$mode"
rm -rf "$mode/repo" "$mode/artifacts"
mkdir -p "$mode/repo" "$mode/artifacts"

cd "$mode/repo"

git init -q
git checkout -b main -q

cat > pyproject.toml <<'TOML'
[project]
name = "tdd_bench_case_001"
version = "0.0.0"
requires-python = ">=3.10"
dependencies = []

[tool.pytest.ini_options]
testpaths = ["tests"]
addopts = "-q"
TOML

cat > requirements-dev.txt <<'REQ'
pytest==8.3.3
coverage==7.6.1
REQ

mkdir -p src tests

cat > src/calc.py <<'PY'
def add(a: int, b: int) -> int:
    return a + b
PY

cat > tests/test_smoke.py <<'PY'
from src.calc import add


def test_add_smoke():
    assert add(1, 2) == 3
PY

git add .
git commit -m "baseline" -q

echo "ok"

