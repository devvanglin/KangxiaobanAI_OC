# -*- coding: utf-8 -*-
"""二次净化：用「名称/Topics 含养老相关词」作为相关性闸门，并黑名单清除政治/招生/游戏等噪声，
从 GitHub+GitLab 全量池中重新筛出干净 Top(N)，与 Gitee 38 个已核验项目合并成最终 100。
"""
import json, os, re
from collections import Counter

BASE = os.path.dirname(os.path.abspath(__file__))

# 强相关信号（必须命中至少一个）
STRONG = [
    '养老', '敬老', '老年', '老人', '长者', '护理院', '疗养', '康养', '适老',
    '独居老人', '空巢', '高龄', '银龄', '颐养',
    'elderly', 'elder care', 'eldercare', 'elder-care', 'elder_care',
    'senior care', 'senior-care', 'seniorcare', 'aged care', 'aged-care',
    'agedcare', 'nursing home', 'nursing-home', 'nursinghome',
    'care home', 'care-home', 'carehome', 'geriatric', 'gerontolog',
    'old age home', 'oldage', 'old-people', 'oldpeople', 'old_people',
    'aging in place', 'ageing in place', 'aged-stage', 'yanglao',
    'elder', 'senior citizen', 'senior-citizen', 'seniorliving',
    'senior living', 'senior-living', 'assisted living', 'assisted-living',
    'longterm care', 'long-term care', 'long term care', 'ltc-',
    'jinglaoyuan', 'laoren', 'kangyang', 'beadhouse', 'gerocomium',
]
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

# 明确黑名单：政治宣传 / 游戏 / 与养老无关的招生薪酬系统
BAD_OWNERS = {
    'cirosantilli', 'mrfwq7lwnpzjavv5v6eo', 'zaohmeing', 'zhaohmng-outlook-com',
    'gege-circle', 'pxvr-official', 'zpc1314521', 'dujltqzv', 'panbinibn',
    'carrotlike', 'superwaterbro', 'organizationings',
}
# 名称级噪声词（命中即淘汰，无论是否含养老词）
NAME_NOISE = [
    'dictatorship', 'dictattor', 'dictatror', 'pcl2', 'packetfix', 'packet-fix',
    'openpacket', 'some-many-books', 'launcher', 'minecraft', 'elderscroll',
    'elder-scroll', 'elderscrolls', 'skyrim', 'eldenring', 'elden-ring',
    'admission_promotion', 'salary_nursing', 'salary', 'recruit', '招生',
    'leetcode', 'resume', 'portfolio', 'dotfiles', 'awesome-',
]
BAD_NAME = ['elderscroll', 'elder-scroll', 'elderscrolls', 'skyrim', 'eldenring',
            'elden-ring', 'elderjs', 'elder.js', 'elderberry']


def norm(s):
    return (s or '').lower()


def has_strong(blob):
    return [k for k in STRONG if k in blob]


def gate_ok(r):
    """相关性闸门：名称或 topics 必须含强相关词；且不在黑名单。"""
    fn = r['full_name']
    owner = fn.split('/')[0].lower()
    if owner in BAD_OWNERS:
        return False
    if fn.lower().endswith('/.github'):
        return False
    name = norm(fn)
    name_clean = name.replace('_', '').replace('-', '').replace(' ', '')
    for b in BAD_NAME:
        if b in name_clean:
            return False
    for n in NAME_NOISE:
        if n in name:
            return False
    # 名称 / topics 含强相关词才算真正相关（规避 README 误命中）
    blob_nt = name + ' ' + ' '.join(r.get('topics') or []).lower()
    if has_strong(blob_nt):
        return True
    # 退路：名称无强词，但 topics 里有养老相关英文 topic 也放行
    tops = [t.lower() for t in (r.get('topics') or [])]
    if any(k in tops for k in ['elderly-care', 'eldercare', 'nursing-home',
                               'senior-care', 'smart-elderly', 'aged-care']):
        return True
    return False


def score(r):
    name = norm(r['full_name'])
    desc = norm(r.get('description'))
    topics = ' '.join(r.get('topics') or []).lower()
    cn = ' '.join(r.get('hits') or [])
    blob = name + ' ' + desc + ' ' + topics + ' ' + cn.lower()

    s = 0.0
    # 名称命中权重最高（最可靠）
    if has_strong(name):
        s += 22
    if has_strong(topics):
        s += 10
    if has_strong(desc):
        s += 5
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
    return round(s, 1)


def load(path, platform):
    p = os.path.join(BASE, path)
    if not os.path.exists(p):
        return []
    data = json.load(open(p, encoding='utf-8'))
    vals = list(data.values()) if isinstance(data, dict) else data
    out = []
    for v in vals:
        v.setdefault('platform', platform)
        v.setdefault('topics', [])
        v.setdefault('hits', [])
        v.setdefault('stars', 0)
        v.setdefault('size_kb', 0)
        out.append(v)
    return out


CAT_RULES = [
    ('AI 视觉监护/跌倒检测', ['fall', '跌倒', 'pose', 'yolo', 'vision', '姿态', '摄像', '行为识别']),
    ('AI 陪伴/对话', ['chat', 'llm', 'gpt', 'companion', '陪伴', '数字人', 'voice', '语音', 'agent', 'rag', '情感']),
    ('养老院/机构管理系统', ['养老院', '敬老院', '疗养', 'nursing home', 'nursing-home', 'care home',
                     '管理系统', 'management system', '机构', '驿站', '照护管理', 'admin', 'gerocomium', 'beadhouse']),
    ('居家/社区养老平台', ['居家养老', '社区养老', 'home care', 'homecare', '社区', '助餐', '上门']),
    ('健康监护/体征监测', ['health', 'monitor', '监护', '监测', '体征', 'vital', 'wearable', 'ecg', 'blood']),
    ('IoT/硬件/嵌入式', ['stm32', 'esp32', 'arduino', 'raspberry', 'iot', '嵌入式', '单片机', 'sensor', 'mqtt', 'csi']),
    ('移动端/小程序/适老化前端', ['app', 'android', 'ios', 'flutter', 'uni-app', 'uniapp', '小程序',
                       'miniprogram', 'vue', 'react', '前端', '适老']),
    ('数据分析/研究/数据集', ['dataset', 'research', 'analysis', 'predict', 'ml', 'paper', '分析', '预测', '论文', 'spark']),
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
    dropped = 0
    for r in gh + gl:
        if not gate_ok(r):
            dropped += 1
            continue
        r['score'] = score(r)
        scored.append(r)
    scored.sort(key=lambda x: -x['score'])
    print('passed gate: %d, dropped: %d' % (len(scored), dropped))

    need = 100 - len(gitee)
    final = gitee + scored[:need]
    for r in final:
        r['cat'] = categorize(r)

    # 去重保护
    seen = set()
    uniq = []
    for r in final:
        if r['full_name'] in seen:
            continue
        seen.add(r['full_name'])
        uniq.append(r)
    json.dump(uniq, open(os.path.join(BASE, 'selected_100.json'), 'w', encoding='utf-8'),
              ensure_ascii=False, indent=1)
    # 备用池（替补 + 继续筛选）
    json.dump(scored[need:need + 120], open(os.path.join(BASE, 'backup_pool.json'), 'w', encoding='utf-8'),
              ensure_ascii=False, indent=1)
    print('FINAL %d (gitee %d + others %d)' % (len(uniq), len(gitee), len(uniq) - len(gitee)))
    print('platform:', Counter([r['platform'] for r in uniq]))
    print('category:', Counter([r['cat'] for r in uniq]))


if __name__ == '__main__':
    main()
