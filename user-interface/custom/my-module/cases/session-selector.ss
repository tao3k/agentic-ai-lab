;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: downstream selector receipt case.
;;; Invariant: selector declarations stay pending receipts; Marlin owns model
;;; scoring, workflow dispatch, and selected-result materialization.

(import :agentic-ai-lab/modules/session/syntax)

(export agentic-ai-lab-custom-my-module-session-selector-case)

(def agentic-ai-lab-custom-my-module-session-selector-case
  (agentic-ai-lab-session-cases
  (session-case custom-session-selector-case
    (metadata (source . user-interface)
              (case . session-selector))
    (objects
     (build-candidate
      (session-selector-candidate candidate/build
        (kind transform)
        (target transform/build-agent)
        (description "Run the build sub-agent transform.")
        (requires derived-session handoff-intent)
        (metadata (source . user-interface)
                  (case . session-selector))))
     (audit-candidate
      (session-selector-candidate candidate/audit
        (kind workflow)
        (target workflow/audit-build)
        (description "Audit build output and diagnostics.")
        (requires runtime-handoff diagnostics)
        (metadata (source . user-interface)
                  (case . session-selector))))
     (governor-candidate
      (session-selector-candidate candidate/governor
        (kind agent-param)
        (target agent-param/custom-build)
        (description
         "Ask the policy governor to decide whether the branch is safe.")
        (requires validation-valid? validation-diagnostic-count)
        (metadata (source . user-interface)
                  (case . session-selector))))
     (selector-receipt
      (session-selector selector/custom-router
        (project custom/project)
        (root custom/root-session)
        (input custom/root-session)
        (candidates build-candidate audit-candidate governor-candidate)
        (policy
         (strategy . llm-router)
         (judge-inputs . (parent-summary last-failure build-report))
         (workflow-target-refs . (workflow/audit-build))
         (transform-target-refs . (transform/build-agent))
         (agent-param-target-refs . (agent-param/custom-build))
         (external-fallback-refs . (empty-workflow))
         (result-contract . workflow-or-transform-ref))
        (fallback empty-workflow)
        (metadata (source . user-interface)
                  (case . session-selector)))))
    (rows (session-selector-row selector-receipt)))))
