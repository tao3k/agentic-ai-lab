;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Proof gate bundle construction and validation.
;;; - Keep composition, scenario, and handoff proof wires joined at one bounded gate boundary.
(import :agentic-ai-lab/modules/proof/projections/proof-fact-wire
        :agentic-ai-lab/modules/proof/projections/composition-facts
        :agentic-ai-lab/modules/workflow/graph/control-plane-handoff-facts
        :agentic-ai-lab/modules/workflow/graph/scenario-gap-rejection-facts)

(export agentic-ai-lab-proof-wire-field-ref
        agentic-ai-lab-proof-gate-bundle
        agentic-ai-lab-proof-gate-bundle-valid?
        agentic-ai-lab-langgraph-proof-gate-bundle
        agentic-ai-lab-langgraph-runtime-owner-rejected-bundle
        agentic-ai-lab-langgraph-missing-capability-rejected-bundle)

;; : (-> Symbol Alist Object)
(def (agentic-ai-lab-proof-wire-field-ref key wire)
  (let ((entry (assq key (agentic-ai-lab-proof-fact-ref 'fields wire))))
    (if entry
      (cdr entry)
      (error "missing proof wire field" key wire))))

;; : (-> Alist Boolean)
(def (agentic-ai-lab-proof-wire-accepted? wire)
  (agentic-ai-lab-proof-fact-ref 'accepted? wire))

;; : (-> Alist Boolean)
(def (agentic-ai-lab-proof-gate-runtime-boundary-ok? handoff-wire)
  (and (agentic-ai-lab-proof-wire-field-ref 'runtime-owner-external handoff-wire)
       (agentic-ai-lab-proof-wire-field-ref 'execution-deferred handoff-wire)))

;; : (-> Alist Alist Alist Alist)
(def (agentic-ai-lab-proof-gate-bundle composition-facts scenario-facts handoff-facts)
  (let* ((composition-wire (agentic-ai-lab-proof-facts->ffi-wire composition-facts))
         (scenario-wire (agentic-ai-lab-proof-facts->ffi-wire scenario-facts))
         (handoff-wire (agentic-ai-lab-proof-facts->ffi-wire handoff-facts))
         (runtime-boundary-ok?
          (agentic-ai-lab-proof-gate-runtime-boundary-ok? handoff-wire))
         (accepted?
          (and (agentic-ai-lab-proof-wire-accepted? composition-wire)
               (agentic-ai-lab-proof-wire-accepted? scenario-wire)
               (agentic-ai-lab-proof-wire-accepted? handoff-wire)
               runtime-boundary-ok?)))
    (list (cons 'schema 'agentic-ai-lab.proof.gate.bundle)
          (cons 'version 1)
          (cons 'composition composition-wire)
          (cons 'scenario scenario-wire)
          (cons 'handoff handoff-wire)
          (cons 'runtime-boundary-ok? runtime-boundary-ok?)
          (cons 'accepted? accepted?))))

;; : (-> Alist Boolean)
(def (agentic-ai-lab-proof-gate-bundle-valid? bundle)
  (and (eq? (agentic-ai-lab-proof-fact-ref 'schema bundle)
            'agentic-ai-lab.proof.gate.bundle)
       (equal? (agentic-ai-lab-proof-fact-ref 'version bundle) 1)
       (agentic-ai-lab-proof-facts-ffi-wire-valid?
        (agentic-ai-lab-proof-fact-ref 'composition bundle))
       (agentic-ai-lab-proof-facts-ffi-wire-valid?
        (agentic-ai-lab-proof-fact-ref 'scenario bundle))
       (agentic-ai-lab-proof-facts-ffi-wire-valid?
        (agentic-ai-lab-proof-fact-ref 'handoff bundle))))

;; : (-> Alist)
(def (agentic-ai-lab-langgraph-composition-facts)
  (agentic-ai-lab-composition-contract->proof-facts
   'langgraph-composition
   #t #t #t #t #t #f))

;; : (-> Alist)
(def (agentic-ai-lab-langgraph-scenario-facts)
  (agentic-ai-lab-scenario-gap-runtime-contract->proof-facts
   'langgraph-scenario-gap
   #t #t #t #f))

;; : (-> Alist)
(def (agentic-ai-lab-langgraph-handoff-facts)
  (agentic-ai-lab-control-plane-handoff-contract->proof-facts
   'langgraph-control-plane-handoff
   #t #t #t #t #t #t #f))

;; : (-> Alist)
(def (agentic-ai-lab-langgraph-proof-gate-bundle)
  (agentic-ai-lab-proof-gate-bundle
   (agentic-ai-lab-langgraph-composition-facts)
   (agentic-ai-lab-langgraph-scenario-facts)
   (agentic-ai-lab-langgraph-handoff-facts)))

;; : (-> Alist)
(def (agentic-ai-lab-langgraph-runtime-owner-rejected-bundle)
  (agentic-ai-lab-proof-gate-bundle
   (agentic-ai-lab-langgraph-composition-facts)
   (agentic-ai-lab-langgraph-scenario-facts)
   (agentic-ai-lab-control-plane-handoff-contract->proof-facts
    'langgraph-runtime-owned-here
    #t #t #t #f #t #t 'runtime-owner)))

;; : (-> Alist)
(def (agentic-ai-lab-langgraph-missing-capability-rejected-bundle)
  (agentic-ai-lab-proof-gate-bundle
   (agentic-ai-lab-langgraph-composition-facts)
   (agentic-ai-lab-scenario-gap-runtime-contract->proof-facts
    'langgraph-scenario-missing-capability
    #t #t #f 'accepted)
   (agentic-ai-lab-langgraph-handoff-facts)))
