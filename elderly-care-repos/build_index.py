# -*- coding: utf-8 -*-
"""合并 GitHub / GitLab / Gitee 候选，按相关度打分筛出 Top100，输出清单"""
import json, os, re, csv

BASE = os.path.dirname(os.path.abspath(__file__))

# 强相关信号（必须命中至少一个）
STRONG = [
    # 中文
    '养老', '敬老', '老年', '老人', '长者', '护理院', '疗养', '康养', '适老',
    '独居老人', '空巢', '高龄', '银龄', '颐养',
    # 英文
    'elderly', 'elder care', 'eldercare', 'elder-care', 'elder_care',
    'senior care', 'senior-care', 'seniorcare', 'aged care', 'aged-care',
    'agedcare', 'nursing home', 'nursing-home', 'nursinghome',
    'care home', 'care-home', 'carehome', 'geriatric', 'gerontolog',
    'old age home', 'oldage', 'old-people', 'oldpeople', 'old_people',
    'aging in place', 'ageing in place', 'aged-stage', 'yanglao',
    'elder', 'senior citizen', 'senior-citizen', 'seniorliving',
    'senior living', 'senior-living', 'assisted living', 'assisted-living',
    'longterm care', 'long-term care', 'long term care', 'ltc-',
    'jinglaoyuan', 'laoren', 'kangyang',
]
# 场景加权
BONUS = {
    'nursing': 3, 'care': 2, 'health': 3, 'monitor': 3, 'fall': 3,
    'management': 3, '管理系统': 6, '管理平台': 5, '服务平台': 5, '监护': 5,
    '照护': 5, '护理': 4, '跌倒': 5, '健康': 3, '智慧': 4, '智能': 3,
    'smart': 3, 'iot': 3, 'robot': 2, 'chat': 1, 'assistant': 2,
    'caregiver': 4, 'dementia': 4, 'alzheimer': 4, 'medication': 2,
    'wearable': 2, 'telehealth': 3, 'telecare': 4, 'aal': 2,
    '养老院': 8, '疗养院': 7, '敬老院': 8, '居家养老': 7, '社区养老': 7,
    '智慧养老': 8, '智能养老': 8, '医养': 6, '陪伴': 3, '看护': 4,
}
# 噪音排除（命中即淘汰，除非同时命中中文养老词）
NOISE = [
    'awesome-', 'dotfiles', 'homework-only', 'leetcode', 'blog-theme',
    'senior-design-template', 'my-portfolio', 'resume',
]
# 明确无关：仅因 "elder" 出现在人名/游戏名
BAD_NAME = ['elderscroll', 'elder-scroll', 'elderscrolls', 'skyrim', 'eldenring',
            'elden-ring', 'eldenring', 'elderjs', 'elder.js', 'elderberry']


def norm(s):
    return (s or '').lower()


def score(r):
    name = norm(r['full_name'])
    desc = norm(r.get('description'))
    topics = ' '.join(r.get('topics') or []).lower()
    cn = (r['full_name'] + ' ' + (r.get('description') or '') + ' ' +
          ' '.join(r.get('hits') or []))
    blob = name + ' ' + desc + ' ' + topics + ' ' + cn.lower()

    for b in BAD_NAME:
        if b in name.replace('_', '').replace(' ', ''):
            return -1
    hit_strong = [k for k in STRONG if k in blob]
    if not hit_strong:
        return -1
    s = 10 * min(len(hit_strong), 4)
    # 名称直接命中权重更高
    for k in STRONG:
        if k in name:
            s += 12
            break
    for k, v in BONUS.items():
        if k in blob:
            s += v
    st = r.get('stars', 0) or 0
    s += min(st, 200) * 0.15
    if (r.get('size_kb') or 0) > 200:
        s += 4
    if (r.get('size_kb') or 0) > 2000:
        s += 3
    if r.get('fork'):
        s -= 8
    if r.get('archived'):
        s -= 3
    if not desc:
        s -= 4
    up = r.get('updated_at') or ''
    if up >= '2025':
        s += 6
    elif up >= '2023':
        s += 3
    elif up < '2019':
        s -= 4
    for n in NOISE:
        if n in name:
            s -= 15
    return s


def load(path, platform):
    p = os.path.join(BASE, path)
    if not os.path.exists(p):
        print('missing', path)
        return []
    data = json.load(open(p, encoding='utf-8'))
    out = []
    if isinstance(data, dict):
        vals = list(data.values())
    else:
        vals = data
    for v in vals:
        v.setdefault('platform', platform)
        v.setdefault('topics', [])
        v.setdefault('hits', [])
        v.setdefault('stars', 0)
        v.setdefault('size_kb', 0)
        out.append(v)
    return out


CAT_RULES = [
    ('AI 视觉监护/跌倒检测', ['fall', '跌倒', 'pose', 'yolo', 'vision', '姿态', '摄像']),
    ('AI 陪伴/对话', ['chat', 'llm', 'gpt', 'companion', '陪伴', '数字人', 'voice', '语音', 'agent', 'rag']),
    ('养老院/机构管理系统', ['养老院', '敬老院', '疗养', 'nursing home', 'nursing-home', 'care home',
                     '管理系统', 'management system', '机构', '驿站', '照护管理', 'admin']),
    ('居家/社区养老平台', ['居家养老', '社区养老', 'home care', 'homecare', '社区', '助餐', '上门']),
    ('健康监护/体征监测', ['health', 'monitor', '监护', '监测', '体征', 'vital', 'wearable', 'ecg', 'blood']),
    ('IoT/硬件/嵌入式', ['stm32', 'esp32', 'arduino', 'raspberry', 'iot', '嵌入式', '单片机', 'sensor', 'mqtt']),
    ('移动端/小程序/适老化前端', ['app', 'android', 'ios', 'flutter', 'uni-app', 'uniapp', '小程序',
                       'miniprogram', 'vue', 'react', '前端', '适老']),
    ('数据分析/研究/数据集', ['dataset', 'research', 'analysis', 'predict', 'ml', 'paper', '分析', '预测', '论文']),
    ('机器人/服务机器人', ['robot', 'ros', '机器人']),
]


def categorize(r):
    blob = (r['full_name'] + ' ' + (r.get('description') or '') + ' ' +
            ' '.join(r.get('topics') or []) + ' ' + ' '.join(r.get('hits') or [])).lower()
    if r.get('cat'):
        return r['cat']
    for cat, kws in CAT_RULES:
        for k in kws:
            if k in blob:
                return cat
    return '其他养老相关'


def main():
    gh = load('raw_github.json', 'github')
    gl = load('raw_gitlab.json', 'gitlab')
    print('github candidates: %d, gitlab: %d' % (len(gh), len(gl)))

    # Gitee 种子（人工核验，直接入选）
    gitee = []
    gp = os.path.join(BASE, 'gitee_seed.json')
    if os.path.exists(gp):
        for it in json.load(open(gp, encoding='utf-8')):
            gitee.append({
                'full_name': it['full_name'],
                'html_url': 'https://gitee.com/' + it['full_name'],
                'clone_url': 'https://gitee.com/' + it['full_name'] + '.git',
                'description': it.get('name_cn', '') + ' — ' + it.get('desc', ''),
                'language': it.get('stack', ''), 'stars': 0, 'forks': 0, 'size_kb': 0,
                'updated_at': '', 'created_at': '', 'topics': [], 'fork': False,
                'archived': False, 'license': '', 'owner': it['full_name'].split('/')[0],
                'default_branch': '', 'platform': 'gitee', 'hits': ['gitee-curated'],
                'cat': it.get('cat', ''), 'name_cn': it.get('name_cn', ''),
                'stack': it.get('stack', ''), 'score': 999,
            })

    scored = []
    for r in gh + gl:
        s = score(r)
        if s < 0:
            continue
        r['score'] = round(s, 1)
        scored.append(r)
    scored.sort(key=lambda x: -x['score'])
    print('scored & kept: %d' % len(scored))

    need = 100 - len(gitee)
    final = gitee + scored[:need]
    for r in final:
        r['cat'] = categorize(r)

    json.dump(final, open(os.path.join(BASE, 'selected_100.json'), 'w', encoding='utf-8'),
              ensure_ascii=False, indent=1)
    # 备用池（clone 失败时替补）
    json.dump(scored[need:need + 80], open(os.path.join(BASE, 'backup_pool.json'), 'w', encoding='utf-8'),
              ensure_ascii=False, indent=1)
    print('FINAL %d (gitee %d + others %d)' % (len(final), len(gitee), len(final) - len(gitee)))
    from collections import Counter
    print(Counter([r['platform'] for r in final]))
    print(Counter([r['cat'] for r in final]))


if __name__ == '__main__':
    main()
