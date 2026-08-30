from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path
from typing import Any


TASK_ROOT = Path(__file__).resolve().parents[1]
WORKSPACE = TASK_ROOT.parent
SEED_ROOT = WORKSPACE / "elderly-care-repos"
POOL_PATH = SEED_ROOT / "backup_pool.json"
STAGING_ROOT = TASK_ROOT / "candidate-repos"
OUTPUT = TASK_ROOT / "manifests" / "backup-clone-results.json"

INCLUDE = re.compile(
    r"nursing|home|beadhouse|aged-stage|elderly-care-system|eldercare-system|"
    r"community.*elder|yanglao|养老|pension|senior-care-facility|care-center|"
    r"care-management|elderly.*health|smart.*elderly",
    re.I,
)
EXCLUDE = re.compile(
    r"fall|detection|\biot\b|esp32|companion|robot|video|heart|medication|"
    r"android|frontend|\bml\b|assistant|algorithm|calculator|hypertension|"
    r"fire-safety|infrastructure",
    re.I,
)


def safe_dir(full_name: str) -> str:
    owner, _, repo = full_name.partition("/")
    clean = lambda value: re.sub(r'[<>:"/\\|?*\s]+', "_", value).strip("._")
    return f"{clean(owner)}__{clean(repo)}"


def run(command: list[str], cwd: Path | None = None, timeout: int = 600) -> subprocess.CompletedProcess[str]:
    env = os.environ.copy()
    env["GIT_TERMINAL_PROMPT"] = "0"
    env["GIT_LFS_SKIP_SMUDGE"] = "1"
    return subprocess.run(
        command,
        cwd=str(cwd) if cwd else None,
        env=env,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        encoding="utf-8",
        errors="replace",
        timeout=timeout,
    )


def git_value(repo: Path, *args: str) -> str:
    result = run(["git", "-C", str(repo), *args], timeout=60)
    return result.stdout.strip() if result.returncode == 0 else ""


def clone_one(record: dict[str, Any]) -> dict[str, Any]:
    started = time.monotonic()
    target = STAGING_ROOT / safe_dir(str(record["full_name"]))
    status = "failed"
    error = ""
    try:
        if (target / ".git").is_dir():
            fetched = run(["git", "-C", str(target), "fetch", "--depth", "1", "origin"], timeout=300)
            if fetched.returncode != 0:
                raise RuntimeError(fetched.stderr[-1000:])
            branch = git_value(target, "symbolic-ref", "--short", "refs/remotes/origin/HEAD")
            if branch.startswith("origin/"):
                checked = run(["git", "-C", str(target), "reset", "--hard", branch], timeout=120)
                if checked.returncode != 0:
                    raise RuntimeError(checked.stderr[-1000:])
            status = "updated"
        else:
            if target.exists():
                shutil.rmtree(target)
            cloned = run(
                [
                    "git",
                    "clone",
                    "--depth",
                    "1",
                    "--filter=blob:none",
                    "--no-tags",
                    str(record["clone_url"]),
                    str(target),
                ],
                timeout=600,
            )
            if cloned.returncode != 0:
                if target.exists():
                    shutil.rmtree(target, ignore_errors=True)
                raise RuntimeError(cloned.stderr[-1200:] or cloned.stdout[-1200:])
            status = "cloned"
    except (OSError, subprocess.SubprocessError, RuntimeError) as exc:
        error = str(exc).strip()[-1200:]
    result = {
        **record,
        "local_dir": str(target) if (target / ".git").is_dir() else "",
        "clone_status": status,
        "git_head": git_value(target, "rev-parse", "HEAD") if (target / ".git").is_dir() else "",
        "git_tree": git_value(target, "rev-parse", "HEAD^{tree}") if (target / ".git").is_dir() else "",
        "elapsed_seconds": round(time.monotonic() - started, 2),
        "error": error,
    }
    print(
        f"{result['clone_status'].upper():7} {record['full_name']} "
        f"({result['elapsed_seconds']}s){(' :: ' + error[:160]) if error else ''}",
        flush=True,
    )
    return result


def main() -> int:
    pool = json.loads(POOL_PATH.read_text(encoding="utf-8"))
    selected: list[dict[str, Any]] = []
    for record in pool:
        text = f"{record.get('full_name', '')} {record.get('description', '')}"
        size_kb = int(record.get("size_kb") or 0)
        if record.get("archived"):
            continue
        if size_kb >= 500_000:
            continue
        if not INCLUDE.search(text) or EXCLUDE.search(text):
            continue
        selected.append(record)
    selected.sort(key=lambda item: (float(item.get("score") or 0), int(item.get("stars") or 0)), reverse=True)
    STAGING_ROOT.mkdir(parents=True, exist_ok=True)
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    print(f"QUEUE={len(selected)}", flush=True)
    results: list[dict[str, Any]] = []
    with ThreadPoolExecutor(max_workers=4) as executor:
        futures = [executor.submit(clone_one, record) for record in selected]
        for future in as_completed(futures):
            results.append(future.result())
            OUTPUT.write_text(json.dumps(results, ensure_ascii=False, indent=2), encoding="utf-8")
    results.sort(key=lambda item: (float(item.get("score") or 0), str(item.get("full_name"))), reverse=True)
    OUTPUT.write_text(json.dumps(results, ensure_ascii=False, indent=2), encoding="utf-8")
    ok = sum(item["clone_status"] in {"cloned", "updated"} for item in results)
    print(f"DONE={len(results)} OK={ok} FAILED={len(results) - ok}", flush=True)
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
