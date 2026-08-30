from __future__ import annotations

import json
import os
import subprocess
import sys
import time
from pathlib import Path


ROOT = Path("/opt/eldercare100")
TOOLS = ROOT / "tools"
STATE = ROOT / "state"
REPORTER = TOOLS / "generate_access_report.py"


def process_rows() -> list[tuple[int, str]]:
    completed = subprocess.run(
        ["ps", "-eo", "pid=,args="],
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        text=True,
        encoding="utf-8",
        errors="replace",
        timeout=30,
        check=False,
    )
    rows = []
    for line in completed.stdout.splitlines():
        parts = line.strip().split(None, 1)
        if len(parts) != 2:
            continue
        try:
            rows.append((int(parts[0]), parts[1]))
        except ValueError:
            continue
    return rows


def wait_for_other_processes(patterns: tuple[str, ...], timeout: int = 10_800) -> None:
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        matching = [
            (pid, command)
            for pid, command in process_rows()
            if pid != os.getpid() and any(pattern in command for pattern in patterns)
        ]
        if not matching:
            return
        print("WAITING_FOR=" + ",".join(f"{pid}:{command[:80]}" for pid, command in matching), flush=True)
        time.sleep(20)
    print("WAIT_TIMEOUT patterns=" + repr(patterns), flush=True)


def run_stage(name: str, command: list[str], timeout: int) -> int:
    print(f"STAGE_START={name} COMMAND={' '.join(command)}", flush=True)
    try:
        completed = subprocess.run(command, timeout=timeout, check=False)
        code = completed.returncode
    except subprocess.TimeoutExpired:
        code = 124
    print(f"STAGE_DONE={name} RC={code}", flush=True)
    return code


def built_ids() -> list[str]:
    try:
        rows = json.loads((STATE / "build-results.json").read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return []
    return sorted(str(item["id"]) for item in rows if item.get("status") == "built")


def main() -> int:
    wait_for_other_processes(("clone_sources.py",), timeout=14_400)
    for attempt in range(1, 4):
        run_stage(
            f"clone-all-{attempt}",
            [sys.executable, "-u", str(TOOLS / "clone_sources.py"), "--workers", "4"],
            timeout=10_800,
        )
        try:
            source_rows = json.loads((STATE / "remote-source-results.json").read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            source_rows = []
        projects_ok = {
            str(item.get("id"))
            for item in source_rows
            if item.get("status") in {"cloned-verified", "already-present"}
        }
        print(f"SOURCE_PROJECTS_OK={len(projects_ok)} ATTEMPT={attempt}", flush=True)
        if len(projects_ok) >= 153:
            break

    wait_for_other_processes(("setup_python_runtime.py",), timeout=7_200)
    run_stage(
        "python-runtime",
        [sys.executable, "-u", str(TOOLS / "setup_python_runtime.py")],
        timeout=7_200,
    )

    wait_for_other_processes(("build_projects.py",), timeout=28_800)
    for attempt in range(1, 3):
        run_stage(
            f"build-all-{attempt}",
            [
                sys.executable,
                "-u",
                str(TOOLS / "build_projects.py"),
                "--workers",
                "3",
                "--skip-built",
            ],
            timeout=43_200,
        )
        run_stage("report-after-build", [sys.executable, "-u", str(REPORTER)], timeout=300)

    projects = built_ids()
    print(f"RUNTIME_BUILT_QUEUE={len(projects)}", flush=True)
    for offset in range(0, len(projects), 10):
        batch = projects[offset : offset + 10]
        run_stage(
            f"runtime-{offset + 1}-{offset + len(batch)}",
            [sys.executable, "-u", str(TOOLS / "batch_runtime.py"), "--skip-http-verified", *batch],
            timeout=max(900, len(batch) * 300),
        )
        run_stage("report-runtime-progress", [sys.executable, "-u", str(REPORTER)], timeout=300)

    run_stage("final-report", [sys.executable, "-u", str(REPORTER)], timeout=300)
    print("OVERNIGHT_PIPELINE_COMPLETE", flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
