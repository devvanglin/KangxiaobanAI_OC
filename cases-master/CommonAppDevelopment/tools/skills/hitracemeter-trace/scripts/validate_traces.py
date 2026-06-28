#!/usr/bin/env python3
"""
validate_traces.py — Validate HiTraceMeter trace start/finish pairing in ArkTS files.

Checks for:
  - Mismatched startSyncTrace / finishSyncTrace pairs
  - Mismatched startAsyncTrace / finishAsyncTrace pairs
  - Unmatched starts (no corresponding finish)
  - Unmatched finishes (no corresponding start)
  - Level mismatch between paired start/finish

Usage:
    python3 validate_traces.py path/to/Page.ets
    python3 validate_traces.py --dir path/to/project
    cat files.txt | python3 validate_traces.py --stdin
"""

import re
import sys
import argparse
from pathlib import Path
from collections import defaultdict


SYNC_START_RE = re.compile(
    r'hiTraceMeter\.startSyncTrace\s*\(\s*(\w+(?:\.\w+)*)\s*,\s*[\'"]([^\'"]+)[\'"]'
)
SYNC_FINISH_RE = re.compile(
    r'hiTraceMeter\.finishSyncTrace\s*\(\s*(\w+(?:\.\w+)*)\s*\)'
)
ASYNC_START_RE = re.compile(
    r'hiTraceMeter\.startAsyncTrace\s*\(\s*(\w+(?:\.\w+)*)\s*,\s*[\'"]([^\'"]+)[\'"]\s*,\s*(\d+)'
)
ASYNC_FINISH_RE = re.compile(
    r'hiTraceMeter\.finishAsyncTrace\s*\(\s*(\w+(?:\.\w+)*)\s*,\s*[\'"]([^\'"]+)[\'"]\s*,\s*(\d+)'
)


def find_trace_calls(filepath: str) -> list[dict]:
    """Extract all HiTraceMeter calls with line numbers."""
    calls = []
    with open(filepath, 'r', encoding='utf-8') as f:
        lines = f.readlines()

    for lineno, line in enumerate(lines, start=1):
        # Sync start
        m = SYNC_START_RE.search(line)
        if m:
            calls.append({
                'line': lineno,
                'type': 'sync-start',
                'level': m.group(1),
                'name': m.group(2),
                'text': line.strip()
            })

        # Sync finish
        m = SYNC_FINISH_RE.search(line)
        if m:
            calls.append({
                'line': lineno,
                'type': 'sync-finish',
                'level': m.group(1),
                'text': line.strip()
            })

        # Async start
        m = ASYNC_START_RE.search(line)
        if m:
            calls.append({
                'line': lineno,
                'type': 'async-start',
                'level': m.group(1),
                'name': m.group(2),
                'task_id': int(m.group(3)),
                'text': line.strip()
            })

        # Async finish
        m = ASYNC_FINISH_RE.search(line)
        if m:
            calls.append({
                'line': lineno,
                'type': 'async-finish',
                'level': m.group(1),
                'name': m.group(2),
                'task_id': int(m.group(3)),
                'text': line.strip()
            })

    return calls


def validate_file(filepath: str) -> list[str]:
    """Validate trace pairing in a file, returning list of issues."""
    issues = []
    calls = find_trace_calls(filepath)

    if not calls:
        return []

    # Sync trace validation (stack-based)
    sync_stack = []  # list of (level, name, lineno)
    for c in calls:
        if c['type'] == 'sync-start':
            sync_stack.append((c['level'], c['name'], c['line']))
        elif c['type'] == 'sync-finish':
            if not sync_stack:
                issues.append(f"  L{c['line']}: ❌ Unmatched finishSyncTrace (no startSyncTrace). "
                              f"Level: {c['level']}")
            else:
                start = sync_stack.pop()
                if c['level'] != start[0]:
                    issues.append(f"  L{start[2]}-L{c['line']}: ⚠️ Level mismatch — "
                                  f"start uses '{start[0]}', finish uses '{c['level']}'")
                    issues.append(f"       Start: L{start[2]} | Finish: L{c['line']}")

    for start_level, start_name, start_lineno in sync_stack:
        issues.append(f"  L{start_lineno}: ❌ Unmatched startSyncTrace '{start_name}' "
                      f"(level: {start_level}) — missing finishSyncTrace")

    # Async trace validation (build map by (name, task_id))
    async_starts = defaultdict(list)
    async_finishes = defaultdict(list)

    for c in calls:
        if c['type'] == 'async-start':
            key = (c['name'], c['task_id'])
            async_starts[key].append(c)
        elif c['type'] == 'async-finish':
            key = (c['name'], c['task_id'])
            async_finishes[key].append(c)

    all_keys = set(list(async_starts.keys()) + list(async_finishes.keys()))

    for key in sorted(all_keys):
        name, task_id = key
        starts = async_starts.get(key, [])
        finishes = async_finishes.get(key, [])

        count_diff = len(starts) - len(finishes)
        if count_diff > 0:
            start_lines = ', '.join(f"L{s['line']}" for s in starts)
            issues.append(f"  {start_lines}: ❌ Async trace '{name}' (taskId={task_id}): "
                          f"{count_diff} more start than finish")
        elif count_diff < 0:
            finish_lines = ', '.join(f"L{f['line']}" for f in finishes)
            issues.append(f"  {finish_lines}: ❌ Async trace '{name}' (taskId={task_id}): "
                          f"{-count_diff} more finish than start")

        # Check level consistency
        if starts and finishes:
            start_levels = set(s['level'] for s in starts)
            finish_levels = set(f['level'] for f in finishes)
            if len(start_levels) > 1 or len(finish_levels) > 1 or start_levels != finish_levels:
                issues.append(f"  ❌ Async trace '{name}' (taskId={task_id}): "
                              f"level mismatch — start levels: {start_levels}, "
                              f"finish levels: {finish_levels}")

    return issues


def main():
    parser = argparse.ArgumentParser(
        description='Validate HiTraceMeter trace start/finish pairing in ArkTS files.'
    )
    parser.add_argument('files', nargs='*', help='One or more .ets files to validate')
    parser.add_argument('--dir', type=str, help='Recursively validate all .ets files in a directory')
    parser.add_argument('--stdin', action='store_true', help='Read file paths from stdin')
    parser.add_argument('--quiet', '-q', action='store_true', help='Only show files with issues')
    args = parser.parse_args()

    files_to_check: list[str] = []

    if args.stdin:
        for line in sys.stdin:
            line = line.strip()
            if line and line.endswith('.ets'):
                files_to_check.append(line)
    elif args.dir:
        p = Path(args.dir)
        if p.is_dir():
            files_to_check = [str(f.resolve()) for f in sorted(p.rglob('*.ets'))]
    elif args.files:
        for f in args.files:
            p = Path(f)
            if p.is_file() and p.suffix == '.ets':
                files_to_check.append(str(p.resolve()))
            elif p.is_dir():
                files_to_check.extend(str(f.resolve()) for f in sorted(p.rglob('*.ets')))
    else:
        parser.print_help()
        sys.exit(1)

    if not files_to_check:
        print('No .ets files found.')
        sys.exit(0)

    total_issues = 0
    total_files_with_traces = 0
    total_files_with_issues = 0

    for fpath in files_to_check:
        issues = validate_file(fpath)
        if not issues:
            calls = find_trace_calls(fpath)
            if calls and not args.quiet:
                print(f'  ✓ {fpath} — {len(calls)} trace calls, all valid')
            if calls:
                total_files_with_traces += 1
            continue

        total_files_with_issues += 1
        total_files_with_traces += 1
        calls = find_trace_calls(fpath)
        print(f'\n📄 {fpath} ({len(calls)} trace calls)')
        for issue in issues:
            print(issue)
            total_issues += 1

    print(f'\nSummary: {total_files_with_issues}/{total_files_with_traces} files with issues, '
          f'{total_issues} issues found.')
    if total_issues == 0:
        print('✅ All trace calls are properly paired!')
        sys.exit(0)
    else:
        sys.exit(1)


if __name__ == '__main__':
    main()
