# 分卷草稿最终一致性独立审计

> 审计时间：2026-08-10T19:28:17+08:00  
> 审计范围：`drafts/*.md` 共 8 个文件  
> 审计方式：只读扫描分卷；仅新增本报告，未修改任何分卷正文  
> 覆盖快照：2026-08-10

## 结论

**0 个阻断项。**

8 个分卷在当前冻结快照下通过以下检查：

- 项目 SDK 基线与当前 `KangxiaobanAI/build-profile.json5` 一致；
- 全树菜单、正文页数、成功/失败数与覆盖台账一致；
- 没有把 `FULL_PAGE_DIGESTS.md` 误称为官网正文镜像、原文复制或“长摘要”；
- 没有过期的“采集中”“尚未全量”“后续再读”状态；
- Markdown 代码围栏全部闭合；
- 未发现 U+FFFD 或常见乱码序列；
- 26 个本地 Markdown 链接全部可解析；
- 353 次 HarmonyOS Guides 官方链接引用全部属于 `menu-inventory.csv` 的 5,694 个规范化 URL；
- 没有未解释的 TODO、TBD、FIXME 或正文占位文本。

此前的导航建议已经解决：`drafts/official-menu-panorama.md:17` 现使用两个可点击 Markdown 链接，分别正确解析到 `../FULL_PAGE_DIGESTS.md` 与 `../coverage/menu-tree.md`。

## 1. 冻结文件清单

| 分卷 | 行数 | 字节 | 围栏标记 | 唯一官方指南链接 | 本地 Markdown 链接 | SHA-256 前 12 位 |
|---|---:|---:|---:|---:|---:|---|
| `00-scope-and-mental-model.md` | 984 | 43,099 | 44 | 1 | 0 | `4958454E96E5` |
| `ai-agent-workbook.md` | 1,312 | 64,708 | 48 | 28 | 4 | `9B84C070A923` |
| `kangxiaobanai-adaptation.md` | 562 | 38,112 | 6 | 0 | 0 | `0446BB31C12E` |
| `official-application-framework.md` | 1,550 | 137,803 | 2 | 121 | 16 | `2CC2646B8A51` |
| `official-menu-panorama.md` | 385 | 21,040 | 0 | 0 | 2 | `F7CC3DB3F514` |
| `official-services-ai-distributed-native.md` | 860 | 73,391 | 10 | 48 | 4 | `54E894A27DB8` |
| `official-tools-testing-experience.md` | 759 | 34,092 | 10 | 57 | 0 | `B3D8B745DB84` |
| `system-media-graphics.md` | 1,159 | 79,618 | 0 | 50 | 0 | `B81284562F36` |
| **合计** | **7,571** | **491,863** | **120** | — | **26** | — |

“围栏标记”为开围栏与闭围栏行的合计；所有文件均为偶数且按顺序闭合。没有代码围栏的分卷不需要围栏。

## 2. 项目 SDK 与工程基线

当前配置的直接证据是：

- `KangxiaobanAI/build-profile.json5:7`：target SDK 为 `6.1.1(24)`；
- `KangxiaobanAI/build-profile.json5:8`：compatible SDK 为 `6.1.0(23)`。

分卷中的项目基线均与此一致，代表性位置：

- `drafts/00-scope-and-mental-model.md:803`
- `drafts/ai-agent-workbook.md:270`
- `drafts/kangxiaobanai-adaptation.md:63-64`
- `drafts/official-application-framework.md:22`
- `drafts/official-services-ai-distributed-native.md:775`
- `drafts/official-tools-testing-experience.md:80`
- `drafts/system-media-graphics.md:842-843`

发现根 `AGENTS.md` 存在历史漂移：`AGENTS.md:147-148` 仍写 target/compatible 均为 `6.1.1(24)`。但同一文件明确规定当前配置优先于手册文字（`AGENTS.md:71-77`），因此本次审计以当前 `build-profile.json5` 的 24/23 为准，不把分卷中的 24/23 判为错误，也不修改产品代码或根手册。

## 3. 全树数量与页面状态

机器台账复算结果：

| 指标 | 复算结果 | 证据 |
|---|---:|---|
| UI 菜单节点 | 5,720 | `coverage/README.md:5` |
| 可展开分支（不含 5 个一级 section） | 1,059 | `coverage/README.md:5` |
| 带正文菜单节点 | 5,694 | `coverage/README.md:5` |
| `page-status.csv` 行数 | 5,694 | `coverage/crawl-report.md:7` |
| 成功读取 | 5,694 | `coverage/crawl-report.md:8` |
| 非成功终态 | 0 | `coverage/crawl-report.md:9-10` |
| `FULL_PAGE_DIGESTS.md` 页面条目 | 5,694 | 按 `^#### [0-9]{4}\\. ` 复算 |

分区合计在 `drafts/official-menu-panorama.md:8-15` 为：

`45 + 4,811 + 757 + 23 + 58 = 5,694`

并与 `drafts/00-scope-and-mental-model.md:69-89` 一致。

专题统计也与 `coverage/topic-statistics.csv` 一致：

- 应用框架：15 个直接子类、1,090 页，见 `drafts/official-application-framework.md:5`、`drafts/official-menu-panorama.md:48-68`；
- 系统、媒体、图形、ArkWeb、窗口、屏幕、IME：1,823 页，见 `drafts/system-media-graphics.md:19-32`；
- 应用服务、AI、多端迁移页、自由流转迁移页、NDK：2,040 页，见 `drafts/official-services-ai-distributed-native.md:21-32`；
- 工具、测试、体验建议：838 页，见 `drafts/official-tools-testing-experience.md:5-17`。

覆盖数据库自身的 SQLite、菜单、页面、哈希、软错误和二次目录检查均通过，见 `coverage/audit-report.md:5-21`。

## 4. FULL_PAGE_DIGESTS 定义检查

`FULL_PAGE_DIGESTS.md:1-5` 将文件定义为 5,694 页逐页结构索引，并明确：

> 它只保留菜单路径、官方 URL、内容结构、章节线索与哈希，不复制正文或完整示例。

分卷中未出现“正文镜像”“原文复制”“长摘要”等错误定义。代表性正确表述：

- `drafts/official-application-framework.md:13-20`：称为“逐页结构索引”，并说明不复制约 670 万字符正文；
- `drafts/official-application-framework.md:1513-1523`：说明索引用于定位，不能替代完整官方正文；
- `drafts/official-tools-testing-experience.md:5-6`：说明不复制官网正文，也不以单个摘要替代 838 页记录；
- `drafts/00-scope-and-mental-model.md:984`：把结论限定为快照读取、结构化记录和完整性审计。

## 5. 状态词、占位文本与编码

未发现过期状态：

- `采集中`
- `尚未全量`
- `后续再读`

两处关键词命中经人工复核后均不是遗留占位：

- `drafts/00-scope-and-mental-model.md:321-329` 是明确标注的“示例格式”，其中 `<待链接到对应 V2 页面>` 用来演示 AI 不得伪造来源；
- `drafts/ai-agent-workbook.md:1116` 是禁止把 TODO 描述为 Implemented 的规则。

未发现 U+FFFD、`锟斤拷`、`ï¿½` 等乱码标记。

## 6. 链接检查

### 6.1 本地 Markdown 链接

按每个 Markdown 文件所在目录解析相对路径，共检查 26 个本地 Markdown 链接，失效数为 0。`drafts/official-menu-panorama.md:17` 新增的两个链接均解析成功。

### 6.2 HarmonyOS Guides 官方链接

从 8 个分卷提取到 353 次
`https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/<slug>`
引用；统一移除末尾斜杠后，全部存在于 `coverage/menu-inventory.csv` 的 5,694 个官方 URL 集合中，越界数为 0。

Best Practices、API Reference 等其他官方域名链接不属于此项菜单 URL 等值检查，但没有被错误计入 HarmonyOS Guides 菜单覆盖率。

## 7. 最终判定

- 阻断项：**0**
- 非阻断导航建议：**0**
- 草稿被本审计修改：**0**
- 可以进入最终组装与主文档验证：**是**

最终组装后仍应重新检查主 `README.md`、目录链接、标题锚点、总体统计、代码围栏和最终文件哈希；本报告只证明当前 8 个冻结分卷之间及其与覆盖台账之间的一致性。
