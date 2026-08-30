from __future__ import annotations

import hashlib
import json
import os
import re
import subprocess
from collections import Counter
from pathlib import Path
from typing import Any


TASK_ROOT = Path(__file__).resolve().parents[1]
WORKSPACE = TASK_ROOT.parent
SEED_ROOT = WORKSPACE / "elderly-care-repos"
SEED_REPOS = SEED_ROOT / "repos"
OUTPUT = TASK_ROOT / "manifests" / "seed-analysis.json"

IGNORED_DIRS = {
    ".git",
    ".github",
    ".idea",
    ".vscode",
    ".gradle",
    ".mvn",
    ".hvigor",
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

TEXT_EXTENSIONS = {
    ".md",
    ".txt",
    ".json",
    ".json5",
    ".yml",
    ".yaml",
    ".xml",
    ".properties",
    ".toml",
    ".ini",
    ".conf",
    ".env",
    ".sql",
    ".java",
    ".kt",
    ".py",
    ".js",
    ".ts",
    ".vue",
    ".jsx",
    ".tsx",
    ".php",
    ".cs",
    ".html",
}


def safe_dir(full_name: str) -> str:
    owner, _, repo = full_name.partition("/")
    clean = lambda value: re.sub(r'[<>:"/\\|?*\s]+', "_", value).strip("._")
    return f"{clean(owner)}__{clean(repo)}"


def run_git(repo: Path, *args: str) -> str:
    try:
        result = subprocess.run(
            ["git", "-C", str(repo), *args],
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            text=True,
            encoding="utf-8",
            errors="replace",
            timeout=30,
        )
        return result.stdout.strip()
    except (OSError, subprocess.SubprocessError):
        return ""


def read_small(path: Path, limit: int = 512_000) -> str:
    try:
        if path.stat().st_size > limit:
            return ""
        return path.read_text(encoding="utf-8", errors="ignore")
    except OSError:
        return ""


def inspect_repo(record: dict[str, Any]) -> dict[str, Any]:
    declared_local = str(record.get("local_dir") or "")
    local = Path(declared_local) if declared_local else SEED_REPOS / safe_dir(str(record["full_name"]))
    if not local.is_dir():
        # Preserve exact directory spelling from earlier Windows clones.
        candidates = [p for p in SEED_REPOS.iterdir() if p.is_dir() and p.name.lower() == safe_dir(str(record["full_name"])).lower()]
        if candidates:
            local = candidates[0]
    markers: Counter[str] = Counter()
    matched_paths: dict[str, list[str]] = {
        "compose": [],
        "dockerfile": [],
        "maven": [],
        "gradle": [],
        "node": [],
        "python": [],
        "php": [],
        "dotnet": [],
        "sql": [],
        "login": [],
        "readme": [],
    }
    sampled_text: list[str] = []
    file_count = 0
    source_bytes = 0
    if local.is_dir():
        for root, dirs, files in os.walk(local, onerror=lambda _err: None):
            dirs[:] = [name for name in dirs if name.lower() not in IGNORED_DIRS]
            root_path = Path(root)
            depth = len(root_path.relative_to(local).parts)
            for name in files:
                path = root_path / name
                rel = path.relative_to(local).as_posix()
                lower_name = name.lower()
                lower_rel = rel.lower()
                file_count += 1
                try:
                    source_bytes += path.stat().st_size
                except OSError:
                    pass
                if lower_name in {"docker-compose.yml", "docker-compose.yaml", "compose.yml", "compose.yaml"}:
                    matched_paths["compose"].append(rel)
                if lower_name.startswith("dockerfile"):
                    matched_paths["dockerfile"].append(rel)
                if lower_name == "pom.xml":
                    matched_paths["maven"].append(rel)
                if lower_name in {"build.gradle", "build.gradle.kts", "settings.gradle", "settings.gradle.kts"}:
                    matched_paths["gradle"].append(rel)
                if lower_name == "package.json":
                    matched_paths["node"].append(rel)
                if lower_name in {"requirements.txt", "pyproject.toml", "pipfile", "manage.py"}:
                    matched_paths["python"].append(rel)
                if lower_name == "composer.json":
                    matched_paths["php"].append(rel)
                if lower_name.endswith((".sln", ".csproj")):
                    matched_paths["dotnet"].append(rel)
                if lower_name.endswith(".sql"):
                    matched_paths["sql"].append(rel)
                if lower_name.startswith("readme"):
                    matched_paths["readme"].append(rel)
                if re.search(r"(^|[/_.-])(login|signin|sign-in|auth|登录|登陆)([/_.-]|$)", lower_rel, re.I):
                    matched_paths["login"].append(rel)
                if (
                    depth <= 4
                    and path.suffix.lower() in TEXT_EXTENSIONS
                    and (
                        lower_name.startswith("readme")
                        or lower_name in {
                            "package.json",
                            "pom.xml",
                            "application.yml",
                            "application.yaml",
                            "application.properties",
                            "docker-compose.yml",
                            "docker-compose.yaml",
                            "compose.yml",
                            "compose.yaml",
                        }
                    )
                ):
                    text = read_small(path)
                    if text:
                        sampled_text.append(text[:200_000])
    blob = "\n".join(sampled_text).lower()
    for token, pattern in {
        "spring": r"spring[-.]boot|springframework|spring-boot",
        "vue": r"\bvue\b|vue-cli|vite",
        "react": r"\breact\b|next\.js|nextjs",
        "angular": r"\bangular\b",
        "django": r"\bdjango\b",
        "flask": r"\bflask\b",
        "fastapi": r"\bfastapi\b",
        "laravel": r"\blaravel\b",
        "mysql": r"\bmysql\b|jdbc:mysql",
        "postgres": r"postgres|postgresql",
        "redis": r"\bredis\b",
        "login_text": r"登录|登陆|sign[ -]?in|username|用户名|账号|password|密码",
        "eldercare_text": r"养老|老人|护理|疗养|elder|senior|nursing home|caregiver|geriatric",
        "embedded": r"arduino|esp32|stm32|zigbee|cc2530|单片机|嵌入式",
        "vision_ml": r"yolo|opencv|tensorflow|pytorch|fall detection|跌倒检测|目标检测",
        "mobile": r"android|uni-app|uniapp|微信小程序|miniprogram|flutter",
    }.items():
        markers[token] = len(re.findall(pattern, blob, re.I))

    has_backend = bool(
        matched_paths["maven"]
        or matched_paths["gradle"]
        or matched_paths["python"]
        or matched_paths["php"]
        or matched_paths["dotnet"]
        or markers["spring"]
        or markers["django"]
        or markers["flask"]
        or markers["fastapi"]
        or markers["laravel"]
    )
    has_frontend = bool(matched_paths["node"] or markers["vue"] or markers["react"] or markers["angular"])
    has_login = bool(matched_paths["login"] or markers["login_text"] >= 2)
    has_database = bool(matched_paths["sql"] or markers["mysql"] or markers["postgres"])
    web_candidate = has_login and (
        (has_backend and (has_frontend or has_database))
        or (has_backend and bool(matched_paths["readme"]))
        or (bool(matched_paths["compose"]) and (has_backend or has_frontend))
    )
    if markers["embedded"] and not web_candidate:
        project_type = "embedded"
    elif markers["vision_ml"] and not has_database and not has_login:
        project_type = "ml-vision"
    elif has_backend and has_frontend:
        project_type = "fullstack"
    elif has_backend:
        project_type = "backend-web"
    elif has_frontend:
        project_type = "frontend-web"
    elif markers["mobile"]:
        project_type = "mobile"
    else:
        project_type = "other"

    remote = run_git(local, "remote", "get-url", "origin") if local.is_dir() else ""
    return {
        **record,
        "local_dir": str(local) if local.is_dir() else "",
        "clone_present": local.is_dir(),
        "git_head": run_git(local, "rev-parse", "HEAD") if local.is_dir() else "",
        "git_tree": run_git(local, "rev-parse", "HEAD^{tree}") if local.is_dir() else "",
        "git_origin": remote,
        "file_count": file_count,
        "source_bytes": source_bytes,
        "project_type": project_type,
        "web_login_candidate": web_candidate,
        "has_backend": has_backend,
        "has_frontend": has_frontend,
        "has_login_evidence": has_login,
        "has_database_evidence": has_database,
        "markers": dict(markers),
        "paths": {key: values[:30] for key, values in matched_paths.items()},
    }


def main() -> int:
    selected = json.loads((SEED_ROOT / "selected_100.json").read_text(encoding="utf-8"))
    results = [inspect_repo(record) for record in selected]
    tree_counts = Counter(item["git_tree"] for item in results if item["git_tree"])
    for item in results:
        item["duplicate_tree_count"] = tree_counts.get(item["git_tree"], 0)
        item["source_fingerprint"] = hashlib.sha256(
            f"{item.get('full_name','')}|{item.get('git_tree','')}".encode("utf-8")
        ).hexdigest()
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(json.dumps(results, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"ANALYZED={len(results)}")
    print(f"CLONED={sum(bool(item['clone_present']) for item in results)}")
    print(f"WEB_LOGIN_CANDIDATE={sum(bool(item['web_login_candidate']) for item in results)}")
    print("TYPES=" + json.dumps(Counter(item["project_type"] for item in results), ensure_ascii=False, sort_keys=True))
    print(f"DUPLICATE_TREES={sum(1 for count in tree_counts.values() if count > 1)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
