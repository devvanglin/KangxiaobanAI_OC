from __future__ import annotations

import argparse
import json
import re
from collections import Counter
from pathlib import Path, PurePosixPath
from typing import Any


TASK_ROOT = Path(__file__).resolve().parents[1]
INVENTORY = TASK_ROOT / "manifests" / "deployment-inventory.json"
OUTPUT = TASK_ROOT / "manifests" / "build-plan.json"


def is_prefix(directory: str, path: str) -> bool:
    directory = "" if directory == "." else directory.strip("/")
    return not directory or path == directory or path.startswith(directory + "/")


def choose_java(component: dict[str, Any]) -> dict[str, Any] | None:
    mains = list(component.get("application_mains") or [])
    poms = list(component.get("poms") or [])
    if not mains or not poms:
        return None

    def main_score(path: str) -> int:
        lower = path.lower()
        score = 0
        score += 35 if any(token in lower for token in ("/admin/", "/web/", "/server/")) else 0
        score += 20 if lower.endswith("application.java") else 0
        score -= 50 if any(token in lower for token in ("gateway", "/test/", "demo", "generator")) else 0
        score -= 15 if any(token in lower for token in ("capi", "sapi", "petal")) else 0
        return score

    main = max(mains, key=main_score)
    ancestors = [pom for pom in poms if is_prefix(str(pom["dir"]), main)]
    if not ancestors:
        return None
    module_pom = max(ancestors, key=lambda pom: len(PurePosixPath(str(pom["dir"])).parts))
    build_root_pom = min(ancestors, key=lambda pom: len(PurePosixPath(str(pom["dir"])).parts))
    module_dir = str(module_pom["dir"])
    build_root = str(build_root_pom["dir"])
    relative_module = str(PurePosixPath(module_dir).relative_to(PurePosixPath(build_root))) if module_dir != build_root else "."
    java_versions = [str(pom.get("java_version") or "") for pom in ancestors]
    java_version = next((value for value in reversed(java_versions) if value), "17")
    return {
        "type": "java-spring",
        "application_main": main,
        "module_dir": module_dir,
        "build_root": build_root,
        "module_selector": relative_module,
        "java_version_declared": java_version,
        "maven_command": (
            ["mvn", "-B", "-ntp", "-DskipTests", "-Dmaven.test.skip=true", "package"]
            if relative_module == "."
            else [
                "mvn",
                "-B",
                "-ntp",
                "-DskipTests",
                "-Dmaven.test.skip=true",
                "-pl",
                relative_module,
                "-am",
                "package",
            ]
        ),
    }


def choose_frontend(component: dict[str, Any]) -> dict[str, Any] | None:
    packages = [item for item in component.get("packages") or [] if item.get("has_build_script")]
    if not packages:
        return None
    login_paths = list(component.get("login_paths") or [])

    def package_score(item: dict[str, Any]) -> int:
        directory = str(item["dir"])
        lower = directory.lower()
        score = 0
        score += 35 if any(is_prefix(directory, path) for path in login_paths) else 0
        score += 12 if item.get("framework") in {"vue", "react", "vite", "next", "nuxt"} else 0
        score += 8 if "admin" in lower or "manage" in lower else 0
        score -= 60 if any(token in lower for token in ("miniprogram", "mini_program", "uniapp", "uni-app", "android")) else 0
        return score

    package = max(packages, key=package_score)
    scripts = package.get("scripts") or {}
    build_scripts = [key for key in scripts if key == "build" or key.startswith("build:")]
    preferred = next((key for key in ("build:prod", "build", "build:production", "build:stage") if key in build_scripts), build_scripts[0])
    directory = str(package["dir"])
    return {
        "type": "node-static",
        "dir": directory,
        "framework": package.get("framework", "node"),
        "build_script": preferred,
        "package_manager": "auto",
        "output_candidates": [
            f"{directory}/dist" if directory != "." else "dist",
            f"{directory}/build" if directory != "." else "build",
        ],
    }


def choose_python(component: dict[str, Any]) -> dict[str, Any] | None:
    manifests = list(component.get("python_manifests") or [])
    if not manifests:
        return None
    manage = next((path for path in manifests if path.endswith("manage.py")), None)
    if manage:
        return {"type": "python-django", "dir": str(PurePosixPath(manage).parent), "entry": "manage.py"}
    requirement = next((path for path in manifests if path.endswith("requirements.txt")), manifests[0])
    return {"type": "python-auto", "dir": str(PurePosixPath(requirement).parent), "entry": "auto-detect"}


def database_engine(component: dict[str, Any]) -> str:
    root = Path(component["root"])
    mysql_hits = 0
    postgres_hits = 0
    for rel in component.get("app_configs") or []:
        path = root / rel
        try:
            text = path.read_text(encoding="utf-8", errors="ignore").lower()
        except OSError:
            continue
        mysql_hits += text.count("jdbc:mysql") + text.count("mysql://")
        postgres_hits += text.count("jdbc:postgresql") + text.count("postgresql://")
    return "postgres" if postgres_hits > mysql_hits else "mysql"


def choose_sql(component: dict[str, Any], engine: str) -> list[str]:
    candidates = []
    for path in component.get("sql") or []:
        lower = path.lower()
        if engine == "mysql" and any(token in lower for token in ("postgres", "oracle", "/dm/", "kingbase", "opengauss")):
            continue
        if engine == "postgres" and "mysql" in lower:
            continue
        score = 0
        score += 30 if any(token in lower for token in ("init", "schema", "database", "_db", "ry_")) else 0
        score += 10 if lower.endswith(".sql") else 0
        score -= 25 if any(token in lower for token in ("quartz", "test", "demo", "change", "migration")) else 0
        candidates.append((score, path))
    candidates.sort(key=lambda item: (item[0], item[1]), reverse=True)
    return [path for _score, path in candidates[:8]]


def remote_component_root(project: dict[str, Any], component: dict[str, Any]) -> str:
    base = f"/opt/eldercare100/sources/{project['id']}"
    if int(project.get("component_count") or 1) == 1:
        return base
    safe = re.sub(r"[^A-Za-z0-9._-]+", "_", str(component["full_name"]).replace("/", "__")).strip("._")[:96]
    return f"{base}/{safe}"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--inventory", type=Path, default=INVENTORY)
    parser.add_argument("--output", type=Path, default=OUTPUT)
    args = parser.parse_args()
    inventory = json.loads(args.inventory.read_text(encoding="utf-8"))
    plans = []
    for project in inventory:
        backends = []
        frontends = []
        sql_files = []
        engines = []
        for component in project["components"]:
            component = dict(component)
            component["remote_root"] = remote_component_root(project, component)
            java = choose_java(component)
            python = choose_python(component)
            frontend = choose_frontend(component)
            backend = java or python
            if backend:
                backend["component"] = component["full_name"]
                backend["remote_root"] = component["remote_root"]
                backends.append(backend)
            if frontend:
                frontend["component"] = component["full_name"]
                frontend["remote_root"] = component["remote_root"]
                frontends.append(frontend)
            engine = database_engine(component)
            engines.append(engine)
            for sql in choose_sql(component, engine):
                sql_files.append(
                    {
                        "component": component["full_name"],
                        "remote_root": component["remote_root"],
                        "path": sql,
                        "engine": engine,
                    }
                )
        backend = backends[0] if backends else None
        frontend = frontends[0] if frontends else None
        engine = "postgres" if engines.count("postgres") > engines.count("mysql") else "mysql"
        plans.append(
            {
                "id": project["id"],
                "primary_full_name": project["primary_full_name"],
                "assigned_port": project["assigned_port"],
                "inventory_strategy": project["strategy"],
                "backend": backend,
                "backend_alternatives": backends[1:],
                "frontend": frontend,
                "frontend_alternatives": frontends[1:],
                "database_engine": engine,
                "database_name": project["id"],
                "sql_files": [item for item in sql_files if item["engine"] == engine][:10],
                "resource_plan": project["resource_plan"],
                "credential_candidates": project["credential_candidates"],
                "plan_status": "ready" if backend else "manual-analysis-required",
                "build_status": "not-tested",
                "runtime_status": "not-tested",
                "login_status": "not-tested",
            }
        )
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(plans, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"PROJECTS={len(plans)}")
    print(f"WITH_BACKEND={sum(bool(item['backend']) for item in plans)}")
    print(f"WITH_FRONTEND={sum(bool(item['frontend']) for item in plans)}")
    print(f"WITH_SQL={sum(bool(item['sql_files']) for item in plans)}")
    print("BACKENDS=" + json.dumps(Counter((item["backend"] or {}).get("type", "none") for item in plans), sort_keys=True))
    print("DATABASES=" + json.dumps(Counter(item["database_engine"] for item in plans), sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
