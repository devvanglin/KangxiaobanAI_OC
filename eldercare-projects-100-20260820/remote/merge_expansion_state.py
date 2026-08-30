from __future__ import annotations

import argparse
import json
from pathlib import Path


def load(path: Path) -> list[dict[str, object]]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, list):
        raise ValueError(f"expected list in {path}")
    return value


def number(row: dict[str, object]) -> int:
    return int(str(row["id"])[2:])


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--base", type=Path, required=True)
    parser.add_argument("--expanded", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--cutoff", type=int, default=153)
    args = parser.parse_args()

    base = {str(row["id"]): row for row in load(args.base) if number(row) <= args.cutoff}
    expanded = {str(row["id"]): row for row in load(args.expanded) if number(row) > args.cutoff}
    merged = list(base.values()) + list(expanded.values())
    merged.sort(key=number)
    if len(base) != args.cutoff:
        raise RuntimeError(f"base count mismatch: expected {args.cutoff}, got {len(base)}")
    temporary = args.output.with_suffix(args.output.suffix + ".tmp")
    temporary.write_text(json.dumps(merged, ensure_ascii=False, indent=2), encoding="utf-8")
    temporary.replace(args.output)
    print(f"BASE={len(base)}")
    print(f"ADDED={len(expanded)}")
    print(f"TOTAL={len(merged)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
