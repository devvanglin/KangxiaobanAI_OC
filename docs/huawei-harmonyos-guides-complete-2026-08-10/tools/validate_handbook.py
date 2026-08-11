#!/usr/bin/env python3
"""Validate coverage evidence and the generated HarmonyOS handbook."""

from __future__ import annotations

import json
import re
from collections import Counter
from pathlib import Path
from urllib.parse import unquote, urlparse


SCRIPT_DIR = Path(__file__).resolve().parent
ROOT_DIR = SCRIPT_DIR.parent
COVERAGE_DIR = ROOT_DIR / "coverage"
README_PATH = ROOT_DIR / "README.md"
PAGE_INDEX_PATH = ROOT_DIR / "FULL_PAGE_DIGESTS.md"
AUDIT_JSON_PATH = COVERAGE_DIR / "audit-report.json"
MENU_JSON_PATH = COVERAGE_DIR / "menu-inventory.json"
THEME_AUDIT_PATH = COVERAGE_DIR / "theme-coverage-audit.md"
REPORT_JSON_PATH = COVERAGE_DIR / "handbook-validation.json"
REPORT_MD_PATH = COVERAGE_DIR / "handbook-validation.md"

EXPECTED_SECTIONS = {
    "入门": 45,
    "开发": 4811,
    "工具": 757,
    "测试": 23,
    "体验建议": 58,
}

EXPECTED_ROOT_COUNTS = [
    ("入门", "基础入门", 45),
    ("开发", "应用开发准备", 1),
    ("开发", "应用框架", 1090),
    ("开发", "系统", 1054),
    ("开发", "媒体", 389),
    ("开发", "图形", 237),
    ("开发", "应用服务", 948),
    ("开发", "AI", 948),
    ("开发", "一次开发，多端部署", 1),
    ("开发", "自由流转", 1),
    ("开发", "NDK开发", 142),
    ("工具", "开发环境搭建", 128),
    ("工具", "编写与调试应用", 437),
    ("工具", "构建应用", 62),
    ("工具", "优化应用性能", 37),
    ("工具", "发布应用", 2),
    ("工具", "命令行工具", 50),
    ("工具", "AI Coding", 10),
    ("工具", "使用AI智能辅助编程（不推荐）", 31),
    ("测试", "应用测试", 23),
    ("体验建议", "应用体验建议", 58),
]

REQUIRED_TOPICS = [
    "基础入门",
    "应用开发准备",
    "应用框架",
    "系统",
    "媒体",
    "图形",
    "应用服务",
    "AI",
    "一次开发，多端部署",
    "自由流转",
    "NDK开发",
    "开发环境搭建",
    "编写与调试应用",
    "构建应用",
    "优化应用性能",
    "发布应用",
    "命令行工具",
    "AI Coding",
    "使用AI智能辅助编程（不推荐）",
    "应用测试",
    "应用体验建议",
]

OUTDATED_PHRASES = [
    "状态：采集中",
    "工作底稿；不代表 5,694 个正文链接已经全部逐页读完",
    "尚未证明所有正文均已完整阅读",
    "等待全量链接台账",
    "等待全量失败清零",
    "仍在写作中",
    "综合章待完成",
    "主题综合仍有缺口",
    "尚未全量完成",
]

THEME_OUTDATED_PHRASES = [
    "写作中，未完成",
    "综合章写作中",
    "摘要和章节关键词",
]

LINK_START_RE = re.compile(r"!?\[[^\]\n]*\]\(")
FENCE_RE = re.compile(r"^[ \t]{0,3}(`{3,}|~{3,})(.*)$")
OFFICIAL_GUIDE_RE = re.compile(
    r"https://developer\.huawei\.com/consumer/cn/doc/harmonyos-guides/([^\s)#?>]+)"
)
MOJIBAKE_MARKERS = ("\ufffd", "锛", "銆", "鈥", "鈿", "锟斤拷", "ï¿½")
VERSION_RE = r"([0-9]+\.[0-9]+\.[0-9]+\([0-9]+\))"


def fence_token(line: str) -> tuple[str, int, str] | None:
    match = FENCE_RE.match(line)
    if not match:
        return None
    marker, remainder = match.groups()
    return marker[0], len(marker), remainder


def fence_errors(text: str) -> list[str]:
    opened: tuple[str, int, int] | None = None
    for line_number, line in enumerate(text.splitlines(), start=1):
        token = fence_token(line)
        if token is None:
            continue
        if opened is None:
            opened = (token[0], token[1], line_number)
            continue
        char, length, remainder = token
        if char == opened[0] and length >= opened[1] and not remainder.strip():
            opened = None
    if opened is None:
        return []
    return [f"line {opened[2]}: unclosed {opened[0] * opened[1]} fence"]


def non_fenced_lines(text: str) -> list[str]:
    result: list[str] = []
    opened: tuple[str, int] | None = None
    for line in text.splitlines():
        token = fence_token(line)
        if opened is None:
            if token is not None:
                opened = (token[0], token[1])
            else:
                result.append(line)
            continue
        if (
            token is not None
            and token[0] == opened[0]
            and token[1] >= opened[1]
            and not token[2].strip()
        ):
            opened = None
    return result


def markdown_link_targets(text: str) -> list[str]:
    """Return inline Markdown link targets outside fenced code blocks."""
    targets: list[str] = []
    for line in non_fenced_lines(text):
        position = 0
        while True:
            match = LINK_START_RE.search(line, position)
            if match is None:
                break
            cursor = match.end()
            if cursor < len(line) and line[cursor] == "<":
                end = line.find(">", cursor + 1)
                close = line.find(")", end + 1) if end >= 0 else -1
                if end < 0 or close < 0:
                    break
                targets.append(line[cursor + 1 : end].strip())
                position = close + 1
                continue

            depth = 0
            escaped = False
            end = cursor
            while end < len(line):
                char = line[end]
                if escaped:
                    escaped = False
                elif char == "\\":
                    escaped = True
                elif char == "(":
                    depth += 1
                elif char == ")":
                    if depth == 0:
                        break
                    depth -= 1
                end += 1
            if end >= len(line):
                break
            raw_target = line[cursor:end].strip()
            # A target containing spaces must use angle brackets; otherwise the
            # remainder is an optional Markdown link title.
            targets.append(raw_target.split(maxsplit=1)[0] if raw_target else "")
            position = end + 1
    return targets


def mojibake_hits(text: str) -> list[str]:
    return [marker for marker in MOJIBAKE_MARKERS if marker in text]


def labelled_version_values(text: str, label: str) -> list[str]:
    pattern = re.compile(re.escape(label) + r".{0,48}?" + VERSION_RE, re.IGNORECASE)
    return pattern.findall(text)


def local_link_errors(markdown_path: Path, text: str) -> list[str]:
    errors: list[str] = []
    for raw_target in markdown_link_targets(text):
        target = raw_target.strip()
        parsed = urlparse(target)
        if not target or parsed.scheme in {"http", "https", "mailto", "tel", "data"}:
            continue
        if target.startswith("#"):
            continue
        path_target = unquote(target.split("#", 1)[0].split("?", 1)[0])
        if re.match(r"^[A-Za-z]:[\\/]", target):
            if not Path(path_target).exists():
                errors.append(target)
            continue
        if path_target.startswith("/"):
            if not Path(path_target).exists():
                errors.append(target)
            continue
        path_part = path_target
        if path_part:
            resolved = (markdown_path.parent / path_part).resolve()
            if resolved == REPORT_MD_PATH.resolve():
                continue
            if not resolved.exists():
                errors.append(target)
    return sorted(set(errors))


def main() -> int:
    checks: dict[str, bool] = {}
    details: dict[str, object] = {}

    audit = json.loads(AUDIT_JSON_PATH.read_text(encoding="utf-8"))
    menu = json.loads(MENU_JSON_PATH.read_text(encoding="utf-8"))
    readme = README_PATH.read_text(encoding="utf-8-sig")
    page_index = PAGE_INDEX_PATH.read_text(encoding="utf-8-sig")
    theme_audit = THEME_AUDIT_PATH.read_text(encoding="utf-8-sig")
    menu_docs = [row for row in menu if row.get("has_document")]

    checks["coverage_audit_passed"] = bool(audit.get("all_critical_passed"))
    checks["audit_database_menu_matches_saved"] = bool(
        audit.get("critical_checks", {}).get("database_menu_matches_saved")
    )
    checks["audit_menu_page_urls_equal"] = bool(
        audit.get("critical_checks", {}).get("menu_page_urls_equal")
    )
    checks["page_count_5694"] = audit.get("counts", {}).get("database_pages") == 5694
    checks["failure_count_zero"] = audit.get("counts", {}).get("status") == {"success": 5694}
    checks["second_catalog_identical"] = bool(
        audit.get("critical_checks", {}).get("second_catalog_identical")
    )
    checks["section_counts_match"] = all(
        audit.get("current_menu_summary", {})
        .get("sections", {})
        .get(section, {})
        .get("links")
        == expected
        for section, expected in EXPECTED_SECTIONS.items()
    )

    expected_root_counter = Counter(
        {(section, root): count for section, root, count in EXPECTED_ROOT_COUNTS}
    )
    actual_root_counter = Counter(
        (row["section"], row["menu_path"][1]) for row in menu_docs
    )
    checks["menu_has_expected_21_roots"] = actual_root_counter == expected_root_counter
    details["menu_root_count"] = len(actual_root_counter)
    details["menu_root_mismatches"] = {
        f"{section} > {root}": {
            "expected": expected_root_counter.get((section, root), 0),
            "actual": actual_root_counter.get((section, root), 0),
        }
        for section, root in sorted(set(expected_root_counter) | set(actual_root_counter))
        if expected_root_counter.get((section, root), 0)
        != actual_root_counter.get((section, root), 0)
    }

    readme_mojibake = mojibake_hits(readme)
    page_index_mojibake = mojibake_hits(page_index)
    theme_mojibake = mojibake_hits(theme_audit)
    checks["readme_utf8_chinese_clean"] = not readme_mojibake
    checks["page_index_utf8_chinese_clean"] = not page_index_mojibake
    checks["theme_audit_utf8_chinese_clean"] = not theme_mojibake
    details["mojibake_hits"] = {
        "readme": readme_mojibake,
        "page_index": page_index_mojibake,
        "theme_audit": theme_mojibake,
    }

    readme_fence_errors = fence_errors(readme)
    page_index_fence_errors = fence_errors(page_index)
    theme_fence_errors = fence_errors(theme_audit)
    checks["readme_fences_balanced"] = not readme_fence_errors
    checks["page_index_fences_balanced"] = not page_index_fence_errors
    checks["theme_audit_fences_balanced"] = not theme_fence_errors
    details["fence_errors"] = {
        "readme": readme_fence_errors,
        "page_index": page_index_fence_errors,
        "theme_audit": theme_fence_errors,
    }

    missing_topics = [topic for topic in REQUIRED_TOPICS if topic not in readme]
    checks["required_topics_present"] = not missing_topics
    details["missing_required_topics"] = missing_topics

    outdated_hits = [phrase for phrase in OUTDATED_PHRASES if phrase in readme]
    checks["no_outdated_status_phrases"] = not outdated_hits
    details["outdated_status_phrases"] = outdated_hits

    target_values = labelled_version_values(readme, "targetSdkVersion")
    compatible_values = labelled_version_values(readme, "compatibleSdkVersion")
    checks["project_sdk_current"] = (
        "6.1.1(24)" in target_values and "6.1.0(23)" in compatible_values
    )
    checks["project_sdk_has_no_conflicting_exact_values"] = (
        set(target_values) == {"6.1.1(24)"}
        and set(compatible_values) == {"6.1.0(23)"}
    )
    details["project_sdk_values"] = {
        "targetSdkVersion": target_values,
        "compatibleSdkVersion": compatible_values,
    }

    checks["readme_has_expected_title"] = readme.startswith(
        "# HarmonyOS 官方指南全量工程手册\n"
    )
    checks["readme_has_eight_chapters"] = len(
        re.findall(r"^## 第 \d+ 部分：", readme, flags=re.MULTILINE)
    ) == 8
    checks["readme_is_generated_from_reviewed_chapters"] = (
        "由 tools/assemble_handbook.py 从 drafts/ 中的已审阅章节生成" in readme
    )

    menu_summary = audit.get("current_menu_summary", {})
    aggregates = audit.get("aggregates", {})
    status = audit.get("counts", {}).get("status", {})
    expected_coverage_rows = [
        f"| 左侧菜单 UI 节点 | {int(menu_summary.get('ui_nodes', -1)):,} |",
        f"| 可展开分支 | {int(menu_summary.get('branch_nodes', -1)):,} |",
        f"| 带正文的菜单入口 | {int(menu_summary.get('document_links', -1)):,} |",
        f"| 正文读取成功 | {int(status.get('success', -1)):,} |",
        "| 失败 / 待读取 | 0 / 0 |",
        f"| 正文字符 | {int(aggregates.get('text_characters', -1)):,} |",
        f"| 代码块 | {int(aggregates.get('code_blocks', -1)):,} |",
        f"| 表格 | {int(aggregates.get('tables', -1)):,} |",
        f"| 提示/警告块 | {int(aggregates.get('admonitions', -1)):,} |",
        f"| 图片记录 | {int(aggregates.get('images', -1)):,} |",
        "| 二次官网目录差异 | 0 |",
    ]
    checks["readme_coverage_numbers_match_audit"] = all(
        row in readme for row in expected_coverage_rows
    )
    details["missing_readme_coverage_rows"] = [
        row for row in expected_coverage_rows if row not in readme
    ]

    index_entries = re.findall(
        r"^####\s+(\d{4})\.\s+(.+)$", page_index, flags=re.MULTILINE
    )
    index_identifiers = re.findall(
        r"^- 页面标识：`([^`]+)`；菜单节点：`([^`]+)`$",
        page_index,
        flags=re.MULTILINE,
    )
    index_url_pairs = re.findall(
        r"^- 官方页面：\[([^\]]+)\]\(([^)]+)\)$",
        page_index,
        flags=re.MULTILINE,
    )
    expected_entries = [
        (f"{row['ordinal']:04d}", row["title"]) for row in menu_docs
    ]
    expected_identifiers = [(row["slug"], row["node_id"]) for row in menu_docs]
    expected_urls = [row["url"] for row in menu_docs]
    checks["page_index_entries_5694"] = len(index_entries) == 5694
    checks["page_index_entries_match_menu_order"] = index_entries == expected_entries
    checks["page_index_identifiers_match_menu"] = index_identifiers == expected_identifiers
    checks["page_index_urls_match_menu"] = (
        len(index_url_pairs) == 5694
        and all(label == target for label, target in index_url_pairs)
        and [target for _, target in index_url_pairs] == expected_urls
    )
    forbidden_index_fields = [
        phrase
        for phrase in ("- 摘要：", "- 正文摘录：", "- 内容摘录：")
        if phrase in page_index
    ]
    checks["page_index_has_no_body_excerpt_field"] = not forbidden_index_fields
    index_root_headings = re.findall(
        r"^### (?!#)(.+)$", page_index, flags=re.MULTILINE
    )
    expected_root_headings = [root for _, root, _ in EXPECTED_ROOT_COUNTS]
    checks["page_index_has_21_roots_in_order"] = (
        index_root_headings == expected_root_headings
    )
    index_section_headings = re.findall(
        r"^## (?!#)(.+)$", page_index, flags=re.MULTILINE
    )
    checks["page_index_has_five_sections_in_order"] = index_section_headings == [
        "使用方法",
        *EXPECTED_SECTIONS.keys(),
    ]
    details["page_index_entries"] = len(index_entries)
    details["page_index_identifier_rows"] = len(index_identifiers)
    details["page_index_url_rows"] = len(index_url_pairs)
    details["page_index_root_headings"] = index_root_headings
    details["page_index_forbidden_fields"] = forbidden_index_fields

    readme_link_errors = local_link_errors(README_PATH, readme)
    page_index_link_errors = local_link_errors(PAGE_INDEX_PATH, page_index)
    theme_link_errors = local_link_errors(THEME_AUDIT_PATH, theme_audit)
    checks["readme_local_links_resolve"] = not readme_link_errors
    checks["page_index_local_links_resolve"] = not page_index_link_errors
    checks["theme_audit_local_links_resolve"] = not theme_link_errors
    details["readme_broken_local_links"] = readme_link_errors
    details["page_index_broken_local_links"] = page_index_link_errors
    details["theme_audit_broken_local_links"] = theme_link_errors

    menu_slugs = {row["slug"] for row in menu_docs}
    official_slugs = set(OFFICIAL_GUIDE_RE.findall(readme))
    missing_official_slugs = sorted(slug for slug in official_slugs if slug not in menu_slugs)
    checks["official_guide_links_in_snapshot"] = not missing_official_slugs
    details["official_guide_link_count"] = len(official_slugs)
    details["official_links_missing_from_snapshot"] = missing_official_slugs

    theme_outdated_hits = [
        phrase for phrase in THEME_OUTDATED_PHRASES if phrase in theme_audit
    ]
    checks["theme_audit_has_no_old_status_or_index_wording"] = not theme_outdated_hits
    checks["theme_audit_has_all_21_root_rows"] = all(
        f"| {index} | {section} | {root} | {count:,} |" in theme_audit
        for index, (section, root, count) in enumerate(EXPECTED_ROOT_COUNTS, start=1)
    )
    checks["theme_audit_uses_structural_index_wording"] = (
        "逐页结构索引" in theme_audit
    )
    details["theme_audit_outdated_phrases"] = theme_outdated_hits

    checks["readme_is_detailed"] = len(readme) >= 150_000 and readme.count("\n") >= 2500
    details["readme_characters"] = len(readme)
    details["readme_lines"] = readme.count("\n") + 1
    details["page_index_characters"] = len(page_index)
    details["all_checks_passed"] = all(checks.values())

    report = {"checks": checks, "details": details}
    REPORT_JSON_PATH.write_text(
        json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )

    md_lines = [
        "# 手册交付验证",
        "",
        f"> 结论：**{'全部通过' if details['all_checks_passed'] else '存在失败项'}**",
        "",
        "| 检查 | 结果 |",
        "|---|---|",
    ]
    md_lines.extend(
        f"| `{name}` | {'通过' if passed else '失败'} |"
        for name, passed in checks.items()
    )
    md_lines.extend(
        [
            "",
            "## 关键数量",
            "",
            f"- 主文档：{details['readme_lines']} 行，{details['readme_characters']} 字符",
            f"- 逐页结构索引条目：{details['page_index_entries']}",
            f"- 主文档官方指南链接：{details['official_guide_link_count']}",
            f"- 主文档失效本地链接：{len(readme_link_errors)}",
            f"- 逐页索引失效本地链接：{len(page_index_link_errors)}",
            f"- 主题覆盖审计失效本地链接：{len(theme_link_errors)}",
            "",
        ]
    )
    failed_checks = [name for name, passed in checks.items() if not passed]
    md_lines.extend(
        [
            "## 失败项",
            "",
            *(f"- `{name}`" for name in failed_checks),
            *( ["- 无"] if not failed_checks else [] ),
            "",
        ]
    )
    REPORT_MD_PATH.write_text("\n".join(md_lines) + "\n", encoding="utf-8")

    print(json.dumps(report, ensure_ascii=False))
    return 0 if details["all_checks_passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
