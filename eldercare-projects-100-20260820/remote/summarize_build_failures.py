#!/usr/bin/env python3
"""Print compact error evidence for failed eldercare builds."""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path


ROOT = Path("/opt/eldercare100")


def main() -> int:
    selected_ids = set(sys.argv[1:])
    results = json.loads((ROOT / "state" / "build-results.json").read_text(encoding="utf-8"))
    plans = {item["id"]: item for item in json.loads((ROOT / "state" / "build-plan.json").read_text(encoding="utf-8"))}
    summaries = []
    for result in results:
        if selected_ids and result.get("id") not in selected_ids:
            continue
        if result.get("status") == "built":
            continue
        project_id = result["id"]
        log_path = ROOT / "logs" / "build" / f"{project_id}.log"
        text = log_path.read_text(encoding="utf-8", errors="ignore") if log_path.is_file() else ""
        selected = []
        pattern = re.compile(
            r"(?i)(\[ERROR\]|error[: ]|failed to|cannot find|could not|module not found|"
            r"not found|unsupported|no executable|no .*artifact|npm ERR|command failed|"
            r"resolutionexception|compilation failure|traceback)"
        )
        for line in text.splitlines():
            clean = re.sub(r"\x1b\[[0-9;]*[A-Za-z]", "", line).strip()
            if clean and pattern.search(clean):
                selected.append(clean)
        plan = plans.get(project_id, {})
        summaries.append(
            {
                "id": project_id,
                "name": plan.get("primary_full_name"),
                "planned_backend": (plan.get("backend") or {}).get("type"),
                "backend": result.get("backend"),
                "frontend": result.get("frontend"),
                "errors": selected[-24:],
            }
        )
    print(json.dumps(summaries, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
