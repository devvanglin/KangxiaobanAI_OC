from __future__ import annotations

import argparse
import csv
import json
import os
import re
import shutil
import stat
import subprocess
import sys
from pathlib import Path
from typing import Any


TASK_ROOT = Path(__file__).resolve().parents[1]
MANIFESTS = TASK_ROOT / "manifests"
CANONICAL = MANIFESTS / "canonical-100.json"
FINAL_CLONES = MANIFESTS / "final-clone-results.json"
CSV_PATH = MANIFESTS / "canonical-100.csv"
INDEX_PATH = TASK_ROOT / "INDEX.md"
REPOS_ROOT = TASK_ROOT / "repos"
ANALYSIS_FILES = (
    MANIFESTS / "raw-analysis.json",
    MANIFESTS / "backup-analysis.json",
    MANIFESTS / "seed-analysis.json",
)


def safe_name(value: str) -> str:
    return re.sub(r"[^A-Za-z0-9._-]+", "_", value).strip("._")[:96]


def atomic_text(path: Path, text: str) -> None:
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(text, encoding="utf-8")
    temporary.replace(path)


def load_candidates() -> dict[str, dict[str, Any]]:
    candidates: dict[str, dict[str, Any]] = {}
    for path in ANALYSIS_FILES:
        for item in json.loads(path.read_text(encoding="utf-8")):
            if item.get("clone_present"):
                candidates[str(item["full_name"]).lower()] = item
    return candidates


def git_value(repo: Path, *args: str) -> str:
    result = subprocess.run(
        ["git", "-C", str(repo), *args],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    return result.stdout.strip() if result.returncode == 0 else ""


def copy_path(path: Path) -> str:
    resolved = str(path.resolve())
    return "\\\\?\\" + resolved if os.name == "nt" else resolved


def remove_tree(path: Path) -> None:
    def clear_readonly(function: Any, target: str, _error: Any) -> None:
        os.chmod(target, stat.S_IWRITE)
        function(target)

    shutil.rmtree(copy_path(path), onexc=clear_readonly)


def selection_score(item: dict[str, Any]) -> float:
    markers = item.get("markers") or {}
    return round(
        float(item.get("stars") or 0)
        + 30 * bool(item.get("has_backend"))
        + 30 * bool(item.get("has_frontend"))
        + 25 * bool(item.get("has_login_evidence"))
        + 25 * bool(item.get("has_database_evidence"))
        + min(float(markers.get("eldercare_text") or 0), 20),
        3,
    )


def platform(item: dict[str, Any]) -> str:
    url = str(item.get("html_url") or "").lower()
    if "gitee.com" in url:
        return "gitee"
    if "gitlab" in url:
        return "gitlab"
    return "github"


def materialize(project_id: str, item: dict[str, Any]) -> tuple[dict[str, Any], dict[str, Any]]:
    source = Path(item["local_dir"])
    if not source.is_dir():
        raise RuntimeError(f"screened clone missing: {source}")
    target = REPOS_ROOT / f"{project_id}_replacement"
    expected_head = str(item.get("git_head") or "")
    if target.exists() and (
        git_value(target, "status", "--porcelain")
        or (expected_head and git_value(target, "rev-parse", "HEAD") != expected_head)
    ):
        remove_tree(target)
    if not target.exists():
        shutil.copytree(copy_path(source), copy_path(target))
    head = git_value(target, "rev-parse", "HEAD") or str(item.get("git_head") or "")
    tree = git_value(target, "rev-parse", "HEAD^{tree}") or str(item.get("git_tree") or "")
    if not head or not tree:
        raise RuntimeError(f"missing verified Git identity for {item['full_name']}")
    score = selection_score(item)
    component = {
        "full_name": item["full_name"],
        "html_url": item["html_url"],
        "clone_url": item["clone_url"],
        "local_dir": str(target),
        "git_head": head,
        "git_tree": tree,
        "project_type": item.get("project_type") or "fullstack",
        "selection_score": score,
        "screened_local_dir": str(source),
        "clone_status": "cloned",
        "changed_since_screening": False,
    }
    license_name = str(item.get("license") or "").strip() or "未声明"
    project = {
        "project_key": str(item["full_name"]).lower(),
        "display_name": item["full_name"],
        "primary_full_name": item["full_name"],
        "primary_url": item["html_url"],
        "platforms": [platform(item)],
        "components": [component],
        "component_count": 1,
        "has_frontend": bool(item.get("has_frontend")),
        "has_backend": bool(item.get("has_backend")),
        "has_login_evidence": bool(item.get("has_login_evidence")),
        "has_database_evidence": bool(item.get("has_database_evidence")),
        "has_compose": bool((item.get("paths") or {}).get("compose")),
        "has_dockerfile": bool((item.get("paths") or {}).get("dockerfile")),
        "license_status": [license_name],
        "selection_score": score,
        "screening_status": "structural-candidate",
        "clone_status": "cloned",
        "build_status": "not-tested",
        "http_status": "not-tested",
        "login_status": "not-tested",
        "id": project_id,
    }
    clone_result = {
        "id": project_id,
        "primary_full_name": item["full_name"],
        "component_full_name": item["full_name"],
        "clone_url": item["clone_url"],
        "target_dir": str(target),
        "status": "cloned",
        "git_head": head,
        "git_tree": tree,
        "analyzed_git_head": str(item.get("git_head") or head),
        "analyzed_git_tree": str(item.get("git_tree") or tree),
        "elapsed_seconds": 0.0,
        "error": "",
        "changed_since_screening": False,
    }
    return project, clone_result


def write_csv(projects: list[dict[str, Any]]) -> None:
    temporary = CSV_PATH.with_suffix(".csv.tmp")
    with temporary.open("w", encoding="utf-8-sig", newline="") as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=[
                "id", "display_name", "primary_full_name", "primary_url", "platforms",
                "component_count", "has_compose", "has_dockerfile", "license_status",
                "selection_score", "build_status", "http_status", "login_status",
            ],
        )
        writer.writeheader()
        for project in projects:
            writer.writerow(
                {
                    **{key: project.get(key) for key in writer.fieldnames},
                    "platforms": ",".join(project.get("platforms") or []),
                    "license_status": "/".join(project.get("license_status") or []),
                }
            )
    temporary.replace(CSV_PATH)


def write_index(projects: list[dict[str, Any]]) -> None:
    lines = [
        "# 智慧养老/养老院代码项目 100 项",
        "",
        "本清单源码均已拉取到 `repos/`。构建、HTTP 和登录状态以服务器验收记录为准。",
        "",
        "| ID | 项目 | 来源 | 组件 | 许可证 | 源码状态 | 构建 | HTTP | 登录 |",
        "|---|---|---|---:|---|---|---|---|---|",
    ]
    for project in projects:
        lines.append(
            f"| {project['id']} | [{project['primary_full_name']}]({project['primary_url']}) | "
            f"{', '.join(project['platforms'])} | {project['component_count']} | "
            f"{' / '.join(project['license_status'])} | 已拉取 | {project['build_status']} | "
            f"{project['http_status']} | {project['login_status']} |"
        )
    atomic_text(INDEX_PATH, "\n".join(lines) + "\n")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("replacements", nargs="+", help="ID=owner/repository")
    args = parser.parse_args()
    requested = dict(value.split("=", 1) for value in args.replacements)
    candidates = load_candidates()
    projects = json.loads(CANONICAL.read_text(encoding="utf-8"))
    clones = json.loads(FINAL_CLONES.read_text(encoding="utf-8"))
    by_id = {project["id"]: index for index, project in enumerate(projects)}
    clone_by_id = {item["id"]: index for index, item in enumerate(clones)}
    for project_id, full_name in requested.items():
        if project_id not in by_id:
            raise RuntimeError(f"unknown project id: {project_id}")
        item = candidates.get(full_name.lower())
        if item is None:
            raise RuntimeError(f"candidate not found: {full_name}")
        project, clone_result = materialize(project_id, item)
        projects[by_id[project_id]] = project
        if project_id in clone_by_id:
            clones[clone_by_id[project_id]] = clone_result
        else:
            clones.append(clone_result)
        print(f"REPLACED {project_id} -> {full_name}")
    projects.sort(key=lambda item: item["id"])
    clones.sort(key=lambda item: (item["id"], item["component_full_name"]))
    atomic_text(CANONICAL, json.dumps(projects, ensure_ascii=False, indent=2))
    atomic_text(FINAL_CLONES, json.dumps(clones, ensure_ascii=False, indent=2))
    write_csv(projects)
    write_index(projects)
    subprocess.run([sys.executable, str(TASK_ROOT / "tools" / "derive_deployment_inventory.py")], check=True)
    subprocess.run([sys.executable, str(TASK_ROOT / "tools" / "generate_build_plan.py")], check=True)
    print(f"PROJECTS={len(projects)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
