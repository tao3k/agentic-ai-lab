#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
set -euo pipefail

mode=$1
path=$2
runtime_options=$3
shift 3

if [[ $(uname -s) != Darwin || ( $mode != control && $mode != terminal ) ]]; then
    echo 'macOS terminal cleanup requires Darwin and mode control or terminal' >&2
    exit 64
fi

fixture="$PWD/t/harness/macos-terminal-cleanup"
work=$(mktemp -d "${TMPDIR:-/tmp}/lab-terminal-cleanup.XXXXXXXX")
trap 'rm -rf "$work"' EXIT
cp "$fixture/handoff.ss" "$work/handoff.ss"
cc -Wall -Wextra -Werror -dynamiclib "$fixture/defer-close.c" -o "$work/defer-close.dylib"
gerbil compile -O -ld-options -Wl,-undefined,dynamic_lookup -d "$work" "$work/handoff.ss"

# Inject only into the native executable. A Homebrew shell wrapper can strip
# DYLD_INSERT_LIBRARIES before Gerbil starts.
gerbil_home=$(gerbil env /usr/bin/printenv GERBIL_HOME)
runtime_home_options="~~=$gerbil_home,~~bin=$gerbil_home/bin,~~lib=$gerbil_home/lib"
"$@" env GERBIL_HOME="$gerbil_home" GAMBOPT="${GAMBOPT:+$GAMBOPT,}$runtime_home_options" \
    DYLD_INSERT_LIBRARIES="$work/defer-close.dylib" \
    GERBIL_LOADPATH="$work${GERBIL_LOADPATH:+:$GERBIL_LOADPATH}" \
    LAB_TERMINAL_CLEANUP="$mode" \
    "$gerbil_home/bin/gerbil" "$runtime_options" "$fixture/run-tests.ss" "$path"
