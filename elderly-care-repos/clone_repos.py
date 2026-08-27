# -*- coding: utf-8 -*-
"""并发克隆 selected_100.json 中的 100 个仓库到 repos/。
- 目标目录 owner__repo（Windows 安全命名）
- 失败回退：用 backup_pool.json 中的干净候补补足到 100
- 记录 clone_log.csv / clone_log.txt，结束汇报成功率与磁盘占用
"""
import json, os, re, subprocess, shutil, csv, time
from concurrent.futures import ThreadPoolExecutor, as_completed

BASE = os.path.dirname(os.path.abspath(__file__))
REPOS = os.path.join(BASE, 'repos')
os.makedirs(REPOS, exist_ok=True)

GIT = shutil.which('git') or 'git'


def safe_dir(full_name):
    owner, _, repo = full_name.partition('/')
    repo = re.sub(r'[<>:"/\\|?*\s]+', '_', repo).strip('._')
    owner = re.sub(r'[<>:"/\\|?*\s]+', '_', owner).strip('._')
    return f"{owner}__{repo}"


sel = json.load(open(os.path.join(BASE, 'selected_100.json'), encoding='utf-8'))
backup = json.load(open(os.path.join(BASE, 'backup_pool.json'), encoding='utf-8'))


def clone_one(rec):
    d = safe_dir(rec['full_name'])
    target = os.path.join(REPOS, d)
    if os.path.exists(target) and os.path.isdir(os.path.join(target, '.git')):
        return rec['full_name'], d, 'skip', 'already cloned'
    try:
        p = subprocess.run(
            [GIT, 'clone', '--depth', '1', '--single-branch',
             rec['clone_url'], target],
            capture_output=True, text=True, timeout=240)
        if p.returncode == 0:
            return rec['full_name'], d, 'ok', (p.stderr or p.stdout).strip()[:200]
        return rec['full_name'], d, 'fail', (p.stderr or p.stdout).strip()[:300]
    except subprocess.TimeoutExpired:
        shutil.rmtree(target, ignore_errors=True)
        return rec['full_name'], d, 'fail', 'timeout'
    except Exception as e:
        shutil.rmtree(target, ignore_errors=True)
        return rec['full_name'], d, 'fail', str(e)[:300]


def dir_size(path):
    tot = 0
    for root, _, files in os.walk(path):
        for f in files:
            try:
                tot += os.path.getsize(os.path.join(root, f))
            except OSError:
                pass
    return tot


# 主循环：先克隆 selected，失败用 backup 补
plan = list(sel)
results = {}
failed_pool = []  # 失败记录，用于回退

print(f'开始克隆 {len(plan)} 个主选仓库 …', flush=True)
with ThreadPoolExecutor(max_workers=6) as ex:
    futs = {ex.submit(clone_one, r): r for r in plan}
    done = 0
    for fut in as_completed(futs):
        fn, d, status, msg = fut.result()
        done += 1
        results[fn] = (d, status, msg)
        if status != 'ok' and status != 'skip':
            failed_pool.append(futs[fut])
        print(f'[{done}/{len(plan)}] {status:4s} {fn}', flush=True)

# 统计主选成功数
ok_main = [fn for fn, v in results.items() if v[1] in ('ok', 'skip')]
need = 100 - len(ok_main)
print(f'主选成功 {len(ok_main)}，需从备用池补 {need}', flush=True)

# 回退补位
used = set(results.keys())
bi = 0
while need > 0 and bi < len(backup):
    rec = backup[bi]; bi += 1
    if rec['full_name'] in used:
        continue
    fn, d, status, msg = clone_one(rec)
    print(f'[backup] {status:4s} {fn}', flush=True)
    if status in ('ok', 'skip'):
        results[fn] = (d, status, msg)
        used.add(fn)
        need -= 1
    else:
        # 备份也失败，继续下一个
        continue

# 汇总日志
log_csv = os.path.join(BASE, 'clone_log.csv')
with open(log_csv, 'w', encoding='utf-8-sig', newline='') as f:
    w = csv.writer(f)
    w.writerow(['仓库名', '本地目录', '状态', '说明'])
    for fn, (d, st, msg) in results.items():
        w.writerow([fn, d, st, msg])

ok = sum(1 for v in results.values() if v[1] in ('ok', 'skip'))
fail = sum(1 for v in results.values() if v[1] == 'fail')
total = sum(dir_size(os.path.join(REPOS, d)) for d in set(v[0] for v in results.values()))
print('\n===== 克隆完成 =====', flush=True)
print(f'成功（含已存在）: {ok}', flush=True)
print(f'失败: {fail}', flush=True)
print(f'repos/ 总占用: {total/1024/1024:.1f} MB', flush=True)
print(f'日志: {log_csv}', flush=True)
