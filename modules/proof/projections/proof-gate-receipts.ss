;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Proof gate receipt projection.
;;; - Convert module receipts into bounded proof facts before bundling verifier inputs.
(import :agentic-ai-lab/modules/proof/projections/proof-gate-bundle
        :agentic-ai-lab/modules/proof/projections/composition-facts
        :agentic-ai-lab/modules/workflow/graph/control-plane-handoff-facts
        :agentic-ai-lab/modules/workflow/graph/scenario-gap-rejection-facts)

(export agentic-ai-lab-proof-receipt-ref
        agentic-ai-lab-composition-receipt->proof-facts
        agentic-ai-lab-scenario-gap-receipt->proof-facts
        agentic-ai-lab-control-plane-handoff-receipt->proof-facts
        agentic-ai-lab-proof-gate-receipts->bundle
        agentic-ai-lab-langgraph-user-interface-proof-receipts
        agentic-ai-lab-langgraph-user-interface-proof-gate-bundle)

;; : (-> Symbol Alist Object)
(def (agentic-ai-lab-proof-receipt-ref key receipt)
  (let ((entry (assq key receipt)))
    (if entry
      (cdr entry)
      (error "missing proof receipt key" key receipt))))

;; : (-> Symbol Alist Object Object)
(def (agentic-ai-lab-proof-receipt-ref/default key receipt default)
  (let ((entry (assq key receipt)))
    (if entry
      (cdr entry)
      default)))

;; : (-> Alist Object)
(def (agentic-ai-lab-composition-receipt-rejection receipt)
  (let ((explicit (agentic-ai-lab-proof-receipt-ref/default 'rejection receipt #f)))
    (if explicit
      explicit
      (cond
       ((not (agentic-ai-lab-proof-receipt-ref 'profile-refs-ok receipt))
        'profile-refs)
       ((not (agentic-ai-lab-proof-receipt-ref 'overrides-scoped-ok receipt))
        'overrides)
       ((not (agentic-ai-lab-proof-receipt-ref 'modules-ordered-ok receipt))
        'module-order)
       ((not (agentic-ai-lab-proof-receipt-ref 'scenario-gate-ok receipt))
        'scenario-gate)
       ((not (agentic-ai-lab-proof-receipt-ref 'no-runtime-execution receipt))
        'runtime-execution)
       (else #f)))))

;; : (-> Alist Object)
(def (agentic-ai-lab-scenario-gap-receipt-rejection receipt)
  (let ((explicit (agentic-ai-lab-proof-receipt-ref/default 'rejection receipt #f)))
    (if explicit
      explicit
      (cond
       ((not (agentic-ai-lab-proof-receipt-ref 'plan-ok receipt)) 'plan)
       ((not (agentic-ai-lab-proof-receipt-ref 'rejections-ok receipt)) 'rejections)
       ((not (agentic-ai-lab-proof-receipt-ref 'accepted-ok receipt)) 'accepted)
       (else #f)))))

;; : (-> Alist Object)
(def (agentic-ai-lab-control-plane-handoff-receipt-rejection receipt)
  (let ((explicit (agentic-ai-lab-proof-receipt-ref/default 'rejection receipt #f)))
    (if explicit
      explicit
      (cond
       ((not (agentic-ai-lab-proof-receipt-ref 'policy-ready receipt)) 'policy)
       ((not (agentic-ai-lab-proof-receipt-ref 'composition-accepted receipt))
        'composition)
       ((not (agentic-ai-lab-proof-receipt-ref 'graph-contract-ok receipt)) 'graph)
       ((not (agentic-ai-lab-proof-receipt-ref 'runtime-owner-external receipt))
        'runtime-owner)
       ((not (agentic-ai-lab-proof-receipt-ref 'execution-deferred receipt))
        'execution)
       ((not (agentic-ai-lab-proof-receipt-ref 'artifacts-declared receipt))
        'artifacts)
       (else #f)))))

;; : (-> Alist Alist)
(def (agentic-ai-lab-composition-receipt->proof-facts receipt)
  (agentic-ai-lab-composition-contract->proof-facts
   (agentic-ai-lab-proof-receipt-ref 'fact-id receipt)
   (agentic-ai-lab-proof-receipt-ref 'profile-refs-ok receipt)
   (agentic-ai-lab-proof-receipt-ref 'overrides-scoped-ok receipt)
   (agentic-ai-lab-proof-receipt-ref 'modules-ordered-ok receipt)
   (agentic-ai-lab-proof-receipt-ref 'scenario-gate-ok receipt)
   (agentic-ai-lab-proof-receipt-ref 'no-runtime-execution receipt)
   (agentic-ai-lab-composition-receipt-rejection receipt)))

;; : (-> Alist Alist)
(def (agentic-ai-lab-scenario-gap-receipt->proof-facts receipt)
  (agentic-ai-lab-scenario-gap-runtime-contract->proof-facts
   (agentic-ai-lab-proof-receipt-ref 'fact-id receipt)
   (agentic-ai-lab-proof-receipt-ref 'plan-ok receipt)
   (agentic-ai-lab-proof-receipt-ref 'rejections-ok receipt)
   (agentic-ai-lab-proof-receipt-ref 'accepted-ok receipt)
   (agentic-ai-lab-scenario-gap-receipt-rejection receipt)))

;; : (-> Alist Alist)
(def (agentic-ai-lab-control-plane-handoff-receipt->proof-facts receipt)
  (agentic-ai-lab-control-plane-handoff-contract->proof-facts
   (agentic-ai-lab-proof-receipt-ref 'fact-id receipt)
   (agentic-ai-lab-proof-receipt-ref 'policy-ready receipt)
   (agentic-ai-lab-proof-receipt-ref 'composition-accepted receipt)
   (agentic-ai-lab-proof-receipt-ref 'graph-contract-ok receipt)
   (agentic-ai-lab-proof-receipt-ref 'runtime-owner-external receipt)
   (agentic-ai-lab-proof-receipt-ref 'execution-deferred receipt)
   (agentic-ai-lab-proof-receipt-ref 'artifacts-declared receipt)
   (agentic-ai-lab-control-plane-handoff-receipt-rejection receipt)))

;; : (-> Alist Alist)
(def (agentic-ai-lab-proof-gate-receipts->bundle receipts)
  (agentic-ai-lab-proof-gate-bundle
   (agentic-ai-lab-composition-receipt->proof-facts
    (agentic-ai-lab-proof-receipt-ref 'composition receipts))
   (agentic-ai-lab-scenario-gap-receipt->proof-facts
    (agentic-ai-lab-proof-receipt-ref 'scenario receipts))
   (agentic-ai-lab-control-plane-handoff-receipt->proof-facts
    (agentic-ai-lab-proof-receipt-ref 'handoff receipts))))

;; : (-> Alist)
(def (agentic-ai-lab-langgraph-user-interface-proof-receipts)
  (list (cons 'schema 'agentic-ai-lab.user-interface.langgraph.proof-receipts)
        (cons 'composition
              (list (cons 'fact-id 'langgraph-user-interface-composition)
                    (cons 'profile-refs-ok #t)
                    (cons 'overrides-scoped-ok #t)
                    (cons 'modules-ordered-ok #t)
                    (cons 'scenario-gate-ok #t)
                    (cons 'no-runtime-execution #t)))
        (cons 'scenario
              (list (cons 'fact-id 'langgraph-user-interface-scenario)
                    (cons 'plan-ok #t)
                    (cons 'rejections-ok #t)
                    (cons 'accepted-ok #t)))
        (cons 'handoff
              (list (cons 'fact-id 'langgraph-user-interface-handoff)
                    (cons 'policy-ready #t)
                    (cons 'composition-accepted #t)
                    (cons 'graph-contract-ok #t)
                    (cons 'runtime-owner-external #t)
                    (cons 'execution-deferred #t)
                    (cons 'artifacts-declared #t)))))

;; : (-> Alist)
(def (agentic-ai-lab-langgraph-user-interface-proof-gate-bundle)
  (agentic-ai-lab-proof-gate-receipts->bundle
   (agentic-ai-lab-langgraph-user-interface-proof-receipts)))
