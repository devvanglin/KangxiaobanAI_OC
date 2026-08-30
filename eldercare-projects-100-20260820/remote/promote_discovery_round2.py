from __future__ import annotations

import json
import shutil
import subprocess
from pathlib import Path


ROOT = Path("/opt/eldercare100")
DISCOVERY = ROOT / "discovery" / "round2"
SOURCES = ROOT / "sources"
STATE = ROOT / "state"
CANONICAL = STATE / "canonical-100.json"
SOURCE_RESULTS = STATE / "remote-source-results.json"
DISCOVERY_REPORT = STATE / "discovery-round2.json"


CANDIDATES = [
    {
        "candidate": "c01",
        "full_name": "LeiQingliang/silverpilot",
        "url": "https://github.com/LeiQingliang/silverpilot",
        "platform": "github",
        "category": "养老服务智能体",
        "description": "可验证、可调用工具的养老服务运营 Agent，包含 Spring Boot、Vue、数据库与 Compose。",
        "license": "Apache-2.0",
    },
    {
        "candidate": "c02",
        "full_name": "eloisesss77-coder/SmartCare-AI-Studio",
        "url": "https://github.com/eloisesss77-coder/SmartCare-AI-Studio",
        "platform": "github",
        "category": "智能养老监控",
        "description": "包含 Python 后端、前端、雷达采集、告警和数据库脚本的智能养老监控平台。",
        "license": "undeclared",
    },
    {
        "candidate": "c03",
        "full_name": "FBB123571/ElderCare-Humanoid-Platform",
        "url": "https://github.com/FBB123571/ElderCare-Humanoid-Platform",
        "platform": "github",
        "category": "养老机器人平台",
        "description": "多模态养老陪护人形机器人平台，包含 Web 控制台、ROS2 桥接与仿真组件。",
        "license": "Apache-2.0",
    },
    {
        "candidate": "c04",
        "full_name": "FENG-lxj/SmartGuard-Cloud-AIoT",
        "url": "https://github.com/FENG-lxj/SmartGuard-Cloud-AIoT",
        "platform": "github",
        "category": "居家养老 AIoT",
        "description": "面向智慧养老的智能家居 AIoT 平台，包含设备、环境监测、告警和可视化。",
        "license": "undeclared",
    },
    {
        "candidate": "c05",
        "full_name": "wp594458910/082-springboot-nursing-home-management",
        "url": "https://github.com/wp594458910/082-springboot-nursing-home-management",
        "platform": "github",
        "category": "养老院管理",
        "description": "Spring Boot 养老院管理系统，覆盖老人、护工、床位、费用和护理业务。",
        "license": "undeclared",
    },
    {
        "candidate": "c06",
        "full_name": "EricXu-0805/nmu-ad-language-training",
        "url": "https://github.com/EricXu-0805/nmu-ad-language-training",
        "platform": "github",
        "category": "认知照护训练",
        "description": "面向轻中度阿尔茨海默病的本地优先语言沟通训练系统。",
        "license": "undeclared",
    },
    {
        "candidate": "c07",
        "full_name": "shajindi-gif/aging-ai-engine",
        "url": "https://github.com/shajindi-gif/aging-ai-engine",
        "platform": "github",
        "category": "养老 AI 服务",
        "description": "面向中国老龄社会的 AI 原生养老服务基础设施和运营工作台。",
        "license": "undeclared",
    },
    {
        "candidate": "c08",
        "full_name": "sunyu9463-blip/nursing-home-beds",
        "url": "https://github.com/sunyu9463-blip/nursing-home-beds",
        "platform": "github",
        "category": "床位护理展示",
        "description": "养老院床位管理与护理需求静态展示网站。",
        "license": "undeclared",
    },
    {
        "candidate": "c09",
        "full_name": "danish9670/eldercare",
        "url": "https://github.com/danish9670/eldercare",
        "platform": "github",
        "category": "老人健康服务",
        "description": "MERN 技术栈的老人健康与照护服务平台。",
        "license": "undeclared",
    },
    {
        "candidate": "c10",
        "full_name": "ruchu-opensource/ruchu-care",
        "url": "https://gitee.com/ruchu-opensource/ruchu-care",
        "platform": "gitee",
        "category": "社区居家养老",
        "description": "如初社区居家养老平台，覆盖居家养老、社区养老和监督管理。",
        "license": "Apache-2.0",
    },
    {
        "candidate": "c11",
        "full_name": "uuu-rongxin/health_elderly",
        "url": "https://gitee.com/uuu-rongxin/health_elderly",
        "platform": "gitee",
        "category": "社区健康监测",
        "description": "Java 社区健康监测与智慧养老关怀系统，包含前端和数据库初始化脚本。",
        "license": "undeclared",
    },
    {
        "candidate": "c12",
        "full_name": "zhai-guanghao/zzyl",
        "url": "https://gitee.com/zhai-guanghao/zzyl",
        "platform": "gitee",
        "category": "智慧养老平台",
        "description": "基于 Spring Boot 与 Vue 的多模块智慧养老管理平台。",
        "license": "MIT",
    },
    {
        "candidate": "c13",
        "full_name": "dengshaoke/zhihuiyanglao_backend",
        "url": "https://gitee.com/dengshaoke/zhihuiyanglao_backend",
        "platform": "gitee",
        "category": "智慧养老后端",
        "description": "面向智慧养老移动端的 Python 后端服务，提供 Dockerfile 和环境配置示例。",
        "license": "undeclared",
    },
]


def git_value(root: Path, *args: str) -> str:
    completed = subprocess.run(
        ["git", "-C", str(root), *args],
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        text=True,
        encoding="utf-8",
        errors="replace",
        check=False,
    )
    return completed.stdout.strip() if completed.returncode == 0 else ""


def load_rows(path: Path) -> list[dict[str, object]]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
        return value if isinstance(value, list) else []
    except (OSError, json.JSONDecodeError):
        return []


def write_rows(path: Path, rows: list[dict[str, object]]) -> None:
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(json.dumps(rows, ensure_ascii=False, indent=2), encoding="utf-8")
    temporary.replace(path)


def main() -> int:
    canonical = load_rows(CANONICAL)
    source_results = load_rows(SOURCE_RESULTS)
    existing_urls = {str(row.get("primary_url") or "").rstrip("/").lower() for row in canonical}
    existing_source_ids = {str(row.get("id")): index for index, row in enumerate(source_results)}
    next_number = max((int(str(row["id"])[2:]) for row in canonical if str(row.get("id", "")).startswith("ec")), default=0) + 1
    promoted: list[dict[str, object]] = []

    for candidate in CANDIDATES:
        normalized_url = str(candidate["url"]).rstrip("/").lower()
        if normalized_url in existing_urls:
            promoted.append({"candidate": candidate["candidate"], "status": "already-listed", "url": candidate["url"]})
            continue
        source = (DISCOVERY / str(candidate["candidate"])).resolve()
        if DISCOVERY.resolve() not in source.parents or not (source / ".git").is_dir():
            promoted.append({"candidate": candidate["candidate"], "status": "missing-clone", "url": candidate["url"]})
            continue
        project_id = f"ec{next_number:03d}"
        next_number += 1
        target = (SOURCES / project_id).resolve()
        if SOURCES.resolve() not in target.parents:
            raise RuntimeError(f"unsafe source target: {target}")
        if not target.exists():
            shutil.copytree(source, target, symlinks=True)

        head = git_value(target, "rev-parse", "HEAD")
        tree = git_value(target, "rev-parse", "HEAD^{tree}")
        full_name = str(candidate["full_name"])
        canonical.append(
            {
                "project_key": full_name.lower(),
                "display_name": full_name,
                "primary_full_name": full_name,
                "primary_url": candidate["url"],
                "platforms": [candidate["platform"]],
                "components": [
                    {
                        "full_name": full_name,
                        "html_url": candidate["url"],
                        "clone_url": str(candidate["url"]) + ".git",
                        "local_dir": str(target),
                        "git_head": head,
                        "git_tree": tree,
                        "project_type": "round2-discovery",
                        "selection_score": 1000.0,
                        "screened_local_dir": str(target),
                        "clone_status": "cloned",
                        "changed_since_screening": False,
                    }
                ],
                "component_count": 1,
                "has_frontend": any((target / name).exists() for name in ("frontend", "web", "src", "zzyl-ui", "rcare-ui")),
                "has_backend": any((target / name).exists() for name in ("backend", "app", "src", "care_companion", "rcare")),
                "has_login_evidence": False,
                "has_database_evidence": any(target.rglob("*.sql")),
                "has_compose": any((target / name).is_file() for name in ("compose.yaml", "compose.yml", "docker-compose.yml", "docker-compose.yaml")),
                "has_dockerfile": any(path.name.startswith("Dockerfile") for path in target.rglob("Dockerfile*")),
                "license_status": [candidate["license"]],
                "selection_score": 1000.0,
                "screening_status": "round2-verified-clone",
                "clone_status": "cloned",
                "build_status": "not-tested",
                "http_status": "not-tested",
                "login_status": "not-tested",
                "category": candidate["category"],
                "description": candidate["description"],
                "id": project_id,
            }
        )
        source_row = {
            "id": project_id,
            "component": full_name,
            "target": str(target),
            "status": "cloned-verified",
            "git_head": head,
            "git_tree": tree,
            "elapsed_seconds": 0.0,
            "error": "",
        }
        if project_id in existing_source_ids:
            source_results[existing_source_ids[project_id]] = source_row
        else:
            source_results.append(source_row)
        existing_urls.add(normalized_url)
        promoted.append({"candidate": candidate["candidate"], "status": "promoted", "id": project_id, "url": candidate["url"]})

    canonical.sort(key=lambda row: int(str(row["id"])[2:]))
    source_results.sort(key=lambda row: int(str(row["id"])[2:]))
    write_rows(CANONICAL, canonical)
    write_rows(SOURCE_RESULTS, source_results)
    write_rows(DISCOVERY_REPORT, promoted)
    print(f"CANONICAL_PROJECTS={len(canonical)}")
    print(f"PROMOTED={sum(row['status'] == 'promoted' for row in promoted)}")
    print(f"SKIPPED={sum(row['status'] != 'promoted' for row in promoted)}")
    for row in promoted:
        print(f"{row.get('status')} {row.get('id', '')} {row['url']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
