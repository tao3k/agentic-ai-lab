;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Public library roots projected through Core's installed native import graph.
;;; init.ss owns the selected Module spec through init.exports; it is not a
;;; library target or an import-graph root here.
(import (only-in :clan/poo/object .get .call)
        (only-in :gerbil/expander expander-context-id)
        (only-in :std/source this-source-file)
        (only-in :yuanxu/module-system/building/source-closure package-library-spec))
(export agentic-ai-lab-public-build-roots agentic-ai-lab-build-spec
        agentic-ai-lab-native-build-spec agentic-ai-lab-test-exclusions
        agentic-ai-lab-context-test-demand)
(def agentic-ai-lab-test-exclusions
  ;; One ordinary-suite inventory serves Gerbil build declarations and execution.
  '("qualification/ascent-integration" "qualification/temporal-mrr-native"
    "performance" "qualification/healthcare-fhir-reference-validator"
    "qualification/healthcare-fhirpath-syntax" "qualification/healthcare-hl7v2-migration"
    "qualification/standards-multi-industry" "module-system-poo-performance-test-support"))
(def agentic-ai-lab-public-build-roots
  ;; Native library facades only. Nix and OpenTofu interface declarations
  ;; require the selected role wrappers owned by init.exports.std-make-spec;
  ;; importing those authored declarations as standalone libraries is invalid.
  ;; Core projects the shared native import closure without duplicate targets.
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
    "modules/nono-sandbox/interface.ss"
    "modules/proof/interface.ss"
    "modules/query/interface.ss"
    "modules/query/results/interface.ss"
    "modules/sandbox-core/interface.ss"
    "modules/search-engine/interface.ss"
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
    "modules/ai-agentic-context/query-provider.ss"
    "modules/session/funs-identity.ss"
    "modules/temporal-causality/runtime/policy-clock.ss"
    "modules/ai-agentic-context/durable-owner.ss"
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
(def (agentic-ai-lab-native-build-spec)
  ;; Production and native test support share these exact FFI declarations.
  ;; Resolve against this owner, independently of a caller's working directory.
  (def ffi-options
    (cond-expand (darwin '("-ld-options" "-Wl,-undefined,dynamic_lookup")) (else '())))
  `((gxc: "modules/nono-sandbox/_nono"
      "-cc-options" ,(string-append "-I" (path-expand "bindings/nono-c" (path-directory (this-source-file))))
      "-ld-options" ,(cond-expand (darwin "-Wl,-undefined,dynamic_lookup") (else "-ldl")))
    ;; The process/AOT consumer supplies these symbols at final link time.
    (gxc: "modules/workflow/runtime/runtime-v0-native" ,@ffi-options)
    (gxc: "modules/workflow/runtime/semantic" ,@ffi-options)))
(def (agentic-ai-lab-build-spec (roots agentic-ai-lab-public-build-roots))
  (def native (agentic-ai-lab-native-build-spec))
  (append (list (car native))
    (package-library-spec (current-directory) 'agentic-ai-lab roots
      admit-context: admit-production-build-context exclude: special-targets)
    (cdr native)))

;; Build and execution demand the same init-owned native program. The program
;; publishes the original Suites and the official Gerbil Harness entrypoint.
(def (agentic-ai-lab-context-test-demand exports)
  (def root (path-directory (this-source-file)))
  (.call (.get exports tests) .for-files
    (list (path-expand "t/qualification/context-temporal/interface.ss" root))
    (map (cut path-expand <> root)
      '("build-spec.ss" "qualification-build.ss" "context-build.ss"
        "t/qualification/testing/specialized.ss"
        "packages/python-runtime/tools/watch.py"
        "dev/modules/testing/native-test-observation.ss"))
    '((exe: "t/qualification/context-temporal/interface" bin: "context-temporal-test"))))
