#!/usr/bin/env bash
set -euo pipefail

fail=0

need () {
  local name="$1"
  if ! command -v "$name" >/dev/null 2>&1; then
    echo "missing: $name" >&2
    fail=1
  fi
}

need git
need python3
need cursor-agent

if [[ "$fail" -ne 0 ]]; then
  exit 1
fi

if ! cursor-agent status >/dev/null 2>&1; then
  echo "cursor-agent not authenticated; run: cursor-agent login" >&2
  exit 1
fi

if [[ ! -f "$(cd "$(dirname "$0")" && pwd)/requirements.txt" ]]; then
  echo "missing python/requirements.txt" >&2
  exit 1
fi

echo "ok"
