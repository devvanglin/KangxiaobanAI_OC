from __future__ import annotations

import json
import os
import subprocess
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path
from typing import Any


TASK_ROOT = Path(__file__).resolve().parents[1]
MANIFESTS = TASK_ROOT / "manifests"
CANONICAL = MANIFESTS / "canonical-100.json"
RESULTS = MANIFESTS / "final-clone-results.json"


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


def retry_one(previous: dict[str, Any], component: dict[str, Any]) -> dict[str, Any]:
    target = Path(previous["target_dir"])
    started = time.monotonic()
    errors = []
    status = "failed"
    for attempt in range(1, 5):
        try:
            if (target / ".git").is_dir():
                fetched = run(
                    [
                        "git",
                        "-c",
                        "http.version=HTTP/1.1",
                        "-C",
                        str(target),
                        "fetch",
                        "--depth",
                        "1",
                        "origin",
                    ],
                    timeout=600,
                )
                if fetched.returncode != 0:
                    raise RuntimeError(fetched.stderr[-1200:])
                head = git_value(target, "rev-parse", "HEAD")
                if not head:
                    remote_head = git_value(target, "symbolic-ref", "--short", "refs/remotes/origin/HEAD")
                    if remote_head.startswith("origin/"):
                        checked = run(["git", "-C", str(target), "checkout", "-f", "-B", remote_head[7:], remote_head])
                        if checked.returncode != 0:
                            raise RuntimeError(checked.stderr[-1200:])
                else:
                    reset = run(["git", "-C", str(target), "reset", "--hard", "HEAD"], timeout=300)
                    if reset.returncode != 0:
                        raise RuntimeError(reset.stderr[-1200:])
                status = "recovered"
                break
            if target.exists():
                raise RuntimeError("Retry target exists but has no .git directory")
            target.parent.mkdir(parents=True, exist_ok=True)
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
                    str(target),
                ],
                timeout=900,
            )
            if cloned.returncode != 0:
                raise RuntimeError(cloned.stderr[-1400:] or cloned.stdout[-1400:])
            status = "cloned-retry"
            break
        except (OSError, subprocess.SubprocessError, RuntimeError) as exc:
            errors.append(f"attempt {attempt}: {str(exc).strip()[-1200:]}")
            time.sleep(attempt * 5)
    result = dict(previous)
    result.update(
        {
            "status": status,
            "git_head": git_value(target, "rev-parse", "HEAD") if (target / ".git").is_dir() else "",
            "git_tree": git_value(target, "rev-parse", "HEAD^{tree}") if (target / ".git").is_dir() else "",
            "elapsed_seconds": round(time.monotonic() - started, 2),
            "error": "\n".join(errors)[-3000:] if status == "failed" else "",
            "retry_attempts": len(errors) + (1 if status != "failed" else 0),
        }
    )
    result["changed_since_screening"] = bool(
        result["git_tree"]
        and result.get("analyzed_git_tree")
        and result["git_tree"] != result["analyzed_git_tree"]
    )
    print(
        f"{status.upper():12} {result['id']} {result['component_full_name']} "
        f"({result['elapsed_seconds']}s){(' :: ' + result['error'][-180:]) if result['error'] else ''}",
        flush=True,
    )
    return result


def main() -> int:
    projects = json.loads(CANONICAL.read_text(encoding="utf-8"))
    components = {
        (project["id"], component["full_name"]): component
        for project in projects
        for component in project["components"]
    }
    previous = json.loads(RESULTS.read_text(encoding="utf-8"))
    failed = [item for item in previous if item["status"] == "failed"]
    print(f"RETRY_QUEUE={len(failed)}", flush=True)
    replacements = {}
    with ThreadPoolExecutor(max_workers=2) as executor:
        futures = {
            executor.submit(retry_one, item, components[(item["id"], item["component_full_name"])]): item
            for item in failed
        }
        for future in as_completed(futures):
            result = future.result()
            replacements[(result["id"], result["component_full_name"])] = result
    merged = [replacements.get((item["id"], item["component_full_name"]), item) for item in previous]
    merged.sort(key=lambda item: (item["id"], item["component_full_name"]))
    RESULTS.write_text(json.dumps(merged, ensure_ascii=False, indent=2), encoding="utf-8")
    failed_count = sum(item["status"] == "failed" for item in merged)
    project_ok = len({item["id"] for item in merged if item["status"] != "failed"})
    print(f"FINAL_RESULTS={len(merged)} FAILED={failed_count} PROJECTS_WITH_SOURCE={project_ok}", flush=True)
    return 0 if failed_count == 0 and project_ok == len(projects) else 2


if __name__ == "__main__":
    raise SystemExit(main())
