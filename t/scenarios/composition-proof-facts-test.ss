;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :core/observability/testing-case poo-flow-test-case)
         (only-in :std/test test-suite)
        :poo-flow/modules/proof/projections/composition-facts)

(def composition-proof-facts-test
  (test-suite "composition proof facts"
    (poo-flow-test-case "projects accepted and rejected composition facts"

(def (alist-ref key alist)
  (let ((entry (assq key alist)))
    (if entry
      (cdr entry)
      (error "missing composition proof fact key" key alist))))

(def (assert-equal label actual expected)
  (unless (equal? actual expected)
    (error "composition proof fact mismatch" label actual expected)))

(def accepted-facts
  (poo-flow-composition-contract->proof-facts
   'generated-langgraph-composition-receipt
   #t
   #t
   #t
   #t
   #t
   #f))

(assert-equal 'schema
              (alist-ref 'schema accepted-facts)
              'poo-flow.proof.composition.receipt)
(assert-equal 'fact-id
              (alist-ref 'fact-id accepted-facts)
              'generated-langgraph-composition-receipt)
(assert-equal 'profile-refs-ok (alist-ref 'profile-refs-ok accepted-facts) #t)
(assert-equal 'overrides-scoped-ok (alist-ref 'overrides-scoped-ok accepted-facts) #t)
(assert-equal 'modules-ordered-ok (alist-ref 'modules-ordered-ok accepted-facts) #t)
(assert-equal 'scenario-gate-ok (alist-ref 'scenario-gate-ok accepted-facts) #t)
(assert-equal 'no-runtime-execution
              (alist-ref 'no-runtime-execution accepted-facts)
              #t)
(assert-equal 'accepted? (alist-ref 'accepted? accepted-facts) #t)
(assert-equal 'rejection-rule (alist-ref 'rejection-rule accepted-facts) #f)
(assert-equal 'ffi-ready? (alist-ref 'ffi-ready? accepted-facts) #t)

(def bad-profile-refs-facts
  (poo-flow-composition-contract->proof-facts
   'generated-composition-bad-profile-refs
   #f
   #t
   #t
   #t
   #t
   'profile-refs))

(assert-equal 'bad-profile-refs-rule
              (alist-ref 'rejection-rule bad-profile-refs-facts)
              'composition-rejected-by-profile-refs)

(def bad-override-facts
  (poo-flow-composition-contract->proof-facts
   'generated-composition-bad-override
   #t
   #f
   #t
   #t
   #t
   'overrides))

(assert-equal 'bad-override-rule
              (alist-ref 'rejection-rule bad-override-facts)
              'composition-rejected-by-override-scope)

(def bad-module-order-facts
  (poo-flow-composition-contract->proof-facts
   'generated-composition-bad-module-order
   #t
   #t
   #f
   #t
   #t
   'module-order))

(assert-equal 'bad-module-order-rule
              (alist-ref 'rejection-rule bad-module-order-facts)
              'composition-rejected-by-module-order)

(def bad-scenario-gate-facts
  (poo-flow-composition-contract->proof-facts
   'generated-composition-bad-scenario-gate
   #t
   #t
   #t
   #f
   #t
   'scenario-gate))

(assert-equal 'bad-scenario-gate-rule
              (alist-ref 'rejection-rule bad-scenario-gate-facts)
              'composition-rejected-by-scenario-gate)

(def runtime-execution-facts
  (poo-flow-composition-contract->proof-facts
   'generated-composition-runtime-execution
   #t
   #t
   #t
   #t
   #f
   'runtime-execution))

(assert-equal 'runtime-execution-rule
              (alist-ref 'rejection-rule runtime-execution-facts)
              'composition-rejected-by-runtime-execution))))
