;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Public library roots projected through Core's installed native import graph.
(import (only-in :gerbil/expander expander-context-id)
        (only-in :yuanxu/module-system/building/source-closure package-library-spec))
(export agentic-ai-lab-public-build-roots agentic-ai-lab-library-spec)
(def special-targets '("modules/nono-sandbox/_nono"
                      "modules/workflow/runtime/runtime-v0-native"
                      "modules/workflow/runtime/semantic"))
(def agentic-ai-lab-public-build-roots
  ;; Visit FFI imports too; only the FFI targets' compiler options are special.
  (append (map (lambda (target) (string-append target ".ss")) special-targets)
   '("init.ss"
    "modules/workflow/scenario/bundle-v1-projection.ss"
    "testing-api.ss"
    ;; Public extension facades must be available after native installation.
    "modules/custom-task/interface.ss"
    "modules/docker/interface.ss"
    "modules/text/interface.ss"
    "modules/agent-sandbox/api.ss"
    ;; Shared public Type used by the OpenTofu Module must be installed.
    "modules/services/types.ss"
    "modules/ai-agentic-context/clue-exchange.ss"

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
)))

(def (admit-production-build-context context)
  (let* ((identity (expander-context-id context))
         (name (and (symbol? identity) (symbol->string identity))))
    (when (and name (string-prefix? "asp-gerbil-scheme/" name))
      (error "production build imports the development-only ASP package" identity))
    (when (and name (string-prefix? "agentic-ai-lab/dev/" name))
      (error "production build imports a development module" identity))))
(def (agentic-ai-lab-library-spec (roots agentic-ai-lab-public-build-roots))
  (package-library-spec (current-directory) 'agentic-ai-lab roots
    admit-context: admit-production-build-context exclude: special-targets))
