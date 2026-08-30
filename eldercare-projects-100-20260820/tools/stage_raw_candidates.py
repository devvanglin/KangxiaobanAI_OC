from __future__ import annotations

import json
import re
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

import stage_backup_candidates as clone_support


TASK_ROOT = Path(__file__).resolve().parents[1]
INPUT = TASK_ROOT / "manifests" / "raw-extra-pool.json"
STAGING_ROOT = TASK_ROOT / "candidate-repos-raw"
OUTPUT = TASK_ROOT / "manifests" / "raw-clone-results.json"

STRONG_NAME = re.compile(
    r"nursing.?home|nursinghome|yanglao|beadhouse|elderly.?care.?management|"
    r"eldercare.?management|elderly.?care.?system|eldercare.?system|aged.?stage|"
    r"community.?elderly|senior.?care|old.?person.?home|retirementmanage|"
    r"elderlycareplatform|smart.?nursing.?home|养老|智慧养老",
    re.I,
)
WEAK_OR_NONAPP = re.compile(
    r"data|dataset|analytics|finance|foundation|vr|agent|chatbot|bot|opencv|"
    r"safeos|guns-medical|ble|hardware|covid|model|infrastructure|algorithm|"
    r"awareness|wordpress|education|lyrics|audioguide",
    re.I,
)


def main() -> int:
    candidates = json.loads(INPUT.read_text(encoding="utf-8"))
    selected = []
    for item in candidates:
        name = str(item.get("full_name") or "")
        text = f"{name} {item.get('description') or ''}"
        if not STRONG_NAME.search(name):
            continue
        if WEAK_OR_NONAPP.search(text):
            continue
        selected.append(item)
    selected.sort(
        key=lambda item: (int(item.get("stars") or 0), str(item.get("updated_at") or "")),
        reverse=True,
    )
    selected = selected[:70]
    clone_support.STAGING_ROOT = STAGING_ROOT
    clone_support.OUTPUT = OUTPUT
    STAGING_ROOT.mkdir(parents=True, exist_ok=True)
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    print(f"QUEUE={len(selected)}", flush=True)
    results = []
    with ThreadPoolExecutor(max_workers=4) as executor:
        futures = [executor.submit(clone_support.clone_one, record) for record in selected]
        for future in as_completed(futures):
            results.append(future.result())
            OUTPUT.write_text(json.dumps(results, ensure_ascii=False, indent=2), encoding="utf-8")
    results.sort(key=lambda item: (int(item.get("stars") or 0), str(item.get("full_name"))), reverse=True)
    OUTPUT.write_text(json.dumps(results, ensure_ascii=False, indent=2), encoding="utf-8")
    ok = sum(item["clone_status"] in {"cloned", "updated"} for item in results)
    print(f"DONE={len(results)} OK={ok} FAILED={len(results) - ok}", flush=True)
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
