from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path


IGNORED_DIRS = {".git", "node_modules", "dist", "build", "target", ".venv", "venv", "__pycache__"}
MANIFEST_NAMES = {
    "package.json",
    "pom.xml",
    "build.gradle",
    "build.gradle.kts",
    "requirements.txt",
    "pyproject.toml",
    "Pipfile",
    "Dockerfile",
    "docker-compose.yml",
    "docker-compose.yaml",
    "compose.yml",
    "compose.yaml",
}


def git_value(root: Path, *args: str) -> str:
    completed = subprocess.run(
        ["git", "-C", str(root), *args],
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    return completed.stdout.strip() if completed.returncode == 0 else ""


def analyze(root: Path) -> dict[str, object]:
    files: list[Path] = []
    total_bytes = 0
    manifests: list[str] = []
    sql_files: list[str] = []
    license_files: list[str] = []
    for current, dirs, names in os.walk(root):
        dirs[:] = [name for name in dirs if name not in IGNORED_DIRS]
        current_path = Path(current)
        for name in names:
            path = current_path / name
            relative = path.relative_to(root).as_posix()
            files.append(path)
            try:
                total_bytes += path.stat().st_size
            except OSError:
                pass
            if name in MANIFEST_NAMES:
                manifests.append(relative)
            if name.lower().endswith(".sql"):
                sql_files.append(relative)
            if name.lower().startswith(("license", "copying")):
                license_files.append(relative)

    top_level = sorted(path.name for path in root.iterdir() if path.name != ".git")[:40]
    return {
        "candidate": root.name,
        "remote_url": git_value(root, "remote", "get-url", "origin"),
        "head": git_value(root, "rev-parse", "HEAD"),
        "tree": git_value(root, "rev-parse", "HEAD^{tree}"),
        "files": len(files),
        "size_mib": round(total_bytes / 1024 / 1024, 2),
        "top_level": top_level,
        "manifests": sorted(manifests)[:100],
        "sql_files": sorted(sql_files)[:30],
        "license_files": sorted(license_files)[:20],
    }


def main() -> int:
    base = Path(sys.argv[1] if len(sys.argv) > 1 else "/opt/eldercare100/discovery/round2")
    rows = [analyze(path) for path in sorted(base.iterdir()) if (path / ".git").is_dir()]
    print(json.dumps(rows, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
