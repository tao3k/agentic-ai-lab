;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :core/observability/testing-case poo-flow-test-case)
         (only-in :std/test test-suite)
        :poo-flow/modules/workflow/graph/control-plane-handoff-facts)

(def control-plane-handoff-facts-test
  (test-suite "control-plane handoff facts"
    (poo-flow-test-case "projects accepted and rejected handoff facts"

(def (alist-ref key alist)
  (let ((entry (assq key alist)))
    (if entry
      (cdr entry)
      (error "missing control-plane handoff proof fact key" key alist))))

(def (assert-equal label actual expected)
  (unless (equal? actual expected)
    (error "control-plane handoff proof fact mismatch" label actual expected)))

(def accepted-facts
  (poo-flow-control-plane-handoff-contract->proof-facts
   'generated-langgraph-control-plane-handoff
   #t
   #t
   #t
   #t
   #t
   #t
   #f))

(assert-equal 'schema
              (alist-ref 'schema accepted-facts)
              'poo-flow.proof.control-plane.handoff)
(assert-equal 'fact-id
              (alist-ref 'fact-id accepted-facts)
              'generated-langgraph-control-plane-handoff)
(assert-equal 'policy-ready (alist-ref 'policy-ready accepted-facts) #t)
(assert-equal 'composition-accepted (alist-ref 'composition-accepted accepted-facts) #t)
(assert-equal 'graph-contract-ok (alist-ref 'graph-contract-ok accepted-facts) #t)
(assert-equal 'runtime-owner-external
              (alist-ref 'runtime-owner-external accepted-facts)
              #t)
(assert-equal 'execution-deferred (alist-ref 'execution-deferred accepted-facts) #t)
(assert-equal 'artifacts-declared (alist-ref 'artifacts-declared accepted-facts) #t)
(assert-equal 'accepted? (alist-ref 'accepted? accepted-facts) #t)
(assert-equal 'rejection-rule (alist-ref 'rejection-rule accepted-facts) #f)
(assert-equal 'ffi-ready? (alist-ref 'ffi-ready? accepted-facts) #t)

(def runtime-owned-here-facts
  (poo-flow-control-plane-handoff-contract->proof-facts
   'generated-runtime-owned-here-handoff
   #t
   #t
   #t
   #f
   #t
   #t
   'runtime-owner))

(assert-equal 'runtime-owned-here-rule
              (alist-ref 'rejection-rule runtime-owned-here-facts)
              'control-plane-handoff-rejected-by-runtime-owner)

(def runtime-executed-here-facts
  (poo-flow-control-plane-handoff-contract->proof-facts
   'generated-runtime-executed-here-handoff
   #t
   #t
   #t
   #t
   #f
   #t
   'execution))

(assert-equal 'runtime-executed-here-rule
              (alist-ref 'rejection-rule runtime-executed-here-facts)
              'control-plane-handoff-rejected-by-execution))))
