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
touch src/ds.py

cat > tests/test_smoke.py <<'PY'
import unittest
import src.ds

class TestSmoke(unittest.TestCase):
    def test_import_ds(self):
        # Just verify we can import the module
        self.assertIsNotNone(src.ds)

if __name__ == "__main__":
    unittest.main()
PY

git add .
git commit -m "baseline" -q

echo "ok"
