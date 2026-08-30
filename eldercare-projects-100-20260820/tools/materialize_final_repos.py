from __future__ import annotations

import json
import os
import re
import subprocess
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path
from typing import Any


TASK_ROOT = Path(__file__).resolve().parents[1]
INPUT = TASK_ROOT / "manifests" / "canonical-100.json"
REPOS_ROOT = TASK_ROOT / "repos"
OUTPUT = TASK_ROOT / "manifests" / "final-clone-results.json"


def safe_name(value: str) -> str:
    return re.sub(r'[^A-Za-z0-9._\-\u4e00-\u9fff]+', "_", value).strip("._")[:96]


def run(command: list[str], timeout: int = 900) -> subprocess.CompletedProcess[str]:
    env = os.environ.copy()
    env["GIT_TERMINAL_PROMPT"] = "0"
    env["GIT_LFS_SKIP_SMUDGE"] = "1"
    return subprocess.run(
        command,
        env=env,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        encoding="utf-8",
        errors="replace",
        timeout=timeout,
    )


def git_value(repo: Path, *args: str) -> str:
    result = run(["git", "-C", str(repo), *args], timeout=90)
    return result.stdout.strip() if result.returncode == 0 else ""


def clone_component(project: dict[str, Any], component: dict[str, Any]) -> dict[str, Any]:
    started = time.monotonic()
    project_dir = REPOS_ROOT / f"{project['id']}_{safe_name(project['primary_full_name'].replace('/', '__'))}"
    if int(project.get("component_count") or 1) > 1:
        target = project_dir / safe_name(str(component["full_name"]).replace("/", "__"))
    else:
        target = project_dir
    target.parent.mkdir(parents=True, exist_ok=True)
    status = "failed"
    error = ""
    try:
        if (target / ".git").is_dir():
            fetched = run(["git", "-C", str(target), "fetch", "--depth", "1", "origin"], timeout=600)
            if fetched.returncode != 0:
                raise RuntimeError(fetched.stderr[-1200:])
            branch = git_value(target, "symbolic-ref", "--short", "refs/remotes/origin/HEAD")
            if branch.startswith("origin/"):
                reset = run(["git", "-C", str(target), "reset", "--hard", branch], timeout=180)
                if reset.returncode != 0:
                    raise RuntimeError(reset.stderr[-1200:])
            status = "updated"
        elif target.exists():
            raise RuntimeError("Target exists but is not a Git repository")
        else:
            cloned = run(
                [
                    "git",
                    "clone",
                    "--depth",
                    "1",
                    "--filter=blob:none",
                    "--no-tags",
                    str(component["clone_url"]),
                    str(target),
                ],
                timeout=900,
            )
            if cloned.returncode != 0:
                raise RuntimeError(cloned.stderr[-1600:] or cloned.stdout[-1600:])
            status = "cloned"
    except (OSError, subprocess.SubprocessError, RuntimeError) as exc:
        error = str(exc).strip()[-1600:]
    result = {
        "id": project["id"],
        "primary_full_name": project["primary_full_name"],
        "component_full_name": component["full_name"],
        "clone_url": component["clone_url"],
        "target_dir": str(target),
        "status": status,
        "git_head": git_value(target, "rev-parse", "HEAD") if (target / ".git").is_dir() else "",
        "git_tree": git_value(target, "rev-parse", "HEAD^{tree}") if (target / ".git").is_dir() else "",
        "analyzed_git_head": component.get("git_head", ""),
        "analyzed_git_tree": component.get("git_tree", ""),
        "elapsed_seconds": round(time.monotonic() - started, 2),
        "error": error,
    }
    result["changed_since_screening"] = bool(
        result["git_tree"]
        and result["analyzed_git_tree"]
        and result["git_tree"] != result["analyzed_git_tree"]
    )
    print(
        f"{status.upper():7} {project['id']} {component['full_name']} "
        f"({result['elapsed_seconds']}s){(' :: ' + error[:180]) if error else ''}",
        flush=True,
    )
    return result


def main() -> int:
    projects = json.loads(INPUT.read_text(encoding="utf-8"))
    REPOS_ROOT.mkdir(parents=True, exist_ok=True)
    jobs = [(project, component) for project in projects for component in project["components"]]
    print(f"PROJECTS={len(projects)} COMPONENTS={len(jobs)}", flush=True)
    results = []
    with ThreadPoolExecutor(max_workers=4) as executor:
        futures = [executor.submit(clone_component, project, component) for project, component in jobs]
        for future in as_completed(futures):
            results.append(future.result())
            OUTPUT.write_text(json.dumps(results, ensure_ascii=False, indent=2), encoding="utf-8")
    results.sort(key=lambda item: (item["id"], item["component_full_name"]))
    OUTPUT.write_text(json.dumps(results, ensure_ascii=False, indent=2), encoding="utf-8")
    ok = sum(item["status"] in {"cloned", "updated"} for item in results)
    project_ok = len({item["id"] for item in results if item["status"] in {"cloned", "updated"}})
    print(f"DONE_COMPONENTS={len(results)} OK_COMPONENTS={ok} OK_PROJECTS={project_ok}", flush=True)
    print(f"CHANGED_SINCE_SCREENING={sum(bool(item['changed_since_screening']) for item in results)}", flush=True)
    return 0 if ok == len(results) and project_ok == len(projects) else 2


if __name__ == "__main__":
    raise SystemExit(main())
