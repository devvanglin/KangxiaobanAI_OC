from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path
from typing import Any


ROOT = Path("/opt/eldercare100")
MANIFEST = ROOT / "state" / "canonical-100.json"
SOURCES = ROOT / "sources"
RESULTS = ROOT / "state" / "remote-source-results.json"


def safe_name(value: str) -> str:
    return re.sub(r"[^A-Za-z0-9._-]+", "_", value).strip("._")[:96]


def run(command: list[str], timeout: int = 1200) -> subprocess.CompletedProcess[str]:
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


def target_for(project: dict[str, Any], component: dict[str, Any]) -> Path:
    base = SOURCES / project["id"]
    if int(project.get("component_count") or 1) > 1:
        return base / safe_name(str(component["full_name"]).replace("/", "__"))
    return base


def clone_one(project: dict[str, Any], component: dict[str, Any]) -> dict[str, Any]:
    target = target_for(project, component)
    metadata = target / ".source.json"
    started = time.monotonic()
    expected_head = str(component["git_head"])
    if metadata.is_file():
        try:
            current = json.loads(metadata.read_text(encoding="utf-8"))
            if current.get("git_head") == expected_head:
                result = {
                    "id": project["id"],
                    "component": component["full_name"],
                    "target": str(target),
                    "status": "already-present",
                    "git_head": expected_head,
                    "git_tree": component["git_tree"],
                    "elapsed_seconds": 0.0,
                    "error": "",
                }
                print(f"SKIP   {project['id']} {component['full_name']}", flush=True)
                return result
        except (OSError, json.JSONDecodeError):
            pass
    temporary = target.parent / f".{target.name}.clone-{os.getpid()}-{int(time.time() * 1000)}"
    status = "failed"
    error = ""
    try:
        if temporary.exists():
            shutil.rmtree(temporary)
        temporary.parent.mkdir(parents=True, exist_ok=True)
        last_error = ""
        for attempt in range(1, 4):
            if temporary.exists():
                shutil.rmtree(temporary, ignore_errors=True)
            cloned = run(
                [
                    "git",
                    "-c",
                    "http.version=HTTP/1.1",
                    "clone",
                    "--depth",
                    "1",
                    "--no-tags",
                    str(component["clone_url"]),
                    str(temporary),
                ],
                timeout=1200,
            )
            if cloned.returncode == 0:
                break
            last_error = cloned.stderr[-1600:] or cloned.stdout[-1600:]
            time.sleep(attempt * 5)
        else:
            raise RuntimeError(last_error)
        head = git_value(temporary, "rev-parse", "HEAD")
        if head != expected_head:
            fetched = run(
                [
                    "git",
                    "-c",
                    "http.version=HTTP/1.1",
                    "-C",
                    str(temporary),
                    "fetch",
                    "--depth",
                    "1",
                    "origin",
                    expected_head,
                ],
                timeout=600,
            )
            if fetched.returncode != 0:
                raise RuntimeError(fetched.stderr[-1600:])
            checked = run(["git", "-C", str(temporary), "checkout", "--detach", expected_head], timeout=180)
            if checked.returncode != 0:
                raise RuntimeError(checked.stderr[-1600:])
            head = git_value(temporary, "rev-parse", "HEAD")
        tree = git_value(temporary, "rev-parse", "HEAD^{tree}")
        if head != expected_head or tree != str(component["git_tree"]):
            raise RuntimeError(f"source verification mismatch head={head} tree={tree}")
        shutil.rmtree(temporary / ".git")
        (temporary / ".source.json").write_text(
            json.dumps(
                {
                    "full_name": component["full_name"],
                    "source_url": component["html_url"],
                    "clone_url": component["clone_url"],
                    "git_head": head,
                    "git_tree": tree,
                },
                ensure_ascii=False,
                indent=2,
            ),
            encoding="utf-8",
        )
        if target.exists():
            raise RuntimeError("verified target already exists with different metadata")
        temporary.rename(target)
        status = "cloned-verified"
    except (OSError, subprocess.SubprocessError, RuntimeError) as exc:
        error = str(exc).strip()[-2400:]
        shutil.rmtree(temporary, ignore_errors=True)
    result = {
        "id": project["id"],
        "component": component["full_name"],
        "target": str(target),
        "status": status,
        "git_head": expected_head if status == "cloned-verified" else "",
        "git_tree": component["git_tree"] if status == "cloned-verified" else "",
        "elapsed_seconds": round(time.monotonic() - started, 2),
        "error": error,
    }
    print(
        f"{status.upper():15} {project['id']} {component['full_name']} "
        f"({result['elapsed_seconds']}s){(' :: ' + error[-180:]) if error else ''}",
        flush=True,
    )
    return result


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--workers", type=int, default=2)
    parser.add_argument("--results-path", default=str(RESULTS))
    parser.add_argument("ids", nargs="*")
    args = parser.parse_args()
    projects = json.loads(MANIFEST.read_text(encoding="utf-8"))
    if args.ids:
        selected_ids = set(args.ids)
        projects = [project for project in projects if project["id"] in selected_ids]
    jobs = [(project, component) for project in projects for component in project["components"]]
    results_path = Path(args.results_path)
    print(f"PROJECTS={len(projects)} COMPONENTS={len(jobs)}", flush=True)
    results = []
    workers = max(1, min(args.workers, 6))
    with ThreadPoolExecutor(max_workers=workers) as executor:
        futures = [executor.submit(clone_one, project, component) for project, component in jobs]
        for future in as_completed(futures):
            results.append(future.result())
            results_path.write_text(json.dumps(results, ensure_ascii=False, indent=2), encoding="utf-8")
    results.sort(key=lambda item: (item["id"], item["component"]))
    results_path.write_text(json.dumps(results, ensure_ascii=False, indent=2), encoding="utf-8")
    failed = sum(item["status"] == "failed" for item in results)
    projects_ok = len({item["id"] for item in results if item["status"] != "failed"})
    print(f"RESULTS={len(results)} FAILED={failed} PROJECTS_OK={projects_ok}", flush=True)
    return 0 if failed == 0 and projects_ok == len(projects) else 2


if __name__ == "__main__":
    raise SystemExit(main())
