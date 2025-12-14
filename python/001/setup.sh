#!/usr/bin/env bash
set -euo pipefail

mode="${1:?usage: ./setup.sh <on|off>}"

mkdir -p "$mode"
rm -rf "$mode/repo" "$mode/artifacts"
mkdir -p "$mode/repo" "$mode/artifacts"

cd "$mode/repo"

git init -q
git checkout -b main -q

mkdir -p src tests

touch src/__init__.py

cat > src/calc.py <<'PY'
def add(a: int, b: int) -> int:
    return a + b
PY

cat > tests/test_smoke.py <<'PY'
import unittest

from src.calc import add


class TestSmoke(unittest.TestCase):
    def test_add_smoke(self):
        self.assertEqual(add(1, 2), 3)


if __name__ == "__main__":
    unittest.main()
PY

git add .
git commit -m "baseline" -q

echo "ok"
