#!/usr/bin/env python3
"""Build human- and AI-searchable reference indexes from the audited crawl."""

from __future__ import annotations

import csv
import gzip
import hashlib
import json
import sqlite3
from collections import defaultdict
from pathlib import Path
from typing import Any


SCRIPT_DIR = Path(__file__).resolve().parent
ROOT_DIR = SCRIPT_DIR.parent
COVERAGE_DIR = ROOT_DIR / "coverage"
DB_PATH = COVERAGE_DIR / "crawl.sqlite3"
MENU_PATH = COVERAGE_DIR / "menu-inventory.json"
FULL_DIGEST_PATH = ROOT_DIR / "FULL_PAGE_DIGESTS.md"
TOPIC_STATS_PATH = COVERAGE_DIR / "topic-statistics.csv"
HEADING_INDEX_PATH = COVERAGE_DIR / "heading-index.csv"
CODE_INDEX_PATH = COVERAGE_DIR / "code-source-index.csv"
ADMONITION_INDEX_PATH = COVERAGE_DIR / "admonition-index.csv"


def clean_inline(value: str) -> str:
    return " ".join((value or "").replace("\u00a0", " ").split())


def load_extract(blob: bytes) -> dict[str, Any]:
    return json.loads(gzip.decompress(blob).decode("utf-8"))


def structural_profile(title: str, headings: list[dict[str, Any]]) -> str:
    """Build an original, compact locator without reproducing page body text."""
    haystack = " ".join([title, *(clean_inline(item.get("text", "")) for item in headings)])
    signals: list[str] = []
    rules = [
        (("概述", "简介", "介绍", "原理", "机制"), "概念/机制"),
        (("约束", "限制", "注意", "前提"), "约束/前提"),
        (("开发步骤", "实现", "接入", "配置", "使用"), "接入/实现"),
        (("接口", "API", "参数", "错误码"), "接口契约"),
        (("生命周期", "回调", "线程", "并发", "异步"), "运行时/生命周期"),
        (("权限", "隐私", "安全", "授权"), "权限/安全"),
        (("性能", "功耗", "内存", "时延", "优化"), "性能"),
        (("示例", "Demo", "Sample"), "示例"),
        (("FAQ", "常见问题", "故障", "问题定位", "排查"), "排障"),
    ]
    for keywords, label in rules:
        if any(keyword in haystack for keyword in keywords):
            signals.append(label)
    return "、".join(signals) if signals else "目录/主题说明"


def write_csv(path: Path, fields: list[str], rows: list[dict[str, Any]]) -> None:
    with path.open("w", encoding="utf-8-sig", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields)
        writer.writeheader()
        writer.writerows(rows)


def main() -> int:
    menu = json.loads(MENU_PATH.read_text(encoding="utf-8"))
    menu_docs = [row for row in menu if row.get("has_document")]
    menu_slugs = [row["slug"] for row in menu_docs]
    if len(menu_docs) != 5694:
        raise RuntimeError(f"Expected 5,694 menu documents, found {len(menu_docs):,}")
    if len(set(menu_slugs)) != len(menu_slugs):
        raise RuntimeError("Menu document slugs are not unique")
    connection = sqlite3.connect(DB_PATH)
    pages = {
        row[0]: {
            "slug": row[0],
            "title": row[1],
            "updated_date": row[2],
            "display_update_time": row[3],
            "device_version": row[4],
            "text_length": row[5],
            "html_length": row[6],
            "heading_count": row[7],
            "code_count": row[8],
            "table_count": row[9],
            "admonition_count": row[10],
            "image_count": row[11],
            "summary": row[12],
            "sha256": row[13],
            "extract": load_extract(row[14]),
        }
        for row in connection.execute(
            """
            SELECT slug,title,updated_date,display_update_time,device_version,
                   text_length,html_length,heading_count,code_count,table_count,
                   admonition_count,image_count,summary,content_sha256,extract_gzip
            FROM pages WHERE status='success'
            """
        )
    }
    connection.close()
    page_slugs = set(pages)
    menu_slug_set = set(menu_slugs)
    if len(pages) != 5694:
        raise RuntimeError(f"Expected 5,694 successful pages, found {len(pages):,}")
    if page_slugs != menu_slug_set:
        missing = sorted(menu_slug_set - page_slugs)[:20]
        extra = sorted(page_slugs - menu_slug_set)[:20]
        raise RuntimeError(
            f"Menu/page slug mismatch; missing={missing!r}, extra={extra!r}"
        )

    topic_stats: dict[tuple[str, str, str], dict[str, int]] = defaultdict(
        lambda: {
            "pages": 0,
            "text_characters": 0,
            "code_blocks": 0,
            "tables": 0,
            "admonitions": 0,
            "images": 0,
        }
    )
    heading_rows: list[dict[str, Any]] = []
    code_rows: list[dict[str, Any]] = []
    admonition_rows: list[dict[str, Any]] = []
    digest_lines = [
        "# HarmonyOS 官方指南 5,694 页逐页结构索引",
        "",
        "> 本文件按官网左侧菜单顺序覆盖每一个带正文的菜单节点。",
        "> 它只保留菜单路径、官方 URL、内容结构、章节线索与哈希，不复制正文或完整示例。",
        "> 主题级理解见主文档与 `drafts/` 中的综合章节；机器审计数据保存在 `coverage/`。",
        "",
        "## 使用方法",
        "",
        "- 人类读者可按菜单分区浏览，或搜索页面标题、Kit、API、错误文本。",
        "- Codex/Claude 应先用本文件定位页面，再通过 `coverage/page-status.csv` 获取精确 URL 和哈希。",
        "- 若需要代码来源，查询 `coverage/code-source-index.csv`。",
        "- 若需要提示、限制与警告，查询 `coverage/admonition-index.csv`。",
        "",
    ]

    current_section = ""
    current_root = ""
    for menu_row in menu_docs:
        slug = menu_row["slug"]
        page = pages[slug]
        path = menu_row["menu_path"]
        section = menu_row["section"]
        root = path[1] if len(path) > 1 else section
        subroot = path[2] if len(path) > 2 else ""
        if section != current_section:
            digest_lines.extend([f"## {section}", ""])
            current_section = section
            current_root = ""
        if root != current_root:
            digest_lines.extend([f"### {root}", ""])
            current_root = root

        headings = page["extract"].get("headings", [])
        concise_headings = [
            clean_inline(item.get("text", ""))[:100]
            for item in headings[:12]
            if clean_inline(item.get("text", ""))
        ]
        heading_text = "；".join(concise_headings)
        if len(headings) > 12:
            heading_text += f"；……（另有 {len(headings) - 12} 个标题，见 heading-index.csv）"
        profile = structural_profile(menu_row["title"], headings)
        ai_checks: list[str] = []
        if page["admonition_count"]:
            ai_checks.append("先查提示/警告索引")
        if page["code_count"]:
            ai_checks.append("示例代码需按当前 SDK 与工程配置复核")
        if page["table_count"]:
            ai_checks.append("表格中的版本、设备和参数条件不可省略")
        if not ai_checks:
            ai_checks.append("将本页作为概念或目录入口，并继续核对下级页面")
        digest_lines.extend(
            [
                f"#### {menu_row['ordinal']:04d}. {menu_row['title']}",
                "",
                f"- 菜单路径：{' > '.join(path)}",
                f"- 官方页面：[{menu_row['url']}]({menu_row['url']})",
                f"- 页面标识：`{slug}`；菜单节点：`{menu_row['node_id']}`",
                f"- 更新时间（官网接口原始值）：`{page['display_update_time'] or page['updated_date']}`",
                f"- 内容结构：正文 {page['text_length']} 字符；标题 {page['heading_count']}；代码块 {page['code_count']}；表格 {page['table_count']}；提示/警告 {page['admonition_count']}；图片 {page['image_count']}",
                f"- 内容哈希：`{page['sha256']}`",
                f"- 结构类型：{profile}",
                f"- 章节：{heading_text or '无独立正文标题；该页主要承担目录、索引或单一简短说明。'}",
                f"- AI 使用提示：{'；'.join(ai_checks)}。",
                "",
            ]
        )

        stats = topic_stats[(section, root, subroot)]
        stats["pages"] += 1
        stats["text_characters"] += page["text_length"]
        stats["code_blocks"] += page["code_count"]
        stats["tables"] += page["table_count"]
        stats["admonitions"] += page["admonition_count"]
        stats["images"] += page["image_count"]

        for position, heading in enumerate(headings, start=1):
            heading_rows.append(
                {
                    "section": section,
                    "root": root,
                    "menu_path": " > ".join(path),
                    "slug": slug,
                    "page_title": page["title"],
                    "url": menu_row["url"],
                    "position": position,
                    "level": heading.get("level", ""),
                    "heading": clean_inline(heading.get("text", "")),
                    "anchor_id": heading.get("id", ""),
                }
            )
        for position, block in enumerate(page["extract"].get("code_blocks", []), start=1):
            code = block.get("code", "")
            first_line = next((clean_inline(line) for line in code.splitlines() if clean_inline(line)), "")
            code_rows.append(
                {
                    "section": section,
                    "root": root,
                    "menu_path": " > ".join(path),
                    "slug": slug,
                    "page_title": page["title"],
                    "url": menu_row["url"],
                    "position": position,
                    "language": block.get("language", ""),
                    "source_url": block.get("source_url", ""),
                    "characters": len(code),
                    "sha256": hashlib.sha256(code.encode("utf-8")).hexdigest(),
                    "preview": first_line[:160],
                }
            )
        for position, block in enumerate(page["extract"].get("admonitions", []), start=1):
            admonition_text = clean_inline(block.get("text", ""))
            admonition_rows.append(
                {
                    "section": section,
                    "root": root,
                    "menu_path": " > ".join(path),
                    "slug": slug,
                    "page_title": page["title"],
                    "url": menu_row["url"],
                    "position": position,
                    "kind": block.get("kind", ""),
                    "title": clean_inline(block.get("title", "")),
                    "characters": len(admonition_text),
                    "sha256": hashlib.sha256(admonition_text.encode("utf-8")).hexdigest(),
                    "preview": admonition_text[:180],
                }
            )

    FULL_DIGEST_PATH.write_text("\n".join(digest_lines) + "\n", encoding="utf-8")

    topic_rows = [
        {"section": key[0], "root": key[1], "subroot": key[2], **stats}
        for key, stats in topic_stats.items()
    ]
    write_csv(
        TOPIC_STATS_PATH,
        ["section", "root", "subroot", "pages", "text_characters", "code_blocks", "tables", "admonitions", "images"],
        topic_rows,
    )
    write_csv(
        HEADING_INDEX_PATH,
        ["section", "root", "menu_path", "slug", "page_title", "url", "position", "level", "heading", "anchor_id"],
        heading_rows,
    )
    write_csv(
        CODE_INDEX_PATH,
        ["section", "root", "menu_path", "slug", "page_title", "url", "position", "language", "source_url", "characters", "sha256", "preview"],
        code_rows,
    )
    write_csv(
        ADMONITION_INDEX_PATH,
        ["section", "root", "menu_path", "slug", "page_title", "url", "position", "kind", "title", "characters", "sha256", "preview"],
        admonition_rows,
    )

    print(
        json.dumps(
            {
                "pages": len(menu_docs),
                "digest_lines": len(digest_lines),
                "topic_rows": len(topic_rows),
                "heading_rows": len(heading_rows),
                "code_rows": len(code_rows),
                "admonition_rows": len(admonition_rows),
            },
            ensure_ascii=False,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
