# -*- coding: utf-8 -*-
"""扫描 GitLab.com 上养老相关公开仓库（匿名 API）"""
import json, time, urllib.request, urllib.parse, os

BASE = os.path.dirname(os.path.abspath(__file__))
HEAD = {'User-Agent': 'elderly-care-scan', 'Accept': 'application/json'}

QUERIES = [
    'elderly care', 'eldercare', 'nursing home', 'senior care', 'aged care',
    'elderly', 'elderly monitoring', 'assisted living', 'caregiver',
    'geriatric', 'senior citizen', 'fall detection', 'ambient assisted living',
    '养老', '智慧养老', '养老院',
]


def search(q, pages=2):
    out = []
    for p in range(1, pages + 1):
        params = {'search': q, 'per_page': 100, 'page': p, 'order_by': 'star_count',
                  'sort': 'desc', 'archived': 'false'}
        url = 'https://gitlab.com/api/v4/projects?' + urllib.parse.urlencode(params)
        req = urllib.request.Request(url, headers=HEAD)
        data = None
        for _ in range(3):
            try:
                with urllib.request.urlopen(req, timeout=45) as r:
                    data = json.load(r)
                break
            except Exception as e:
                print('  ERR %s p%d: %s' % (q, p, e), flush=True)
                time.sleep(6)
        if not data:
            break
        out.extend(data)
        print('  [%s] p%d +%d' % (q, p, len(data)), flush=True)
        if len(data) < 100:
            break
        time.sleep(2)
    time.sleep(1.5)
    return out


def main():
    store = {}
    for i, q in enumerate(QUERIES, 1):
        print('(%d/%d) %s' % (i, len(QUERIES), q), flush=True)
        for it in search(q):
            fn = it.get('path_with_namespace')
            if not fn:
                continue
            if fn not in store:
                store[fn] = {
                    'full_name': fn,
                    'html_url': it.get('web_url', ''),
                    'clone_url': it.get('http_url_to_repo', ''),
                    'description': (it.get('description') or '').replace('\n', ' ')[:400],
                    'language': '',
                    'stars': it.get('star_count', 0),
                    'forks': it.get('forks_count', 0),
                    'size_kb': 0,
                    'updated_at': it.get('last_activity_at', ''),
                    'created_at': it.get('created_at', ''),
                    'topics': it.get('topics', []) or it.get('tag_list', []),
                    'fork': bool(it.get('forked_from_project')),
                    'archived': it.get('archived', False),
                    'license': '',
                    'owner': (it.get('namespace') or {}).get('path', ''),
                    'default_branch': it.get('default_branch', '') or 'main',
                    'platform': 'gitlab',
                    'hits': [],
                }
            store[fn]['hits'].append(q)
    out = os.path.join(BASE, 'raw_gitlab.json')
    with open(out, 'w', encoding='utf-8') as f:
        json.dump(store, f, ensure_ascii=False, indent=1)
    print('SAVED %d unique gitlab repos' % len(store))


if __name__ == '__main__':
    main()
