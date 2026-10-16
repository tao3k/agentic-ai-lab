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

temporary=${TEST_TMPDIR:-${TMPDIR:-/tmp}}/poo-flow-bundle-v1.$$
descriptor=$temporary.descriptor.bin
arena=$temporary.arena.bin
trap 'rm -f "$descriptor" "$arena"' EXIT HUP INT TERM

POO_FLOW_BUNDLE_V1_DESCRIPTOR_OUT=$descriptor
POO_FLOW_BUNDLE_V1_ARENA_OUT=$arena
export POO_FLOW_BUNDLE_V1_DESCRIPTOR_OUT POO_FLOW_BUNDLE_V1_ARENA_OUT

"$gxi" -:max-heap=1G,debug=q "$fixture" < /dev/null
"$harness" "$descriptor" "$arena"
