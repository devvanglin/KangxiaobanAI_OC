#!/usr/bin/env python3
"""Generate a compact statistical panorama of the complete official menu."""

from __future__ import annotations

import csv
from collections import defaultdict
from pathlib import Path


SCRIPT_DIR = Path(__file__).resolve().parent
ROOT_DIR = SCRIPT_DIR.parent
STATS_PATH = ROOT_DIR / "coverage" / "topic-statistics.csv"
OUTPUT_PATH = ROOT_DIR / "drafts" / "official-menu-panorama.md"
EXPECTED_SECTION_COUNTS = {
    "入门": 45,
    "开发": 4811,
    "工具": 757,
    "测试": 23,
    "体验建议": 58,
}


def number(value: str) -> str:
    return f"{int(value):,}"


def main() -> int:
    rows = list(csv.DictReader(STATS_PATH.open(encoding="utf-8-sig", newline="")))
    grouped: dict[tuple[str, str], list[dict[str, str]]] = defaultdict(list)
    section_order: list[str] = []
    root_order: dict[str, list[str]] = defaultdict(list)
    for row in rows:
        section = row["section"]
        root = row["root"]
        if section not in section_order:
            section_order.append(section)
        if root not in root_order[section]:
            root_order[section].append(root)
        grouped[(section, root)].append(row)

    section_totals = {
        section: sum(int(row["pages"]) for row in rows if row["section"] == section)
        for section in section_order
    }
    if section_totals != EXPECTED_SECTION_COUNTS:
        raise RuntimeError(
            f"Unexpected section totals: {section_totals!r}; "
            f"expected {EXPECTED_SECTION_COUNTS!r}"
        )
    if len(grouped) != 21:
        raise RuntimeError(f"Expected 21 root topics, found {len(grouped)}")
    total_pages = sum(section_totals.values())

    lines = [
        "# 官网左侧菜单全景与内容体量",
        "",
        f"> 本章由已审计的 {total_pages:,} 篇正文统计生成，用于说明知识版图和检索入口。",
        "> 数量代表官方菜单页面，不代表当前项目已经接入对应能力。",
        "",
        "## 总览",
        "",
        "| 分区 | 正文页 |",
        "|---|---:|",
        *(f"| {section} | {section_totals[section]:,} |" for section in section_order),
        f"| **合计** | **{total_pages:,}** |",
        "",
        "完整逐页入口见 [逐页结构索引](../FULL_PAGE_DIGESTS.md)；原始菜单层级见 [完整菜单树](../coverage/menu-tree.md)。",
        "",
    ]
    for section in section_order:
        lines.extend([f"## {section}", ""])
        for root in root_order[section]:
            group = grouped[(section, root)]
            totals = {
                key: sum(int(item[key]) for item in group)
                for key in (
                    "pages",
                    "text_characters",
                    "code_blocks",
                    "tables",
                    "admonitions",
                    "images",
                )
            }
            lines.extend(
                [
                    f"### {root}",
                    "",
                    f"[官方事实] 共 {number(str(totals['pages']))} 篇正文、"
                    f"{number(str(totals['text_characters']))} 个正文字符、"
                    f"{number(str(totals['code_blocks']))} 个代码块、"
                    f"{number(str(totals['tables']))} 张表、"
                    f"{number(str(totals['admonitions']))} 个提示/警告块、"
                    f"{number(str(totals['images']))} 张图。",
                    "",
                ]
            )
            children = [item for item in group if item["subroot"]]
            if children:
                lines.extend(
                    [
                        "| 直接子类 | 页面 | 正文字符 | 代码块 | 表格 | 提示/警告 | 图片 |",
                        "|---|---:|---:|---:|---:|---:|---:|",
                    ]
                )
                for item in sorted(children, key=lambda row: int(row["pages"]), reverse=True):
                    lines.append(
                        f"| {item['subroot']} | {number(item['pages'])} | "
                        f"{number(item['text_characters'])} | {number(item['code_blocks'])} | "
                        f"{number(item['tables'])} | {number(item['admonitions'])} | "
                        f"{number(item['images'])} |"
                    )
                lines.append("")
            lines.extend(
                [
                    "[解释] 这里的统计用于判断资料体量和选择检索入口；具体 API、版本、"
                    "SystemCapability、权限与限制必须回到对应官方页面核对。",
                    "",
                ]
            )

    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_PATH.write_text("\n".join(lines), encoding="utf-8")
    print(f"wrote {OUTPUT_PATH} ({len(lines)} lines)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
