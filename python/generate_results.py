#!/usr/bin/env python3

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
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
    p.add_argument("--input-dir", required=True, help="Directory containing run results (e.g. run_1/001/off.json)")
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
    input_root = Path(args.input_dir)
    runs_detected: set[str] = set()
    
    for case, weight in cases:
        # Find all off/on pairs for this case in the input directory
        # Expected structure: <input_dir>/<run_id>/<case>/<off|on>.json
        # OR: <input_dir>/<case>/<off|on>.json (single run)
        
        off_files = sorted(input_root.glob(f"**/{case}/off.json"))
        on_files = sorted(input_root.glob(f"**/{case}/on.json"))
        
        if not off_files:
            print(f"Warning: No results found for case {case}", file=sys.stderr)
            continue
        for f in off_files:
            # Best-effort: treat the parent of the case dir as a run id when present.
            # e.g. <input>/<run_1>/<case>/off.json
            try:
                runs_detected.add(f.parent.parent.name)
            except Exception:
                pass

        off_scores = []
        for f in off_files:
            data = load_json(f)
            off_scores.append(float(data["score"]))
            
        on_scores = []
        for f in on_files:
            data = load_json(f)
            on_scores.append(float(data["score"]))
            
        avg_off = sum(off_scores) / len(off_scores) if off_scores else 0.0
        avg_on = sum(on_scores) / len(on_scores) if on_scores else 0.0
        
        results.append(CaseResult(case=case, weight=weight, off=avg_off, on=avg_on))

    off_total = sum(r.off * r.weight for r in results)
    on_total = sum(r.on * r.weight for r in results)

    out = Path(args.output)
    out.parent.mkdir(parents=True, exist_ok=True)

    lines = []
    lines.append("# Results: `TDD` (python)")
    lines.append("")
    lines.append(f"Benchmark repo: `CursorCult/_benchmark_TDD`")
    lines.append(f"Runs aggregated: {len(runs_detected) if runs_detected else 1}")
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
