#!/usr/bin/env python3

from __future__ import annotations

import argparse
import json
import os
import subprocess
from dataclasses import dataclass
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
PY_ROOT = ROOT / "python"


@dataclass(frozen=True)
class CaseResult:
    case: str
    weight: float
    off: float
    on: float

    @property
    def effect(self) -> float:
        return self.on - self.off


def run(cmd: list[str], *, cwd: Path) -> None:
    proc = subprocess.run(cmd, cwd=str(cwd), text=True)
    if proc.returncode != 0:
        raise SystemExit(proc.returncode)


def load_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--output", required=True)
    args = p.parse_args()

    weights_path = PY_ROOT / "weights.json"
    weights = json.loads(weights_path.read_text(encoding="utf-8"))
    if not isinstance(weights, dict) or not weights:
        raise SystemExit("python/weights.json must be a non-empty object")

    cases = []
    for case, w in weights.items():
        if not isinstance(case, str) or not case:
            raise SystemExit("invalid case key in weights.json")
        if not isinstance(w, (int, float)) or w <= 0:
            raise SystemExit(f"invalid weight for {case}")
        cases.append((case, float(w)))

    total_w = sum(w for _, w in cases)
    cases = [(c, w / total_w) for c, w in cases]

    results: list[CaseResult] = []
    for case, weight in cases:
        case_dir = PY_ROOT / case
        run(["bash", "run.sh"], cwd=case_dir)
        off_doc = load_json(case_dir / "off.json")
        on_doc = load_json(case_dir / "on.json")
        off_score = float(off_doc["score"])
        on_score = float(on_doc["score"])
        results.append(CaseResult(case=case, weight=weight, off=off_score, on=on_score))

    off_total = sum(r.off * r.weight for r in results)
    on_total = sum(r.on * r.weight for r in results)

    out = Path(args.output)
    out.parent.mkdir(parents=True, exist_ok=True)

    lines = []
    lines.append("# Results: `TDD` (python)")
    lines.append("")
    lines.append(f"Benchmark repo: `CursorCult/_benchmark_TDD`")
    lines.append("")
    lines.append("## Per-case")
    lines.append("")
    lines.append("| Case | Off | On | Effectiveness |")
    lines.append("|---|---:|---:|---:|")
    for r in results:
        lines.append(f"| {r.case} | {r.off:.2f} | {r.on:.2f} | {r.effect:+.2f} |")
    lines.append("")
    lines.append("## Aggregate (weighted)")
    lines.append("")
    lines.append(f"- Off: `{off_total:.2f}`")
    lines.append(f"- On: `{on_total:.2f}`")
    lines.append(f"- Effectiveness: `{(on_total - off_total):+.2f}`")
    lines.append("")
    out.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

