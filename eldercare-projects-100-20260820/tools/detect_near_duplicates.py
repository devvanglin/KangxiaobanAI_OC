from __future__ import annotations

import json
import os
from pathlib import Path


TASK_ROOT = Path(__file__).resolve().parents[1]
INPUT = TASK_ROOT / "manifests" / "canonical-100.json"
OUTPUT = TASK_ROOT / "manifests" / "near-duplicates.json"
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
}
SOURCE_SUFFIXES = {
    ".java",
    ".kt",
    ".xml",
    ".yml",
    ".yaml",
    ".properties",
    ".js",
    ".ts",
    ".vue",
    ".jsx",
    ".tsx",
    ".py",
    ".php",
    ".cs",
    ".html",
    ".css",
    ".scss",
    ".sql",
    ".json",
}


def path_set(root: Path) -> set[str]:
    paths: list[tuple[str, ...]] = []
    for current, dirs, files in os.walk(root, onerror=lambda _err: None):
        dirs[:] = [name for name in dirs if name.lower() not in IGNORED]
        current_path = Path(current)
        for name in files:
            if Path(name).suffix.lower() not in SOURCE_SUFFIXES:
                continue
            rel = (current_path / name).relative_to(root)
            parts = tuple(part.lower() for part in rel.parts)
            if len(parts) > 5:
                parts = parts[-5:]
            paths.append(parts)
    return {"/".join(parts) for parts in paths}


def jaccard(left: set[str], right: set[str]) -> float:
    if not left or not right:
        return 0.0
    return len(left & right) / len(left | right)


def main() -> int:
    projects = json.loads(INPUT.read_text(encoding="utf-8"))
    signatures = {}
    for project in projects:
        root = Path(project["components"][0]["local_dir"])
        signatures[project["id"]] = path_set(root)
    pairs = []
    for index, left in enumerate(projects):
        for right in projects[index + 1 :]:
            similarity = jaccard(signatures[left["id"]], signatures[right["id"]])
            if similarity < 0.72:
                continue
            pairs.append(
                {
                    "left_id": left["id"],
                    "left": left["primary_full_name"],
                    "right_id": right["id"],
                    "right": right["primary_full_name"],
                    "path_jaccard": round(similarity, 4),
                    "left_paths": len(signatures[left["id"]]),
                    "right_paths": len(signatures[right["id"]]),
                }
            )
    pairs.sort(key=lambda item: float(item["path_jaccard"]), reverse=True)
    OUTPUT.write_text(json.dumps(pairs, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"NEAR_DUPLICATE_PAIRS={len(pairs)}")
    for pair in pairs[:80]:
        print(
            f"{pair['path_jaccard']:.4f} {pair['left_id']} {pair['left']} <> "
            f"{pair['right_id']} {pair['right']}"
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
