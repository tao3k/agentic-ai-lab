#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""Materialize the compiler-owned semantic AOT closure; never inspect Scheme IR."""
from __future__ import annotations
import argparse
import hashlib
import os
from pathlib import Path
import platform
import re
import shlex
import shutil
import subprocess
import sys


ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "packages/python-runtime/src/poo_flow_runtime"))
from scheme_wire import dumps


def run(argv: list[str], *, capture: bool = False) -> str:
    print(f"BUILD {argv[0]} {argv[1:3]}", flush=True)
    result = subprocess.run(argv, cwd=ROOT, text=True,
                            stdout=subprocess.PIPE if capture else None)
    if result.returncode and capture:
        sys.stdout.write(result.stdout or "")
        sys.stdout.flush()
    result.check_returncode()
    return result.stdout or ""


def native_link_flags(home: Path, system: str) -> list[str]:
    flags = shlex.split((home / "lib/libgerbil.ldd").read_text().strip().strip("()"))
    if system == "Darwin":
        # A portable SDK can retain its producer's versioned Homebrew paths.
        # Host pkg-config supplies current OpenSSL search paths; keep the SDK's
        # complete dependency flags and fail if the host provider is unavailable.
        current = subprocess.check_output(
            ["pkg-config", "--libs-only-L", "openssl"], text=True
        )
        flags = [*shlex.split(current), *flags]
    return flags


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    # Resolve the selected package SDK before platform C-tool PATH adjustments.
    home = Path(run(["gxi", "-e", "(displayln (gerbil-home))"], capture=True).strip())
    if platform.system() == 'Darwin':
        for key in ['SDKROOT', 'NIX_CFLAGS_COMPILE', 'NIX_CFLAGS_COMPILE_FOR_BUILD',
                    'NIX_LDFLAGS', 'NIX_LDFLAGS_FOR_BUILD']:
            os.environ.pop(key, None)
        os.environ['CC'] = '/usr/bin/clang'
        os.environ['PATH'] = '/usr/bin:/bin:/opt/homebrew/bin:' + os.environ.get('PATH', '')
        os.environ['MACOSX_DEPLOYMENT_TARGET'] = platform.mac_ver()[0].split('.')[0] + '.0'
        developer = Path('/Applications/Xcode.app/Contents/Developer')
        if developer.is_dir():
            os.environ['DEVELOPER_DIR'] = str(developer)
    output = args.output.resolve()
    stage = output.parent / "semantic-build"
    stage.mkdir(parents=True, exist_ok=True)
    gsc = str(home / "bin/gsc")
    os.environ["GAMBOPT"] = f"~~={home},~~bin={home / 'bin'},~~lib={home / 'lib'}"
    compiler = [str(home / "bin/gxc"), "-:max-heap=1G,debug=q"]
    # Module compilation already emits compiler-owned static sources.
    # -static controls executable dependency linkage and cannot link Darwin dylibs.
    for source in ["core/utilities/product-syntax.ss", "core/utilities/final-projection-syntax.ss",
                   "core/graph/types-core.ss", "core/graph/algorithms-list-support.ss",
                   "core/graph/algorithms.ss", "modules/temporal-causality/types.ss",
                   "modules/temporal-causality/objects.ss", "modules/temporal-causality/funs.ss",
                   "modules/workflow/runtime/temporal-family.ss", "modules/temporal-causality/truth-maintenance/types.ss",
                   "modules/temporal-causality/conclusions/types.ss",
                   "modules/temporal-causality/conclusions/objects.ss",
                   "modules/temporal-causality/conclusions/funs.ss",
                   "modules/temporal-causality/admission/interface.ss",
                   "modules/temporal-causality/applicability/types.ss",
                   "modules/temporal-causality/applicability/objects.ss",
                   "modules/temporal-causality/applicability/funs.ss",
                   "modules/temporal-causality/applicability/interface.ss",
                   "modules/temporal-causality/truth-maintenance/objects.ss",
                   "modules/temporal-causality/lifecycle/types.ss",
                   "modules/temporal-causality/lifecycle/objects.ss",
                   "modules/temporal-causality/lifecycle/funs.ss",
                   "modules/temporal-causality/lifecycle/interface.ss",
                   "modules/query/semantic/context-restriction.ss", "modules/workflow/runtime/context-restriction.ss",
                   "modules/workflow/runtime/temporal-admission.ss", "modules/workflow/runtime/scheme-wire.ss", "modules/workflow/runtime/temporal-archive.ss",
                   "modules/temporal-causality/time/types.ss", "modules/temporal-causality/time/objects.ss",
                   "modules/temporal-causality/time/funs.ss",
                   "modules/temporal-causality/revisions/types.ss", "modules/temporal-causality/revisions/objects.ss",
                   "modules/temporal-causality/revisions/funs.ss", "modules/temporal-causality/revisions/interface.ss",
                   "modules/temporal-causality/truth-maintenance/funs.ss",
                   "modules/temporal-causality/truth-maintenance/support/types.ss",
                   "modules/temporal-causality/truth-maintenance/support/objects.ss",
                   "modules/temporal-causality/truth-maintenance/support/funs.ss",
                   "modules/temporal-causality/truth-maintenance/support/policy.ss",
                   "modules/temporal-causality/truth-maintenance/support/interface.ss",
                   "modules/temporal-causality/truth-maintenance/support/policy-host.ss",
                   "modules/ai-agentic-context/use-host.ss",
                   "modules/temporal-causality/evaluator/fact.ss", "modules/workflow/runtime/temporal-support.ss",
                   "modules/temporal-causality/evaluator/positive-proof.ss",
                   "modules/temporal-causality/evaluator/binding.ss",
                   "modules/temporal-causality/evaluator/rule.ss",
                   "modules/temporal-causality/evaluator/derivation.ss",
                   "modules/temporal-causality/evaluator/proof-host.ss",
                   "modules/temporal-causality/evaluator/interface.ss", "modules/workflow/runtime/temporal-proof.ss", "modules/workflow/runtime/temporal-policy.ss", "modules/workflow/runtime/temporal-proof-host.ss", "modules/workflow/runtime/context-use.ss"]:
        run([*compiler, "-O", source])
    run([*compiler, "-O",
         "-ld-options", "-Wl,-undefined,dynamic_lookup" if platform.system() == "Darwin" else "-ldl",
         "modules/workflow/runtime/semantic.ss"])
    expression = '''(let* ((ctx (import-module "modules/workflow/runtime/semantic.ss"))
                           (deps (gxc#find-runtime-module-deps ctx)))
                      (for-each (lambda (dep)
                        (displayln (expander-context-id dep) "\\t"
                                   (gxc#find-static-module-file dep))) deps)
                      (displayln "ROOT\\t" (gxc#find-static-module-file ctx)))'''
    closure = run([str(home / "bin/gxi"), "-:max-heap=1G,debug=q", "-e", "(import :gerbil/compiler/driver :gerbil/expander)",
                   "-e", expression], capture=True)
    system, user, inputs = [], [], []
    seen = set()
    for line in closure.splitlines():
        name, path = line.split("\t", 1)
        source = Path(path).resolve()
        if source in seen or name.startswith("gerbil/core"):
            continue
        seen.add(source)
        if not source.is_file():
            raise RuntimeError(f"missing compiler closure source: {name}")
        if not source.stat().st_size:
            continue
        inputs.append({"module": name, "sha256": hashlib.sha256(source.read_bytes()).hexdigest()})
        if name.startswith(("gerbil/", "std/")):
            system.append(source)
        else:
            target = stage / f"module-{len(user)}.scm"
            shutil.copyfile(source, target)
            user.append(target)
    linker = stage / "semantic_.c"
    run([gsc, "-link", "-o", str(linker),
         *[str(p.with_suffix('.c')) for p in system], *map(str, user)])
    text = linker.read_text()
    def define(name: str) -> str:
        match = re.search(rf"^#define {name} ([A-Za-z0-9_]+)$", text, re.M)
        if not match:
            raise RuntimeError(f"missing Gambit linker metadata: {name}")
        return match[1]
    objects = []
    for source in user:
        target = source.with_suffix('.o')
        fingerprint = hashlib.sha256(source.read_bytes() + Path(gsc).read_bytes() +
                                     (home / 'include/gambit.h').read_bytes() +
                                     b'-fPIC' + platform.platform().encode()).hexdigest()
        cache = target.with_suffix('.sha256')
        if not target.is_file() or not cache.is_file() or cache.read_text() != fingerprint:
            run([gsc, "-cc-options", "-fPIC", "-obj", "-o", str(target), str(source.with_suffix('.c'))])
            cache.write_text(fingerprint)
        objects.append(target)
    for source in system:
        obj = source.with_suffix('.o')
        if not obj.is_file():
            raise RuntimeError(f"missing installed system object: {obj}")
        objects.append(obj)
    link_object, host_object = stage / "link.o", stage / "host.o"
    run([gsc, "-cc-options", "-fPIC -D___LIBRARY", "-obj", "-o", str(link_object), str(linker)])
    options = (f"-fPIC -D___VERSION={define('___VERSION')} "
               f"-DPOO_FLOW_SEMANTIC_LINKER={define('___LINKER_ID')} "
               f"-I{ROOT / 'bindings/runtime-c/include'}")
    run([gsc, "-cc-options", options, "-obj", "-o", str(host_object),
         str(ROOT / 'bindings/runtime-c/src/semantic_host.c')])
    flags = native_link_flags(home, platform.system())
    shared = ["-shared"]
    if platform.system() == "Darwin":
        shared = ["-dynamiclib", "-Wl,-no_compact_unwind"]
    run([os.environ.get('CC', 'cc'), *shared, '-o', str(output),
         *map(str, objects), str(link_object), str(host_object),
         '-L', str(home / 'lib'), '-lgambit', *flags])
    manifest = {"schema": "poo-flow.semantic-aot-artifact", "version": 1, "modules": inputs,
                "artifactSha256": hashlib.sha256(output.read_bytes()).hexdigest(),
                "sourceSha256": hashlib.sha256((ROOT / 'modules/workflow/runtime/semantic.ss').read_bytes()).hexdigest(),
                "hostSha256": hashlib.sha256((ROOT / 'bindings/runtime-c/src/semantic_host.c').read_bytes()).hexdigest(),
                "headerSha256": hashlib.sha256((ROOT / 'bindings/runtime-c/include/poo_flow/semantic.h').read_bytes()).hexdigest(),
                "compilerSha256": hashlib.sha256(Path(gsc).read_bytes()).hexdigest()}
    output.with_suffix(output.suffix + '.ss').write_text(dumps(manifest) + '\n')
    print(f"BUILD-OK {output} {manifest['artifactSha256']}", flush=True)


if __name__ == '__main__':
    main()
