#!/usr/bin/env python3
"""Reconstruct build metadata from preserved deployment artifacts after state-file loss."""

from __future__ import annotations

import json
import os
import re
import zipfile
from pathlib import Path
from typing import Any


ROOT = Path("/opt/eldercare100")
PLAN_PATH = ROOT / "state" / "build-plan.json"
RESULTS_PATH = ROOT / "state" / "build-results.json"


def detect_java_version(build_root: Path) -> int:
    versions: list[int] = []
    patterns = (
        r"<(?:java\.version|maven\.compiler\.source|maven\.compiler\.target|maven\.compiler\.release|jdk\.version)>\s*([^<]+)",
        r"<(?:source|target|release)>\s*([^<]+)",
    )
    for pom in [build_root / "pom.xml", *build_root.glob("*/pom.xml")]:
        if not pom.is_file():
            continue
        text = pom.read_text(encoding="utf-8", errors="ignore")
        for pattern in patterns:
            for raw in re.findall(pattern, text, flags=re.IGNORECASE):
                match = re.search(r"(?:1\.)?(\d+)", raw)
                if match:
                    versions.append(int(match.group(1)))
    requested = max(versions, default=17)
    if requested <= 8:
        return 8
    if requested <= 11:
        return 11
    if requested <= 17:
        return 17
    return 21


def executable_jar(path: Path) -> bool:
    try:
        with zipfile.ZipFile(path) as archive:
            names = archive.namelist()
            return any(name.startswith("BOOT-INF/") for name in names) or "META-INF/MANIFEST.MF" in names
    except (OSError, zipfile.BadZipFile):
        return False


def recover_backend(plan: dict[str, Any], app_dir: Path) -> dict[str, Any]:
    jar = app_dir / "app.jar"
    war = app_dir / "app.war"
    python_root = app_dir / "backend"
    dotnet_root = app_dir / "dotnet"
    backend_plan = plan.get("backend") or {}
    source = Path(backend_plan.get("remote_root") or (plan.get("frontend") or {}).get("remote_root") or "/nonexistent")
    build_root = source / ("" if backend_plan.get("build_root", ".") == "." else backend_plan.get("build_root", "."))
    java_version = detect_java_version(build_root)
    if jar.is_file() and jar.stat().st_size > 1024 and executable_jar(jar):
        return {
            "status": "built",
            "type": "java-spring",
            "return_code": 0,
            "jar": str(jar),
            "jar_bytes": jar.stat().st_size,
            "java_version": java_version,
            "build_image": f"maven:3.9-eclipse-temurin-{java_version}",
            "recovered": True,
        }
    if war.is_file() and war.stat().st_size > 1024:
        return {
            "status": "built",
            "type": "java-war",
            "return_code": 0,
            "war": str(war),
            "war_bytes": war.stat().st_size,
            "java_version": java_version,
            "build_image": f"maven:3.9-eclipse-temurin-{java_version}",
            "recovered": True,
        }
    if python_root.is_dir():
        entry = "django" if (python_root / "manage.py").is_file() else (
            "app.py" if (python_root / "app.py").is_file() else next((path.name for path in sorted(python_root.glob("*.py"))), "")
        )
        if entry:
            return {
                "status": "built",
                "type": backend_plan.get("type", "python-auto"),
                "return_code": 0,
                "entry": entry,
                "root": str(python_root),
                "file_count": sum(1 for path in python_root.rglob("*") if path.is_file()),
                "recovered": True,
            }
    if dotnet_root.is_dir():
        dlls = sorted(dotnet_root.glob("*.dll"), key=lambda path: path.stat().st_size, reverse=True)
        if dlls:
            return {
                "status": "built",
                "type": "dotnet",
                "return_code": 0,
                "root": str(dotnet_root),
                "entry_dll": dlls[0].name,
                "dotnet_version": 8,
                "file_count": sum(1 for path in dotnet_root.rglob("*") if path.is_file()),
                "recovered": True,
            }
    return {"status": "failed", "type": backend_plan.get("type") or "none", "recovered": True}


def recover_frontend(plan: dict[str, Any], app_dir: Path) -> dict[str, Any]:
    if not plan.get("frontend"):
        return {"status": "not-present", "web": "", "recovered": True}
    web = app_dir / "web"
    files = sum(1 for path in web.rglob("*") if path.is_file()) if web.is_dir() else 0
    if files:
        return {"status": "built", "return_code": 0, "web": str(web), "file_count": files, "recovered": True}
    return {"status": "failed", "return_code": 1, "web": "", "recovered": True}


def recover_database(plan: dict[str, Any]) -> dict[str, Any]:
    log = ROOT / "logs" / "build" / f"{plan['id']}.log"
    applied: list[str] = []
    failed: list[dict[str, str]] = []
    if log.is_file():
        text = log.read_text(encoding="utf-8", errors="ignore")
        for path, code in re.findall(r"--- SQL (.+?) rc=(\d+) ---", text):
            if code == "0":
                applied.append(path)
            else:
                failed.append({"path": path, "error": f"recorded return code {code}"})
    return {"database": plan["database_name"], "sql_applied": applied, "sql_failed": failed, "recovered": True}


def main() -> int:
    plans = json.loads(PLAN_PATH.read_text(encoding="utf-8"))
    results: list[dict[str, Any]] = []
    for plan in plans:
        app_dir = ROOT / "apps" / plan["id"]
        backend = recover_backend(plan, app_dir)
        frontend = recover_frontend(plan, app_dir)
        status = "built" if backend["status"] == "built" and frontend["status"] in {"built", "not-present"} else "failed"
        results.append(
            {
                "id": plan["id"],
                "primary_full_name": plan["primary_full_name"],
                "status": status,
                "backend": backend,
                "frontend": frontend,
                "database": recover_database(plan),
                "source_repairs": [],
                "log": str(ROOT / "logs" / "build" / f"{plan['id']}.log"),
                "elapsed_seconds": None,
                "recovered": True,
            }
        )
    payload = json.dumps(results, ensure_ascii=False, indent=2)
    temporary = RESULTS_PATH.with_suffix(".json.tmp")
    temporary.write_text(payload, encoding="utf-8")
    os.replace(temporary, RESULTS_PATH)
    print(f"RECOVERED={len(results)} BUILT={sum(item['status'] == 'built' for item in results)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
