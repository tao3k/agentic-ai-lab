;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Scenario-gap runtime rejection proof facts.
;;; - Keep runtime-row proof receipts stable while scenario planning remains object/native upstream.
(export poo-flow-scenario-gap-runtime-contract->proof-facts)

;;; Static failure mapping keeps runtime-row proof ABI changes data-driven.
(def +poo-flow-scenario-gap-rejection-rules+
  '((plan . runtime-row-rejected-by-plan)
    (rejections . runtime-row-rejected-by-rejections)
    (accepted . runtime-row-rejected-by-accepted)))

;;; Boundary: runtime-row rejection rules are serialized proof atoms, not planner internals.
;;; Risk: unknown failure gates must fail fast before emitting an invalid proof receipt.
;; : (-> ScenarioGapRuntimeFailure ScenarioGapRuntimeRejectionRule)
(def (poo-flow-scenario-gap-rejection-rule failure)
  (let (matches
        (filter (lambda (row) (eq? failure (car row)))
                +poo-flow-scenario-gap-rejection-rules+))
    (if (null? matches)
      (error "unknown scenario gap rejection failure" failure)
      (cdr (car matches)))))

;;; Boundary: this bounded alist is the scenario-gap proof ABI for runtime-row checks.
;;; Optimization: runtime planning remains object/native upstream; proof handoff receives stable fields only.
;; : (-> ProofFactId ScenarioGapPlanOk? ScenarioGapRejectionsOk? ScenarioGapAcceptedOk? ScenarioGapRuntimeFailure ScenarioGapRuntimeProofFacts)
(def (poo-flow-scenario-gap-runtime-contract->proof-facts
      fact-id
      plan-ok
      rejections-ok
      accepted-ok
      failure)
  (let ((accepted? (foldr (lambda (gate accepted?)
                            (and gate accepted?))
                          #t
                          (list plan-ok rejections-ok accepted-ok))))
    (foldr cons
           (list
            (cons 'rejection-rule
                  (if accepted?
                    #f
                    (poo-flow-scenario-gap-rejection-rule failure)))
            (cons 'ffi-ready? #t))
           (list (cons 'schema 'poo-flow.proof.scenario-gap.runtime-row)
                 (cons 'fact-id fact-id)
                 (cons 'plan-ok plan-ok)
                 (cons 'rejections-ok rejections-ok)
                 (cons 'accepted-ok accepted-ok)
                 (cons 'accepted? accepted?)
                 (cons 'rejection failure)))))
