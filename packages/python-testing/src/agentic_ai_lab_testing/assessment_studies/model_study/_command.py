# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Command for the model study study."""

from agentic_ai_lab_testing.model_study.reporting import report_text
import argparse
from pathlib import Path
from ._execution import live
from ._native import probe
from ._snapshot import prepare
from ._validation import validate


def main():
    parser = argparse.ArgumentParser()
    modes = parser.add_subparsers(dest="mode", required=True)
    prepare_args = modes.add_parser("prepare")
    prepare_args.add_argument("output", type=Path)
    probe_args = modes.add_parser("probe")
    probe_args.add_argument("output", type=Path)
    validate_args = modes.add_parser("validate")
    validate_args.add_argument("preview", type=Path)
    validate_args.add_argument("--approved-sha256", required=True)
    live_args = modes.add_parser("live")
    live_args.add_argument("preview", type=Path)
    live_args.add_argument("output", type=Path)
    live_args.add_argument("--approved-sha256", required=True)
    args = parser.parse_args()
    if args.mode == "prepare":
        prepare(args.output.resolve())
    elif args.mode == "probe":
        probe(args.output.resolve())
        report_text("NATIVE-SOURCE-PROBE-OK modelCalls=0", flush=True)
    elif args.mode == "validate":
        validate(args.preview.resolve(), args.approved_sha256)
        report_text("OFFLINE-VALID modelCalls=0", flush=True)
    else:
        live(args.preview.resolve(), args.output.resolve(), args.approved_sha256)
