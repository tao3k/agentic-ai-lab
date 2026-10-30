# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Freeze and run four controlled repairs from two shared native-owned seeds."""

from __future__ import annotations

import argparse
import json
import os
import subprocess
from pathlib import Path

from ..ascent.live import key_from_file
from .archive import require_archive, seal
from .protocol import require_clean, require_pinned_ascent
from .reporting import report_json
from .runner import source_head
from .support import call, inert_output
from .support_native import observe, parse_observation, score
from .support_protocol import SETTINGS, TRANSPORT, TASK, digest

TASKS = ('compute', 'filter')
ORDER = (('compute', 'self'), ('compute', 'native'), ('filter', 'native'), ('filter', 'self'))
SELF = 'Repair the supplied candidate using the task and candidate contract. Return only the final candidate datum.'
NATIVE = SELF + '\nInitial-source native observation (execution/evidence only, not task intent):\n{observation}'


def native_data(root: Path, gerbil_path: Path, command: list[str]) -> str:
    env = os.environ.copy()
    env.pop('DEEPSEEK_API_KEY', None)
    env.update(GERBIL_PATH=str(gerbil_path), GERBIL_LOADPATH=str(root))
    return subprocess.run(['just', *command], cwd=root, env=env, text=True,
                          capture_output=True, check=True, timeout=125).stdout


def metadata(ascent: Path, poo: Path, files: dict[str, bytes]) -> dict:
    return {'protocol': 'shared-seed-repair-v1', 'ascent_head': source_head(ascent),
            'poo_head': source_head(poo), 'settings': SETTINGS, 'transport': TRANSPORT,
            'max_calls': 4, 'order': [list(item) for item in ORDER],
            'state_count': 7, 'files': {name: digest(raw) for name, raw in files.items()}}


def names() -> set[str]:
    return {'contract.sexp', 'reference.tsv',
            *(f'{task}.{kind}.txt' for task in TASKS for kind in ('seed', 'self', 'native'))}


def preview(directory: Path, ascent: Path, poo: Path, gerbil_path: Path) -> dict:
    require_clean(ascent)
    require_clean(poo)
    require_pinned_ascent(ascent, poo)
    if directory.exists() or any(directory.resolve().is_relative_to(root.resolve())
                                 for root in (ascent, poo)):
        raise ValueError('preview requires a new external directory')
    contract = native_data(ascent, gerbil_path, ['candidate-description'])
    reference = observe(ascent, gerbil_path, discriminator=True)
    records = parse_observation(reference, state_count=7)
    if ([r['rows'] for r in records[:-1]] != [f'((0 {n}))' for n in (20, 20, 8, 12, 8, 12, 8)]
            or not score(reference, reference, state_count=7)['correct']):
        raise RuntimeError('qualified seven-state reference changed')
    files = {'contract.sexp': contract.encode(), 'reference.tsv': reference.encode()}
    for task, mode in (('compute', 'repair-seed'), ('filter', 'filter-seed')):
        seed = native_data(ascent, gerbil_path, ['candidate-repair-seed', mode])
        observation = observe(ascent, gerbil_path, seed, initial=True)
        initial = parse_observation(observation, initial=True)[0]
        expected = 'invalid-computation' if task == 'compute' else 'invalid-filter'
        if initial['status'] != 'rejected' or expected not in initial['diagnostics']:
            raise RuntimeError('frozen repair seed no longer has its expected native diagnostic')
        common = 'Candidate syntax contract:\n' + contract + '\nTask:\n' + TASK + '\nCandidate to repair:\n' + seed
        files[f'{task}.seed.txt'] = seed.encode()
        files[f'{task}.self.txt'] = (common + '\n' + SELF).encode()
        files[f'{task}.native.txt'] = (common + '\n' + NATIVE.format(observation=observation)).encode()
    manifest = metadata(ascent, poo, files)
    directory.mkdir(parents=True)
    for name, raw in files.items():
        (directory / name).write_bytes(raw)
    (directory / 'manifest.json').write_text(json.dumps(manifest, sort_keys=True, indent=2) + '\n')
    return manifest


def validate(directory: Path, ascent: Path, poo: Path) -> dict[str, str]:
    require_clean(ascent)
    require_clean(poo)
    require_pinned_ascent(ascent, poo)
    files = {name: (directory / name).read_bytes() for name in names()}
    manifest = json.loads((directory / 'manifest.json').read_text())
    if manifest != metadata(ascent, poo, files):
        raise RuntimeError('repair preview bytes, heads or settings changed')
    parse_observation(files['reference.tsv'].decode(), state_count=7)
    return {name: raw.decode() for name, raw in files.items()}


def run(client, files: dict[str, str], ascent: Path, gerbil_path: Path, output: Path) -> dict:
    results = {}
    for task, arm in ORDER:
        name = f'{task}.{arm}'
        response = call(client, [{'role': 'user', 'content': files[f'{name}.txt']}], output, name)
        candidate = inert_output(response)
        result = {'response_completed': response.status == 'completed',
                  'candidate_readable': candidate is not None}
        if candidate is None:
            result.update(correct=False, reason='invalid-model-output')
        else:
            raw = observe(ascent, gerbil_path, candidate, discriminator=True)
            (output / f'{name}.tsv').write_text(raw)
            result.update(score(raw, files['reference.tsv'], state_count=7))
        results[name] = result
        (output / 'scores.json').write_text(json.dumps(results, sort_keys=True, indent=2) + '\n')
    return results


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ('ascent-root', 'poo-root', 'gerbil-path', 'preview-dir'):
        parser.add_argument('--' + name, type=Path, required=True)
    parser.add_argument('--output-dir', type=Path)
    parser.add_argument('--archive-dir', type=Path)
    parser.add_argument('--approved-manifest-sha256')
    parser.add_argument('--env-file', type=Path)
    args = parser.parse_args()
    if args.output_dir is None:
        report_json(preview(args.preview_dir, args.ascent_root, args.poo_root, args.gerbil_path))
        return 0
    manifest = (args.preview_dir / 'manifest.json').read_bytes()
    if digest(manifest) != args.approved_manifest_sha256:
        parser.error('live run requires the approved repair manifest SHA256')
    files = validate(args.preview_dir, args.ascent_root, args.poo_root)
    if args.archive_dir is None:
        parser.error('live runs require a durable --archive-dir')
    require_archive(args.archive_dir, args.preview_dir, args.output_dir)
    if args.output_dir.exists() or any(args.output_dir.resolve().is_relative_to(root.resolve())
                                      for root in (args.poo_root, args.ascent_root)):
        parser.error('results require a new external directory')
    key = os.environ.get('DEEPSEEK_API_KEY') or (key_from_file(args.env_file) if args.env_file else '')
    if not key:
        parser.error('a live API key is required')
    from openai import OpenAI
    client = OpenAI(api_key=key, **TRANSPORT)
    args.output_dir.mkdir(parents=True)
    (args.output_dir / 'preview-manifest.json').write_bytes(manifest)
    try:
        result = run(client, files, args.ascent_root, args.gerbil_path, args.output_dir)
    except Exception:
        seal(args.preview_dir, args.output_dir, args.archive_dir, outcome='failed')
        raise
    seal(args.preview_dir, args.output_dir, args.archive_dir, outcome='completed')
    report_json(result)
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
