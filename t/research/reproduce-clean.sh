#!/bin/sh
set -eu
artifact=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
work=$(mktemp -d "${TMPDIR:-/tmp}/ascent-clean-rebuild.XXXXXX")
work=$(CDPATH= cd -- "$work" && pwd -P)
git clone --quiet --branch research/library-evidence-consumer "$artifact/source.bundle" "$work/source"
trap 'printf "REPRODUCTION-RECEIPTS %s\n" "$work"' EXIT
cd "$work/source"
export GERBIL_PATH="$work/gerbil"
export GERBIL_BUILD_CORES="${GERBIL_BUILD_CORES:-$(getconf _NPROCESSORS_ONLN 2>/dev/null || getconf NPROCESSORS_ONLN)}"
export UV_CACHE_DIR="$work/uv-cache"
openssl_prefix="${ASCENT_OPENSSL_PREFIX:-/opt/homebrew/opt/openssl@3}"
test -f "$openssl_prefix/lib/libcrypto.dylib"
export LDFLAGS="${LDFLAGS:-} -L$openssl_prefix/lib"
printf "%s\n" "$LDFLAGS" > "$work/link-configuration.txt"
# These are explicit caller-installed tools; package dependencies use gerbil.pkg pins.
gxi -e '(displayln (gerbil-home))' > "$work/sdk.txt"
timeout -k 5 240 gxpkg deps --install > "$work/dependencies.log" 2>&1
timeout -k 5 240 gxi build.ss > "$work/scheme-build.log" 2>&1
timeout -k 5 60 uv sync --project python --locked --extra native-build --python 3.13 > "$work/python-install.log" 2>&1
timeout -k 5 180 uv run --project python --locked --offline python -m ascent_engine.build --root . --output "$work/libascent.dylib" > "$work/native-build.log" 2>&1
timeout -k 5 180 uv run --project python --locked --offline python -m ascent_engine.api_build --library "$work/libascent.dylib" --header bindings/c/ascent.h --out "$work/api" --cc "${ASCENT_CC:-/opt/homebrew/bin/gcc-16}" > "$work/api-build.log" 2>&1
export PYTHONPATH="$work/source/python/src:$work/api"
timeout -k 5 180 uv run --project python --locked --offline python -m unittest discover -s python/engine_tests -p test_computational_evidence.py -v > "$work/api-test.log" 2>&1
ASCENT_ENGINE_BACKEND=abi ASCENT_ENGINE_LIBRARY="$work/libascent.dylib" timeout -k 5 180 uv run --project python --locked --offline python -m unittest discover -s python/engine_tests -p test_computational_evidence.py -v > "$work/abi-test.log" 2>&1
timeout -k 5 180 uv run --project python --locked --offline python -m unittest discover -s python/tests -p test_shared_premise.py -v > "$work/consumer-test.log" 2>&1
timeout -k 5 30 quint typecheck packages/proofs/quint/SharedPremiseReuse.qnt > "$work/quint-typecheck.log" 2>&1
timeout -k 5 30 quint run packages/proofs/quint/SharedPremiseReuse.qnt --invariants Bound Correct --max-samples 1000 --max-steps 12 --seed 713 --backend typescript > "$work/quint-sample.log" 2>&1
(cd packages/proofs/lean && timeout -k 5 30 lean ProofDag.lean) > "$work/lean-proof.log" 2>&1
export ASCENT_CFFI_RECEIPT="$work/api/receipt.json"
timeout -k 5 180 uv run --project python --locked --offline python -m ascent_test_support.evidence_chain_study branch-freeze "$work/libascent.dylib" "$work/frozen" > "$work/freeze.log" 2>&1
printf 'CLEAN-REBUILD-OK %s\n' "$work"
# Deliberately no model invocation. New paid runs use branch-live explicitly.
