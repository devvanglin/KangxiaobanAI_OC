from __future__ import annotations

import csv
import json
import math
import re
from collections import defaultdict
from difflib import SequenceMatcher
from pathlib import Path
from typing import Any

from detect_near_duplicates import jaccard, path_set


TASK_ROOT = Path(__file__).resolve().parents[1]
MANIFEST_ROOT = TASK_ROOT / "manifests"
INPUTS = [
    MANIFEST_ROOT / "seed-analysis.json",
    MANIFEST_ROOT / "backup-analysis.json",
    MANIFEST_ROOT / "raw-analysis.json",
]
OUTPUT_JSON = MANIFEST_ROOT / "canonical-100.json"
OUTPUT_CSV = MANIFEST_ROOT / "canonical-100.csv"

DENY = re.compile(
    r"retirementmanage|pension.?calculator|pension.?advisor|nursing.?home.?quality|"
    r"nursing.?home.?compare|nursing.?home.?grade|bayes|dataset|covid|finance.?model|"
    r"testing.?strategy|beds$|mcp$|computer.?vision|\bcv\b|harmony|algorithm|"
    r"fall.?detection|esp32|arduino|zigbee|robot|companion|medical.?image",
    re.I,
)

MANUAL_PRODUCT_KEYS = {
    "mohaos/e-shouhu-ui": "mohaos/e-shouhu",
    "mohaos/e-guarded-backend": "mohaos/e-shouhu",
    "mohaos/backend-of-e-guard": "mohaos/e-shouhu",
}


def normalized_product_key(full_name: str) -> str:
    lower = full_name.lower()
    if lower in MANUAL_PRODUCT_KEYS:
        return MANUAL_PRODUCT_KEYS[lower]
    owner, _, repo = lower.partition("/")
    tokens = re.split(r"[^a-z0-9\u4e00-\u9fff]+", repo)
    removable = {
        "frontend",
        "fronted",
        "backend",
        "server",
        "client",
        "admin",
        "web",
        "ui",
        "page",
        "pages",
        "springboot",
        "spring",
        "vue",
        "react",
        "api",
    }
    core = [token for token in tokens if token and token not in removable]
    return f"{owner}/{'-'.join(core) or repo}"


def repo_score(item: dict[str, Any]) -> float:
    project_type = str(item.get("project_type") or "")
    score = {"fullstack": 120.0, "backend-web": 82.0, "frontend-web": 45.0}.get(project_type, 20.0)
    paths = item.get("paths") or {}
    score += min(len(paths.get("compose") or []), 2) * 18
    score += min(len(paths.get("dockerfile") or []), 2) * 10
    score += min(len(paths.get("sql") or []), 8) * 2.5
    score += min(len(paths.get("login") or []), 8) * 2.0
    score += min(len(paths.get("readme") or []), 2) * 3.0
    score += 8 if item.get("has_database_evidence") else 0
    score += 8 if item.get("has_frontend") else 0
    score += 8 if item.get("has_backend") else 0
    score += min(math.log10(max(int(item.get("file_count") or 1), 1)) * 4, 14)
    score += min(math.log10(max(int(item.get("stars") or 0) + 1, 1)) * 4, 8)
    score += min(float(item.get("score") or 0) / 20, 5)
    full_name = str(item.get("full_name") or "")
    if re.search(r"frontend|fronted|backend|[-_/]web$|[-_/]ui$", full_name, re.I):
        score -= 16
    if not str(item.get("license") or "").strip():
        score -= 2
    if int(item.get("file_count") or 0) < 30:
        score -= 35
    if int(item.get("source_bytes") or 0) < 20_000:
        score -= 35
    return round(score, 3)


def load_candidates() -> list[dict[str, Any]]:
    candidates: list[dict[str, Any]] = []
    for path in INPUTS:
        for item in json.loads(path.read_text(encoding="utf-8")):
            item["analysis_source"] = path.name
            item["selection_score"] = repo_score(item)
            candidates.append(item)
    return candidates


def eligible(item: dict[str, Any]) -> bool:
    if not item.get("clone_present") or not item.get("git_tree"):
        return False
    if not item.get("web_login_candidate"):
        return False
    if int((item.get("markers") or {}).get("eldercare_text") or 0) < 1:
        return False
    if int(item.get("file_count") or 0) < 20 or int(item.get("source_bytes") or 0) < 10_000:
        return False
    full_name = str(item.get("full_name") or "")
    if DENY.search(full_name):
        return False
    if item.get("project_type") == "backend-web" and not item.get("has_database_evidence"):
        return False
    return True


def combine_components(items: list[dict[str, Any]]) -> dict[str, Any]:
    ranked = sorted(items, key=lambda item: float(item["selection_score"]), reverse=True)
    primary = ranked[0]
    combined_frontend = any(bool(item.get("has_frontend")) for item in ranked)
    combined_backend = any(bool(item.get("has_backend")) for item in ranked)
    combined_login = any(bool(item.get("has_login_evidence")) for item in ranked)
    combined_database = any(bool(item.get("has_database_evidence")) for item in ranked)
    combined_score = float(primary["selection_score"])
    if len(ranked) > 1 and combined_frontend and combined_backend:
        combined_score += 15
    return {
        "project_key": normalized_product_key(str(primary["full_name"])),
        "display_name": str(primary.get("name_cn") or primary.get("full_name") or ""),
        "primary_full_name": str(primary["full_name"]),
        "primary_url": str(primary.get("html_url") or ""),
        "platforms": sorted({str(item.get("platform") or "github") for item in ranked}),
        "components": [
            {
                "full_name": str(item["full_name"]),
                "html_url": str(item.get("html_url") or ""),
                "clone_url": str(item.get("clone_url") or ""),
                "local_dir": str(item.get("local_dir") or ""),
                "git_head": str(item.get("git_head") or ""),
                "git_tree": str(item.get("git_tree") or ""),
                "project_type": str(item.get("project_type") or ""),
                "selection_score": float(item["selection_score"]),
            }
            for item in ranked
        ],
        "component_count": len(ranked),
        "has_frontend": combined_frontend,
        "has_backend": combined_backend,
        "has_login_evidence": combined_login,
        "has_database_evidence": combined_database,
        "has_compose": any(bool((item.get("paths") or {}).get("compose")) for item in ranked),
        "has_dockerfile": any(bool((item.get("paths") or {}).get("dockerfile")) for item in ranked),
        "license_status": sorted({str(item.get("license") or "未声明") for item in ranked}),
        "selection_score": round(combined_score, 3),
        "screening_status": "structural-candidate",
        "clone_status": "source-cloned-in-staging",
        "build_status": "not-tested",
        "http_status": "not-tested",
        "login_status": "not-tested",
    }


def main() -> int:
    candidates = [item for item in load_candidates() if eligible(item)]
    # Exact tree duplicates across different owners are one source project.
    by_tree: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for item in candidates:
        by_tree[str(item["git_tree"])].append(item)
    unique_repos = [
        max(items, key=lambda item: float(item["selection_score"]))
        for items in by_tree.values()
    ]
    # Merge obvious sibling frontend/backend repositories owned by the same author.
    by_product: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for item in unique_repos:
        by_product[normalized_product_key(str(item["full_name"]))].append(item)
    projects = [combine_components(items) for items in by_product.values()]
    projects = [
        project
        for project in projects
        if project["has_login_evidence"]
        and project["has_backend"]
        and project["has_database_evidence"]
    ]
    projects.sort(key=lambda project: (float(project["selection_score"]), project["primary_full_name"]), reverse=True)
    selected: list[dict[str, Any]] = []
    selected_signatures: list[set[str]] = []
    near_duplicate_count = 0
    for project in projects:
        root = Path(project["components"][0]["local_dir"])
        signature = path_set(root)
        duplicate_index = next(
            (
                index
                for index, existing in enumerate(selected_signatures)
                if jaccard(signature, existing) >= 0.95
            ),
            None,
        )
        if duplicate_index is not None:
            selected[duplicate_index].setdefault("near_duplicate_aliases", []).append(
                {
                    "full_name": project["primary_full_name"],
                    "url": project["primary_url"],
                    "reason": "normalized-source-path-jaccard>=0.95",
                }
            )
            near_duplicate_count += 1
            continue
        selected.append(project)
        selected_signatures.append(signature)
        if len(selected) == 100:
            break
    for index, project in enumerate(selected, start=1):
        project["id"] = f"ec{index:03d}"
    OUTPUT_JSON.write_text(json.dumps(selected, ensure_ascii=False, indent=2), encoding="utf-8")
    with OUTPUT_CSV.open("w", encoding="utf-8-sig", newline="") as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=[
                "id",
                "display_name",
                "primary_full_name",
                "primary_url",
                "platforms",
                "component_count",
                "has_compose",
                "has_dockerfile",
                "license_status",
                "selection_score",
                "build_status",
                "http_status",
                "login_status",
            ],
        )
        writer.writeheader()
        for project in selected:
            row = dict(project)
            row["platforms"] = ",".join(project["platforms"])
            row["license_status"] = ",".join(project["license_status"])
            writer.writerow({key: row.get(key, "") for key in writer.fieldnames})
    print(f"ELIGIBLE_REPOSITORIES={len(candidates)}")
    print(f"UNIQUE_TREES={len(unique_repos)}")
    print(f"PRODUCTS={len(projects)}")
    print(f"NEAR_DUPLICATES_SKIPPED={near_duplicate_count}")
    print(f"SELECTED={len(selected)}")
    print(f"MULTI_COMPONENT={sum(int(project['component_count']) > 1 for project in selected)}")
    return 0 if len(selected) == 100 else 2


if __name__ == "__main__":
    raise SystemExit(main())
