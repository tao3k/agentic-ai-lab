;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Proof gate receipt projection.
;;; - Convert module receipts into bounded proof facts before bundling verifier inputs.
(import :poo-flow/modules/proof/projections/proof-gate-bundle
        :poo-flow/modules/proof/projections/composition-facts
        :poo-flow/modules/workflow/graph/control-plane-handoff-facts
        :poo-flow/modules/workflow/graph/scenario-gap-rejection-facts)

(export poo-flow-proof-receipt-ref
        poo-flow-composition-receipt->proof-facts
        poo-flow-scenario-gap-receipt->proof-facts
        poo-flow-control-plane-handoff-receipt->proof-facts
        poo-flow-proof-gate-receipts->bundle
        poo-flow-langgraph-user-interface-proof-receipts
        poo-flow-langgraph-user-interface-proof-gate-bundle)

;; : (-> Symbol Alist Object)
(def (poo-flow-proof-receipt-ref key receipt)
  (let ((entry (assq key receipt)))
    (if entry
      (cdr entry)
      (error "missing proof receipt key" key receipt))))

;; : (-> Symbol Alist Object Object)
(def (poo-flow-proof-receipt-ref/default key receipt default)
  (let ((entry (assq key receipt)))
    (if entry
      (cdr entry)
      default)))

;; : (-> Alist Object)
(def (poo-flow-composition-receipt-rejection receipt)
  (let ((explicit (poo-flow-proof-receipt-ref/default 'rejection receipt #f)))
    (if explicit
      explicit
      (cond
       ((not (poo-flow-proof-receipt-ref 'profile-refs-ok receipt))
        'profile-refs)
       ((not (poo-flow-proof-receipt-ref 'overrides-scoped-ok receipt))
        'overrides)
       ((not (poo-flow-proof-receipt-ref 'modules-ordered-ok receipt))
        'module-order)
       ((not (poo-flow-proof-receipt-ref 'scenario-gate-ok receipt))
        'scenario-gate)
       ((not (poo-flow-proof-receipt-ref 'no-runtime-execution receipt))
        'runtime-execution)
       (else #f)))))

;; : (-> Alist Object)
(def (poo-flow-scenario-gap-receipt-rejection receipt)
  (let ((explicit (poo-flow-proof-receipt-ref/default 'rejection receipt #f)))
    (if explicit
      explicit
      (cond
       ((not (poo-flow-proof-receipt-ref 'plan-ok receipt)) 'plan)
       ((not (poo-flow-proof-receipt-ref 'rejections-ok receipt)) 'rejections)
       ((not (poo-flow-proof-receipt-ref 'accepted-ok receipt)) 'accepted)
       (else #f)))))

;; : (-> Alist Object)
(def (poo-flow-control-plane-handoff-receipt-rejection receipt)
  (let ((explicit (poo-flow-proof-receipt-ref/default 'rejection receipt #f)))
    (if explicit
      explicit
      (cond
       ((not (poo-flow-proof-receipt-ref 'policy-ready receipt)) 'policy)
       ((not (poo-flow-proof-receipt-ref 'composition-accepted receipt))
        'composition)
       ((not (poo-flow-proof-receipt-ref 'graph-contract-ok receipt)) 'graph)
       ((not (poo-flow-proof-receipt-ref 'runtime-owner-external receipt))
        'runtime-owner)
       ((not (poo-flow-proof-receipt-ref 'execution-deferred receipt))
        'execution)
       ((not (poo-flow-proof-receipt-ref 'artifacts-declared receipt))
        'artifacts)
       (else #f)))))

;; : (-> Alist Alist)
(def (poo-flow-composition-receipt->proof-facts receipt)
  (poo-flow-composition-contract->proof-facts
   (poo-flow-proof-receipt-ref 'fact-id receipt)
   (poo-flow-proof-receipt-ref 'profile-refs-ok receipt)
   (poo-flow-proof-receipt-ref 'overrides-scoped-ok receipt)
   (poo-flow-proof-receipt-ref 'modules-ordered-ok receipt)
   (poo-flow-proof-receipt-ref 'scenario-gate-ok receipt)
   (poo-flow-proof-receipt-ref 'no-runtime-execution receipt)
   (poo-flow-composition-receipt-rejection receipt)))

;; : (-> Alist Alist)
(def (poo-flow-scenario-gap-receipt->proof-facts receipt)
  (poo-flow-scenario-gap-runtime-contract->proof-facts
   (poo-flow-proof-receipt-ref 'fact-id receipt)
   (poo-flow-proof-receipt-ref 'plan-ok receipt)
   (poo-flow-proof-receipt-ref 'rejections-ok receipt)
   (poo-flow-proof-receipt-ref 'accepted-ok receipt)
   (poo-flow-scenario-gap-receipt-rejection receipt)))

;; : (-> Alist Alist)
(def (poo-flow-control-plane-handoff-receipt->proof-facts receipt)
  (poo-flow-control-plane-handoff-contract->proof-facts
   (poo-flow-proof-receipt-ref 'fact-id receipt)
   (poo-flow-proof-receipt-ref 'policy-ready receipt)
   (poo-flow-proof-receipt-ref 'composition-accepted receipt)
   (poo-flow-proof-receipt-ref 'graph-contract-ok receipt)
   (poo-flow-proof-receipt-ref 'runtime-owner-external receipt)
   (poo-flow-proof-receipt-ref 'execution-deferred receipt)
   (poo-flow-proof-receipt-ref 'artifacts-declared receipt)
   (poo-flow-control-plane-handoff-receipt-rejection receipt)))

;; : (-> Alist Alist)
(def (poo-flow-proof-gate-receipts->bundle receipts)
  (poo-flow-proof-gate-bundle
   (poo-flow-composition-receipt->proof-facts
    (poo-flow-proof-receipt-ref 'composition receipts))
   (poo-flow-scenario-gap-receipt->proof-facts
    (poo-flow-proof-receipt-ref 'scenario receipts))
   (poo-flow-control-plane-handoff-receipt->proof-facts
    (poo-flow-proof-receipt-ref 'handoff receipts))))

;; : (-> Alist)
(def (poo-flow-langgraph-user-interface-proof-receipts)
  (list (cons 'schema 'poo-flow.user-interface.langgraph.proof-receipts)
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
(def (poo-flow-langgraph-user-interface-proof-gate-bundle)
  (poo-flow-proof-gate-receipts->bundle
   (poo-flow-langgraph-user-interface-proof-receipts)))
