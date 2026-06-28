#!/usr/bin/env python3
"""
remove_traces.py — Remove all HiTraceMeter trace calls from ArkTS files.

Usage:
    # Remove traces from a single file
    python3 remove_traces.py path/to/Page.ets

    # Remove traces from all .ets files in a directory (recursive)
    python3 remove_traces.py --dir path/to/project

    # Dry run (show what would be removed without modifying)
    python3 remove_traces.py --dir path/to/project --dry-run

    # Remove from specific files via stdin (one path per line)
    cat files.txt | python3 remove_traces.py --stdin
"""

import re
import sys
import os
import argparse
from pathlib import Path


def _is_trace_call(line: str) -> bool:
    """Check if a line is a hiTraceMeter call."""
    return bool(re.match(
        r'^\s*hiTraceMeter\.(?:startSyncTrace|finishSyncTrace|startAsyncTrace|finishAsyncTrace|traceByValue|isTraceEnabled)\s*\(',
        line
    ))


def _is_level_var(line: str) -> bool:
    """Check if a line declares the HiTraceOutputLevel constant."""
    return bool(re.match(
        r'^\s*(?:const|let|var)\s+\w+\s*=\s*hiTraceMeter\.HiTraceOutputLevel\.\w+',
        line
    ))


def _is_hitrace_import(line: str) -> bool:
    """Check if a line imports hiTraceMeter."""
    return bool(re.match(
        r'^\s*import\s*\{[^}]*\bhiTraceMeter\b[^}]*\}\s*from\s*[\'"]@kit\.PerformanceAnalysisKit[\'"]',
        line
    ))


def _collapsible_newlines(lines: list[str], removed_indices: set[int],
                          left: int, right: int) -> int:
    """
    Within range [left, right), check if consecutive blank lines span a
    removal boundary. If so, return the number of blank lines to keep (1).
    Returns 0 if no collapse needed.

    This only collapses blank lines that were CREATED by removals, not
    pre-existing blank lines in the file.
    """
    # Find all blank line runs in the range
    i = left
    while i < right:
        if i >= len(lines):
            break
        if lines[i].strip() != '':
            i += 1
            continue
        # Start of blank run
        start = i
        while i < right and i < len(lines) and lines[i].strip() == '':
            i += 1
        blank_count = i - start

        if blank_count >= 2:
            # Check if any of these blank lines was originally a non-blank
            # line that was removed (i.e., its index was in removed_indices)
            for j in range(start, i):
                if j in removed_indices:
                    # This blank line was a removal site, merge duplicates
                    return 1

    return 0


def _merge_blank_lines(new_lines: list[str], original_lines: list[str],
                         removed_set: set[int]) -> list[str]:
    """
    Merge consecutive blank lines that were created by removals.

    Key insight: when a non-blank trace line is removed from between two
    existing blank lines, those blanks become adjacent and create a double
    blank. This function detects that case by checking if any non-blank
    lines were removed BETWEEN the blank lines in the original.

    Preserves all pre-existing blank lines in the file.
    """
    # Map each position in new_lines back to its original index
    orig_idx_of_new = [
        j for j in range(len(original_lines))
        if j not in removed_set
    ]
    assert len(orig_idx_of_new) == len(new_lines), \
        "orig_idx_of_new length mismatch"

    result = []
    i = 0
    n = len(new_lines)

    while i < n:
        if new_lines[i].strip() == '':
            start = i
            while i < n and new_lines[i].strip() == '':
                i += 1
            blank_count = i - start

            if blank_count >= 2:
                # Get original indices for this blank run
                first_orig = orig_idx_of_new[start]
                last_orig = orig_idx_of_new[i - 1]

                # Check if any non-blank lines were removed BETWEEN
                # the first and last blank in the original
                had_removed_content = any(
                    j in removed_set and original_lines[j].strip() != ''
                    for j in range(first_orig + 1, last_orig)
                )

                if had_removed_content:
                    # Merge to 1 blank line
                    result.append(new_lines[start])
                else:
                    result.extend(new_lines[start:i])
            else:
                result.append(new_lines[start])
        else:
            result.append(new_lines[i])
            i += 1

    return result


def remove_traces_from_file(filepath: str, dry_run: bool = False) -> list[dict]:
    """
    Remove HiTraceMeter trace calls from a single .ets file.
    Processes line-by-line for clean, reversible removal.
    """
    changes = []

    with open(filepath, 'r', encoding='utf-8') as f:
        original_lines = f.readlines()

    # Preserve original line ending style
    raw_bytes = open(filepath, 'rb').read()
    has_crlf = b'\r\n' in raw_bytes
    line_end = '\r\n' if has_crlf else '\n'

    # Track which lines to remove and why
    lines_to_remove: set[int] = set()

    for i, line in enumerate(original_lines):
        stripped = line.strip()

        # Skip multi-line isTraceEnabled blocks
        if stripped.startswith('if') and 'hiTraceMeter.isTraceEnabled' in stripped:
            # Find the closing brace
            brace_depth = stripped.count('{') - stripped.count('}')
            j = i
            block_lines = [line]
            while brace_depth > 0 and j + 1 < len(original_lines):
                j += 1
                block_lines.append(original_lines[j])
                brace_depth += original_lines[j].count('{') - original_lines[j].count('}')
            # Mark all lines of the block for removal
            for k in range(i, j + 1):
                lines_to_remove.add(k)
            continue

        if _is_trace_call(stripped):
            lines_to_remove.add(i)
        elif _is_level_var(stripped):
            lines_to_remove.add(i)
        elif _is_hitrace_import(stripped):
            lines_to_remove.add(i)

    # Build new content by skipping removed lines
    new_lines = [
        line for i, line in enumerate(original_lines)
        if i not in lines_to_remove
    ]

    # Merge blank lines created by removals
    new_lines = _merge_blank_lines(new_lines, original_lines, lines_to_remove)

    # Build output (use same line endings as original)
    if has_crlf:
        new_lines = [l.replace('\n', '\r\n') for l in new_lines]
    output = ''.join(new_lines)
    original = ''.join(original_lines)

    # Track what was removed
    removed_count = len(lines_to_remove)
    if removed_count > 0:
        # Count by type
        trace_count = sum(1 for i in lines_to_remove
                          if _is_trace_call(original_lines[i].strip()))
        level_count = sum(1 for i in lines_to_remove
                          if _is_level_var(original_lines[i].strip()))
        import_count = sum(1 for i in lines_to_remove
                           if _is_hitrace_import(original_lines[i].strip()))
        ifblock_count = removed_count - trace_count - level_count - import_count

        if trace_count:
            changes.append({'file': filepath, 'type': 'trace-calls-removed', 'count': trace_count})
        if level_count:
            changes.append({'file': filepath, 'type': 'level-var-removed', 'count': level_count})
        if import_count:
            changes.append({'file': filepath, 'type': 'import-removed', 'count': import_count})
        if ifblock_count:
            changes.append({'file': filepath, 'type': 'if-block-removed', 'count': ifblock_count})

    if not dry_run and output != original:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(output)

    if output != original:
        changes.append({
            'file': filepath,
            'type': 'saved',
            'dry_run': dry_run,
            'chars_removed': len(original) - len(output)
        })

    return changes


def collect_ets_files(paths: list[str]) -> list[str]:
    """Collect .ets files from the given paths (files or directories)."""
    files = []
    for p in paths:
        path = Path(p)
        if path.is_file() and path.suffix == '.ets':
            files.append(str(path.resolve()))
        elif path.is_dir():
            for f in sorted(path.rglob('*.ets')):
                files.append(str(f.resolve()))
    return sorted(set(files))


def main():
    parser = argparse.ArgumentParser(
        description='Remove all HiTraceMeter trace calls from ArkTS (.ets) files.'
    )
    parser.add_argument('files', nargs='*', help='One or more .ets files to process')
    parser.add_argument('--dir', type=str, help='Recursively process all .ets files in a directory')
    parser.add_argument('--stdin', action='store_true', help='Read file paths from stdin (one per line)')
    parser.add_argument('--dry-run', action='store_true', help='Show what would be removed without modifying files')
    parser.add_argument('--verbose', '-v', action='store_true', help='Show per-file details')
    args = parser.parse_args()

    files_to_process: list[str] = []

    if args.stdin:
        for line in sys.stdin:
            line = line.strip()
            if line and line.endswith('.ets'):
                files_to_process.append(line)
    elif args.dir:
        files_to_process = collect_ets_files([args.dir])
    elif args.files:
        files_to_process = collect_ets_files(args.files)
    else:
        parser.print_help()
        sys.exit(1)

    if not files_to_process:
        print('No .ets files found.')
        sys.exit(0)

    total_changes = 0
    total_files_modified = 0

    for fpath in files_to_process:
        changes = remove_traces_from_file(fpath, dry_run=args.dry_run)
        trace_changes = [c for c in changes if c.get('type') != 'saved']
        save_info = [c for c in changes if c.get('type') == 'saved']

        if not trace_changes:
            if args.verbose:
                print(f'  ✓ {fpath} — no traces found')
            continue

        total_files_modified += 1
        desc = ', '.join(f"{c['count']}×{c['type']}" for c in trace_changes)
        removed = f" (-{save_info[0]['chars_removed']} chars)" if save_info else ''
        dry_tag = ' [DRY RUN]' if args.dry_run else ''
        print(f'  ✂ {fpath} — {desc}{removed}{dry_tag}')
        total_changes += sum(c.get('count', 0) for c in trace_changes)

    print(f'\nSummary: {total_files_modified}/{len(files_to_process)} files modified, {total_changes} trace calls removed.')
    if args.dry_run:
        print('This was a dry run. Run without --dry-run to apply changes.')


if __name__ == '__main__':
    main()
