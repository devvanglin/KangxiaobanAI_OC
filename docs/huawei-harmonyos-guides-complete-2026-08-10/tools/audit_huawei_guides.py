#!/usr/bin/env python3
"""Audit completeness and integrity of the HarmonyOS guide crawl."""

from __future__ import annotations

import gzip
import hashlib
import json
import sqlite3
import sys
import unicodedata
from pathlib import Path
from typing import Any


SCRIPT_DIR = Path(__file__).resolve().parent
ROOT_DIR = SCRIPT_DIR.parent
COVERAGE_DIR = ROOT_DIR / "coverage"
DB_PATH = COVERAGE_DIR / "crawl.sqlite3"
MENU_PATH = COVERAGE_DIR / "menu-inventory.json"
REPORT_JSON_PATH = COVERAGE_DIR / "audit-report.json"
REPORT_MD_PATH = COVERAGE_DIR / "audit-report.md"

sys.path.insert(0, str(SCRIPT_DIR))
import crawl_huawei_guides as crawler  # noqa: E402


def suspicious_title(title: str) -> bool:
    if not title.strip() or "\ufffd" in title:
        return True
    for char in title:
        code = ord(char)
        if 0xAC00 <= code <= 0xD7AF:  # Hangul is unexpected in the Chinese catalog.
            return True
        if unicodedata.category(char) in {"Cc", "Cs"}:
            return True
    return False


def compact_rows(rows: list[tuple[Any, ...]], keys: list[str], limit: int = 50) -> list[dict[str, Any]]:
    return [dict(zip(keys, row, strict=True)) for row in rows[:limit]]


def main() -> int:
    menu_raw = json.loads(MENU_PATH.read_text(encoding="utf-8"))
    menu_docs = [row for row in menu_raw if row.get("has_document")]
    menu_by_slug = {row["slug"]: row for row in menu_docs}
    saved_signature = [
        (
            row["ordinal"],
            row["node_id"],
            row["kind"],
            row["section"],
            row["depth"],
            tuple(row["menu_path"]),
            row["slug"],
        )
        for row in menu_raw
    ]

    current_catalog = crawler.fetch_catalog(30.0)
    current_rows = crawler.build_menu_rows(current_catalog)
    current_signature = [
        (
            row.ordinal,
            row.node_id,
            row.kind,
            row.section,
            row.depth,
            tuple(row.menu_path),
            row.slug,
        )
        for row in current_rows
    ]
    current_menu_summary = crawler.validate_menu(current_rows)

    connection = sqlite3.connect(DB_PATH)
    integrity = connection.execute("PRAGMA integrity_check").fetchone()[0]
    status_counts = dict(
        connection.execute("SELECT status,COUNT(*) FROM pages GROUP BY status").fetchall()
    )
    page_count = connection.execute("SELECT COUNT(*) FROM pages").fetchone()[0]
    page_slugs = {
        row[0] for row in connection.execute("SELECT slug FROM pages")
    }
    page_urls = dict(
        connection.execute("SELECT slug,requested_url FROM pages").fetchall()
    )
    database_menu_signature = [
        (
            ordinal,
            node_id,
            kind,
            section,
            depth,
            tuple(json.loads(menu_path_json)),
            slug,
        )
        for ordinal, node_id, kind, section, depth, menu_path_json, slug
        in connection.execute(
            """
            SELECT ordinal,node_id,kind,section,depth,menu_path_json,slug
            FROM menu_nodes ORDER BY ordinal
            """
        )
    ]

    duplicate_hash_rows = connection.execute(
        """
        SELECT content_sha256,COUNT(*) AS count,GROUP_CONCAT(slug,' | ')
        FROM pages
        WHERE status='success' AND content_sha256<>''
        GROUP BY content_sha256 HAVING COUNT(*)>1
        ORDER BY count DESC,content_sha256
        """
    ).fetchall()
    short_rows = connection.execute(
        """
        SELECT slug,title,text_length,html_length,summary
        FROM pages WHERE status='success' ORDER BY text_length,slug LIMIT 100
        """
    ).fetchall()
    title_rows = connection.execute(
        "SELECT slug,title FROM pages WHERE status='success' ORDER BY slug"
    ).fetchall()
    title_anomalies = [
        {
            "slug": slug,
            "official_title": title,
            "menu_title": menu_by_slug.get(slug, {}).get("title", ""),
        }
        for slug, title in title_rows
        if suspicious_title(title)
    ]
    title_mismatches = [
        {
            "slug": slug,
            "official_title": title,
            "menu_title": menu_by_slug.get(slug, {}).get("title", ""),
        }
        for slug, title in title_rows
        if menu_by_slug.get(slug, {}).get("title", "").strip() != title.strip()
    ]

    blob_errors: list[dict[str, str]] = []
    soft_error_pages: list[dict[str, str]] = []
    verified_blobs = 0
    generic_error_titles = {
        "页面不存在",
        "系统繁忙",
        "网络异常",
        "page not found",
        "404 not found",
        "404",
    }
    for row in connection.execute(
        """
        SELECT slug,title,html_length,text_length,content_sha256,
               heading_count,code_count,table_count,admonition_count,image_count,
               html_gzip,text_gzip,extract_gzip,summary
        FROM pages WHERE status='success' ORDER BY slug
        """
    ):
        (
            slug,
            title,
            html_length,
            text_length,
            expected_hash,
            heading_count,
            code_count,
            table_count,
            admonition_count,
            image_count,
            html_blob,
            text_blob,
            extract_blob,
            summary,
        ) = row
        try:
            html = gzip.decompress(html_blob).decode("utf-8")
            text = gzip.decompress(text_blob).decode("utf-8")
            extract = json.loads(gzip.decompress(extract_blob).decode("utf-8"))
            if len(html) != html_length:
                raise ValueError(f"HTML length {len(html)} != {html_length}")
            if len(text) != text_length:
                raise ValueError(f"text length {len(text)} != {text_length}")
            actual_hash = hashlib.sha256(html.encode("utf-8")).hexdigest()
            if actual_hash != expected_hash:
                raise ValueError(f"hash {actual_hash} != {expected_hash}")
            for key in ("headings", "code_blocks", "tables", "admonitions", "images", "links"):
                if key not in extract or not isinstance(extract[key], list):
                    raise ValueError(f"extract missing list {key}")
            expected_extract_counts = {
                "headings": heading_count,
                "code_blocks": code_count,
                "tables": table_count,
                "admonitions": admonition_count,
                "images": image_count,
            }
            for key, expected_count in expected_extract_counts.items():
                actual_count = len(extract[key])
                if actual_count != expected_count:
                    raise ValueError(
                        f"extract {key} count {actual_count} != {expected_count}"
                    )
            verified_blobs += 1
            normalized_title = title.strip().lower()
            normalized_start = text[:200].strip().lower()
            looks_like_short_error = text_length < 200 and normalized_start in generic_error_titles
            if normalized_title in generic_error_titles or looks_like_short_error:
                soft_error_pages.append(
                    {"slug": slug, "title": title, "preview": normalized_start[:200]}
                )
        except Exception as exc:  # noqa: BLE001 - audit records exact corruption
            blob_errors.append({"slug": slug, "error": f"{type(exc).__name__}: {exc}"})

    aggregates = connection.execute(
        """
        SELECT COALESCE(SUM(text_length),0),COALESCE(SUM(html_length),0),
               COALESCE(SUM(code_count),0),COALESCE(SUM(table_count),0),
               COALESCE(SUM(admonition_count),0),COALESCE(SUM(image_count),0),
               MIN(text_length),MAX(text_length),AVG(text_length)
        FROM pages WHERE status='success'
        """
    ).fetchone()
    connection.close()

    saved_slug_set = set(menu_by_slug)
    saved_urls = {slug: row["url"] for slug, row in menu_by_slug.items()}
    critical = {
        "sqlite_integrity": integrity == "ok",
        "saved_menu_node_count": len(menu_raw) == 5720,
        "saved_menu_document_count": len(menu_docs) == 5694,
        "database_menu_matches_saved": database_menu_signature == saved_signature,
        "page_row_count": page_count == 5694,
        "success_count": status_counts.get("success", 0) == 5694,
        "failed_count_zero": status_counts.get("failed", 0) == 0,
        "menu_page_slug_sets_equal": saved_slug_set == page_slugs,
        "menu_page_urls_equal": saved_urls == page_urls,
        "blob_integrity": verified_blobs == 5694 and not blob_errors,
        "soft_error_pages_zero": not soft_error_pages,
        "second_catalog_identical": saved_signature == current_signature,
        "current_catalog_baseline": not current_menu_summary.get("baseline_mismatches"),
    }
    report = {
        "generated_at": crawler.now_iso(),
        "critical_checks": critical,
        "all_critical_passed": all(critical.values()),
        "counts": {
            "saved_menu_nodes": len(menu_raw),
            "saved_menu_documents": len(menu_docs),
            "database_pages": page_count,
            "status": status_counts,
            "verified_blobs": verified_blobs,
            "title_mismatches": len(title_mismatches),
            "title_anomalies": len(title_anomalies),
            "duplicate_hash_groups": len(duplicate_hash_rows),
            "soft_error_pages": len(soft_error_pages),
            "blob_errors": len(blob_errors),
        },
        "aggregates": {
            "text_characters": aggregates[0],
            "html_characters": aggregates[1],
            "code_blocks": aggregates[2],
            "tables": aggregates[3],
            "admonitions": aggregates[4],
            "images": aggregates[5],
            "min_text_length": aggregates[6],
            "max_text_length": aggregates[7],
            "average_text_length": round(aggregates[8] or 0, 2),
        },
        "current_menu_summary": current_menu_summary,
        "warnings": {
            "title_anomalies": title_anomalies[:100],
            "title_mismatch_examples": title_mismatches[:100],
            "duplicate_hash_examples": compact_rows(
                duplicate_hash_rows,
                ["sha256", "count", "slugs"],
                100,
            ),
            "shortest_pages": compact_rows(
                short_rows,
                ["slug", "title", "text_length", "html_length", "summary"],
                100,
            ),
            "soft_error_pages": soft_error_pages,
            "blob_errors": blob_errors,
        },
    }
    REPORT_JSON_PATH.write_text(crawler.json_text(report, pretty=True), encoding="utf-8")

    check_lines = [
        f"| {name} | {'通过' if passed else '失败'} |"
        for name, passed in critical.items()
    ]
    anomaly_lines = [
        f"- `{item['slug']}`：官网标题 `{item['official_title']}`；菜单标题 `{item['menu_title']}`"
        for item in title_anomalies[:50]
    ] or ["- 无"]
    REPORT_MD_PATH.write_text(
        "\n".join(
            [
                "# 全量采集完整性审计",
                "",
                f"> 审计时间：{report['generated_at']}",
                "",
                f"结论：**{'全部关键检查通过' if report['all_critical_passed'] else '存在关键检查失败'}**。",
                "",
                "## 关键检查",
                "",
                "| 检查项 | 结果 |",
                "|---|---|",
                *check_lines,
                "",
                "## 内容统计",
                "",
                f"- 正文页面：{page_count}",
                f"- 正文字符：{aggregates[0]}",
                f"- HTML 字符：{aggregates[1]}",
                f"- 代码块：{aggregates[2]}",
                f"- 表格：{aggregates[3]}",
                f"- 提示/警告块：{aggregates[4]}",
                f"- 图片：{aggregates[5]}",
                f"- 最短/最长/平均正文字符：{aggregates[6]} / {aggregates[7]} / {round(aggregates[8] or 0, 2)}",
                "",
                "## 官网标题编码异常",
                "",
                "这些页面保留官网原始标题字段，但人类文档和 AI 索引优先使用正常的菜单标题。",
                "",
                *anomaly_lines,
                "",
                "## 说明",
                "",
                "同一内容哈希可能来自官方重复说明或占位页，不据此删除菜单项；"
                "每个菜单节点仍保留独立审计记录。",
                "",
            ]
        ),
        encoding="utf-8",
    )
    print(crawler.json_text(report), flush=True)
    return 0 if report["all_critical_passed"] else 2


if __name__ == "__main__":
    raise SystemExit(main())
