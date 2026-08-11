#!/usr/bin/env python3
"""Assemble the reviewed thematic chapters into one AI- and human-readable handbook."""

from __future__ import annotations

import json
import re
from pathlib import Path


SCRIPT_DIR = Path(__file__).resolve().parent
ROOT_DIR = SCRIPT_DIR.parent
DRAFT_DIR = ROOT_DIR / "drafts"
OUTPUT_PATH = ROOT_DIR / "README.md"

CHAPTERS = [
    "00-scope-and-mental-model.md",
    "official-menu-panorama.md",
    "official-application-framework.md",
    "system-media-graphics.md",
    "official-services-ai-distributed-native.md",
    "official-tools-testing-experience.md",
    "ai-agent-workbook.md",
    "kangxiaobanai-adaptation.md",
]

LINK_RE = re.compile(r"(!?\[[^\]\n]*\]\()([^\)\n]+)(\))")
FENCE_RE = re.compile(r"^[ \t]{0,3}(`{3,}|~{3,})(.*)$")


def fence_token(line: str) -> tuple[str, int, str] | None:
    match = FENCE_RE.match(line)
    if not match:
        return None
    marker, remainder = match.groups()
    return marker[0], len(marker), remainder


def is_closing_fence(token: tuple[str, int, str], opened: tuple[str, int]) -> bool:
    char, length, remainder = token
    return char == opened[0] and length >= opened[1] and not remainder.strip()


def assert_balanced_fences(text: str, source: Path) -> None:
    opened: tuple[str, int, int] | None = None
    for line_number, line in enumerate(text.splitlines(), start=1):
        token = fence_token(line)
        if token is None:
            continue
        if opened is None:
            opened = (token[0], token[1], line_number)
        elif is_closing_fence(token, (opened[0], opened[1])):
            opened = None
    if opened is not None:
        raise ValueError(
            f"Unclosed Markdown fence in {source} at line {opened[2]} "
            f"({opened[0] * opened[1]})"
        )


def rewrite_relative_links(text: str, source: Path) -> str:
    def replace(match: re.Match[str]) -> str:
        prefix, raw_target, suffix = match.groups()
        target = raw_target.strip()
        wrapped = target.startswith("<") and target.endswith(">")
        clean_target = target[1:-1] if wrapped else target
        if (
            not clean_target
            or clean_target.startswith(("http://", "https://", "mailto:", "#", "/"))
            or re.match(r"^[A-Za-z]:[\\/]", clean_target)
        ):
            return match.group(0)
        path_part, hash_mark, fragment = clean_target.partition("#")
        resolved = (source.parent / path_part).resolve()
        try:
            relative = resolved.relative_to(ROOT_DIR).as_posix()
        except ValueError:
            return match.group(0)
        rewritten = relative + (f"#{fragment}" if hash_mark else "")
        if " " in rewritten:
            rewritten = f"<{rewritten}>"
        return f"{prefix}{rewritten}{suffix}"

    result: list[str] = []
    opened: tuple[str, int] | None = None
    for line in text.splitlines(keepends=True):
        token = fence_token(line.rstrip("\r\n"))
        if opened is None:
            if token is not None:
                opened = (token[0], token[1])
                result.append(line)
            else:
                result.append(LINK_RE.sub(replace, line))
        else:
            result.append(line)
            if token is not None and is_closing_fence(token, opened):
                opened = None
    return "".join(result)


def shift_headings(text: str) -> tuple[str, str]:
    lines = text.splitlines()
    title = ""
    first_heading_index: int | None = None
    opened: tuple[str, int] | None = None
    for index, line in enumerate(lines):
        token = fence_token(line)
        if opened is not None:
            if token is not None and is_closing_fence(token, opened):
                opened = None
            continue
        if token is not None:
            opened = (token[0], token[1])
            continue
        if line.startswith("# "):
            title = line[2:].strip()
            first_heading_index = index
            break
    if first_heading_index is None or not title:
        raise ValueError("Chapter is missing a non-empty level-one heading")
    del lines[first_heading_index]

    result: list[str] = []
    opened = None
    for line in lines:
        token = fence_token(line)
        if opened is not None:
            result.append(line)
            if token is not None and is_closing_fence(token, opened):
                opened = None
            continue
        if token is not None:
            opened = (token[0], token[1])
            result.append(line)
            continue
        match = re.match(r"^(#{1,6})(\s+.*)$", line)
        if match:
            marks, remainder = match.groups()
            line = f"{'#' * min(6, len(marks) + 1)}{remainder}"
        result.append(line)
    return title, "\n".join(result).strip()


def build_header(chapter_titles: list[str]) -> str:
    chapter_list = "\n".join(
        f"{index}. {title}" for index, title in enumerate(chapter_titles, start=1)
    )
    return f"""# HarmonyOS 官方指南全量工程手册

> 面向人类开发者、Codex、Claude 与其他编程 Agent  
> 官方入口：<https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arkts>  
> 官网目录与正文快照：2026-08-10（Asia/Shanghai）  
> 主文档状态：**已完成本次左侧菜单全树读取、完整性审计、主题综合与 `KangxiaobanAI` 项目适配**

<!-- 本文件由 tools/assemble_handbook.py 从 drafts/ 中的已审阅章节生成。 -->

## 先看结论

本次范围不是只有 ArkTS 首页，而是用户截图中左侧“指南”的整棵菜单：入门、开发、工具、测试、体验建议，以及它们的全部多级子菜单。

| 完整性项目 | 结果 |
|---|---:|
| 左侧菜单 UI 节点 | 5,720 |
| 可展开分支 | 1,059 |
| 最终仍折叠分支 | 0 |
| 带正文的菜单入口 | 5,694 |
| 正文读取成功 | 5,694 |
| 失败 / 待读取 | 0 / 0 |
| 正文字符 | 19,621,279 |
| 代码块 | 20,996 |
| 表格 | 5,018 |
| 提示/警告块 | 3,325 |
| 图片记录 | 11,339 |
| 二次官网目录差异 | 0 |

完整性证据见 [audit-report.md](coverage/audit-report.md)；浏览器跨五大分区抽样见 [browser-sample-audit.md](coverage/browser-sample-audit.md)。

这里的“全量读取完成”表示：每个菜单正文入口都获得了完整页面内容并完成结构化读取、哈希与审计。它不表示 5,694 个示例都已在本机 SDK、模拟器、真机或真实服务上运行。任何具体实现仍须核对当前官网、当前 SDK 声明和当前工程配置。

## 这套文件怎样使用

| 需求 | 首选文件 |
|---|---|
| 系统理解、开发决策、AI 编程约束 | 本 `README.md` |
| 对照用户截图的 21 个根菜单检查主题章覆盖 | [theme-coverage-audit.md](coverage/theme-coverage-audit.md) |
| 确认某个左侧菜单是否覆盖 | [menu-tree.md](coverage/menu-tree.md) |
| 查 5,694 个页面的路径、URL、结构和哈希 | [FULL_PAGE_DIGESTS.md](FULL_PAGE_DIGESTS.md) |
| 查某页最终状态与精确 URL | [page-status.csv](coverage/page-status.csv) |
| 按标题/章节检索 | [heading-index.csv](coverage/heading-index.csv) |
| 定位官方代码块来源 | [code-source-index.csv](coverage/code-source-index.csv) |
| 定位提示、警告和限制 | [admonition-index.csv](coverage/admonition-index.csv) |
| 查看最终交付自检 | [handbook-validation.md](coverage/handbook-validation.md) |
| 做机器级追溯或重新生成索引 | `coverage/crawl.sqlite3` 与 `tools/` |

## 建议阅读顺序

{chapter_list}

## 三类内容标签

- `[官方事实]`：来自本次官网快照，可回到官方 URL 核对。
- `[解释]`：对多个官方页面的工程化归纳，不冒充逐字原文。
- `[项目适配]`：结合当前 `KangxiaobanAI` 源码与配置给出的落地判断。

验证状态必须另外说明：静态、构建、模拟器、真机、服务、性能和发布不能互相替代。
"""


def build_footer() -> str:
    return """## 附录：审计与再生成

在本目录执行：

```powershell
python tools/audit_huawei_guides.py
python tools/build_reference_indexes.py
python tools/build_menu_panorama.py
python tools/assemble_handbook.py
python tools/validate_handbook.py
```

注意：重新抓取官网会访问外部网络并可能得到更新后的目录；只运行审计与索引脚本不会修改产品源码。

### 本次项目适配的证据边界

- 当前源码配置优先于历史说明。
- `KangxiaobanAI` 当前 `targetSdkVersion` 为 `6.1.1(24)`，`compatibleSdkVersion` 为 `6.1.0(23)`。
- 产品代码未因本次文档任务被修改。
- 本次项目适配是静态源码与配置核对，不是构建、真机、服务、性能或发布验证。
- 工作树中的既有修改和签名相关配置属于用户，未被覆盖或打印。
"""


def main() -> int:
    missing = [name for name in CHAPTERS if not (DRAFT_DIR / name).exists()]
    if missing:
        raise FileNotFoundError(f"Missing chapter files: {missing}")

    prepared: list[tuple[str, str]] = []
    for name in CHAPTERS:
        source = DRAFT_DIR / name
        raw = source.read_text(encoding="utf-8-sig")
        assert_balanced_fences(raw, source)
        raw = rewrite_relative_links(raw, source)
        title, body = shift_headings(raw)
        prepared.append((title, body))

    parts = [build_header([title for title, _ in prepared]).rstrip()]
    for index, (title, body) in enumerate(prepared, start=1):
        parts.extend(
            [
                "",
                "---",
                "",
                f"## 第 {index} 部分：{title}",
                "",
                body,
            ]
        )
    parts.extend(["", "---", "", build_footer().rstrip(), ""])
    output = "\n".join(parts)
    OUTPUT_PATH.write_text(output, encoding="utf-8")
    print(
        json.dumps(
            {
                "output": str(OUTPUT_PATH),
                "chapters": len(prepared),
                "characters": len(output),
                "lines": output.count("\n") + 1,
            },
            ensure_ascii=False,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
