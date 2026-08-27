# -*- coding: utf-8 -*-
"""根据 selected_100.json 生成带分类标注的清单：INDEX.md / repos.csv / clone_list.txt"""
import json, os, csv, re
from collections import OrderedDict, Counter

BASE = os.path.dirname(os.path.abspath(__file__))
sel = json.load(open(os.path.join(BASE, 'selected_100.json'), encoding='utf-8'))

PLATFORM_CN = {'github': 'GitHub', 'gitee': 'Gitee', 'gitlab': 'GitLab'}


def safe_dir(full_name):
    """owner__repo，过滤 Windows 非法字符，避免大小写冲突。"""
    owner, _, repo = full_name.partition('/')
    repo = re.sub(r'[<>:"/\\|?*\s]+', '_', repo).strip('._')
    owner = re.sub(r'[<>:"/\\|?*\s]+', '_', owner).strip('._')
    return f"{owner}__{repo}"


# 校验目标目录无冲突
dirs = [safe_dir(r['full_name']) for r in sel]
dup = [d for d in set(dirs) if dirs.count(d) > 1]
assert not dup, f"发现重复目标目录: {dup}"

# ---- repos.csv ----
csv_path = os.path.join(BASE, 'repos.csv')
with open(csv_path, 'w', encoding='utf-8-sig', newline='') as f:
    w = csv.writer(f)
    w.writerow(['序号', '仓库名', '平台', '分类', 'Stars', '主语言',
                '克隆地址', '主页', '本地目录', '简介'])
    for i, r in enumerate(sel, 1):
        w.writerow([i, r['full_name'], PLATFORM_CN.get(r['platform'], r['platform']),
                    r['cat'], r.get('stars', 0), r.get('language', ''),
                    r.get('clone_url', ''), r.get('html_url', ''),
                    safe_dir(r['full_name']),
                    (r.get('description') or '').replace('\n', ' ')])
print('wrote', csv_path)

# ---- clone_list.txt ----
cl_path = os.path.join(BASE, 'clone_list.txt')
with open(cl_path, 'w', encoding='utf-8') as f:
    f.write('# 克隆命令清单（每条可单独执行）\n')
    f.write('# 用法：在 elderly-care-repos/ 目录下，git clone --depth 1 <url> repos/<本地目录>\n\n')
    for r in sel:
        d = safe_dir(r['full_name'])
        f.write(f"git clone --depth 1 --single-branch {r['clone_url']} repos/{d}\n")
print('wrote', cl_path)

# ---- INDEX.md ----
md = []
md.append('# 智能养老 / 养老院开源项目清单（100 个）\n')
md.append('> 来源：GitHub、Gitee（全网扫描 + 人工核验）。')
md.append('> 筛选：要求仓库名称或 Topics 含养老/老年/护理/康养等强相关词，并剔除政治宣传、游戏、招生薪酬等无关仓库。')
md.append('> 生成时间：2026-08-20\n')
md.append(f'**总计：{len(sel)} 个**（GitHub {sum(1 for r in sel if r["platform"]=="github")} '
          f'+ Gitee {sum(1 for r in sel if r["platform"]=="gitee")}）\n')

cat_counter = Counter(r['cat'] for r in sel)
md.append('## 分类统计\n')
md.append('| 分类 | 数量 |')
md.append('| --- | ---: |')
for cat, n in cat_counter.most_common():
    md.append(f'| {cat} | {n} |')
md.append('')

# 按分类分组展示
groups = OrderedDict()
for r in sel:
    groups.setdefault(r['cat'], []).append(r)

idx = 0
for cat, items in groups.items():
    md.append(f'## {cat}（{len(items)}）\n')
    for r in items:
        idx += 1
        lang = r.get('language') or '-'
        stars = r.get('stars', 0)
        pf = PLATFORM_CN.get(r['platform'], r['platform'])
        desc = (r.get('description') or '').replace('\n', ' ').strip()
        md.append(f'{idx}. **[{r["full_name"]}]({r.get("html_url","")})** '
                  f'`{pf}` · ⭐{stars} · {lang}\n'
                  f'   - 分类：{r["cat"]} ｜ 本地目录：`repos/{safe_dir(r["full_name"])}`\n'
                  f'   - 简介：{desc}\n')
md.append('\n---\n')
md.append('*本清单由脚本自动生成，clone 命令见 `clone_list.txt`，结构化数据见 `repos.csv`。*')

md_path = os.path.join(BASE, 'INDEX.md')
open(md_path, 'w', encoding='utf-8').write('\n'.join(md))
print('wrote', md_path)
print('categories:', dict(cat_counter))
