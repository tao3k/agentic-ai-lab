;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Composition proof fact projection owned by the Proof boundary.
;;; - Keep bounded proof rows separate from module execution and runtime handoff.

(export poo-flow-composition-contract->proof-facts)

;;; Rejection symbols are normalized into proof-facing rule identifiers.
;; : (-> Symbol Symbol)
(def (poo-flow-composition-rejection-rule failure)
  (let (entry
        (assq failure
              '((profile-refs . composition-rejected-by-profile-refs)
                (overrides . composition-rejected-by-override-scope)
                (module-order . composition-rejected-by-module-order)
                (scenario-gate . composition-rejected-by-scenario-gate)
                (runtime-execution . composition-rejected-by-runtime-execution))))
    (if entry
      (cdr entry)
      (error "unknown composition proof failure" failure))))

;;; Acceptance is a pure boolean fold over composition contract gates.
;; : (-> Boolean Boolean Boolean Boolean Boolean Boolean)
(def (poo-flow-composition-contract-accepted?
      profile-refs-ok
      overrides-scoped-ok
      modules-ordered-ok
      scenario-gate-ok
      no-runtime-execution)
  (and profile-refs-ok
       (andmap (lambda (gate) gate)
               (list overrides-scoped-ok
                     modules-ordered-ok
                     scenario-gate-ok
                     no-runtime-execution))))

;;; Proof facts stay as bounded rows for Lean/FFI handoff.
;; : (forall (id rule) (-> id Boolean Boolean Boolean Boolean Boolean rule Alist))
;; : (-> Symbol Boolean Boolean Boolean Boolean Boolean Symbol Alist)
(def (poo-flow-composition-contract->proof-facts
      fact-id
      profile-refs-ok
      overrides-scoped-ok
      modules-ordered-ok
      scenario-gate-ok
      no-runtime-execution
      rejection)
  (let ((accepted?
         (poo-flow-composition-contract-accepted?
          profile-refs-ok
          overrides-scoped-ok
          modules-ordered-ok
          scenario-gate-ok
          no-runtime-execution)))
    (foldr cons
           '()
           (list (cons 'schema 'poo-flow.proof.composition.receipt)
                 (cons 'fact-id fact-id)
                 (cons 'profile-refs-ok profile-refs-ok)
                 (cons 'overrides-scoped-ok overrides-scoped-ok)
                 (cons 'modules-ordered-ok modules-ordered-ok)
                 (cons 'scenario-gate-ok scenario-gate-ok)
                 (cons 'no-runtime-execution no-runtime-execution)
                 (cons 'accepted? accepted?)
                 (cons 'rejection rejection)
                 (cons 'rejection-rule
                       (if accepted?
                         #f
                         (poo-flow-composition-rejection-rule rejection)))
                 (cons 'ffi-ready? #t)))))
