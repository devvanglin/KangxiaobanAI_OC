from __future__ import annotations

import json
import re
from pathlib import Path


TASK_ROOT = Path(__file__).resolve().parents[1]
WORKSPACE = TASK_ROOT.parent
SEED_ROOT = WORKSPACE / "elderly-care-repos"
OUTPUT = TASK_ROOT / "manifests" / "raw-extra-pool.json"

INCLUDE = re.compile(
    r"nursing.?home|nursinghome|elderly.?care|eldercare|aged.?stage|beadhouse|"
    r"yanglao|zhihuiyanglao|pension.?system|senior.?care|community.?elder|"
    r"oldpeoplehome|gerocomium|养老院|智慧养老|社区养老",
    re.I,
)
EXCLUDE = re.compile(
    r"fall|detect|yolo|\biot\b|esp32|arduino|robot|companion|assistant|dataset|"
    r"paper|android|flutter|mini.?program|frontend|backend|medical.?image|algorithm|"
    r"calculator|firmware|awesome|resources|tutorial",
    re.I,
)
LANGUAGES = {"Java", "Vue", "JavaScript", "TypeScript", "Python", "PHP", "C#", "Go", "HTML"}


def main() -> int:
    raw = json.loads((SEED_ROOT / "raw_github.json").read_text(encoding="utf-8"))
    known: set[str] = set()
    for filename in ("selected_100.json", "backup_pool.json"):
        known.update(
            str(item["full_name"]).lower()
            for item in json.loads((SEED_ROOT / filename).read_text(encoding="utf-8"))
        )
    values = raw.values() if isinstance(raw, dict) else raw
    candidates = []
    for item in values:
        full_name = str(item.get("full_name") or "")
        description = str(item.get("description") or "")
        text = f"{full_name} {description}"
        size_kb = int(item.get("size_kb") or 0)
        language = str(item.get("language") or "")
        if full_name.lower() in known:
            continue
        if item.get("archived") or item.get("fork"):
            continue
        if size_kb >= 500_000 or language not in LANGUAGES:
            continue
        if not INCLUDE.search(text) or EXCLUDE.search(text):
            continue
        candidates.append(item)
    candidates.sort(
        key=lambda item: (int(item.get("stars") or 0), str(item.get("updated_at") or "")),
        reverse=True,
    )
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(json.dumps(candidates, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"RAW_EXTRA_COUNT={len(candidates)}")
    for item in candidates[:120]:
        print(
            f"{item.get('full_name')} | {item.get('language')} | "
            f"stars={item.get('stars', 0)} | size_kb={item.get('size_kb', 0)}"
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
