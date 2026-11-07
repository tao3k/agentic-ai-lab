#!/bin/sh
# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

set -eu

gxi=$1
fixture=$2
harness=$3
clan_package=$4
core_package=$5

GERBIL_LOADPATH=$PWD:$(dirname "$core_package"):$(dirname "$clan_package")${GERBIL_LOADPATH:+:$GERBIL_LOADPATH}
export GERBIL_LOADPATH

temporary=${TEST_TMPDIR:-${TMPDIR:-/tmp}}/agentic-ai-lab-bundle-v1.$$
descriptor=$temporary.descriptor.bin
arena=$temporary.arena.bin
trap 'rm -f "$descriptor" "$arena"' EXIT HUP INT TERM

YUANXU_BUNDLE_V1_DESCRIPTOR_OUT=$descriptor
YUANXU_BUNDLE_V1_ARENA_OUT=$arena
export YUANXU_BUNDLE_V1_DESCRIPTOR_OUT YUANXU_BUNDLE_V1_ARENA_OUT
YUANXU_BUNDLE_V1_CORE_SOURCE=$(dirname "$core_package")
export YUANXU_BUNDLE_V1_CORE_SOURCE

"$gxi" -:max-heap=1G,debug=q \
  -e '(import (only-in :yuanxu/module-system/building/source-package register-yuanxu-build-source!))' \
  -e '(register-yuanxu-build-source! (getenv "YUANXU_BUNDLE_V1_CORE_SOURCE"))' \
  "$fixture" < /dev/null
"$harness" "$descriptor" "$arena"
