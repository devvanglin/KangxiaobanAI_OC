#!/usr/bin/env python3
"""Resumable crawler for Huawei's public HarmonyOS guide catalog.

The script uses the same read-only JSON endpoints loaded by the official
developer.huawei.com document page. It preserves the original menu tree,
fetches every document-bearing node (including branch overview pages), stores
compressed source/extract data in SQLite, and exports human/machine-readable
coverage reports.
"""

from __future__ import annotations

import argparse
import csv
import gzip
import hashlib
import json
import random
import re
import sqlite3
import sys
import threading
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from dataclasses import asdict, dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Iterable

import requests
from bs4 import BeautifulSoup


CATALOG_ENDPOINT = (
    "https://svc-drcn.developer.huawei.com/community/servlet/consumer/cn/"
    "documentPortal/getCatalogTree"
)
DOCUMENT_ENDPOINT = (
    "https://svc-drcn.developer.huawei.com/community/servlet/consumer/cn/"
    "documentPortal/getDocumentById"
)
PUBLIC_PAGE_PREFIX = (
    "https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/"
)
CATALOG_NAME = "harmonyos-guides"
LANGUAGE = "cn"

SCRIPT_DIR = Path(__file__).resolve().parent
ROOT_DIR = SCRIPT_DIR.parent
COVERAGE_DIR = ROOT_DIR / "coverage"
DB_PATH = COVERAGE_DIR / "crawl.sqlite3"
CATALOG_PATH = COVERAGE_DIR / "catalog-response.json"
MENU_JSON_PATH = COVERAGE_DIR / "menu-inventory.json"
MENU_CSV_PATH = COVERAGE_DIR / "menu-inventory.csv"
MENU_TREE_PATH = COVERAGE_DIR / "menu-tree.md"
PAGE_STATUS_PATH = COVERAGE_DIR / "page-status.csv"
PAGE_DIGESTS_PATH = COVERAGE_DIR / "page-digests.jsonl"
CRAWL_REPORT_PATH = COVERAGE_DIR / "crawl-report.md"

THREAD_LOCAL = threading.local()


@dataclass(frozen=True)
class MenuRow:
    ordinal: int
    kind: str
    section: str
    depth: int
    title: str
    menu_path: list[str]
    node_id: str
    parent_id: str
    is_leaf: bool
    has_children: bool
    has_document: bool
    slug: str
    url: str
    label_no: str


def now_iso() -> str:
    return datetime.now(timezone.utc).astimezone().isoformat(timespec="seconds")


def json_text(value: Any, *, pretty: bool = False) -> str:
    return json.dumps(
        value,
        ensure_ascii=False,
        indent=2 if pretty else None,
        separators=None if pretty else (",", ":"),
    )


def normalize_text(value: str) -> str:
    value = value.replace("\u00a0", " ").replace("\r\n", "\n").replace("\r", "\n")
    value = re.sub(r"[ \t]+", " ", value)
    value = re.sub(r"\n[ \t]+", "\n", value)
    value = re.sub(r"\n{3,}", "\n\n", value)
    return value.strip()


def normalize_code(value: str) -> str:
    """Preserve indentation while removing only transport/layout noise."""
    value = value.replace("\u00a0", " ").replace("\r\n", "\n").replace("\r", "\n")
    value = re.sub(r"\n{3,}", "\n\n", value)
    return value.strip("\n")


def children_of(node: dict[str, Any]) -> list[dict[str, Any]]:
    children = node.get("children")
    return children if isinstance(children, list) else []


def session_for_thread() -> requests.Session:
    session = getattr(THREAD_LOCAL, "session", None)
    if session is None:
        session = requests.Session()
        session.headers.update(
            {
                "Accept": "application/json, text/plain, */*",
                "Content-Type": "application/json;charset=UTF-8",
                "User-Agent": "Codex-HarmonyOS-Documentation-Audit/1.0",
            }
        )
        THREAD_LOCAL.session = session
    return session


def post_json(endpoint: str, payload: dict[str, Any], timeout: float) -> dict[str, Any]:
    response = session_for_thread().post(endpoint, json=payload, timeout=timeout)
    response.raise_for_status()
    data = response.json()
    if data.get("code") != 0:
        raise RuntimeError(
            f"Official endpoint returned code={data.get('code')!r}: "
            f"{data.get('message') or data.get('msg') or ''}"
        )
    return data


def fetch_catalog(timeout: float) -> dict[str, Any]:
    return post_json(
        CATALOG_ENDPOINT,
        {"language": LANGUAGE, "catalogName": CATALOG_NAME},
        timeout,
    )


def build_menu_rows(catalog: dict[str, Any]) -> list[MenuRow]:
    value = catalog.get("value") or {}
    roots = value.get("catalogTreeList") or []
    display_labels = value.get("displayLabels") or []
    roots_by_label: dict[str, list[dict[str, Any]]] = {}
    for root in roots:
        roots_by_label.setdefault(str(root.get("labelNo") or ""), []).append(root)

    labels = sorted(display_labels, key=lambda item: int(item.get("sequence") or 0))
    rows: list[MenuRow] = []

    def visit(node: dict[str, Any], section: str, ancestors: list[str]) -> None:
        title = str(node.get("nodeName") or "").strip()
        node_id = str(node.get("nodeId") or "").strip()
        parent_id = str(node.get("parent") or "").strip()
        slug = str(node.get("relateDocument") or "").strip()
        children = children_of(node)
        path = [section, *ancestors, title]
        rows.append(
            MenuRow(
                ordinal=len(rows) + 1,
                kind="document-branch" if children and slug else (
                    "group" if children else "document"
                ),
                section=section,
                depth=len(ancestors),
                title=title,
                menu_path=path,
                node_id=node_id,
                parent_id=parent_id,
                is_leaf=bool(node.get("isLeaf")) and not children,
                has_children=bool(children),
                has_document=bool(slug),
                slug=slug,
                url=f"{PUBLIC_PAGE_PREFIX}{slug}" if slug else "",
                label_no=str(node.get("labelNo") or ""),
            )
        )
        for child in children:
            visit(child, section, [*ancestors, title])

    used_labels: set[str] = set()
    for label in labels:
        label_no = str(label.get("labelNo") or "")
        matching_roots = roots_by_label.get(label_no) or []
        if not matching_roots:
            continue
        used_labels.add(label_no)
        section = str(label.get("labelNameCn") or label.get("labelNameEn") or "").strip()
        rows.append(
            MenuRow(
                ordinal=len(rows) + 1,
                kind="section",
                section=section,
                depth=-1,
                title=section,
                menu_path=[section],
                node_id=f"section:{label_no}",
                parent_id="",
                is_leaf=False,
                has_children=True,
                has_document=False,
                slug="",
                url="",
                label_no=label_no,
            )
        )
        for root in matching_roots:
            visit(root, section, [])

    # Fail closed if Huawei introduces a root label that is not in displayLabels.
    unmatched = [root for root in roots if str(root.get("labelNo") or "") not in used_labels]
    if unmatched:
        names = ", ".join(str(item.get("nodeName") or "") for item in unmatched[:20])
        raise RuntimeError(f"Catalog contains unmatched root labels: {names}")

    return rows


def validate_menu(rows: list[MenuRow]) -> dict[str, Any]:
    links = [row for row in rows if row.has_document]
    slugs = [row.slug for row in links]
    duplicate_slugs = sorted({slug for slug in slugs if slugs.count(slug) > 1})
    sections: dict[str, dict[str, int]] = {}
    for row in rows:
        stats = sections.setdefault(row.section, {"nodes": 0, "links": 0, "groups": 0})
        stats["nodes"] += 1
        if row.has_document:
            stats["links"] += 1
        elif row.kind != "section":
            stats["groups"] += 1
    result = {
        "ui_nodes": len(rows),
        "raw_nodes": len(rows) - sum(1 for row in rows if row.kind == "section"),
        "section_nodes": sum(1 for row in rows if row.kind == "section"),
        "branch_nodes": sum(1 for row in rows if row.has_children and row.kind != "section"),
        "group_nodes": sum(1 for row in rows if row.kind == "group"),
        "document_links": len(links),
        "branch_documents": sum(1 for row in rows if row.has_children and row.has_document),
        "leaf_documents": sum(1 for row in rows if not row.has_children and row.has_document),
        "unique_slugs": len(set(slugs)),
        "duplicate_slugs": duplicate_slugs,
        "max_depth": max((row.depth for row in rows), default=-1),
        "sections": sections,
    }
    expected = {
        "ui_nodes": 5720,
        "raw_nodes": 5715,
        "section_nodes": 5,
        "branch_nodes": 1059,
        "group_nodes": 21,
        "document_links": 5694,
        "branch_documents": 1038,
        "leaf_documents": 4656,
        "unique_slugs": 5694,
    }
    mismatches = {
        key: {"expected": expected_value, "actual": result.get(key)}
        for key, expected_value in expected.items()
        if result.get(key) != expected_value
    }
    result["baseline_mismatches"] = mismatches
    if duplicate_slugs:
        raise RuntimeError(f"Duplicate relateDocument slugs found: {duplicate_slugs[:20]}")
    return result


def save_catalog_and_menu(catalog: dict[str, Any], rows: list[MenuRow]) -> dict[str, Any]:
    COVERAGE_DIR.mkdir(parents=True, exist_ok=True)
    CATALOG_PATH.write_text(json_text(catalog, pretty=True), encoding="utf-8")
    row_dicts = [asdict(row) for row in rows]
    MENU_JSON_PATH.write_text(json_text(row_dicts, pretty=True), encoding="utf-8")

    fields = list(row_dicts[0].keys()) if row_dicts else []
    with MENU_CSV_PATH.open("w", encoding="utf-8-sig", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields)
        writer.writeheader()
        for row in row_dicts:
            item = dict(row)
            item["menu_path"] = " > ".join(row["menu_path"])
            writer.writerow(item)

    lines = [
        "# 华为 HarmonyOS 指南左侧菜单完整树",
        "",
        f"> 生成时间：{now_iso()}",
        "> 数据来源：官网 `getCatalogTree` 只读接口；顺序与左侧菜单一致。",
        "",
    ]
    for row in rows:
        if row.kind == "section":
            lines.extend([f"## {row.title}", ""])
            continue
        indent = "  " * max(row.depth, 0)
        marker = "-"
        label = f"[{row.title}]({row.url})" if row.url else row.title
        suffix = " （分支概览页）" if row.kind == "document-branch" else (
            " （分组，无正文）" if row.kind == "group" else ""
        )
        lines.append(f"{indent}{marker} {label}{suffix}")
    MENU_TREE_PATH.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return validate_menu(rows)


def init_database(rows: list[MenuRow], menu_summary: dict[str, Any]) -> sqlite3.Connection:
    connection = sqlite3.connect(DB_PATH)
    connection.execute("PRAGMA journal_mode=WAL")
    connection.execute("PRAGMA synchronous=NORMAL")
    connection.executescript(
        """
        CREATE TABLE IF NOT EXISTS meta (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL
        );
        CREATE TABLE IF NOT EXISTS menu_nodes (
          ordinal INTEGER PRIMARY KEY,
          kind TEXT NOT NULL,
          section TEXT NOT NULL,
          depth INTEGER NOT NULL,
          title TEXT NOT NULL,
          menu_path_json TEXT NOT NULL,
          node_id TEXT NOT NULL,
          parent_id TEXT NOT NULL,
          is_leaf INTEGER NOT NULL,
          has_children INTEGER NOT NULL,
          has_document INTEGER NOT NULL,
          slug TEXT NOT NULL,
          url TEXT NOT NULL,
          label_no TEXT NOT NULL
        );
        CREATE UNIQUE INDEX IF NOT EXISTS idx_menu_node_id ON menu_nodes(node_id);
        CREATE INDEX IF NOT EXISTS idx_menu_slug ON menu_nodes(slug);
        CREATE TABLE IF NOT EXISTS pages (
          slug TEXT PRIMARY KEY,
          requested_url TEXT NOT NULL,
          status TEXT NOT NULL,
          attempts INTEGER NOT NULL,
          checked_at TEXT NOT NULL,
          title TEXT NOT NULL,
          updated_date TEXT NOT NULL,
          display_update_time TEXT NOT NULL,
          device_version TEXT NOT NULL,
          content_type TEXT NOT NULL,
          restricted_type TEXT NOT NULL,
          is_import TEXT NOT NULL,
          html_length INTEGER NOT NULL,
          text_length INTEGER NOT NULL,
          content_sha256 TEXT NOT NULL,
          heading_count INTEGER NOT NULL,
          code_count INTEGER NOT NULL,
          table_count INTEGER NOT NULL,
          admonition_count INTEGER NOT NULL,
          image_count INTEGER NOT NULL,
          summary TEXT NOT NULL,
          metadata_json TEXT NOT NULL,
          extract_gzip BLOB,
          html_gzip BLOB,
          text_gzip BLOB,
          error TEXT NOT NULL
        );
        CREATE INDEX IF NOT EXISTS idx_pages_status ON pages(status);
        """
    )
    connection.execute("DELETE FROM menu_nodes")
    connection.executemany(
        """
        INSERT INTO menu_nodes VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?)
        """,
        [
            (
                row.ordinal,
                row.kind,
                row.section,
                row.depth,
                row.title,
                json_text(row.menu_path),
                row.node_id,
                row.parent_id,
                int(row.is_leaf),
                int(row.has_children),
                int(row.has_document),
                row.slug,
                row.url,
                row.label_no,
            )
            for row in rows
        ],
    )
    meta_values = {
        "catalog_checked_at": now_iso(),
        "menu_summary": json_text(menu_summary),
        "catalog_endpoint": CATALOG_ENDPOINT,
        "document_endpoint": DOCUMENT_ENDPOINT,
    }
    connection.executemany(
        "INSERT OR REPLACE INTO meta(key,value) VALUES (?,?)",
        list(meta_values.items()),
    )
    connection.commit()
    return connection


def extract_article(html: str) -> tuple[str, dict[str, Any], str]:
    soup = BeautifulSoup(html, "html.parser")

    for tag in soup(["script", "style", "noscript"]):
        tag.decompose()

    headings = [
        {
            "level": int(tag.name[1]),
            "text": normalize_text(tag.get_text(" ", strip=True)),
            "id": str(tag.get("id") or ""),
        }
        for tag in soup.find_all(re.compile(r"^h[1-6]$"))
    ]

    code_blocks = []
    for pre in soup.find_all("pre"):
        classes = [str(item) for item in (pre.get("class") or [])]
        language = str(pre.get("hw-language") or "")
        if not language:
            language_class = next(
                (item for item in classes if item.startswith("language-")), ""
            )
            language = language_class.removeprefix("language-")
        code_blocks.append(
            {
                "language": language,
                "source_url": str(pre.get("codehub") or ""),
                "code": normalize_code(pre.get_text("\n", strip=False)),
            }
        )

    tables = []
    for table in soup.find_all("table"):
        rows = []
        for tr in table.find_all("tr"):
            cells = []
            for cell in tr.find_all(["th", "td"], recursive=False):
                cells.append(
                    {
                        "tag": cell.name,
                        "text": normalize_text(cell.get_text(" ", strip=True)),
                        "row_span": int(cell.get("rowspan") or 1),
                        "col_span": int(cell.get("colspan") or 1),
                        "links": [
                            {
                                "text": normalize_text(link.get_text(" ", strip=True)),
                                "href": str(link.get("href") or ""),
                            }
                            for link in cell.find_all("a", href=True)
                        ],
                    }
                )
            if cells:
                rows.append(cells)
        tables.append({"class": " ".join(table.get("class") or []), "rows": rows})

    admonitions = []
    seen_admonitions: set[int] = set()
    for block in soup.select(
        ".hw-editor-tip, .note, .warning, .caution, .tip, .important, .attention"
    ):
        if id(block) in seen_admonitions:
            continue
        seen_admonitions.add(id(block))
        classes = [item for item in (block.get("class") or []) if item != "hw-editor-tip"]
        title = block.select_one(".title, .notetitle, .warningtitle")
        content = block.select_one(".content, .notebody, .warningbody")
        admonitions.append(
            {
                "kind": classes[0] if classes else "tip",
                "title": normalize_text(title.get_text(" ", strip=True)) if title else "",
                "text": normalize_text(
                    (content or block).get_text("\n", strip=True)
                ),
            }
        )
    for block in soup.find_all("blockquote"):
        admonitions.append(
            {
                "kind": "blockquote",
                "title": "",
                "text": normalize_text(block.get_text("\n", strip=True)),
            }
        )

    images = [
        {
            "src": str(image.get("src") or image.get("data-src") or ""),
            "alt": normalize_text(str(image.get("alt") or "")),
            "width": str(image.get("width") or ""),
            "height": str(image.get("height") or ""),
        }
        for image in soup.find_all("img")
    ]

    links = [
        {
            "text": normalize_text(link.get_text(" ", strip=True)),
            "href": str(link.get("href") or ""),
        }
        for link in soup.find_all("a", href=True)
    ]

    text = normalize_text(soup.get_text("\n", strip=True))
    paragraphs: list[str] = []
    seen: set[str] = set()
    for tag in soup.find_all(["p", "li"]):
        paragraph = normalize_text(tag.get_text(" ", strip=True))
        if len(paragraph) < 20 or paragraph in seen:
            continue
        seen.add(paragraph)
        paragraphs.append(paragraph)
        if sum(len(item) for item in paragraphs) >= 900:
            break
    summary = normalize_text(" ".join(paragraphs))[:1200]
    if not summary:
        summary = text[:1200]

    extract = {
        "headings": headings,
        "code_blocks": code_blocks,
        "tables": tables,
        "admonitions": admonitions,
        "images": images,
        "links": links,
    }
    return text, extract, summary


def fetch_document(slug: str, *, timeout: float, retries: int) -> dict[str, Any]:
    requested_url = f"{PUBLIC_PAGE_PREFIX}{slug}"
    last_error = ""
    for attempt in range(1, retries + 1):
        try:
            data = post_json(
                DOCUMENT_ENDPOINT,
                {
                    "language": LANGUAGE,
                    "catalogName": CATALOG_NAME,
                    "objectId": slug,
                    "version": "",
                },
                timeout,
            )
            value = data.get("value") or {}
            content = value.get("content") or {}
            content_type = str(content.get("type") or "")
            html = str(content.get("content") or "")
            if content_type != "html" or not html.strip():
                raise RuntimeError(
                    f"Missing HTML body (content_type={content_type!r}, length={len(html)})"
                )
            text, extract, summary = extract_article(html)
            metadata = {
                key: value.get(key)
                for key in (
                    "docId",
                    "title",
                    "lang",
                    "domain",
                    "businessName",
                    "businessType",
                    "businessTypeName",
                    "serviceType",
                    "version",
                    "anchorList",
                    "status",
                    "catalogName",
                    "isImport",
                    "tag",
                    "fileName",
                    "navigationAddress",
                    "updatedDate",
                    "websiteType",
                    "isGray",
                    "restrictedType",
                    "searchTitle",
                    "keywords",
                    "platform",
                    "versionLabels",
                    "contentLabels",
                    "showBeta",
                    "displayUpdateTime",
                    "deviceVersion",
                )
            }
            extract_bytes = json_text(extract).encode("utf-8")
            return {
                "slug": slug,
                "requested_url": requested_url,
                "status": "success",
                "attempts": attempt,
                "checked_at": now_iso(),
                "title": str(value.get("title") or ""),
                "updated_date": str(value.get("updatedDate") or ""),
                "display_update_time": str(value.get("displayUpdateTime") or ""),
                "device_version": str(value.get("deviceVersion") or ""),
                "content_type": content_type,
                "restricted_type": str(value.get("restrictedType") or ""),
                "is_import": str(value.get("isImport") or ""),
                "html_length": len(html),
                "text_length": len(text),
                "content_sha256": hashlib.sha256(html.encode("utf-8")).hexdigest(),
                "heading_count": len(extract["headings"]),
                "code_count": len(extract["code_blocks"]),
                "table_count": len(extract["tables"]),
                "admonition_count": len(extract["admonitions"]),
                "image_count": len(extract["images"]),
                "summary": summary,
                "metadata_json": json_text(metadata),
                "extract_gzip": gzip.compress(extract_bytes, compresslevel=6),
                "html_gzip": gzip.compress(html.encode("utf-8"), compresslevel=6),
                "text_gzip": gzip.compress(text.encode("utf-8"), compresslevel=6),
                "error": "",
            }
        except Exception as exc:  # noqa: BLE001 - audit needs exact failure text
            last_error = f"{type(exc).__name__}: {exc}"
            if attempt < retries:
                time.sleep((2 ** (attempt - 1)) + random.uniform(0.05, 0.35))

    return {
        "slug": slug,
        "requested_url": requested_url,
        "status": "failed",
        "attempts": retries,
        "checked_at": now_iso(),
        "title": "",
        "updated_date": "",
        "display_update_time": "",
        "device_version": "",
        "content_type": "",
        "restricted_type": "",
        "is_import": "",
        "html_length": 0,
        "text_length": 0,
        "content_sha256": "",
        "heading_count": 0,
        "code_count": 0,
        "table_count": 0,
        "admonition_count": 0,
        "image_count": 0,
        "summary": "",
        "metadata_json": "{}",
        "extract_gzip": None,
        "html_gzip": None,
        "text_gzip": None,
        "error": last_error,
    }


PAGE_COLUMNS = [
    "slug",
    "requested_url",
    "status",
    "attempts",
    "checked_at",
    "title",
    "updated_date",
    "display_update_time",
    "device_version",
    "content_type",
    "restricted_type",
    "is_import",
    "html_length",
    "text_length",
    "content_sha256",
    "heading_count",
    "code_count",
    "table_count",
    "admonition_count",
    "image_count",
    "summary",
    "metadata_json",
    "extract_gzip",
    "html_gzip",
    "text_gzip",
    "error",
]


def upsert_page(connection: sqlite3.Connection, row: dict[str, Any]) -> None:
    placeholders = ",".join("?" for _ in PAGE_COLUMNS)
    updates = ",".join(f"{column}=excluded.{column}" for column in PAGE_COLUMNS[1:])
    connection.execute(
        f"INSERT INTO pages({','.join(PAGE_COLUMNS)}) VALUES ({placeholders}) "
        f"ON CONFLICT(slug) DO UPDATE SET {updates}",
        [row[column] for column in PAGE_COLUMNS],
    )


def successful_slugs(connection: sqlite3.Connection) -> set[str]:
    return {
        row[0]
        for row in connection.execute("SELECT slug FROM pages WHERE status='success'")
    }


def reparse_pages(connection: sqlite3.Connection) -> dict[str, int]:
    rows = connection.execute(
        "SELECT slug,html_gzip FROM pages WHERE status='success' ORDER BY slug"
    ).fetchall()
    completed = 0
    for slug, html_blob in rows:
        html = gzip.decompress(html_blob).decode("utf-8")
        text, extract, summary = extract_article(html)
        connection.execute(
            """
            UPDATE pages
            SET text_length=?,heading_count=?,code_count=?,table_count=?,
                admonition_count=?,image_count=?,summary=?,extract_gzip=?,text_gzip=?
            WHERE slug=?
            """,
            (
                len(text),
                len(extract["headings"]),
                len(extract["code_blocks"]),
                len(extract["tables"]),
                len(extract["admonitions"]),
                len(extract["images"]),
                summary,
                gzip.compress(json_text(extract).encode("utf-8"), compresslevel=6),
                gzip.compress(text.encode("utf-8"), compresslevel=6),
                slug,
            ),
        )
        completed += 1
        if completed % 100 == 0 or completed == len(rows):
            connection.commit()
            print(
                json_text(
                    {
                        "event": "reparse_progress",
                        "completed": completed,
                        "total": len(rows),
                        "last_slug": slug,
                    }
                ),
                flush=True,
            )
    connection.commit()
    return {"reparsed": completed}


def crawl_pages(
    connection: sqlite3.Connection,
    rows: list[MenuRow],
    *,
    workers: int,
    timeout: float,
    retries: int,
    refresh: bool,
    failed_only: bool,
    limit: int | None,
) -> dict[str, Any]:
    documents = [row for row in rows if row.has_document]
    existing_success = successful_slugs(connection)
    previous_failed = {
        row[0]
        for row in connection.execute("SELECT slug FROM pages WHERE status='failed'")
    }

    queue: list[str] = []
    for row in documents:
        if failed_only and row.slug not in previous_failed:
            continue
        if not refresh and row.slug in existing_success:
            continue
        queue.append(row.slug)
    if limit is not None:
        queue = queue[:limit]

    print(
        json_text(
            {
                "event": "crawl_start",
                "total_documents": len(documents),
                "already_success": len(existing_success),
                "queued": len(queue),
                "workers": workers,
            }
        ),
        flush=True,
    )

    completed = success = failed = 0
    started = time.monotonic()
    with ThreadPoolExecutor(max_workers=workers) as executor:
        futures = {
            executor.submit(
                fetch_document,
                slug,
                timeout=timeout,
                retries=retries,
            ): slug
            for slug in queue
        }
        for future in as_completed(futures):
            slug = futures[future]
            try:
                result = future.result()
            except Exception as exc:  # safety net around worker itself
                result = fetch_document(slug, timeout=timeout, retries=1)
                if result["status"] != "success":
                    result["error"] = f"Worker failure: {type(exc).__name__}: {exc}; {result['error']}"
            upsert_page(connection, result)
            completed += 1
            if result["status"] == "success":
                success += 1
            else:
                failed += 1
            if completed % 20 == 0 or completed == len(queue):
                connection.commit()
                elapsed = max(time.monotonic() - started, 0.001)
                print(
                    json_text(
                        {
                            "event": "crawl_progress",
                            "completed": completed,
                            "queued": len(queue),
                            "success": success,
                            "failed": failed,
                            "pages_per_second": round(completed / elapsed, 2),
                            "last_slug": slug,
                        }
                    ),
                    flush=True,
                )
    connection.commit()
    return {
        "queued": len(queue),
        "completed": completed,
        "new_success": success,
        "new_failed": failed,
    }


def load_extract(blob: bytes | None) -> dict[str, Any]:
    if not blob:
        return {}
    return json.loads(gzip.decompress(blob).decode("utf-8"))


def export_reports(connection: sqlite3.Connection, rows: list[MenuRow]) -> dict[str, Any]:
    page_rows = {
        row[0]: row
        for row in connection.execute(
            """
            SELECT slug,status,attempts,checked_at,title,updated_date,
                   display_update_time,device_version,content_type,
                   restricted_type,is_import,html_length,text_length,
                   content_sha256,heading_count,code_count,table_count,
                   admonition_count,image_count,summary,error,metadata_json,
                   extract_gzip
            FROM pages
            """
        )
    }

    status_fields = [
        "ordinal",
        "section",
        "menu_path",
        "depth",
        "title",
        "node_id",
        "kind",
        "slug",
        "url",
        "page_status",
        "attempts",
        "checked_at",
        "official_title",
        "updated_date",
        "display_update_time",
        "device_version",
        "html_length",
        "text_length",
        "content_sha256",
        "heading_count",
        "code_count",
        "table_count",
        "admonition_count",
        "image_count",
        "summary",
        "error",
    ]
    with PAGE_STATUS_PATH.open("w", encoding="utf-8-sig", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=status_fields)
        writer.writeheader()
        for menu in rows:
            if not menu.has_document:
                continue
            page = page_rows.get(menu.slug)
            item = {
                "ordinal": menu.ordinal,
                "section": menu.section,
                "menu_path": " > ".join(menu.menu_path),
                "depth": menu.depth,
                "title": menu.title,
                "node_id": menu.node_id,
                "kind": menu.kind,
                "slug": menu.slug,
                "url": menu.url,
                "page_status": page[1] if page else "pending",
                "attempts": page[2] if page else 0,
                "checked_at": page[3] if page else "",
                "official_title": page[4] if page else "",
                "updated_date": page[5] if page else "",
                "display_update_time": page[6] if page else "",
                "device_version": page[7] if page else "",
                "html_length": page[11] if page else 0,
                "text_length": page[12] if page else 0,
                "content_sha256": page[13] if page else "",
                "heading_count": page[14] if page else 0,
                "code_count": page[15] if page else 0,
                "table_count": page[16] if page else 0,
                "admonition_count": page[17] if page else 0,
                "image_count": page[18] if page else 0,
                "summary": page[19] if page else "",
                "error": page[20] if page else "",
            }
            writer.writerow(item)

    with PAGE_DIGESTS_PATH.open("w", encoding="utf-8") as handle:
        for menu in rows:
            if not menu.has_document:
                continue
            page = page_rows.get(menu.slug)
            if not page:
                digest = {
                    "slug": menu.slug,
                    "url": menu.url,
                    "menu_path": menu.menu_path,
                    "status": "pending",
                }
            else:
                extract = load_extract(page[22])
                digest = {
                    "slug": menu.slug,
                    "url": menu.url,
                    "menu_path": menu.menu_path,
                    "status": page[1],
                    "title": page[4],
                    "updated_date": page[5],
                    "display_update_time": page[6],
                    "device_version": page[7],
                    "html_length": page[11],
                    "text_length": page[12],
                    "content_sha256": page[13],
                    "summary": page[19],
                    "headings": extract.get("headings", []),
                    "code_blocks": [
                        {
                            "language": item.get("language", ""),
                            "source_url": item.get("source_url", ""),
                            "characters": len(item.get("code", "")),
                            "preview": item.get("code", "")[:400],
                        }
                        for item in extract.get("code_blocks", [])
                    ],
                    "table_shapes": [
                        [len(table.get("rows", [])), max(
                            (len(row) for row in table.get("rows", [])),
                            default=0,
                        )]
                        for table in extract.get("tables", [])
                    ],
                    "admonitions": extract.get("admonitions", []),
                    "images": extract.get("images", []),
                    "error": page[20],
                }
            handle.write(json_text(digest) + "\n")

    counts = dict(
        connection.execute(
            "SELECT status,COUNT(*) FROM pages GROUP BY status"
        ).fetchall()
    )
    total_links = sum(1 for row in rows if row.has_document)
    success_count = int(counts.get("success", 0))
    failed_count = int(counts.get("failed", 0))
    pending_count = total_links - success_count - failed_count
    aggregate = connection.execute(
        """
        SELECT COALESCE(SUM(text_length),0),COALESCE(SUM(html_length),0),
               COALESCE(SUM(code_count),0),COALESCE(SUM(table_count),0),
               COALESCE(SUM(admonition_count),0),COALESCE(SUM(image_count),0)
        FROM pages WHERE status='success'
        """
    ).fetchone()
    report = {
        "generated_at": now_iso(),
        "menu_links": total_links,
        "success": success_count,
        "failed": failed_count,
        "pending": pending_count,
        "text_characters": aggregate[0],
        "html_characters": aggregate[1],
        "code_blocks": aggregate[2],
        "tables": aggregate[3],
        "admonitions": aggregate[4],
        "images": aggregate[5],
    }
    CRAWL_REPORT_PATH.write_text(
        "\n".join(
            [
                "# 官网逐页读取报告",
                "",
                f"> 生成时间：{report['generated_at']}",
                "",
                "| 指标 | 数量 |",
                "|---|---:|",
                f"| 左侧菜单正文链接 | {total_links} |",
                f"| 成功读取 | {success_count} |",
                f"| 失败 | {failed_count} |",
                f"| 待读取 | {pending_count} |",
                f"| 正文字符合计 | {report['text_characters']} |",
                f"| HTML 字符合计 | {report['html_characters']} |",
                f"| 代码块 | {report['code_blocks']} |",
                f"| 表格 | {report['tables']} |",
                f"| 提示/警告块 | {report['admonitions']} |",
                f"| 图片 | {report['images']} |",
                "",
                "只有失败数与待读取数均为 0，并完成第二次菜单差异检查后，"
                "才可声明全量完成。",
                "",
            ]
        ),
        encoding="utf-8",
    )
    return report


def load_menu_rows() -> list[MenuRow]:
    raw = json.loads(MENU_JSON_PATH.read_text(encoding="utf-8"))
    return [MenuRow(**item) for item in raw]


def parse_args(argv: Iterable[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--catalog-only", action="store_true")
    parser.add_argument("--export-only", action="store_true")
    parser.add_argument("--reparse-only", action="store_true")
    parser.add_argument("--failed-only", action="store_true")
    parser.add_argument("--refresh", action="store_true")
    parser.add_argument("--workers", type=int, default=8)
    parser.add_argument("--timeout", type=float, default=30.0)
    parser.add_argument("--retries", type=int, default=3)
    parser.add_argument("--limit", type=int)
    return parser.parse_args(list(argv))


def main(argv: Iterable[str] = sys.argv[1:]) -> int:
    args = parse_args(argv)
    COVERAGE_DIR.mkdir(parents=True, exist_ok=True)

    if args.export_only:
        rows = load_menu_rows()
        connection = sqlite3.connect(DB_PATH)
        report = export_reports(connection, rows)
        connection.close()
        print(json_text({"event": "export_complete", **report}), flush=True)
        return 0

    if args.reparse_only:
        rows = load_menu_rows()
        connection = sqlite3.connect(DB_PATH)
        summary = reparse_pages(connection)
        report = export_reports(connection, rows)
        connection.close()
        print(
            json_text({"event": "reparse_complete", **summary, "report": report}),
            flush=True,
        )
        return 0

    catalog = fetch_catalog(args.timeout)
    rows = build_menu_rows(catalog)
    menu_summary = save_catalog_and_menu(catalog, rows)
    print(json_text({"event": "catalog_complete", **menu_summary}), flush=True)

    connection = init_database(rows, menu_summary)
    if args.catalog_only:
        report = export_reports(connection, rows)
        connection.close()
        print(json_text({"event": "catalog_only_complete", **report}), flush=True)
        return 0

    crawl_summary = crawl_pages(
        connection,
        rows,
        workers=max(1, min(args.workers, 32)),
        timeout=args.timeout,
        retries=max(1, args.retries),
        refresh=args.refresh,
        failed_only=args.failed_only,
        limit=args.limit,
    )
    report = export_reports(connection, rows)
    connection.close()
    print(
        json_text(
            {"event": "crawl_complete", **crawl_summary, "report": report}
        ),
        flush=True,
    )
    return 0 if report["failed"] == 0 else 2


if __name__ == "__main__":
    raise SystemExit(main())
