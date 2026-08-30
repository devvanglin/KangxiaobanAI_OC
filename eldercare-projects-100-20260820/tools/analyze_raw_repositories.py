from __future__ import annotations

import json
from collections import Counter
from pathlib import Path

from analyze_seed_repositories import inspect_repo


TASK_ROOT = Path(__file__).resolve().parents[1]
INPUT = TASK_ROOT / "manifests" / "raw-clone-results.json"
OUTPUT = TASK_ROOT / "manifests" / "raw-analysis.json"


def main() -> int:
    cloned = json.loads(INPUT.read_text(encoding="utf-8"))
    results = [inspect_repo(record) for record in cloned if record.get("local_dir")]
    tree_counts = Counter(item["git_tree"] for item in results if item["git_tree"])
    for item in results:
        item["duplicate_tree_count"] = tree_counts.get(item["git_tree"], 0)
    OUTPUT.write_text(json.dumps(results, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"ANALYZED={len(results)}")
    print(f"WEB_LOGIN_CANDIDATE={sum(bool(item['web_login_candidate']) for item in results)}")
    print("TYPES=" + json.dumps(Counter(item["project_type"] for item in results), ensure_ascii=False, sort_keys=True))
    print(f"DUPLICATE_TREES={sum(1 for count in tree_counts.values() if count > 1)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
