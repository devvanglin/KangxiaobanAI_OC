# 全量采集完整性审计

> 审计时间：2026-08-10T19:27:02+08:00

结论：**全部关键检查通过**。

## 关键检查

| 检查项 | 结果 |
|---|---|
| sqlite_integrity | 通过 |
| saved_menu_node_count | 通过 |
| saved_menu_document_count | 通过 |
| database_menu_matches_saved | 通过 |
| page_row_count | 通过 |
| success_count | 通过 |
| failed_count_zero | 通过 |
| menu_page_slug_sets_equal | 通过 |
| menu_page_urls_equal | 通过 |
| blob_integrity | 通过 |
| soft_error_pages_zero | 通过 |
| second_catalog_identical | 通过 |
| current_catalog_baseline | 通过 |

## 内容统计

- 正文页面：5694
- 正文字符：19621279
- HTML 字符：50846355
- 代码块：20996
- 表格：5018
- 提示/警告块：3325
- 图片：11339
- 最短/最长/平均正文字符：7 / 79672 / 3445.96

## 官网标题编码异常

这些页面保留官网原始标题字段，但人类文档和 AI 索引优先使用正常的菜单标题。

- 无

## 说明

同一内容哈希可能来自官方重复说明或占位页，不据此删除菜单项；每个菜单节点仍保留独立审计记录。
