# -*- coding: utf-8 -*-
"""扫描 GitHub 上养老/智能养老相关仓库"""
import json, time, urllib.request, urllib.parse, os, sys

BASE = os.path.dirname(os.path.abspath(__file__))
TOKEN = open(os.path.join(BASE, '.ghtoken'), encoding='utf-8').read().strip()
HEAD = {
    'Authorization': 'Bearer ' + TOKEN,
    'Accept': 'application/vnd.github+json',
    'User-Agent': 'elderly-care-scan',
}

QUERIES = [
    # 中文核心
    '智能养老', '智慧养老', '养老院', '养老管理系统', '养老服务', '养老系统',
    '居家养老', '社区养老', '养老平台', '敬老院', '护理院', '康养',
    '智慧康养', '医养结合', '养老机构', '老年公寓', '适老化', '养老小程序',
    '老年人健康', '老人看护', '养老护理', '长者服务', '养老信息化', '智慧照护',
    '老人跌倒检测', '独居老人', '养老大数据',
    # 英文核心
    'elderly care', 'eldercare', 'nursing home', 'senior care', 'aged care',
    'elderly care system', 'nursing home management', 'elderly monitoring',
    'smart elderly', 'smart eldercare', 'care home management',
    'long-term care', 'assisted living', 'elderly health monitoring',
    'fall detection elderly', 'senior living', 'elderly companion robot',
    'old age home', 'elderly management system', 'caregiver app',
    'aging in place', 'elderly iot', 'geriatric care', 'elderly assistant',
    'senior citizen management', 'elderly smart home',
    # topic 定向
    'topic:elderly-care', 'topic:eldercare', 'topic:nursing-home',
    'topic:elderly', 'topic:aged-care', 'topic:senior-care',
    'topic:elderly-people', 'topic:elderlycare', 'topic:yanglao',
    'topic:smart-elderly-care', 'topic:fall-detection',
]


def search(q, pages=2):
    out = []
    for p in range(1, pages + 1):
        params = {'q': q, 'per_page': 100, 'page': p}
        url = 'https://api.github.com/search/repositories?' + urllib.parse.urlencode(params)
        req = urllib.request.Request(url, headers=HEAD)
        for attempt in range(3):
            try:
                with urllib.request.urlopen(req, timeout=45) as r:
                    data = json.load(r)
                break
            except Exception as e:
                print('  ERR %s p%d: %s' % (q, p, e), flush=True)
                time.sleep(8)
                data = None
        if not data:
            break
        items = data.get('items', [])
        out.extend(items)
        print('  [%s] p%d +%d / total %s' % (q, p, len(items), data.get('total_count')), flush=True)
        if len(items) < 100:
            break
        time.sleep(2.5)
    time.sleep(2.5)
    return out


def main():
    store = {}
    for i, q in enumerate(QUERIES, 1):
        print('(%d/%d) %s' % (i, len(QUERIES), q), flush=True)
        for it in search(q):
            fn = it['full_name']
            if fn not in store:
                store[fn] = {
                    'full_name': fn,
                    'html_url': it['html_url'],
                    'clone_url': it['clone_url'],
                    'description': it.get('description') or '',
                    'language': it.get('language') or '',
                    'stars': it.get('stargazers_count', 0),
                    'forks': it.get('forks_count', 0),
                    'size_kb': it.get('size', 0),
                    'updated_at': it.get('updated_at', ''),
                    'created_at': it.get('created_at', ''),
                    'topics': it.get('topics', []),
                    'fork': it.get('fork', False),
                    'archived': it.get('archived', False),
                    'license': (it.get('license') or {}).get('spdx_id') if it.get('license') else '',
                    'owner': it['owner']['login'],
                    'default_branch': it.get('default_branch', ''),
                    'hits': [],
                }
            store[fn]['hits'].append(q)
    out = os.path.join(BASE, 'raw_github.json')
    with open(out, 'w', encoding='utf-8') as f:
        json.dump(store, f, ensure_ascii=False, indent=1)
    print('SAVED %d unique repos -> %s' % (len(store), out))


if __name__ == '__main__':
    main()
