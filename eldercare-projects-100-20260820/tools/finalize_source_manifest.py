from __future__ import annotations

import csv
import json
from pathlib import Path


TASK_ROOT = Path(__file__).resolve().parents[1]
MANIFESTS = TASK_ROOT / "manifests"
CANONICAL = MANIFESTS / "canonical-100.json"
CLONES = MANIFESTS / "final-clone-results.json"
INDEX = TASK_ROOT / "INDEX.md"


def main() -> int:
    projects = json.loads(CANONICAL.read_text(encoding="utf-8"))
    clones = json.loads(CLONES.read_text(encoding="utf-8"))
    by_component = {
        (item["id"], item["component_full_name"]): item
        for item in clones
    }
    for project in projects:
        for component in project["components"]:
            clone = by_component[(project["id"], component["full_name"])]
            component["screened_local_dir"] = component.get("local_dir", "")
            component["local_dir"] = clone["target_dir"]
            component["git_head"] = clone["git_head"]
            component["git_tree"] = clone["git_tree"]
            component["clone_status"] = clone["status"]
            component["changed_since_screening"] = clone["changed_since_screening"]
        project["clone_status"] = "cloned"
    CANONICAL.write_text(json.dumps(projects, ensure_ascii=False, indent=2), encoding="utf-8")

    lines = [
        "# 智慧养老/养老院代码项目 100 项",
        "",
        "本清单中的源码已经重新从记录的远端地址拉取到 `repos/`。`结构候选` 只表示代码中存在后端、数据库和登录证据；构建、HTTP 与登录验收状态以部署报告为准。",
        "",
        "| ID | 项目 | 来源 | 组件 | 许可证 | 源码状态 | 构建 | HTTP | 登录 |",
        "|---|---|---|---:|---|---|---|---|---|",
    ]
    for project in projects:
        licenses = " / ".join(project["license_status"])
        platforms = ", ".join(project["platforms"])
        lines.append(
            f"| {project['id']} | [{project['primary_full_name']}]({project['primary_url']}) "
            f"| {platforms} | {project['component_count']} | {licenses} | 已拉取 | "
            f"{project['build_status']} | {project['http_status']} | {project['login_status']} |"
        )
    INDEX.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"PROJECTS={len(projects)} COMPONENTS={sum(len(project['components']) for project in projects)}")
    print(f"INDEX={INDEX}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
