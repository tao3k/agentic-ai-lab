#!/bin/sh
# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

set -eu

gxi=$1
validator=$2
library=$3
manifest=$4
clan_package=${5:-}
# Runfiles expose the migrated product module tree and declared POO source.
# Source discovery must not depend on the removed product src/ directory.
GERBIL_LOADPATH=$PWD${clan_package:+:$(dirname "$clan_package")}${GERBIL_LOADPATH:+:$GERBIL_LOADPATH}
export GERBIL_LOADPATH
temporary=${TEST_TMPDIR:-${TMPDIR:-/tmp}}/agentic-ai-lab-runtime-symbols.$$
actual=$temporary.actual
trap 'rm -f "$actual"' EXIT HUP INT TERM

if [ -n "${NM_BIN:-}" ]; then
  nm_bin=$NM_BIN
elif command -v nm >/dev/null 2>&1; then
  nm_bin=$(command -v nm)
elif command -v llvm-nm >/dev/null 2>&1; then
  nm_bin=$(command -v llvm-nm)
elif [ -x /usr/bin/nm ]; then
  nm_bin=/usr/bin/nm
else
  echo "runtime_v0_symbol_surface_test: nm or llvm-nm not found" >&2
  exit 127
fi

case "$(uname -s)" in
  Darwin) "$nm_bin" -gU "$library" ;;
  *) "$nm_bin" -g --defined-only "$library" ;;
esac \
  | awk '{print $NF}' \
  | sed 's/^_//' \
  | awk '/^agentic_ai_lab_runtime_v0_/ || /^agentic_ai_lab_proof_/' \
  | LC_ALL=C sort -u >"$actual"

exec "$gxi" -:max-heap=1G,debug=q "$validator" "$manifest" "$actual" < /dev/null
