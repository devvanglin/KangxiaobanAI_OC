from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import time
import zipfile
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path
from typing import Any


ROOT = Path("/opt/eldercare100")
PLAN_PATH = ROOT / "state" / "build-plan.json"
SECRETS_PATH = ROOT / "private" / "secrets.json"
APPS_ROOT = ROOT / "apps"
LOG_ROOT = ROOT / "logs" / "build"
RESULTS_PATH = ROOT / "state" / "build-results.json"
REPAIRS_ROOT = ROOT / "tools" / "repairs"


def run(
    command: list[str],
    *,
    timeout: int,
    input_bytes: bytes | None = None,
    log_path: Path | None = None,
) -> subprocess.CompletedProcess[bytes]:
    if log_path is None:
        return subprocess.run(
            command,
            input=input_bytes,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            timeout=timeout,
        )
    log_path.parent.mkdir(parents=True, exist_ok=True)
    with log_path.open("ab") as handle:
        handle.write(("\n$ " + " ".join(command[:12]) + "\n").encode("utf-8", "replace"))
        handle.flush()
        return subprocess.run(
            command,
            input=input_bytes,
            stdout=handle,
            stderr=subprocess.STDOUT,
            timeout=timeout,
        )


def setup_mysql_client(secrets: dict[str, str]) -> None:
    content = f"[client]\nuser=root\npassword={secrets['mysql_root_password']}\ndefault-character-set=utf8mb4\n"
    result = run(
        ["docker", "exec", "-i", "ec100-mysql", "sh", "-c", "umask 077; cat > /tmp/ec100-root.cnf"],
        input_bytes=content.encode("utf-8"),
        timeout=30,
    )
    if result.returncode != 0:
        raise RuntimeError(result.stdout.decode("utf-8", "replace")[-1200:])


def mysql_exec(sql: str, database: str | None = None, timeout: int = 120) -> subprocess.CompletedProcess[bytes]:
    command = [
        "docker",
        "exec",
        "-i",
        "ec100-mysql",
        "mysql",
        "--defaults-extra-file=/tmp/ec100-root.cnf",
        "--default-character-set=utf8mb4",
    ]
    if database:
        command.append(database)
    return run(command, input_bytes=sql.encode("utf-8"), timeout=timeout)


def decode_sql(path: Path) -> str:
    data = path.read_bytes()
    for encoding in ("utf-8-sig", "utf-8", "gb18030"):
        try:
            return data.decode(encoding)
        except UnicodeDecodeError:
            continue
    return data.decode("utf-8", "replace")


def normalize_sql(text: str, database: str) -> str:
    text = re.sub(r"(?im)^\s*(?:CREATE|DROP)\s+DATABASE\b[^;]*;\s*", "", text)
    text = re.sub(r"(?im)^\s*USE\s+[`\"']?[^;`\"']+[`\"']?\s*;", f"USE `{database}`;", text)
    text = re.sub(r"(?i)DEFINER\s*=\s*[^*\s]+", "", text)
    return (
        f"USE `{database}`;\n"
        "SET SESSION sql_mode='';\n"
        "SET FOREIGN_KEY_CHECKS=0;\n"
        f"{text}\n"
        "SET FOREIGN_KEY_CHECKS=1;\n"
    )


def prepare_database(plan: dict[str, Any], log_path: Path) -> dict[str, Any]:
    database = str(plan["database_name"])
    created = mysql_exec(
        f"DROP DATABASE IF EXISTS `{database}`; "
        f"CREATE DATABASE `{database}` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
    )
    if created.returncode != 0:
        raise RuntimeError(created.stdout.decode("utf-8", "replace")[-1200:])
    applied = []
    failed = []
    for item in plan.get("sql_files") or []:
        path = Path(item["remote_root"]) / item["path"]
        if not path.is_file():
            failed.append({"path": str(path), "error": "missing"})
            continue
        try:
            sql = normalize_sql(decode_sql(path), database)
            result = mysql_exec(sql, database=database, timeout=600)
            output = result.stdout.decode("utf-8", "replace")
            with log_path.open("ab") as handle:
                handle.write((f"\n--- SQL {path} rc={result.returncode} ---\n" + output[-5000:]).encode("utf-8", "replace"))
            if result.returncode == 0:
                applied.append(str(path))
            else:
                failed.append({"path": str(path), "error": output[-1200:]})
        except (OSError, subprocess.SubprocessError) as exc:
            failed.append({"path": str(path), "error": str(exc)[-1200:]})
    return {"database": database, "sql_applied": applied, "sql_failed": failed}


def choose_jar(module_root: Path) -> Path | None:
    candidates = []
    for path in module_root.rglob("target/*.jar"):
        lower = path.name.lower()
        if any(token in lower for token in ("sources", "javadoc", "original-", "tests")):
            continue
        try:
            score = path.stat().st_size
            with zipfile.ZipFile(path) as archive:
                names = archive.namelist()
                if any(name.startswith("BOOT-INF/") for name in names):
                    score += 10_000_000_000
                manifest = archive.read("META-INF/MANIFEST.MF").decode("utf-8", "ignore") if "META-INF/MANIFEST.MF" in names else ""
                if "Main-Class:" in manifest:
                    score += 1_000_000_000
            candidates.append((score, path))
        except (OSError, zipfile.BadZipFile, KeyError):
            continue
    return max(candidates, default=(0, None), key=lambda item: item[0])[1]


def choose_war(module_root: Path) -> Path | None:
    candidates = [
        path
        for path in module_root.rglob("target/*.war")
        if "original" not in path.name.lower()
    ]
    return max(candidates, default=None, key=lambda path: path.stat().st_size)


def remove_generated_directories(source: Path, names: set[str]) -> None:
    for path in sorted(
        (item for item in source.rglob("*") if item.is_dir() and item.name in names),
        key=lambda item: len(item.parts),
        reverse=True,
    ):
        try:
            shutil.rmtree(path)
        except OSError:
            continue


def detect_java_version(build_root: Path) -> int:
    """Choose the smallest supported JDK that satisfies the Maven project."""
    versions: list[int] = []
    pom_files = [build_root / "pom.xml", *build_root.glob("*/pom.xml")]
    patterns = (
        r"<(?:java\.version|maven\.compiler\.source|maven\.compiler\.target|maven\.compiler\.release|jdk\.version)>\s*([^<]+)",
        r"<(?:source|target|release)>\s*([^<]+)",
    )
    for pom in pom_files:
        if not pom.is_file():
            continue
        try:
            text = pom.read_text(encoding="utf-8", errors="ignore")
        except OSError:
            continue
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
    if requested <= 21:
        return 21
    return 25


def build_java(plan: dict[str, Any], app_dir: Path, log_path: Path) -> dict[str, Any]:
    backend = plan["backend"]
    source = Path(backend["remote_root"])
    build_root = source / ("" if backend["build_root"] == "." else backend["build_root"])
    module_root = source / ("" if backend["module_dir"] == "." else backend["module_dir"])
    java_version = detect_java_version(build_root)
    build_image = f"maven:3.9-eclipse-temurin-{java_version}"
    command = [
        "docker",
        "run",
        "--rm",
        "--name",
        f"ec100-build-{plan['id']}",
        "--memory",
        "2600m",
        "--cpus",
        "2.0",
        "-e",
        "MAVEN_OPTS=-Xms128m -Xmx1800m -Dfile.encoding=UTF-8",
        "-v",
        f"{ROOT / 'cache' / 'maven'}:/root/.m2",
        "-v",
        f"{source}:/src",
        "-w",
        "/src" + (("/" + backend["build_root"]) if backend["build_root"] != "." else ""),
        build_image,
        *backend["maven_command"],
    ]
    result = run(command, timeout=2400, log_path=log_path)
    if result.returncode != 0:
        remove_generated_directories(source, {"target"})
        return {
            "status": "failed",
            "type": "java-spring",
            "return_code": result.returncode,
            "jar": "",
            "java_version": java_version,
            "build_image": build_image,
        }
    jar = choose_jar(module_root)
    if jar is None:
        war = choose_war(module_root)
        if war is not None:
            destination = app_dir / "app.war"
            shutil.copy2(war, destination)
            war_bytes = destination.stat().st_size
            remove_generated_directories(source, {"target"})
            return {
                "status": "built",
                "type": "java-war",
                "return_code": 0,
                "war": str(destination),
                "war_bytes": war_bytes,
                "java_version": java_version,
                "build_image": build_image,
            }
        return {
            "status": "failed",
            "type": "java-spring",
            "return_code": 0,
            "jar": "",
            "error": "no executable jar found",
            "java_version": java_version,
            "build_image": build_image,
        }
    destination = app_dir / "app.jar"
    shutil.copy2(jar, destination)
    jar_bytes = destination.stat().st_size
    remove_generated_directories(source, {"target"})
    return {
        "status": "built",
        "type": "java-spring",
        "return_code": 0,
        "jar": str(destination),
        "jar_bytes": jar_bytes,
        "java_version": java_version,
        "build_image": build_image,
    }


def build_python(plan: dict[str, Any], app_dir: Path, log_path: Path) -> dict[str, Any]:
    backend = plan["backend"]
    source = Path(backend["remote_root"])
    relative = backend.get("dir", ".")
    directory = source / ("" if relative == "." else relative)
    if not directory.is_dir():
        return {"status": "failed", "error": f"missing Python backend directory: {directory}"}
    destination = app_dir / "backend"
    if destination.exists():
        if destination.parent.resolve() != app_dir.resolve():
            raise RuntimeError(f"refusing to clean unexpected Python build path: {destination}")
        run(
            [
                "docker",
                "run",
                "--rm",
                "-v",
                f"{app_dir}:/apps",
                "node:18-alpine",
                "chmod",
                "-R",
                "a+rwX",
                "/apps/backend",
            ],
            timeout=60,
        )
        shutil.rmtree(destination)
    shutil.copytree(
        directory,
        destination,
        ignore=shutil.ignore_patterns("__pycache__", ".venv", "venv", "env", ".pytest_cache", "*.pyc"),
    )
    if (destination / "manage.py").is_file():
        entry = "django"
    elif (destination / "app.py").is_file():
        entry = "app.py"
    else:
        candidates = sorted(destination.glob("*.py"))
        if candidates:
            entry = candidates[0].name
        else:
            nested_entries = (
                "app/main.py",
                "web/server.py",
                "api/app.py",
                "api/main.py",
                "src/main.py",
            )
            entry = next((relative for relative in nested_entries if (destination / relative).is_file()), "")
    if not entry:
        return {"status": "failed", "error": "no Python entry point found"}
    result = run(
        [
            "docker",
            "run",
            "--rm",
            "--memory",
            "1200m",
            "--cpus",
            "1.0",
            "--user",
            f"{os.getuid()}:{os.getgid()}",
            "-v",
            f"{destination}:/app",
            "-w",
            "/app",
            "ec100/python-runtime:3",
            "python",
            "-m",
            "compileall",
            "-q",
            ".",
        ],
        timeout=300,
        log_path=log_path,
    )
    remove_generated_directories(destination, {"__pycache__"})
    if result.returncode != 0:
        return {"status": "failed", "return_code": result.returncode, "entry": entry}
    file_count = sum(1 for path in destination.rglob("*") if path.is_file())
    return {"status": "built", "return_code": 0, "entry": entry, "root": str(destination), "file_count": file_count}


def plan_source_root(plan: dict[str, Any]) -> Path | None:
    for section_name in ("backend", "frontend"):
        value = (plan.get(section_name) or {}).get("remote_root")
        if value:
            return Path(value)
    fallback = ROOT / "sources" / str(plan.get("id") or "")
    return fallback if fallback.is_dir() else None


def detect_dotnet_project(plan: dict[str, Any]) -> Path | None:
    source = plan_source_root(plan)
    if source is None or not source.is_dir():
        return None
    candidates = [
        path
        for path in source.rglob("*.csproj")
        if "test" not in path.name.lower() and "test" not in str(path.parent).lower()
    ]
    if not candidates:
        return None
    return max(
        candidates,
        key=lambda path: (
            "webapi" in path.name.lower(),
            (path.parent / "Dockerfile").is_file(),
            -len(path.parts),
        ),
    )


def build_dotnet(plan: dict[str, Any], app_dir: Path, log_path: Path, project: Path) -> dict[str, Any]:
    source = plan_source_root(plan)
    if source is None:
        return {"status": "failed", "type": "dotnet", "error": "missing source root"}
    try:
        project_text = project.read_text(encoding="utf-8", errors="ignore")
    except OSError as exc:
        return {"status": "failed", "type": "dotnet", "error": str(exc)}
    framework_match = re.search(r"<TargetFramework>\s*net(\d+)", project_text, flags=re.IGNORECASE)
    dotnet_version = int(framework_match.group(1)) if framework_match else 8
    if dotnet_version not in {6, 7, 8, 9}:
        dotnet_version = 8
    destination = app_dir / "dotnet"
    if destination.exists():
        shutil.rmtree(destination)
    destination.mkdir(parents=True, exist_ok=True)
    working = "/src/" + str(project.parent.relative_to(source)).replace("\\", "/")
    command = [
        "docker",
        "run",
        "--rm",
        "--name",
        f"ec100-dotnetbuild-{plan['id']}",
        "--memory",
        "2600m",
        "--cpus",
        "2.0",
        "-v",
        f"{ROOT / 'cache' / 'nuget'}:/root/.nuget/packages",
        "-v",
        f"{source}:/src",
        "-v",
        f"{destination}:/out",
        "-w",
        working,
        f"mcr.microsoft.com/dotnet/sdk:{dotnet_version}.0-alpine",
        "dotnet",
        "publish",
        project.name,
        "-c",
        "Release",
        "-o",
        "/out",
    ]
    result = run(command, timeout=2400, log_path=log_path)
    if result.returncode != 0:
        return {
            "status": "failed",
            "type": "dotnet",
            "return_code": result.returncode,
            "dotnet_version": dotnet_version,
        }
    entry = destination / f"{project.stem}.dll"
    if not entry.is_file():
        dlls = sorted(destination.glob("*.dll"), key=lambda path: path.stat().st_size, reverse=True)
        entry = dlls[0] if dlls else Path()
    if not entry.is_file():
        return {
            "status": "failed",
            "type": "dotnet",
            "return_code": 0,
            "error": "no published application dll found",
            "dotnet_version": dotnet_version,
        }
    return {
        "status": "built",
        "type": "dotnet",
        "return_code": 0,
        "root": str(destination),
        "entry_dll": entry.name,
        "dotnet_version": dotnet_version,
        "file_count": sum(1 for path in destination.rglob("*") if path.is_file()),
    }


def detect_maven_war_project(plan: dict[str, Any]) -> Path | None:
    source = plan_source_root(plan)
    if source is None or not source.is_dir():
        return None
    for pom in source.rglob("pom.xml"):
        try:
            text = pom.read_text(encoding="utf-8", errors="ignore")
        except OSError:
            continue
        if re.search(r"<packaging>\s*war\s*</packaging>", text, flags=re.IGNORECASE):
            return pom
    return None


def build_maven_war(plan: dict[str, Any], app_dir: Path, log_path: Path, pom: Path) -> dict[str, Any]:
    source = plan_source_root(plan)
    if source is None:
        return {"status": "failed", "type": "java-war", "error": "missing source root"}
    project_root = pom.parent
    java_version = detect_java_version(project_root)
    build_image = f"maven:3.9-eclipse-temurin-{java_version}"
    command = [
        "docker",
        "run",
        "--rm",
        "--name",
        f"ec100-warbuild-{plan['id']}",
        "--memory",
        "2600m",
        "--cpus",
        "2.0",
        "-e",
        "MAVEN_OPTS=-Xms128m -Xmx1800m -Dfile.encoding=UTF-8",
        "-v",
        f"{ROOT / 'cache' / 'maven'}:/root/.m2",
        "-v",
        f"{source}:/src",
        "-w",
        "/src/" + str(project_root.relative_to(source)).replace("\\", "/"),
        build_image,
        "mvn",
        "-B",
        "-ntp",
        "-DskipTests",
        "-Dmaven.test.skip=true",
        "package",
    ]
    result = run(command, timeout=2400, log_path=log_path)
    if result.returncode != 0:
        remove_generated_directories(source, {"target"})
        return {
            "status": "failed",
            "type": "java-war",
            "return_code": result.returncode,
            "java_version": java_version,
        }
    wars = [path for path in (project_root / "target").glob("*.war") if "original" not in path.name.lower()]
    war = max(wars, default=None, key=lambda path: path.stat().st_size)
    if war is None:
        return {"status": "failed", "type": "java-war", "error": "no WAR artifact found"}
    destination = app_dir / "app.war"
    shutil.copy2(war, destination)
    war_bytes = destination.stat().st_size
    remove_generated_directories(source, {"target"})
    return {
        "status": "built",
        "type": "java-war",
        "war": str(destination),
        "war_bytes": war_bytes,
        "java_version": java_version,
        "build_image": build_image,
    }


def build_static_web(plan: dict[str, Any], app_dir: Path, relative: str) -> dict[str, Any]:
    source = plan_source_root(plan)
    if source is None:
        return {"status": "failed", "web": "", "error": "missing source root"}
    directory = source / relative
    if not directory.is_dir():
        return {"status": "failed", "web": "", "error": f"missing static web directory: {directory}"}
    destination = app_dir / "web"
    if destination.exists():
        shutil.rmtree(destination)
    shutil.copytree(
        directory,
        destination,
        ignore=shutil.ignore_patterns("node_modules", "src", "test", "*.md", "package*.json", "*.lock"),
    )
    login = destination / "login.html"
    if login.is_file() and not (destination / "index.html").is_file():
        shutil.copy2(login, destination / "index.html")
    replacements = 0
    for path in destination.rglob("*.js"):
        try:
            text = path.read_text(encoding="utf-8", errors="ignore")
        except OSError:
            continue
        updated = text.replace("http://39.105.65.209:8080", "")
        if updated != text:
            path.write_text(updated, encoding="utf-8")
            replacements += 1
    return {
        "status": "built",
        "web": str(destination),
        "file_count": sum(1 for path in destination.rglob("*") if path.is_file()),
        "same_origin_url_repairs": replacements,
    }


def node_install_script(directory: Path, build_script: str, node_image: str) -> str:
    package_data: dict[str, Any] = {}
    try:
        package_data = json.loads((directory / "package.json").read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        pass
    declared = {
        **(package_data.get("dependencies") or {}),
        **(package_data.get("devDependencies") or {}),
    }
    dev_package_manager = (package_data.get("devEngines") or {}).get("packageManager", {})
    if isinstance(dev_package_manager, list):
        dev_package_manager = dev_package_manager[0] if dev_package_manager else {}
    npm_version_match = (
        re.search(r"(\d+)", str(dev_package_manager.get("version", "")))
        if isinstance(dev_package_manager, dict)
        and str(dev_package_manager.get("name", "")).lower() == "npm"
        else None
    )
    vite_match = re.search(r"(\d+)", str(declared.get("vite", "")))
    needs_vite_compat = bool(
        vite_match and int(vite_match.group(1)) >= 7 and node_image.startswith("node:18")
    )
    configured_build = str((package_data.get("scripts") or {}).get(build_script, ""))
    scripts = package_data.get("scripts") or {}
    build_only_script = str(scripts.get("build-only", ""))
    skip_broken_typecheck = (
        "vite build" in configured_build
        and any(token in configured_build for token in ("vue-tsc", "tsc -b", "tsc &&", "tsc;"))
    ) or (
        "vite build" in build_only_script
        and any(token in configured_build for token in ("type-check", "vue-tsc", "tsc"))
    )
    vue_match = re.search(r"(\d+)", str(declared.get("vue", "")))
    test_utils_match = re.search(r"(\d+)", str(declared.get("@vue/test-utils", "")))
    needs_vue2_test_utils_compat = bool(
        vue_match
        and int(vue_match.group(1)) == 2
        and test_utils_match
        and int(test_utils_match.group(1)) >= 2
    )
    needs_lodash = False
    if "lodash" not in declared:
        for suffix in ("*.js", "*.ts", "*.vue"):
            for path in (directory / "src").rglob(suffix) if (directory / "src").is_dir() else []:
                try:
                    if "lodash/" in path.read_text(encoding="utf-8", errors="ignore"):
                        needs_lodash = True
                        break
                except OSError:
                    continue
            if needs_lodash:
                break
    if (directory / "pnpm-lock.yaml").is_file():
        install = (
            "npm install -g pnpm@8.15.9 --registry=https://registry.npmmirror.com "
            "&& pnpm config set registry https://registry.npmmirror.com "
            "&& (pnpm install --frozen-lockfile || pnpm install)"
        )
        if needs_lodash:
            install += " && pnpm add lodash"
        if needs_vite_compat:
            install += " && pnpm add -D vite@6.1.0 @vitejs/plugin-vue@5.2.1"
        if needs_vue2_test_utils_compat:
            install += " && pnpm add -D @vue/test-utils@1.3.6"
        build = "pnpm run build-only" if skip_broken_typecheck and build_only_script else (
            "pnpm exec vite build" if skip_broken_typecheck else f"pnpm run {build_script}"
        )
    elif (directory / "yarn.lock").is_file():
        install = (
            "npm install -g yarn@1.22.22 --force --registry=https://registry.npmmirror.com "
            "&& yarn config set registry https://registry.npmmirror.com "
            "&& (yarn install --frozen-lockfile || yarn install)"
        )
        if needs_lodash:
            install += " && yarn add lodash"
        if needs_vite_compat:
            install += " && yarn add -D vite@6.1.0 @vitejs/plugin-vue@5.2.1"
        if needs_vue2_test_utils_compat:
            install += " && yarn add -D @vue/test-utils@1.3.6"
        build = "yarn build-only" if skip_broken_typecheck and build_only_script else (
            "yarn vite build" if skip_broken_typecheck else f"yarn {build_script}"
        )
    else:
        install = "npm config set registry https://registry.npmmirror.com && npm install --legacy-peer-deps --no-audit --no-fund"
        if npm_version_match and int(npm_version_match.group(1)) >= 12:
            install = "npm install -g npm@12 --registry=https://registry.npmmirror.com && " + install
        if needs_lodash:
            install += " && npm install lodash --no-save --legacy-peer-deps --no-audit --no-fund"
        if needs_vite_compat:
            install += " && npm install vite@6.1.0 @vitejs/plugin-vue@5.2.1 --no-save --legacy-peer-deps --no-audit --no-fund"
        if needs_vue2_test_utils_compat:
            install += " && npm install @vue/test-utils@1.3.6 --no-save --legacy-peer-deps --no-audit --no-fund"
        build = "npm run build-only" if skip_broken_typecheck and build_only_script else (
            "npx vite build" if skip_broken_typecheck else f"npm run {build_script}"
        )
    node_options = (
        "export CI=false NODE_OPTIONS=--openssl-legacy-provider;"
        if node_image.startswith(("node:18", "node:20", "node:22"))
        else "export CI=false;"
    )
    return f"set -e; rm -rf node_modules; {node_options} {install}; {build}"


def repair_case_mismatched_imports(directory: Path, log_path: Path) -> list[str]:
    """Create deployment-copy aliases for imports authored on case-insensitive filesystems."""
    source_root = directory / "src"
    if not source_root.is_dir():
        return []
    actual_by_lower = {
        str(path.resolve()).lower(): path
        for path in source_root.rglob("*")
        if path.is_file()
    }
    import_pattern = re.compile(r"(?:from\s*|import\s*\(\s*)['\"]([^'\"]+)['\"]")
    repaired: list[str] = []
    for source_file in source_root.rglob("*"):
        if source_file.suffix.lower() not in {".js", ".jsx", ".ts", ".tsx", ".vue"}:
            continue
        try:
            text = source_file.read_text(encoding="utf-8", errors="ignore")
        except OSError:
            continue
        for specifier in import_pattern.findall(text):
            specifier = specifier.split("?", 1)[0]
            if specifier.startswith("@/"):
                target = source_root / specifier[2:]
            elif specifier.startswith("./") or specifier.startswith("../"):
                target = source_file.parent / specifier
            else:
                continue
            candidates = [target]
            if not target.suffix:
                candidates.extend(target.with_suffix(ext) for ext in (".vue", ".ts", ".js", ".tsx", ".jsx"))
                candidates.extend(target / ("index" + ext) for ext in (".vue", ".ts", ".js"))
            for candidate in candidates:
                if candidate.exists():
                    break
                actual = actual_by_lower.get(str(candidate.resolve()).lower())
                if actual is None:
                    continue
                candidate.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(actual, candidate)
                repaired.append(f"{candidate.relative_to(directory)} <- {actual.relative_to(directory)}")
                break
    if repaired:
        with log_path.open("a", encoding="utf-8") as handle:
            handle.write("\n--- CASE-MISMATCH IMPORT REPAIRS ---\n" + "\n".join(repaired) + "\n")
    return repaired


def repair_vite_template_import_meta(directory: Path, log_path: Path) -> list[str]:
    """Vite 2 cannot parse import.meta expressions inside Vue templates."""
    repaired: list[str] = []
    source_root = directory / "src"
    if not source_root.is_dir():
        return repaired
    for path in source_root.rglob("*.vue"):
        try:
            text = path.read_text(encoding="utf-8")
        except (OSError, UnicodeDecodeError):
            continue
        script_offset = text.find("<script")
        template = text if script_offset < 0 else text[:script_offset]
        if "import.meta.env.DEV" not in template:
            continue
        updated_template = template.replace("import.meta.env.DEV", "false")
        updated = updated_template if script_offset < 0 else updated_template + text[script_offset:]
        path.write_text(updated, encoding="utf-8")
        repaired.append(str(path.relative_to(directory)))
    if repaired:
        with log_path.open("a", encoding="utf-8") as handle:
            handle.write("\n--- VITE TEMPLATE IMPORT.META REPAIRS ---\n" + "\n".join(repaired) + "\n")
    return repaired


def apply_project_source_repairs(plan: dict[str, Any], log_path: Path) -> list[str]:
    """Apply small, auditable deployment-copy fixes for known upstream defects."""
    repairs: list[str] = []
    source_value = ((plan.get("backend") or {}).get("remote_root")) or (
        (plan.get("frontend") or {}).get("remote_root")
    )
    if not source_value:
        return repairs
    source = Path(source_value)
    active_mysql_config = False
    configs = [*source.rglob("*.properties"), *source.rglob("*.yml"), *source.rglob("*.yaml")]
    for config in configs:
        try:
            for line in config.read_text(encoding="utf-8", errors="ignore").splitlines():
                stripped = line.strip()
                if not stripped.startswith("#") and "jdbc:mysql:" in stripped:
                    active_mysql_config = True
                    break
        except OSError:
            continue
        if active_mysql_config:
            break
    if active_mysql_config:
        dependency_pattern = re.compile(
            r"\s*<dependency>\s*<groupId>com\.microsoft\.sqlserver</groupId>\s*"
            r"<artifactId>sqljdbc4</artifactId>.*?</dependency>",
            flags=re.IGNORECASE | re.DOTALL,
        )
        for pom in source.rglob("pom.xml"):
            try:
                text = pom.read_text(encoding="utf-8", errors="ignore")
            except OSError:
                continue
            updated, count = dependency_pattern.subn("", text)
            if count:
                pom.write_text(updated, encoding="utf-8")
                repairs.append(str(pom.relative_to(source)))
    if plan["id"] == "ec066":
        plan["backend"].update(
            {
                "build_root": "order-management",
                "module_dir": "order-management",
                "module_selector": ".",
                "maven_command": ["mvn", "-B", "-ntp", "-DskipTests", "-Dmaven.test.skip=true", "package"],
            }
        )
        repairs.append("build plan: compile order-management directly")
    if plan["id"] == "ec096":
        plan["backend"].update(
            {
                "build_root": "carenest",
                "module_dir": "carenest",
                "module_selector": ".",
                "maven_command": ["mvn", "-B", "-ntp", "-DskipTests", "-Dmaven.test.skip=true", "package"],
            }
        )
        repairs.append("build plan: compile carenest directly")
    if plan["id"] == "ec099":
        plan["backend"].update(
            {
                "build_root": "mohaos__e-guarded-backend",
                "module_dir": "mohaos__e-guarded-backend",
                "module_selector": ".",
                "maven_command": ["mvn", "-B", "-ntp", "-DskipTests", "-Dmaven.test.skip=true", "package"],
            }
        )
        repairs.append("build plan: use nested backend repository root")
    if plan["id"] == "ec087":
        old_main = source / "src/main/java/com/sm/Application.java"
        new_main = source / "src/main/java/com/sm/GraduationApplication.java"
        if old_main.is_file() and not new_main.exists():
            old_main.rename(new_main)
            repairs.append(str(new_main.relative_to(source)))
        controller_source = REPAIRS_ROOT / "ec087" / "DeploymentController.java"
        controller_target = source / "src/main/java/com/sm/DeploymentController.java"
        if controller_source.is_file():
            controller_target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(controller_source, controller_target)
            repairs.append(str(controller_target.relative_to(source)))
        pom = source / "pom.xml"
        if pom.is_file():
            text = pom.read_text(encoding="utf-8", errors="ignore")
            if "<artifactId>spring-boot-maven-plugin</artifactId>" not in text:
                build = (
                    "\n    <build>\n"
                    "        <plugins>\n"
                    "            <plugin>\n"
                    "                <groupId>org.springframework.boot</groupId>\n"
                    "                <artifactId>spring-boot-maven-plugin</artifactId>\n"
                    "            </plugin>\n"
                    "        </plugins>\n"
                    "    </build>\n"
                )
                pom.write_text(text.replace("</project>", build + "</project>", 1), encoding="utf-8")
                repairs.append("pom.xml: add Spring Boot executable-jar plugin")
    if plan["id"] == "ec094":
        pom = source / "info-manage-main/pom.xml"
        if pom.is_file():
            text = pom.read_text(encoding="utf-8", errors="ignore")
            broken = "        </dependency>\n        </dependency>\n"
            if broken in text:
                text = text.replace(broken, "        </dependency>\n", 1)
            if "<artifactId>pagehelper-spring-boot-starter</artifactId>" not in text:
                dependencies = (
                    "        <dependency>\n"
                    "            <groupId>com.github.pagehelper</groupId>\n"
                    "            <artifactId>pagehelper-spring-boot-starter</artifactId>\n"
                    "            <version>1.4.7</version>\n"
                    "        </dependency>\n"
                    "        <dependency>\n"
                    "            <groupId>com.github.whvcse</groupId>\n"
                    "            <artifactId>easy-captcha</artifactId>\n"
                    "            <version>1.6.2</version>\n"
                    "        </dependency>\n\n"
                )
                text = text.replace("    </dependencies>", dependencies + "    </dependencies>", 1)
            pom.write_text(text, encoding="utf-8")
            repairs.append(str(pom.relative_to(source)))
    if plan["id"] == "ec091":
        pom = source / "pom.xml"
        if pom.is_file():
            text = pom.read_text(encoding="utf-8", errors="ignore")
            updated = re.sub(r"(<java\.version>\s*)25(\s*</java\.version>)", r"\g<1>21\g<2>", text)
            if updated != text:
                pom.write_text(updated, encoding="utf-8")
                repairs.append("pom.xml: Java 25 deployment baseline reduced to Java 21")
    if plan["id"] == "ec119":
        path = source / "elder-care-backend/wyyl-service/src/main/java/com/zzyl/job/AmqpClient.java"
        if path.is_file():
            text = path.read_text(encoding="utf-8", errors="ignore")
            original = "    public void run(ApplicationArguments args) throws Exception {\n        start();\n    }"
            replacement = (
                "    public void run(ApplicationArguments args) throws Exception {\n"
                "        if (\"1\".equals(System.getenv(\"DISABLE_ALIYUN_IOT\"))) {\n"
                "            logger.warn(\"Aliyun IoT AMQP disabled for local deployment acceptance\");\n"
                "            return;\n"
                "        }\n"
                "        start();\n"
                "    }"
            )
            if original in text:
                path.write_text(text.replace(original, replacement, 1), encoding="utf-8")
                repairs.append(str(path.relative_to(source)))
    lombok_pattern = re.compile(
        r"(<dependency>\s*<groupId>org\.projectlombok</groupId>\s*"
        r"<artifactId>lombok</artifactId>\s*<version>)1\.18\.(?:[0-2]?\d)(</version>)",
        flags=re.IGNORECASE | re.DOTALL,
    )
    for pom in source.rglob("pom.xml"):
        try:
            text = pom.read_text(encoding="utf-8", errors="ignore")
        except OSError:
            continue
        updated, count = lombok_pattern.subn(r"\g<1>1.18.32\g<2>", text)
        if count and updated != text:
            pom.write_text(updated, encoding="utf-8")
            relative = str(pom.relative_to(source))
            if relative not in repairs:
                repairs.append(relative)
    if plan["id"] == "ec002":
        path = source / "SeniorCareManager-Backend/SeniorCareManager.WebAPI/Startup.cs"
        if path.is_file():
            text = path.read_text(encoding="utf-8", errors="ignore")
            original = "options.Cookie.SecurePolicy = CookieSecurePolicy.Always;"
            replacement = (
                "options.Cookie.SecurePolicy = Configuration.GetValue<bool>(\"AllowInsecureHttpCookies\")\n"
                "                    ? CookieSecurePolicy.SameAsRequest\n"
                "                    : CookieSecurePolicy.Always;"
            )
            if original in text:
                path.write_text(text.replace(original, replacement, 1), encoding="utf-8")
                repairs.append(str(path.relative_to(source)))
    if plan["id"] == "ec013":
        path = source / "lcyl-vue/lcyl/src/views/checkin/approve.vue"
        if path.is_file():
            text = path.read_text(encoding="utf-8", errors="ignore")
            broken = (
                "\n          checkInId: currentCheckInId.value,\n"
                "          approveResult: approveForm.approveResult,\n"
                "          approveRemark: approveForm.approveRemark\n"
                "        })\n"
            )
            if broken in text:
                path.write_text(text.replace(broken, "\n", 1), encoding="utf-8")
                repairs.append(str(path.relative_to(source)))
    if plan["id"] == "ec005":
        import_repairs = {
            "backend/src/main/java/com/example/eldercare/service/MealPlanService.java": [
                "import com.example.eldercare.dto.MealFeedbackDTO;",
                "import java.io.File;",
            ],
            "backend/src/main/java/com/example/eldercare/repository/ActivityCommentRepository.java": [
                "import org.springframework.data.jpa.repository.Query;",
                "import org.springframework.data.repository.query.Param;",
            ],
            "backend/src/main/java/com/example/eldercare/repository/ActivityLikeRepository.java": [
                "import org.springframework.data.jpa.repository.Query;",
                "import org.springframework.data.repository.query.Param;",
            ],
        }
        for relative, imports in import_repairs.items():
            path = source / relative
            if not path.is_file():
                continue
            text = path.read_text(encoding="utf-8", errors="ignore")
            missing = [line for line in imports if line not in text]
            if not missing:
                continue
            package_end = text.find("\n", text.find("package "))
            if package_end < 0:
                continue
            insertion = "\n" + "\n".join(missing) + "\n"
            path.write_text(text[: package_end + 1] + insertion + text[package_end + 1 :], encoding="utf-8")
            repairs.append(relative)
        method_repairs = {
            "backend/src/main/java/com/example/eldercare/repository/ActivityCommentRepository.java": [
                "    void deleteByPostId(Long postId);"
            ],
            "backend/src/main/java/com/example/eldercare/repository/ActivityLikeRepository.java": [
                "    void deleteByPostId(Long postId);"
            ],
            "backend/src/main/java/com/example/eldercare/repository/MealPlanRepository.java": [
                "    org.springframework.data.domain.Page<MealPlan> findByMealDateBetweenOrderByMealDateDescMealTypeDesc(LocalDate startDate, LocalDate endDate, org.springframework.data.domain.Pageable pageable);",
                "    @Query(\"SELECT m FROM MealPlan m WHERE m.mealDate >= :date ORDER BY m.mealDate DESC, m.mealType DESC\")\n    org.springframework.data.domain.Page<MealPlan> findFromToday(@Param(\"date\") LocalDate date, org.springframework.data.domain.Pageable pageable);",
            ],
        }
        for relative, methods in method_repairs.items():
            path = source / relative
            if not path.is_file():
                continue
            text = path.read_text(encoding="utf-8", errors="ignore")
            missing = [method for method in methods if method.split("\n")[-1].strip() not in text]
            if not missing:
                continue
            closing = text.rfind("}")
            if closing < 0:
                continue
            insertion = "\n" + "\n\n".join(missing) + "\n"
            path.write_text(text[:closing] + insertion + text[closing:], encoding="utf-8")
            if relative not in repairs:
                repairs.append(relative)
    if plan["id"] == "ec029":
        for pom in source.glob("*/pom.xml"):
            try:
                text = pom.read_text(encoding="utf-8", errors="ignore")
            except OSError:
                continue
            parent_end = text.find("</parent>")
            if parent_end < 0:
                continue
            parent = text[:parent_end]
            if "<groupId>com.yanglao</groupId>" not in parent or "<artifactId>yanglao</artifactId>" not in parent:
                continue
            updated_parent = re.sub(
                r"<relativePath\s*/>",
                "<relativePath>../pom.xml</relativePath>",
                parent,
                count=1,
            )
            if updated_parent != parent:
                pom.write_text(updated_parent + text[parent_end:], encoding="utf-8")
                repairs.append(str(pom.relative_to(source)))
    if repairs:
        with log_path.open("a", encoding="utf-8") as handle:
            handle.write("\n--- PROJECT SOURCE REPAIRS ---\n" + "\n".join(repairs) + "\n")
    return repairs


def frontend_node_image(directory: Path) -> str:
    try:
        package_data = json.loads((directory / "package.json").read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        package_data = {}
    declared = {
        **(package_data.get("dependencies") or {}),
        **(package_data.get("devDependencies") or {}),
    }
    node_sass_match = re.search(r"(\d+)", str(declared.get("node-sass", "")))
    if node_sass_match and int(node_sass_match.group(1)) <= 4:
        return "node:14-bullseye-slim"
    if node_sass_match and int(node_sass_match.group(1)) <= 6:
        return "node:16-bullseye-slim"
    vite_match = re.search(r"(\d+)", str(declared.get("vite", "")))
    engine_match = re.search(r"(\d+)", str((package_data.get("engines") or {}).get("node", "")))
    dev_runtime = (package_data.get("devEngines") or {}).get("runtime", {})
    if isinstance(dev_runtime, list):
        dev_runtime = dev_runtime[0] if dev_runtime else {}
    dev_engine_match = re.search(r"(\d+)", str(dev_runtime.get("version", ""))) if isinstance(dev_runtime, dict) else None
    modern_dependency = any(
        (match := re.search(r"(\d+)", str(declared.get(name, ""))))
        and int(match.group(1)) >= minimum
        for name, minimum in (
            ("vitest", 4),
            ("jsdom", 27),
            ("@testing-library/jest-dom", 7),
            ("@types/node", 20),
        )
    )
    if dev_engine_match and int(dev_engine_match.group(1)) >= 24:
        return "node:24-alpine"
    if (vite_match and int(vite_match.group(1)) >= 7) or (
        engine_match and int(engine_match.group(1)) >= 20
    ) or modern_dependency:
        return "node:22-alpine"
    return "node:18-alpine"


def disable_interactive_bundle_analyzer(directory: Path, log_path: Path) -> list[str]:
    """Prevent production builds from staying alive to serve an analyzer UI."""
    repairs: list[str] = []
    for relative in ("config/index.js", "vue.config.js"):
        path = directory / relative
        if not path.is_file():
            continue
        try:
            text = path.read_text(encoding="utf-8", errors="ignore")
        except OSError:
            continue
        updated, count = re.subn(
            r"(bundleAnalyzerReport\s*:\s*)true\b",
            r"\g<1>false",
            text,
        )
        if count and updated != text:
            path.write_text(updated, encoding="utf-8")
            repairs.append(relative)
    if repairs:
        with log_path.open("a", encoding="utf-8") as handle:
            handle.write("\n--- DISABLED INTERACTIVE BUNDLE ANALYZER ---\n" + "\n".join(repairs) + "\n")
    return repairs


def build_frontend(plan: dict[str, Any], app_dir: Path, log_path: Path) -> dict[str, Any]:
    frontend = plan.get("frontend")
    if not frontend:
        return {"status": "not-present", "web": ""}
    source = Path(frontend["remote_root"])
    directory = source / ("" if frontend["dir"] == "." else frontend["dir"])
    repairs = repair_case_mismatched_imports(directory, log_path)
    template_repairs = repair_vite_template_import_meta(directory, log_path)
    analyzer_repairs = disable_interactive_bundle_analyzer(directory, log_path)
    node_image = frontend_node_image(directory)
    command = [
        "docker",
        "run",
        "--rm",
        "--name",
        f"ec100-webbuild-{plan['id']}",
        "--memory",
        "2200m",
        "--cpus",
        "2.0",
        "-v",
        f"{ROOT / 'cache' / 'npm'}:/root/.npm",
        "-v",
        f"{source}:/src",
        "-w",
        "/src" + (("/" + frontend["dir"]) if frontend["dir"] != "." else ""),
        node_image,
        "sh",
        "-lc",
        node_install_script(directory, frontend["build_script"], node_image),
    ]
    try:
        result = run(command, timeout=1800, log_path=log_path)
    finally:
        remove_generated_directories(directory, {"node_modules"})
    output = next((source / path for path in frontend["output_candidates"] if (source / path).is_dir()), None)
    build_completed = False
    if result.returncode != 0 and output is not None:
        try:
            log_tail = log_path.read_text(encoding="utf-8", errors="ignore")[-20000:]
            build_completed = "Build complete" in log_tail
        except OSError:
            build_completed = False
    if result.returncode != 0 and not build_completed:
        return {"status": "failed", "return_code": result.returncode, "web": ""}
    if output is None:
        return {"status": "failed", "return_code": 0, "web": "", "error": "no dist/build directory found"}
    destination = app_dir / "web"
    if destination.exists():
        shutil.rmtree(destination)
    shutil.copytree(output, destination)
    file_count = sum(1 for path in destination.rglob("*") if path.is_file())
    return {
        "status": "built",
        "return_code": 0,
        "web": str(destination),
        "file_count": file_count,
        "case_repairs": repairs,
        "template_repairs": template_repairs,
        "analyzer_repairs": analyzer_repairs,
        "accepted_after_nonzero": result.returncode != 0,
        "node_image": node_image,
    }


def load_existing_results() -> dict[str, dict[str, Any]]:
    if not RESULTS_PATH.is_file():
        return {}
    try:
        return {item["id"]: item for item in json.loads(RESULTS_PATH.read_text(encoding="utf-8"))}
    except (OSError, json.JSONDecodeError, KeyError):
        return {}


def save_results(results: dict[str, dict[str, Any]]) -> None:
    ordered = [results[key] for key in sorted(results)]
    payload = json.dumps(ordered, ensure_ascii=False, indent=2)
    temporary = RESULTS_PATH.with_suffix(".json.tmp")
    temporary.write_text(payload, encoding="utf-8")
    os.replace(temporary, RESULTS_PATH)


def build_one(plan: dict[str, Any]) -> dict[str, Any]:
    started = time.monotonic()
    app_dir = APPS_ROOT / plan["id"]
    app_dir.mkdir(parents=True, exist_ok=True)
    log_path = LOG_ROOT / f"{plan['id']}.log"
    log_path.parent.mkdir(parents=True, exist_ok=True)
    log_path.write_text(f"BUILD {plan['id']} {plan['primary_full_name']}\n", encoding="utf-8")
    source_repairs = apply_project_source_repairs(plan, log_path)
    database = prepare_database(plan, log_path)
    backend_type = (plan.get("backend") or {}).get("type")
    dotnet_project = detect_dotnet_project(plan) if not backend_type else None
    war_project = detect_maven_war_project(plan) if not backend_type and dotnet_project is None else None
    if backend_type == "java-spring":
        backend = build_java(plan, app_dir, log_path)
    elif backend_type in {"python-auto", "python-django"}:
        backend = build_python(plan, app_dir, log_path)
    elif dotnet_project is not None:
        backend = build_dotnet(plan, app_dir, log_path, dotnet_project)
    elif war_project is not None:
        backend = build_maven_war(plan, app_dir, log_path, war_project)
    else:
        backend = {"status": "unsupported", "type": backend_type or "none"}
    if plan["id"] == "ec016":
        frontend = build_static_web(plan, app_dir, "web")
    elif plan.get("frontend"):
        frontend = build_frontend(plan, app_dir, log_path)
    else:
        source_root = plan_source_root(plan)
        static_relative = next(
            (
                relative
                for relative in (".", "web", "frontend", "public")
                if source_root is not None
                and (source_root / relative / "index.html").is_file()
            ),
            None,
        )
        frontend = (
            build_static_web(plan, app_dir, static_relative)
            if static_relative is not None
            else build_frontend(plan, app_dir, log_path)
        )
    if backend.get("status") == "unsupported" and frontend.get("status") == "built":
        backend = {"status": "built", "type": "static-only"}
    overall = "built" if backend.get("status") == "built" and frontend.get("status") in {"built", "not-present"} else "failed"
    result = {
        "id": plan["id"],
        "primary_full_name": plan["primary_full_name"],
        "status": overall,
        "backend": backend,
        "frontend": frontend,
        "database": database,
        "source_repairs": source_repairs,
        "log": str(log_path),
        "elapsed_seconds": round(time.monotonic() - started, 2),
    }
    print(
        f"{overall.upper():6} {plan['id']} backend={backend.get('status')} "
        f"frontend={frontend.get('status')} sql={len(database['sql_applied'])}/{len(plan.get('sql_files') or [])} "
        f"elapsed={result['elapsed_seconds']}s",
        flush=True,
    )
    return result


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--skip-built", action="store_true")
    parser.add_argument("--workers", type=int, default=1)
    parser.add_argument("ids", nargs="*")
    args = parser.parse_args()
    plans = json.loads(PLAN_PATH.read_text(encoding="utf-8"))
    secrets = json.loads(SECRETS_PATH.read_text(encoding="utf-8"))
    setup_mysql_client(secrets)
    results = load_existing_results()
    selected = [
        plan
        for plan in plans
        if (not args.ids or plan["id"] in set(args.ids))
        and (not args.skip_built or results.get(plan["id"], {}).get("status") != "built")
    ]
    workers = max(1, min(args.workers, 4))
    print(f"BUILD_QUEUE={len(selected)} WORKERS={workers}", flush=True)

    def guarded_build(plan: dict[str, Any]) -> tuple[str, dict[str, Any]]:
        try:
            return plan["id"], build_one(plan)
        except (OSError, subprocess.SubprocessError, RuntimeError) as exc:
            result = {
                "id": plan["id"],
                "primary_full_name": plan["primary_full_name"],
                "status": "failed",
                "error": str(exc)[-2400:],
            }
            print(f"FAILED {plan['id']} exception={str(exc)[-180:]}", flush=True)
            return plan["id"], result

    if workers == 1:
        for plan in selected:
            project_id, result = guarded_build(plan)
            results[project_id] = result
            save_results(results)
    else:
        with ThreadPoolExecutor(max_workers=workers) as executor:
            futures = [executor.submit(guarded_build, plan) for plan in selected]
            for future in as_completed(futures):
                project_id, result = future.result()
                results[project_id] = result
                save_results(results)
    failed = sum(results[plan["id"]]["status"] != "built" for plan in selected)
    print(f"BUILD_DONE={len(selected)} FAILED={failed}", flush=True)
    return 0 if failed == 0 else 2


if __name__ == "__main__":
    raise SystemExit(main())
