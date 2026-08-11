# 官网 21 个根目录主题覆盖审计

> 最终复核时间：2026-08-10T19:10:16+08:00  
> 审计对象：用户截图所列全部根菜单  
> 数据源：<code>crawl.sqlite3</code>、<code>menu-inventory.csv</code>、<code>page-digests.jsonl</code>、<code>FULL_PAGE_DIGESTS.md</code>  
> 目的：把菜单页数、逐页结构索引和负责综合章节一一对齐，明确正文覆盖与综合写作是否仍有缺口

## 1. 结论先行

数据库与逐页结构索引的 21 个根目录已经完全对齐：

- 根目录数：21；
- 根目录页面数合计：5,694；
- 菜单中带正文的节点：5,694；
- 唯一 slug：5,694；
- 数据库页面记录：5,694；
- 成功读取：5,694；
- 失败或非 success：0；
- <code>FULL_PAGE_DIGESTS.md</code> 根目录标题：21；
- <code>FULL_PAGE_DIGESTS.md</code> 逐页结构索引条目：5,694；
- 根目录逐项计数差异：0；
- 遗漏 slug：0；
- 重复归入两个根目录的 slug：0。

因此，菜单发现、正文读取和逐页结构索引层面没有缺口。

主题综合映射也已完整：<code>drafts/official-services-ai-distributed-native.md</code> 已完成并负责应用服务、AI、一次开发多端部署、自由流转和 NDK 开发五个根目录，共 2,040 页。至此 21 个根目录均有明确的负责综合章节。

根目录计数之和：

    45
    + 1 + 1090 + 1054 + 389 + 237 + 948 + 948 + 1 + 1 + 142
    + 128 + 437 + 62 + 37 + 2 + 50 + 10 + 31
    + 23
    + 58
    = 5694

## 2. 状态口径

| 状态 | 含义 |
|---|---|
| 正文完整 | 该根目录在 SQLite 中的全部页面均为 success |
| 逐页结构索引完整 | <code>FULL_PAGE_DIGESTS.md</code> 中该根目录条目数与数据库完全一致 |
| 综合章已完成 | 计划负责该根目录的独立综合章节文件已经存在且不是空文件 |
| 总纲型综合 | 已由总纲建立工程模型，但不是 45 份逐页内容的顺序复述 |
| 交叉覆盖 | 该主题还在其他章节出现，用于补充，不改变主要负责章节 |

综合章状态只核对文件存在、规模和主题结构，不把“文件存在”冒充逐条事实已二次人工复审。逐页完整性由数据库、菜单清单和逐页结构索引单独证明。

## 3. 21 个根目录逐项审计

| 序号 | 一级分区 | 根目录 | 数据库正文页 | 负责综合章节 | 综合章状态 | 逐页结构索引 | 正文状态 |
|---:|---|---|---:|---|---|---|---|
| 1 | 入门 | 基础入门 | 45 | [00-scope-and-mental-model.md](../drafts/00-scope-and-mental-model.md)，应用框架章补充 ArkTS/ArkUI | 已完成，总纲型综合 | 是，45/45 | 完整，45 success |
| 2 | 开发 | 应用开发准备 | 1 | [00-scope-and-mental-model.md](../drafts/00-scope-and-mental-model.md) | 已完成 | 是，1/1 | 完整，1 success |
| 3 | 开发 | 应用框架 | 1,090 | [official-application-framework.md](../drafts/official-application-framework.md) | 已完成；ArkWeb、IME 还由系统媒体图形章交叉覆盖 | 是，1,090/1,090 | 完整，1,090 success |
| 4 | 开发 | 系统 | 1,054 | [system-media-graphics.md](../drafts/system-media-graphics.md) | 已完成 | 是，1,054/1,054 | 完整，1,054 success |
| 5 | 开发 | 媒体 | 389 | [system-media-graphics.md](../drafts/system-media-graphics.md) | 已完成 | 是，389/389 | 完整，389 success |
| 6 | 开发 | 图形 | 237 | [system-media-graphics.md](../drafts/system-media-graphics.md) | 已完成 | 是，237/237 | 完整，237 success |
| 7 | 开发 | 应用服务 | 948 | [official-services-ai-distributed-native.md](../drafts/official-services-ai-distributed-native.md) | 已完成 | 是，948/948 | 完整，948 success |
| 8 | 开发 | AI | 948 | [official-services-ai-distributed-native.md](../drafts/official-services-ai-distributed-native.md) | 已完成 | 是，948/948 | 完整，948 success |
| 9 | 开发 | 一次开发，多端部署 | 1 | [official-services-ai-distributed-native.md](../drafts/official-services-ai-distributed-native.md)，总纲另有工程模型 | 已完成；有总纲交叉覆盖 | 是，1/1 | 完整，1 success |
| 10 | 开发 | 自由流转 | 1 | [official-services-ai-distributed-native.md](../drafts/official-services-ai-distributed-native.md)，总纲另有工程模型 | 已完成；有总纲交叉覆盖 | 是，1/1 | 完整，1 success |
| 11 | 开发 | NDK开发 | 142 | [official-services-ai-distributed-native.md](../drafts/official-services-ai-distributed-native.md) | 已完成 | 是，142/142 | 完整，142 success |
| 12 | 工具 | 开发环境搭建 | 128 | [official-tools-testing-experience.md](../drafts/official-tools-testing-experience.md) | 已完成 | 是，128/128 | 完整，128 success |
| 13 | 工具 | 编写与调试应用 | 437 | [official-tools-testing-experience.md](../drafts/official-tools-testing-experience.md) | 已完成 | 是，437/437 | 完整，437 success |
| 14 | 工具 | 构建应用 | 62 | [official-tools-testing-experience.md](../drafts/official-tools-testing-experience.md) | 已完成 | 是，62/62 | 完整，62 success |
| 15 | 工具 | 优化应用性能 | 37 | [official-tools-testing-experience.md](../drafts/official-tools-testing-experience.md) | 已完成 | 是，37/37 | 完整，37 success |
| 16 | 工具 | 发布应用 | 2 | [official-tools-testing-experience.md](../drafts/official-tools-testing-experience.md) | 已完成 | 是，2/2 | 完整，2 success |
| 17 | 工具 | 命令行工具 | 50 | [official-tools-testing-experience.md](../drafts/official-tools-testing-experience.md) | 已完成 | 是，50/50 | 完整，50 success |
| 18 | 工具 | AI Coding | 10 | [official-tools-testing-experience.md](../drafts/official-tools-testing-experience.md) 与 [ai-agent-workbook.md](../drafts/ai-agent-workbook.md) | 已完成 | 是，10/10 | 完整，10 success |
| 19 | 工具 | 使用AI智能辅助编程（不推荐） | 31 | [official-tools-testing-experience.md](../drafts/official-tools-testing-experience.md) 与 [ai-agent-workbook.md](../drafts/ai-agent-workbook.md) | 已完成 | 是，31/31 | 完整，31 success |
| 20 | 测试 | 应用测试 | 23 | [official-tools-testing-experience.md](../drafts/official-tools-testing-experience.md) | 已完成 | 是，23/23 | 完整，23 success |
| 21 | 体验建议 | 应用体验建议 | 58 | [official-tools-testing-experience.md](../drafts/official-tools-testing-experience.md) | 已完成 | 是，58/58 | 完整，58 success |
|  |  | **合计** | **5,694** |  |  | **5,694/5,694** | **5,694 success** |

所有根目录同时还由 [official-menu-panorama.md](../drafts/official-menu-panorama.md) 提供页面数、正文字符、代码块、表格、提示警告与图片数量全景；[FULL_PAGE_DIGESTS.md](../FULL_PAGE_DIGESTS.md) 是逐页回查入口。

## 4. 分区小计复核

| 一级分区 | 根目录组成 | 根目录数 | 页面小计 | 官方分区基线 | 差异 |
|---|---|---:|---:|---:|---:|
| 入门 | 基础入门 | 1 | 45 | 45 | 0 |
| 开发 | 应用开发准备、应用框架、系统、媒体、图形、应用服务、AI、一次开发多端部署、自由流转、NDK开发 | 10 | 4,811 | 4,811 | 0 |
| 工具 | 开发环境搭建、编写与调试应用、构建应用、优化应用性能、发布应用、命令行工具、AI Coding、使用AI智能辅助编程（不推荐） | 8 | 757 | 757 | 0 |
| 测试 | 应用测试 | 1 | 23 | 23 | 0 |
| 体验建议 | 应用体验建议 | 1 | 58 | 58 | 0 |
| **合计** | **21 个根目录** | **21** | **5,694** | **5,694** | **0** |

开发分区计算：

    1 + 1090 + 1054 + 389 + 237 + 948 + 948 + 1 + 1 + 142 = 4811

工具分区计算：

    128 + 437 + 62 + 37 + 2 + 50 + 10 + 31 = 757

总计：

    45 + 4811 + 757 + 23 + 58 = 5694

## 5. 逐页结构索引独立复核

<code>FULL_PAGE_DIGESTS.md</code> 的格式是：

- 二级标题：五个一级分区，另有一个“使用方法”标题；
- 三级标题：21 个根目录；
- 四级标题：每个菜单正文页面一条，共 5,694 条；
- 每条包含菜单路径、官方 URL、slug、菜单节点 ID、正文结构、内容哈希、结构类型、章节线索和 AI 使用提示；不复制正文摘要。

按三级标题统计四级条目，结果如下：

| 根目录 | 索引条目 | 数据库页 | 差异 |
|---|---:|---:|---:|
| 基础入门 | 45 | 45 | 0 |
| 应用开发准备 | 1 | 1 | 0 |
| 应用框架 | 1,090 | 1,090 | 0 |
| 系统 | 1,054 | 1,054 | 0 |
| 媒体 | 389 | 389 | 0 |
| 图形 | 237 | 237 | 0 |
| 应用服务 | 948 | 948 | 0 |
| AI | 948 | 948 | 0 |
| 一次开发，多端部署 | 1 | 1 | 0 |
| 自由流转 | 1 | 1 | 0 |
| NDK开发 | 142 | 142 | 0 |
| 开发环境搭建 | 128 | 128 | 0 |
| 编写与调试应用 | 437 | 437 | 0 |
| 构建应用 | 62 | 62 | 0 |
| 优化应用性能 | 37 | 37 | 0 |
| 发布应用 | 2 | 2 | 0 |
| 命令行工具 | 50 | 50 | 0 |
| AI Coding | 10 | 10 | 0 |
| 使用AI智能辅助编程（不推荐） | 31 | 31 | 0 |
| 应用测试 | 23 | 23 | 0 |
| 应用体验建议 | 58 | 58 | 0 |
| **合计** | **5,694** | **5,694** | **0** |

## 6. 机器可核验结论

### 6.1 不变量

本报告使用以下不变量判定根目录覆盖通过：

    expected_root_count = 21
    actual_root_count = 21

    sum(root_page_counts) = 5694
    menu_document_rows = 5694
    unique_menu_slugs = 5694

    sqlite_page_rows = 5694
    sqlite_success_rows = 5694
    sqlite_non_success_rows = 0

    full_page_digest_root_headings = 21
    full_page_digest_page_entries = 5694

    root_count_mismatches = 0
    missing_slugs = 0
    duplicate_root_assignments = 0

只有上述等式同时成立，才判定 21 个根目录的菜单、正文和逐页结构索引完整。

### 6.2 可复算脚本

下面脚本只读 SQLite，按菜单路径的前两段分桶：

    import collections
    import json
    import sqlite3

    database = r"coverage\crawl.sqlite3"
    connection = sqlite3.connect(database)

    rows = connection.execute(
        "select slug, menu_path_json "
        "from menu_nodes where has_document = 1 order by ordinal"
    ).fetchall()

    buckets = collections.Counter()
    all_slugs = []

    for slug, path_json in rows:
        path = json.loads(path_json)
        buckets[(path[0], path[1])] += 1
        all_slugs.append(slug)

    assert len(buckets) == 21
    assert sum(buckets.values()) == 5694
    assert len(all_slugs) == 5694
    assert len(set(all_slugs)) == 5694

    assert connection.execute(
        "select count(*) from pages"
    ).fetchone()[0] == 5694

    assert connection.execute(
        "select count(*) from pages where status = 'success'"
    ).fetchone()[0] == 5694

    assert connection.execute(
        "select count(*) from pages where status != 'success'"
    ).fetchone()[0] == 0

逐页 Markdown 结构索引可用以下逻辑复算：

    from pathlib import Path

    text = Path("FULL_PAGE_DIGESTS.md").read_text(encoding="utf-8")
    root_count = sum(1 for line in text.splitlines() if line.startswith("### "))
    page_count = sum(1 for line in text.splitlines() if line.startswith("#### "))

    assert root_count == 21
    assert page_count == 5694

### 6.3 关键证据文件哈希

| 文件 | SHA-256 |
|---|---|
| <code>coverage/crawl.sqlite3</code> | <code>6BB7D9369122BE803FBA2B2BEC25F27B7CB436E0220A94DA224FA79CBEDC8470</code> |
| <code>coverage/menu-inventory.csv</code> | <code>D62316568CF7E5429EE8AFB4AE0B6131B9E22F4B936E2B8D6CE5EE44DE858E07</code> |
| <code>coverage/page-digests.jsonl</code> | <code>493E8D974A8DAAD31B97CE40E425A750827BAF8B7F96A433AECFBCE6FD679C7E</code> |

上述哈希对应不可替代的采集证据快照。`FULL_PAGE_DIGESTS.md` 是可再生成的派生索引，其格式变化会改变哈希；最终交付以验证脚本对 5,694 条菜单顺序、slug、节点 ID、URL 和 21 个根目录的逐项比对为准。

## 7. 缺口与后续动作

### 7.1 数据和逐页结构索引

没有缺口。21 个根目录、5 个一级分区和 5,694 个正文页面全部匹配。

### 7.2 主题综合

没有根目录综合章节缺口。应用服务、AI、一次开发多端部署、自由流转和 NDK 开发已由 [official-services-ai-distributed-native.md](../drafts/official-services-ai-distributed-native.md) 统一负责，21 个根目录均有明确负责章节。

### 7.3 总手册装配边界

本报告只审计 21 个根目录的菜单、正文、逐页结构索引和负责综合章节。将各草稿装配成单一总手册属于独立生成与验证步骤，不改变本报告的根目录覆盖判定。

### 7.4 不能由本报告证明的事项

- 本报告不证明每个 API 都适用于当前项目的 API 版本和设备；
- 不证明 5,694 页示例均在当前项目构建；
- 不证明媒体、网络、AI、应用服务或设备能力已经在真机验证；
- 不证明官网在审计时间之后没有新增、删除或移动页面；
- 不以综合章文件存在替代事实级内容复核。

## 8. 最终判定

| 审计层 | 判定 |
|---|---|
| 用户截图 21 个根目录发现完整性 | 通过 |
| 21 根目录页面计数合计 | 通过，5,694 |
| 菜单节点与页面 slug 集合 | 通过，差异 0 |
| 正文读取状态 | 通过，5,694 success，0 failed |
| 逐页结构索引 | 通过，21 根目录、5,694 条 |
| 已完成综合章映射 | 通过，21 个根目录均有负责章节 |
| 综合章缺口 | 0 |

本报告的机器结论是：**21 个根目录的数据覆盖、逐页结构索引覆盖和综合章节映射均为 100%；菜单漏点、页面漏读、索引缺失和主题综合缺口均为 0。**
