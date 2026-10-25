;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Public library roots projected through Core's installed native import graph.
;;; init.ss owns the selected Module spec through init.exports; it is not a
;;; library target or an import-graph root here.
(import (only-in :gerbil/expander expander-context-id)
        (only-in :yuanxu/module-system/building/source-closure package-library-spec))
(export agentic-ai-lab-public-build-roots agentic-ai-lab-build-spec)
(def agentic-ai-lab-public-build-roots
  ;; Every maintained Module and Feature interface is a public library root.
  ;; Core projects their shared native import closure without duplicate targets.
  '("modules/agent-sandbox/interface.ss"
    "modules/ai-agentic-context/features/memory/interface.ss"
    "modules/ai-agentic-context/interface.ss"
    "modules/authorization/interface.ss"
    "modules/authorization/providers/cedar/interface.ss"
    "modules/building/interface.ss"
    "modules/cubeSandbox/interface.ss"
    "modules/custom-task/interface.ss"
    "modules/docker-sandbox/interface.ss"
    "modules/docker/interface.ss"
    "modules/evidence-assessment/interface.ss"
    "modules/governance/interface.ss"
    "modules/governor/interface.ss"
    "modules/loop-engine/interface.ss"
    "modules/model-core/interface.ss"
    "modules/module-authoring/interface.ss"
    "modules/nix/interface.ss"
    "modules/nono-sandbox/interface.ss"
    "modules/proof/interface.ss"
    "modules/query/interface.ss"
    "modules/query/results/interface.ss"
    "modules/sandbox-core/interface.ss"
    "modules/search-engine/interface.ss"
    "modules/services/opentofu/interface.ss"
    "modules/session/interface.ss"
    "modules/standards/interface.ss"
    "modules/temporal-causality/admission/interface.ss"
    "modules/temporal-causality/applicability/interface.ss"
    "modules/temporal-causality/candidates/interface.ss"
    "modules/temporal-causality/conclusions/interface.ss"
    "modules/temporal-causality/evaluator/interface.ss"
    "modules/temporal-causality/evidence/interface.ss"
    "modules/temporal-causality/impact/interface.ss"
    "modules/temporal-causality/interface.ss"
    "modules/temporal-causality/lifecycle/interface.ss"
    "modules/temporal-causality/revisions/interface.ss"
    "modules/temporal-causality/time/interface.ss"
    "modules/temporal-causality/trajectory/interface.ss"
    "modules/temporal-causality/truth-maintenance/interface.ss"
    "modules/temporal-causality/truth-maintenance/support/interface.ss"
    "modules/text/interface.ss"
    "modules/tool-core/interface.ss"
    "modules/workflow/interface.ss"
    "modules/workflow/profiles/kernel/interface.ss"
    "modules/workflow/scenario/configuration/interface.ss"

    ;; Standalone public/embedded APIs and compiler-option owners.
    "modules/workflow/scenario/bundle-v1-projection.ss"
    "testing-api.ss"
    "modules/agent-sandbox/api.ss"
    "modules/ai-agentic-context/clue-exchange.ss"
    "services.ss"
    "nix-contracts.ss"
    "opentofu-contracts.ss"
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
    "modules/workflow/profiles/human-ai-capability.ss"
    "modules/workflow/profiles/agentic-research.ss"
    "modules/governance/evidence/batched-merkle.ss"
    "modules/ai-agentic-context/use-host.ss"
    "modules/ai-agentic-context/session-host.ss"
    "modules/query/semantic/context-restriction.ss"
    "modules/query/semantic/orgize-interface.ss"
    "modules/query/semantic/orgize-source-interface.ss"
    "modules/query/rust-ir.ss"
    "modules/temporal-causality/ascent-exchange.ss"
    "modules/workflow/runtime/scheme-wire.ss"
    "modules/workflow/runtime/temporal-policy.ss"
    "modules/workflow/runtime/context-use.ss"
    "modules/workflow/runtime/temporal-proof.ss"
    "modules/workflow/runtime/temporal-proof-host.ss"
    "modules/nono-sandbox/_nono.ss"
    "modules/workflow/runtime/runtime-v0-native.ss"
    "modules/workflow/runtime/semantic.ss"))

(def special-targets '("modules/nono-sandbox/_nono"
                      "modules/workflow/runtime/runtime-v0-native"
                      "modules/workflow/runtime/semantic"))
(def (admit-production-build-context context)
  (let* ((identity (expander-context-id context))
         (name (and (symbol? identity) (symbol->string identity))))
    (when (and name (string-prefix? "asp-gerbil-scheme/" name))
      (error "production build imports the development-only ASP package" identity))
    (when (and name (string-prefix? "agentic-ai-lab/dev/" name))
      (error "production build imports a development module" identity))))
(def (agentic-ai-lab-build-spec (roots agentic-ai-lab-public-build-roots))
  (def ffi-options
    (cond-expand (darwin '("-ld-options" "-Wl,-undefined,dynamic_lookup")) (else '())))
  (append
    `((gxc: "modules/nono-sandbox/_nono"
            "-cc-options" ,(string-append "-I" (path-expand "bindings/nono-c" (current-directory)))
            "-ld-options" ,(cond-expand (darwin "-Wl,-undefined,dynamic_lookup") (else "-ldl"))))
    (package-library-spec (current-directory) 'agentic-ai-lab roots
      admit-context: admit-production-build-context exclude: special-targets)
    ;; The process/AOT consumer supplies runtime symbols at final link time.
    `((gxc: "modules/workflow/runtime/runtime-v0-native" ,@ffi-options)
      (gxc: "modules/workflow/runtime/semantic" ,@ffi-options))))
