#!/usr/bin/env gxi
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; -*- Gerbil -*-
;;; Development-only policy declaration for the production package.

(export agentic-ai-lab-package-spec agentic-ai-lab-native-spec)

(import (only-in :std/source this-source-file)
        ;; Native package declaration only needs the latency-bounded PackageSpec
        ;; facade. Optional profiles compose through PackageSpec POO slots and
        ;; must not add another framework to the `gerbil build` startup closure.
        (only-in :asp-gerbil-scheme/building-api
                 asp-gerbil-scheme-package-spec!
                 asp-gerbil-scheme-library-package-prototype
                 default-exclude-dirs))

(def +agentic-ai-lab-build-exclude-dirs+
  (append '("packages/lambda-episteme"
            "core"
            "bindings"
            "packages"
            "target"
            "user-interface")
          default-exclude-dirs))

(def +nono-c-include-option+
  (string-append
   "-I"
   (path-normalize (path-expand "../bindings/nono-c" (path-directory (this-source-file))))))

(def +nono-c-link-option+
  (cond-expand
   (darwin "-Wl,-undefined,dynamic_lookup")
   (else "-ldl")))

;;; Gambit emits a loadable bundle for begin-ffi modules on Darwin.  The
;;; process/AOT consumer supplies libc and runtime symbols at final link time.
(def +runtime-v0-native-ffi-spec+
  (cond-expand
   (darwin
    '(gxc: "modules/workflow/runtime/runtime-v0-native"
           "-ld-options" "-Wl,-undefined,dynamic_lookup"))
   (else
    '(gxc: "modules/workflow/runtime/runtime-v0-native"))))

(def +semantic-native-ffi-spec+
  (cond-expand
   (darwin '(gxc: "modules/workflow/runtime/semantic" "-ld-options" "-Wl,-undefined,dynamic_lookup"))
   (else '(gxc: "modules/workflow/runtime/semantic"))))

(asp-gerbil-scheme-package-spec!
 (agentic-ai-lab-package-spec
 @ asp-gerbil-scheme-library-package-prototype)
 (spec agentic-ai-lab-native-spec)
 (public-entry-modules
  '("init.ss"
    "modules/workflow/scenario/bundle-v1-projection.ss"

    "modules/module-authoring/module-descriptor.ss"
    "modules/workflow/scenario/configuration/module-activation.ss"
    "modules/module-authoring/module-source-collection.ss"
    "modules/building/official-contributions.ss"
    "modules/workflow/scenario/configuration/module-source-selection.ss"
    "modules/workflow/scenario/configuration/module-source-tree.ss"
    "modules/workflow/scenario/configuration/module-diagnostics.ss"
    "modules/workflow/scenario/configuration/doctor-presentation.ss"
    "modules/building/build-projection.ss"
    "modules/proof/projections/composition-facts.ss"
    "modules/workflow/scenario/profile-root.ss"
    "modules/workflow/scenario/composition-syntax.ss"
    "modules/workflow/scenario/case.ss"
    "modules/workflow/scenario/accessors.ss"
    "modules/workflow/scenario/workload.ss"
    "modules/workflow/scenario/plan-projection.ss"
    "modules/workflow/funflow-config.ss"
    "modules/workflow/profiles/funflow-library.ss"
    "modules/workflow/profiles/github-ci-contract.ss"
    "modules/workflow/scenario/runtime-funflow.ss"
    "modules/session/interface.ss"
    "modules/ai-agentic-context/interface.ss"
    "modules/workflow/profiles/human-ai-capability.ss"
    "modules/workflow/profiles/agentic-research.ss"
    "modules/authorization/interface.ss"
    "modules/authorization/providers/cedar/interface.ss"
    "modules/governance/interface.ss"
    "modules/proof/interface.ss"
    "modules/ai-agentic-context/use-host.ss"
    "modules/ai-agentic-context/session-host.ss"
    "modules/query/semantic/context-restriction.ss"
    "modules/query/semantic/orgize-interface.ss"
    "modules/query/semantic/orgize-source-interface.ss"
    "modules/query/interface.ss"
    "modules/search-engine/interface.ss"
    "modules/query/rust-ir.ss"
    "modules/standards/interface.ss"
    "modules/temporal-causality/interface.ss"
    "modules/temporal-causality/ascent-exchange.ss"
    ;; Advanced embedded owner projections must ship in the installed package.
    ;; Ordinary authoring continues through the POO-native Temporal interface.
    "modules/workflow/runtime/scheme-wire.ss"
    "modules/workflow/runtime/temporal-policy.ss"
    "modules/workflow/runtime/context-use.ss"
    "modules/workflow/runtime/temporal-proof.ss"
    "modules/workflow/runtime/temporal-proof-host.ss"
))
 (exclude-dirs +agentic-ai-lab-build-exclude-dirs+)
 (exclude-modules '("modules/nono-sandbox/_nono.ss"
                    "modules/workflow/runtime/runtime-v0-native.ss"
                    "modules/workflow/runtime/semantic.ss"
                    "observe-contribute-import.ss"
                    "performance-tests.ss"
                    "run-contribute-test.ss"))
 (native-prelude-spec
  `((gxc: "modules/nono-sandbox/_nono"
          "-cc-options" ,+nono-c-include-option+
          "-ld-options" ,+nono-c-link-option+)))
 (extra-spec `(,+runtime-v0-native-ffi-spec+ ,+semantic-native-ffi-spec+)))
