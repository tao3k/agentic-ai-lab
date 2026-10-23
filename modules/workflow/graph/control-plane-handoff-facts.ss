;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Control-plane handoff proof fact projection.
;;; - Keep serialized proof facts stable while control-plane objects evolve upstream.
(export agentic-ai-lab-control-plane-handoff-contract->proof-facts)

;;; Static failure mapping remains data so proof-rule additions do not add branch depth.
(def +agentic-ai-lab-control-plane-handoff-rejection-rules+
  '((policy . control-plane-handoff-rejected-by-policy)
    (composition . control-plane-handoff-rejected-by-composition)
    (graph . control-plane-handoff-rejected-by-graph)
    (runtime-owner . control-plane-handoff-rejected-by-runtime-owner)
    (execution . control-plane-handoff-rejected-by-execution)
    (artifacts . control-plane-handoff-rejected-by-artifacts)))

;;; Boundary: rejection-rule symbols are stable proof atoms consumed by Lean/FFI fact rows.
;;; Risk: unknown failures must stop projection instead of silently producing an invalid proof rule.
;; : (-> ControlPlaneHandoffFailure ControlPlaneHandoffRejectionRule)
(def (agentic-ai-lab-control-plane-handoff-rejection-rule failure)
  (let (matches
        (filter (lambda (row) (eq? failure (car row)))
                +agentic-ai-lab-control-plane-handoff-rejection-rules+))
    (if (null? matches)
      (error "unknown control-plane handoff proof failure" failure)
      (cdr (car matches)))))

;;; Invariant: the handoff is accepted only when every boundary gate has accepted.
;;; Intent: keep the acceptance predicate separate from rejection-rule attribution.
;; : (-> PolicyGateReady? CompositionAccepted? GraphContractOk? RuntimeOwnerExternal? ExecutionDeferred? ArtifactsDeclared? HandoffAccepted?)
(def (agentic-ai-lab-control-plane-handoff-contract-accepted?
      policy-ready
      composition-accepted
      graph-contract-ok
      runtime-owner-external
      execution-deferred
      artifacts-declared)
  (and policy-ready
       composition-accepted
       graph-contract-ok
       runtime-owner-external
       (foldr (lambda (gate accepted?)
                (and gate accepted?))
              #t
              (list execution-deferred artifacts-declared))))

;;; Boundary: this is the bounded alist projection for the external proof/runtime handoff.
;;; Optimization: internal control-plane objects stay upstream; only serialized proof fields cross this ABI.
;; : (-> ProofFactId PolicyGateReady? CompositionAccepted? GraphContractOk? RuntimeOwnerExternal? ExecutionDeferred? ArtifactsDeclared? ControlPlaneHandoffFailure ControlPlaneHandoffProofFacts)
(def (agentic-ai-lab-control-plane-handoff-contract->proof-facts
      fact-id
      policy-ready
      composition-accepted
      graph-contract-ok
      runtime-owner-external
      execution-deferred
      artifacts-declared
      rejection)
  (let ((accepted?
         (agentic-ai-lab-control-plane-handoff-contract-accepted?
          policy-ready
          composition-accepted
          graph-contract-ok
          runtime-owner-external
          execution-deferred
          artifacts-declared)))
    (foldr cons
           (list
            (cons 'rejection-rule
                  (if accepted?
                    #f
                    (agentic-ai-lab-control-plane-handoff-rejection-rule rejection)))
            (cons 'ffi-ready? #t))
           (list (cons 'schema 'agentic-ai-lab.proof.control-plane.handoff)
                 (cons 'fact-id fact-id)
                 (cons 'policy-ready policy-ready)
                 (cons 'composition-accepted composition-accepted)
                 (cons 'graph-contract-ok graph-contract-ok)
                 (cons 'runtime-owner-external runtime-owner-external)
                 (cons 'execution-deferred execution-deferred)
                 (cons 'artifacts-declared artifacts-declared)
                 (cons 'accepted? accepted?)
                 (cons 'rejection rejection)))))
