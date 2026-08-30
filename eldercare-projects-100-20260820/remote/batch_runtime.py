#!/usr/bin/env python3
"""Start projects one at a time, record HTTP evidence, then release containers."""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path


ROOT = Path("/opt/eldercare100")
RUNNER = ROOT / "tools" / "run_project.py"
PLAN = ROOT / "state" / "build-plan.json"
RUNTIME = ROOT / "state" / "runtime-results.json"
LOG_ROOT = ROOT / "logs" / "runtime"


def load_results() -> dict[str, dict]:
    if not RUNTIME.is_file():
        return {}
    try:
        return {item["id"]: item for item in json.loads(RUNTIME.read_text(encoding="utf-8"))}
    except (OSError, json.JSONDecodeError, KeyError):
        return {}


def stop_project(project_id: str) -> None:
    found = subprocess.run(
        ["docker", "ps", "-aq", "--filter", f"label=com.kxb.project={project_id}"],
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    ids = found.stdout.split()
    if ids:
        subprocess.run(["docker", "rm", "-f", *ids], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def capture_container_logs(project_id: str, log_path: Path) -> None:
    found = subprocess.run(
        ["docker", "ps", "-aq", "--filter", f"label=com.kxb.project={project_id}"],
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    with log_path.open("a", encoding="utf-8") as handle:
        for container_id in found.stdout.split():
            name = subprocess.run(
                ["docker", "inspect", "--format", "{{.Name}}", container_id],
                stdout=subprocess.PIPE,
                stderr=subprocess.DEVNULL,
                text=True,
                encoding="utf-8",
                errors="replace",
            ).stdout.strip()
            output = subprocess.run(
                ["docker", "logs", "--tail", "240", container_id],
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                encoding="utf-8",
                errors="replace",
            ).stdout
            handle.write(f"\n--- CONTAINER {name or container_id} ---\n{output}\n")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--skip-http-verified", action="store_true")
    parser.add_argument("ids", nargs="*")
    args = parser.parse_args()
    plans = json.loads(PLAN.read_text(encoding="utf-8"))
    selected = [item["id"] for item in plans if not args.ids or item["id"] in set(args.ids)]
    previous = load_results()
    if args.skip_http_verified:
        selected = [project_id for project_id in selected if previous.get(project_id, {}).get("status") != "http-verified"]
    LOG_ROOT.mkdir(parents=True, exist_ok=True)
    print(f"RUNTIME_QUEUE={len(selected)}", flush=True)
    for project_id in selected:
        log_path = LOG_ROOT / f"{project_id}.log"
        try:
            completed = subprocess.run(
                [sys.executable, str(RUNNER), project_id],
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                encoding="utf-8",
                errors="replace",
                timeout=360,
            )
            log_path.write_text(completed.stdout, encoding="utf-8")
        except subprocess.TimeoutExpired as exc:
            output = exc.stdout if isinstance(exc.stdout, str) else ""
            log_path.write_text(output + "\nBATCH_TIMEOUT=360\n", encoding="utf-8")
        finally:
            capture_container_logs(project_id, log_path)
            stop_project(project_id)
        results = load_results()
        result = results.get(project_id, {})
        print(
            f"RUNTIME {project_id} status={result.get('status', 'missing')} "
            f"http={result.get('http_status', 0)} error={str(result.get('http_error') or result.get('error') or '')[-120:]}",
            flush=True,
        )
    results = load_results()
    verified = sum(results.get(project_id, {}).get("status") == "http-verified" for project_id in selected)
    print(f"RUNTIME_DONE={len(selected)} HTTP_VERIFIED={verified}", flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
