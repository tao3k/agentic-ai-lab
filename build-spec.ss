;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Public library roots projected through Core's installed runtime import graph.
;;; Explicit library requests complement an init-owned Module projection.
;;; Explicit library callers own their requested roots. Package installation
;;; supplies an empty library specification.
(import (only-in :gerbil/expander expander-context-id)
        (only-in :yuanxu/module-system/building/source-closure package-library-spec))
(export agentic-ai-lab-public-build-roots agentic-ai-lab-build-spec)
(def agentic-ai-lab-public-build-roots
  ;; Retained package-library entries migrate only after selected-owner coverage.
  ;; Nix's Interface/roles/public progress library now come from its selected
  ;; publication and Build role. Core closes native imports without duplicates.
  ;; Context's Memory Interface is collected by the selected Feature.
  ;; This ordinary public library has a native package root, not a Module
  ;; selection request. Do not initialize the application source registry and
  ;; its collection/policy objects to reconstruct this constant entrypoint.
  ;; Gerbil still discovers every transitive source through the roots below.
  '("modules/workflow/scenario/configuration/declaration-case.ss"
    "modules/agent-sandbox/interface.ss"
    "modules/ai-agentic-context/funs.ss"
    "modules/authorization/interface.ss"
    "modules/authorization/providers/cedar/interface.ss"
    "modules/building/interface.ss"
    "modules/cubeSandbox/interface.ss"
    "modules/custom-task/interface.ss"
    "modules/docker-sandbox/interface.ss"
    "modules/docker/interface.ss"
    "modules/evidence-assessment/interface.ss"
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
    "modules/workflow/cicd-config.ss"
    "modules/workflow/flows-builders.ss"
    "modules/workflow/flows-alignment-report.ss"
    "modules/workflow/profiles/kernel/interface.ss"
    "modules/workflow/scenario/configuration/presentation-config.ss"

    ;; Standalone public/embedded APIs and compiler-option owners.
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
    "modules/workflow/runtime/runtime-v0-ffi.ss"
    "modules/workflow/runtime/semantic.ss"))

(def (admit-production-build-context context)
  (let* ((identity (expander-context-id context))
         (name (and (symbol? identity) (symbol->string identity))))
    (when (and name (string-prefix? "asp-gerbil-scheme/" name))
      (error "production build imports the development-only ASP package" identity))
    (when (and name (string-prefix? "agentic-ai-lab/dev/" name))
      (error "production build imports a development module" identity))))
(def (agentic-ai-lab-build-spec (roots agentic-ai-lab-public-build-roots)
                                observe-context: (observe-context void))
  (def ffi-options
    (cond-expand (darwin '("-ld-options" "-Wl,-undefined,dynamic_lookup")) (else '())))
  ;; Preserve compiler options for every demanded special target, including a
  ;; transitive import. Unselected targets contribute neither files nor options.
  (map
    (lambda (target)
      (cond
        ((equal? target "modules/nono-sandbox/_nono")
         `(gxc: ,target
                "-cc-options" ,(string-append "-I" (path-expand "bindings/nono-c" (current-directory)))
                "-ld-options" ,(cond-expand (darwin "-Wl,-undefined,dynamic_lookup") (else "-ldl"))))
        ((member target '("modules/workflow/runtime/runtime-v0-ffi" "modules/workflow/runtime/semantic"))
         `(gxc: ,target ,@ffi-options))
        (else target)))
    (package-library-spec (current-directory) 'agentic-ai-lab roots
      admit-context:
      (lambda (context)
        (admit-production-build-context context)
        (observe-context context)))))
