from __future__ import annotations

import argparse
import json
import os
import re
from collections import Counter
from pathlib import Path
from typing import Any


TASK_ROOT = Path(__file__).resolve().parents[1]
CANONICAL = TASK_ROOT / "manifests" / "canonical-100.json"
OUTPUT = TASK_ROOT / "manifests" / "deployment-inventory.json"

IGNORED = {
    ".git",
    ".idea",
    ".vscode",
    "node_modules",
    "target",
    "build",
    "dist",
    "out",
    "vendor",
    "coverage",
    "__pycache__",
    "venv",
    ".venv",
}


def read_text(path: Path, limit: int = 2_000_000) -> str:
    try:
        if path.stat().st_size > limit:
            return ""
        return path.read_text(encoding="utf-8", errors="ignore")
    except OSError:
        return ""


def relative(root: Path, path: Path) -> str:
    return path.relative_to(root).as_posix()


def find_files(root: Path) -> list[Path]:
    files: list[Path] = []
    for current, dirs, names in os.walk(root, onerror=lambda _err: None):
        dirs[:] = [name for name in dirs if name.lower() not in IGNORED]
        current_path = Path(current)
        for name in names:
            files.append(current_path / name)
    return files


def package_info(path: Path, root: Path) -> dict[str, Any]:
    try:
        data = json.loads(path.read_text(encoding="utf-8", errors="ignore"))
    except (OSError, json.JSONDecodeError):
        data = {}
    scripts = data.get("scripts") if isinstance(data.get("scripts"), dict) else {}
    dependencies = {}
    for key in ("dependencies", "devDependencies"):
        if isinstance(data.get(key), dict):
            dependencies.update(data[key])
    framework = "node"
    for name in ("vue", "react", "@angular/core", "next", "nuxt", "vite"):
        if name in dependencies:
            framework = name
            break
    return {
        "path": relative(root, path),
        "dir": relative(root, path.parent) or ".",
        "name": str(data.get("name") or ""),
        "scripts": {key: str(value) for key, value in scripts.items()},
        "framework": framework,
        "has_build_script": any(key == "build" or key.startswith("build:") for key in scripts),
        "has_start_script": "start" in scripts or "serve" in scripts or "dev" in scripts,
    }


def pom_info(path: Path, root: Path) -> dict[str, Any]:
    text = read_text(path)
    artifact = ""
    match = re.search(r"<artifactId>\s*([^<]+)\s*</artifactId>", text)
    if match:
        artifact = match.group(1).strip()
    packaging_match = re.search(r"<packaging>\s*([^<]+)\s*</packaging>", text)
    packaging = packaging_match.group(1).strip() if packaging_match else "jar"
    return {
        "path": relative(root, path),
        "dir": relative(root, path.parent) or ".",
        "artifact": artifact,
        "packaging": packaging,
        "spring_boot_plugin": "spring-boot-maven-plugin" in text,
        "spring_web": "spring-boot-starter-web" in text or "spring-webmvc" in text,
        "modules": re.findall(r"<module>\s*([^<]+)\s*</module>", text),
        "java_version": (re.search(r"<(?:java.version|maven.compiler.source)>\s*([^<]+)", text) or [None, ""])[1],
    }


def credential_candidates(text: str) -> list[dict[str, str]]:
    found: list[dict[str, str]] = []
    patterns = [
        re.compile(
            r"(?:账号|帐号|用户名|账户|user(?:name)?|account)\s*[：:=]?\s*`?([A-Za-z0-9@._-]{2,40})`?"
            r"[^\n]{0,80}?(?:密码|口令|pass(?:word)?)\s*[：:=]?\s*`?([^\s`|,，;；<]{3,80})",
            re.I,
        ),
        re.compile(r"\b(admin|root|administrator)\s*[/|]\s*([A-Za-z0-9@._!#$%&*+-]{3,80})\b", re.I),
    ]
    for pattern in patterns:
        for match in pattern.finditer(text):
            username = match.group(1).strip("`'\"")
            password = match.group(2).strip("`'\"")
            if username.lower() in {"username", "user", "account"}:
                continue
            if password.lower() in {"password", "passwd", "pass"}:
                continue
            item = {"username": username, "password": password, "source": "README"}
            if item not in found:
                found.append(item)
    return found[:12]


def inspect_project(project: dict[str, Any]) -> dict[str, Any]:
    component_records = []
    all_credentials = []
    combined = Counter()
    for component in project["components"]:
        root = Path(component["local_dir"])
        files = find_files(root)
        compose = []
        dockerfiles = []
        sql = []
        readmes = []
        poms = []
        packages = []
        python_manifests = []
        php_manifests = []
        dotnet_manifests = []
        app_configs = []
        application_mains = []
        runtime_property_keys = set()
        template_dirs = set()
        login_paths = []
        readme_texts = []
        for path in files:
            name = path.name.lower()
            rel = relative(root, path)
            lower_rel = rel.lower()
            if name in {"docker-compose.yml", "docker-compose.yaml", "compose.yml", "compose.yaml"}:
                compose.append(rel)
            if name.startswith("dockerfile"):
                dockerfiles.append(rel)
            if name.endswith(".sql"):
                sql.append(rel)
            if name.startswith("readme"):
                readmes.append(rel)
                text = read_text(path)
                if text:
                    readme_texts.append(text)
            if name == "pom.xml":
                poms.append(pom_info(path, root))
            if name == "package.json":
                packages.append(package_info(path, root))
            if name in {"requirements.txt", "pyproject.toml", "pipfile", "manage.py"}:
                python_manifests.append(rel)
            if name == "composer.json":
                php_manifests.append(rel)
            if name.endswith((".csproj", ".sln")):
                dotnet_manifests.append(rel)
            if name in {"application.yml", "application.yaml", "application.properties", "settings.py", ".env.example"}:
                app_configs.append(rel)
                config_text = read_text(path, limit=1_000_000)
                for key in re.findall(
                    r"(?im)^\s*([A-Za-z0-9_.-]*(?:datasource|redis|server\.port|context-path)[A-Za-z0-9_.-]*)\s*[:=]",
                    config_text,
                ):
                    runtime_property_keys.add(key)
            if name.endswith(".java"):
                java_text = read_text(path, limit=600_000)
                if "SpringApplication.run" in java_text and "static void main" in java_text:
                    application_mains.append(rel)
            if "/templates/" in f"/{lower_rel}" or "/static/" in f"/{lower_rel}":
                template_dirs.add(str(Path(rel).parent).replace("\\", "/"))
            if re.search(r"(^|[/_.-])(login|signin|sign-in|auth|登录|登陆)([/_.-]|$)", lower_rel, re.I):
                login_paths.append(rel)
        readme_blob = "\n".join(readme_texts)
        creds = credential_candidates(readme_blob)
        all_credentials.extend(
            {**item, "component": component["full_name"]}
            for item in creds
            if {**item, "component": component["full_name"]} not in all_credentials
        )
        spring_boot_poms = [item for item in poms if item["spring_boot_plugin"] or item["spring_web"]]
        buildable_packages = [item for item in packages if item["has_build_script"] or item["has_start_script"]]
        combined.update(
            {
                "compose": len(compose),
                "dockerfile": len(dockerfiles),
                "sql": len(sql),
                "maven": len(poms),
                "spring_boot": len(spring_boot_poms),
                "node": len(packages),
                "node_buildable": len(buildable_packages),
                "python": len(python_manifests),
                "php": len(php_manifests),
                "dotnet": len(dotnet_manifests),
                "login_paths": len(login_paths),
            }
        )
        component_records.append(
            {
                "full_name": component["full_name"],
                "root": str(root),
                "compose": compose[:20],
                "dockerfiles": dockerfiles[:20],
                "sql": sql[:60],
                "readmes": readmes[:20],
                "poms": poms[:30],
                "packages": packages[:30],
                "python_manifests": python_manifests[:30],
                "php_manifests": php_manifests[:20],
                "dotnet_manifests": dotnet_manifests[:30],
                "app_configs": app_configs[:40],
                "application_mains": application_mains[:30],
                "runtime_property_keys": sorted(runtime_property_keys)[:80],
                "template_dirs": sorted(template_dirs)[:30],
                "login_paths": login_paths[:60],
                "credential_candidates": creds,
            }
        )
    if combined["compose"]:
        strategy = "native-compose"
    elif combined["spring_boot"] and combined["node_buildable"]:
        strategy = "spring-plus-node"
    elif combined["spring_boot"]:
        strategy = "spring-web"
    elif combined["python"] and combined["node_buildable"]:
        strategy = "python-plus-node"
    elif combined["python"]:
        strategy = "python-web"
    elif combined["php"]:
        strategy = "php-web"
    elif combined["dotnet"]:
        strategy = "dotnet-web"
    elif combined["node_buildable"]:
        strategy = "node-web"
    else:
        strategy = "manual-analysis-required"
    return {
        "id": project["id"],
        "primary_full_name": project["primary_full_name"],
        "primary_url": project["primary_url"],
        "assigned_port": 18000 + int(project["id"][2:]),
        "strategy": strategy,
        "evidence_counts": dict(combined),
        "credential_candidates": all_credentials[:20],
        "components": component_records,
        "resource_plan": {
            "cpu_limit": 0.5 if strategy.startswith("spring") or strategy == "native-compose" else 0.3,
            "memory_limit_mib": 512 if strategy.startswith("spring") or strategy == "native-compose" else 256,
            "concurrency_policy": "on-demand; stop least-recently-used project before exceeding 6 GiB aggregate",
        },
        "build_status": "not-tested",
        "http_status": "not-tested",
        "login_status": "not-tested",
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--canonical", type=Path, default=CANONICAL)
    parser.add_argument("--output", type=Path, default=OUTPUT)
    args = parser.parse_args()
    projects = json.loads(args.canonical.read_text(encoding="utf-8"))
    inventory = [inspect_project(project) for project in projects]
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(inventory, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"PROJECTS={len(inventory)}")
    print("STRATEGIES=" + json.dumps(Counter(item["strategy"] for item in inventory), ensure_ascii=False, sort_keys=True))
    print(f"WITH_CREDENTIAL_CANDIDATES={sum(bool(item['credential_candidates']) for item in inventory)}")
    print(f"WITH_NATIVE_DOCKER={sum(item['strategy'] == 'native-compose' for item in inventory)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
